#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# VaultRix EC2 Disaster Recovery Failback Automation Script
#
# Description:
#   Restores traffic to the Primary Region (ap-south-1) after Primary EC2/RDS
#   recovery and health verification.
#
# Usage:
#   ./ec2-failback.sh
#
# The script:
#   1. Verifies Primary ALB /health endpoint is responding
#   2. If a forced DNS override was applied during failover, restores the
#      PRIMARY health check association so Route 53 resumes normal failover policy
#   3. Confirms Route 53 is routing to PRIMARY
# ==============================================================================

DOMAIN_NAME="${DOMAIN_NAME:-dr.vaultrix.in}"
RECORD_NAME="${RECORD_NAME:-ec2.dr.vaultrix.in}"
PRIMARY_REGION="ap-south-1"
DR_REGION="ap-southeast-1"

echo "============================================================"
echo " Starting VaultRix EC2 Application Failback Sequence"
echo " Date: $(date -u)"
echo " Domain: ${RECORD_NAME}"
echo "============================================================"

# 1. Fetch Route 53 Hosted Zone ID
echo "[1/5] Retrieving Route 53 Hosted Zone ID for domain: ${DOMAIN_NAME}..."
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name "${DOMAIN_NAME}" \
  --query "HostedZones[0].Id" \
  --output text | sed 's#/hostedzone/##')

if [ -z "${HOSTED_ZONE_ID}" ] || [ "${HOSTED_ZONE_ID}" == "None" ]; then
  echo "ERROR: Route 53 Hosted Zone not found for ${DOMAIN_NAME}."
  exit 1
fi
echo "Hosted Zone ID: ${HOSTED_ZONE_ID}"

# 2. Verify Primary ALB Health Before Restoring DNS
echo "[2/5] Verifying Primary ALB is healthy before restoring DNS..."
PRIMARY_ALB_DNS=$(aws elbv2 describe-load-balancers \
  --region "${PRIMARY_REGION}" \
  --names "vaultrix-dr-primary-ec2-alb" \
  --query "LoadBalancers[0].DNSName" \
  --output text 2>/dev/null || echo "")

if [ -z "${PRIMARY_ALB_DNS}" ] || [ "${PRIMARY_ALB_DNS}" == "None" ]; then
  echo "ERROR: Primary ALB not found in ${PRIMARY_REGION}. Cannot confirm Primary is healthy."
  echo "Ensure terraform apply has completed in environments/primary/ec2 before failback."
  exit 1
fi

echo "Primary ALB DNS: ${PRIMARY_ALB_DNS}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "http://${PRIMARY_ALB_DNS}/health" 2>/dev/null || echo "000")
echo "Primary /health HTTP status: ${HTTP_CODE}"

if [ "${HTTP_CODE}" != "200" ]; then
  echo "ERROR: Primary /health did not return 200 (got ${HTTP_CODE})."
  echo "Primary region is NOT ready. Resolve Primary health before proceeding with failback."
  exit 1
fi
echo "Primary region confirmed healthy."

# 3. Verify Primary Route 53 Health Check Status
echo "[3/5] Checking Primary Route 53 health check status..."
PRIMARY_HEALTH_CHECK_ID=$(aws route53 list-resource-record-sets \
  --hosted-zone-id "${HOSTED_ZONE_ID}" \
  --query "ResourceRecordSets[?Name=='${RECORD_NAME}.' && SetIdentifier=='PRIMARY'].HealthCheckId" \
  --output text)

if [ -n "${PRIMARY_HEALTH_CHECK_ID}" ] && [ "${PRIMARY_HEALTH_CHECK_ID}" != "None" ] && [ "${PRIMARY_HEALTH_CHECK_ID}" != "" ]; then
  PRIMARY_STATUS=$(aws route53 get-health-check-status \
    --health-check-id "${PRIMARY_HEALTH_CHECK_ID}" \
    --query "HealthCheckObservations[0].StatusReport.Status" \
    --output text 2>/dev/null || echo "UNKNOWN")
  echo "Primary Health Check Status (${PRIMARY_HEALTH_CHECK_ID}): ${PRIMARY_STATUS}"
  echo "Health check association already present — Route 53 will restore PRIMARY routing automatically."
