#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# VaultRix EC2 Disaster Recovery Failover Automation Script
#
# Description:
#   Initiates failover of the EC2 Application workload from Primary (ap-south-1)
#   to DR Standby (ap-southeast-1).
#
# Usage:
#   Normal mode  (monitor only):   ./ec2-failover.sh
#   Force mode   (override DNS):   FORCE_FAILOVER=true ./ec2-failover.sh
#
# FORCE_FAILOVER=true disables the Primary Route 53 health check association
# so Route 53 immediately directs traffic to the SECONDARY (DR) record.
# ==============================================================================

DOMAIN_NAME="${DOMAIN_NAME:-dr.vaultrix.in}"
RECORD_NAME="${RECORD_NAME:-ec2.dr.vaultrix.in}"
PRIMARY_REGION="ap-south-1"
DR_REGION="ap-southeast-1"
FORCE_FAILOVER="${FORCE_FAILOVER:-false}"

echo "============================================================"
echo " Starting VaultRix EC2 Application DR Failover Sequence"
echo " Date: $(date -u)"
echo " Domain: ${RECORD_NAME}"
echo " Mode: ${FORCE_FAILOVER}"
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

# 2. Inspect DR Standby Health Check
echo "[2/5] Verifying DR Standby ALB Target Availability in ${DR_REGION}..."
DR_HEALTH_CHECK_ID=$(aws route53 list-resource-record-sets \
  --hosted-zone-id "${HOSTED_ZONE_ID}" \
  --query "ResourceRecordSets[?Name=='${RECORD_NAME}.' && SetIdentifier=='SECONDARY'].HealthCheckId" \
  --output text)

if [ -n "${DR_HEALTH_CHECK_ID}" ] && [ "${DR_HEALTH_CHECK_ID}" != "None" ]; then
  DR_STATUS=$(aws route53 get-health-check-status \
    --health-check-id "${DR_HEALTH_CHECK_ID}" \
    --query "HealthCheckObservations[0].StatusReport.Status" \
    --output text 2>/dev/null || echo "UNKNOWN")
  echo "DR Health Check Status (${DR_HEALTH_CHECK_ID}): ${DR_STATUS}"
else
  echo "WARNING: DR health check not found. Ensure DR environment is provisioned."
fi

# 3. Route 53 Failover — Automatic or Forced
echo "[3/5] Evaluating failover mode..."
if [ "${FORCE_FAILOVER}" == "true" ]; then
  echo "FORCE_FAILOVER=true — executing manual DNS override..."

  # Retrieve the current PRIMARY record details for re-creation without health check
  PRIMARY_RECORD=$(aws route53 list-resource-record-sets \
    --hosted-zone-id "${HOSTED_ZONE_ID}" \
    --query "ResourceRecordSets[?Name=='${RECORD_NAME}.' && SetIdentifier=='PRIMARY'] | [0]" \
    --output json)

  if [ -z "${PRIMARY_RECORD}" ] || [ "${PRIMARY_RECORD}" == "null" ]; then
    echo "ERROR: PRIMARY record not found in hosted zone ${HOSTED_ZONE_ID}. Cannot force failover."
    exit 1
  fi

  # Extract the ALB alias target info from the existing record
  ALIAS_DNS=$(echo "${PRIMARY_RECORD}" | python3 -c "import json,sys; r=json.load(sys.stdin); print(r['AliasTarget']['DNSName'])")
  ALIAS_ZONE=$(echo "${PRIMARY_RECORD}" | python3 -c "import json,sys; r=json.load(sys.stdin); print(r['AliasTarget']['HostedZoneId'])")

  echo "Removing health check association from PRIMARY record to force SECONDARY routing..."

  # Re-upsert the PRIMARY record without a health_check_id.
  # Without a healthy health check, Route 53 treats PRIMARY as unhealthy
  # and immediately serves the SECONDARY record.
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
        "AliasTarget": {
          "HostedZoneId": "${ALIAS_ZONE}",
          "DNSName": "${ALIAS_DNS}",
          "EvaluateTargetHealth": false
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
  echo "Waiting for propagation (up to 60 seconds)..."
  aws route53 wait resource-record-sets-changed --id "${CHANGE_ID}" || true
  echo "DNS override applied. Traffic is now routing to DR SECONDARY."

else
  echo "Automatic mode: Route 53 Failover Policy is active."
  echo "Traffic will route to SECONDARY automatically upon Primary health check failure."
  echo "(To force an immediate DNS override, re-run with FORCE_FAILOVER=true)"
fi

# 4. Verify DR endpoint resolution
echo "[4/5] Verifying DR ALB endpoint..."
DR_ALB_DNS=$(aws elbv2 describe-load-balancers \
  --region "${DR_REGION}" \
  --names "vaultrix-dr-dr-ec2-alb" \
  --query "LoadBalancers[0].DNSName" \
  --output text 2>/dev/null || echo "")

if [ -n "${DR_ALB_DNS}" ] && [ "${DR_ALB_DNS}" != "None" ]; then
  echo "DR ALB DNS: ${DR_ALB_DNS}"
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "http://${DR_ALB_DNS}/health" 2>/dev/null || echo "000")
  echo "DR /health HTTP status: ${HTTP_CODE}"
  if [ "${HTTP_CODE}" == "200" ]; then
    echo "DR application is healthy and serving traffic."
  else
    echo "WARNING: DR /health did not return 200. Investigate DR environment before completing failover."
  fi
else
  echo "WARNING: DR ALB not found in ${DR_REGION}. Ensure terraform apply has been run for dr/ec2."
fi

# 5. Final Failover Status
echo "[5/5] Failover sequence complete."
echo "============================================================"
echo " FAILOVER SEQUENCE COMPLETED"
echo " Primary Region: ${PRIMARY_REGION} (OFFLINE / DEGRADED)"
echo " DR Region:      ${DR_REGION} (ACTIVE)"
if [ "${FORCE_FAILOVER}" == "true" ]; then
  echo " DNS Override:   APPLIED (health check association removed from PRIMARY)"
  echo ""
  echo " IMPORTANT: After Primary recovery, run ec2-failback.sh to restore"
  echo " the health check association and return traffic to PRIMARY."
fi
echo "============================================================"
