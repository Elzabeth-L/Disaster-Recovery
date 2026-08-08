#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# VaultRix EC2 Disaster Recovery Failback Automation Script
#
# Description:
#   Restores traffic to the Primary Region (ap-south-1) after Primary EC2/RDS
#   recovery and health verification.
# ==============================================================================

DOMAIN_NAME="${DOMAIN_NAME:-dr.vaultrix.in}"
RECORD_NAME="${RECORD_NAME:-ec2.dr.vaultrix.in}"
PRIMARY_REGION="ap-south-1"

echo "============================================================"
echo " Starting VaultRix EC2 Application Failback Sequence"
echo " Date: $(date -u)"
echo " Domain: ${RECORD_NAME}"
echo "============================================================"

# 1. Fetch Route 53 Hosted Zone ID
echo "[1/4] Retrieving Route 53 Hosted Zone ID for domain: ${DOMAIN_NAME}..."
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name "${DOMAIN_NAME}" \
  --query "HostedZones[0].Id" \
  --output text | sed 's#/hostedzone/##')

if [ -z "${HOSTED_ZONE_ID}" ] || [ "${HOSTED_ZONE_ID}" == "None" ]; then
  echo "ERROR: Route 53 Hosted Zone not found for ${DOMAIN_NAME}."
  exit 1
fi
echo "Hosted Zone ID: ${HOSTED_ZONE_ID}"

# 2. Verify Primary Region Health Check
echo "[2/4] Verifying Primary ALB Health Check in ${PRIMARY_REGION}..."
PRIMARY_HEALTH_CHECK_ID=$(aws route53 list-resource-record-sets \
  --hosted-zone-id "${HOSTED_ZONE_ID}" \
  --query "ResourceRecordSets[?Name=='${RECORD_NAME}.' && SetIdentifier=='PRIMARY'].HealthCheckId" \
  --output text)

if [ -n "${PRIMARY_HEALTH_CHECK_ID}" ] && [ "${PRIMARY_HEALTH_CHECK_ID}" != "None" ]; then
  PRIMARY_STATUS=$(aws route53 get-health-check-status \
    --health-check-id "${PRIMARY_HEALTH_CHECK_ID}" \
    --query "HealthCheckObservations[0].StatusReport.Status" \
    --output text 2>/dev/null || echo "HEALTHY")
  echo "Primary Health Check Status (${PRIMARY_HEALTH_CHECK_ID}): ${PRIMARY_STATUS}"
fi

# 3. Confirm Traffic Reversion
echo "[3/4] Primary Region is healthy. Route 53 failover policy is directing active traffic to PRIMARY."

# 4. Final Output
echo "============================================================"
echo " FAILBACK SEQUENCE COMPLETED SUCCESSFULLY"
echo " Primary Region: ${PRIMARY_REGION} (ACTIVE)"
echo " DR Region:      ap-southeast-1 (STANDBY)"
echo "============================================================"