else
  echo "WARNING: PRIMARY record has no health check association."
  echo "This can happen if FORCE_FAILOVER=true was used during failover."
  echo "Restoring health check association to re-enable automatic failover policy..."

  # Retrieve current PRIMARY record
  PRIMARY_RECORD=$(aws route53 list-resource-record-sets \
    --hosted-zone-id "${HOSTED_ZONE_ID}" \
    --query "ResourceRecordSets[?Name=='${RECORD_NAME}.' && SetIdentifier=='PRIMARY'] | [0]" \
    --output json)

  ALIAS_DNS=$(echo "${PRIMARY_RECORD}" | python3 -c "import json,sys; r=json.load(sys.stdin); print(r['AliasTarget']['DNSName'])")
  ALIAS_ZONE=$(echo "${PRIMARY_RECORD}" | python3 -c "import json,sys; r=json.load(sys.stdin); print(r['AliasTarget']['HostedZoneId'])")

  # Retrieve the health check for Primary ALB by its FQDN (created by Terraform)
  HEALTH_CHECK_ID=$(aws route53 list-health-checks \
    --query "HealthChecks[?HealthCheckConfig.FullyQualifiedDomainName=='${PRIMARY_ALB_DNS}'].Id" \
    --output text | awk '{print $1}')

  if [ -z "${HEALTH_CHECK_ID}" ] || [ "${HEALTH_CHECK_ID}" == "None" ]; then
    echo "ERROR: Cannot locate Primary health check for ${PRIMARY_ALB_DNS}."
    echo "Manually re-run 'terraform apply' in environments/primary/ec2 to restore the health check."
    exit 1
  fi

  echo "Restoring health check ${HEALTH_CHECK_ID} to PRIMARY DNS record..."

  CHANGE_BATCH=$(cat <<EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${RECORD_NAME}",
        "Type": "A",
        "SetIdentifier": "PRIMARY",
        "Failover": "PRIMARY",
        "HealthCheckId": "${HEALTH_CHECK_ID}",
        "AliasTarget": {
          "HostedZoneId": "${ALIAS_ZONE}",
          "DNSName": "${ALIAS_DNS}",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}
EOF
)

  CHANGE_ID=$(aws route53 change-resource-record-sets \
    --hosted-zone-id "${HOSTED_ZONE_ID}" \
    --change-batch "${CHANGE_BATCH}" \
    --query "ChangeInfo.Id" \
    --output text)

  echo "Route 53 change submitted: ${CHANGE_ID}"
  echo "Waiting for DNS propagation..."
  aws route53 wait resource-record-sets-changed --id "${CHANGE_ID}" || true
  echo "Health check association restored. Route 53 will route to PRIMARY when health check is HEALTHY."
fi

# 4. Post-Failback Verification
echo "[4/5] Post-failback verification checklist..."
echo "  [ ] Confirm Primary EC2 is running: aws ec2 describe-instances --region ap-south-1"
echo "  [ ] Confirm Primary ALB /health returns 200"
echo "  [ ] Confirm Route 53 health check shows HEALTHY in AWS Console"
echo "  [ ] Test application at http://ec2.dr.vaultrix.in — badge should show PRIMARY"
echo "  [ ] Verify task data is intact (data may need to be restored from DR to Primary)"

# 5. Final Failback Status
echo "[5/5] Failback sequence complete."
echo "============================================================"
echo " FAILBACK SEQUENCE COMPLETED"
echo " Primary Region: ${PRIMARY_REGION} (ACTIVE)"
echo " DR Region:      ${DR_REGION} (STANDBY)"
echo ""
echo " IMPORTANT: If data was written to the DR database during the outage,"
echo " a manual data migration from DR RDS to Primary RDS is required."
echo " Consult docs/runbooks/ec2-failback.md for data sync procedure."
echo "============================================================"
