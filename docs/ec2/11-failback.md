# 11. Failback Mechanics & Data Sync — Comprehensive Notes

## 1. Overview

Failback restores production traffic to Primary (`ap-south-1`) after Primary region infrastructure stability has been verified.

---

## 2. Failback Script Logic ([`scripts/failback/ec2-failback.sh`](file:///c:/Users/smine/Disaster-Recovery/scripts/failback/ec2-failback.sh))

```bash
#!/usr/bin/env bash
set -euo pipefail

DOMAIN_NAME="${DOMAIN_NAME:-dr.vaultrix.in}"
RECORD_NAME="${RECORD_NAME:-ec2.dr.vaultrix.in}"
PRIMARY_REGION="ap-south-1"
DR_REGION="ap-southeast-1"

# 1. Fetch Route 53 Hosted Zone ID
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name "${DOMAIN_NAME}" \
  --query "HostedZones[0].Id" --output text | sed 's#/hostedzone/##')

# 2. Verify Primary ALB Health Before Restoring DNS
PRIMARY_ALB_DNS=$(aws elbv2 describe-load-balancers \
  --region "${PRIMARY_REGION}" \
  --names "vaultrix-dr-primary-ec2-alb" \
  --query "LoadBalancers[0].DNSName" --output text)

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "http://${PRIMARY_ALB_DNS}/health")

if [ "${HTTP_CODE}" != "200" ]; then
  echo "ERROR: Primary /health did not return 200 (got ${HTTP_CODE}). Aborting failback."
  exit 1
fi

# 3. Check & Restore Route 53 Health Check Association
PRIMARY_HEALTH_CHECK_ID=$(aws route53 list-resource-record-sets \
  --hosted-zone-id "${HOSTED_ZONE_ID}" \
  --query "ResourceRecordSets[?Name=='${RECORD_NAME}.' && SetIdentifier=='PRIMARY'].HealthCheckId" \
  --output text)

if [ -z "${PRIMARY_HEALTH_CHECK_ID}" ] || [ "${PRIMARY_HEALTH_CHECK_ID}" == "None" ]; then
  # Re-attach health check ID to PRIMARY record
  HEALTH_CHECK_ID=$(aws route53 list-health-checks \
    --query "HealthChecks[?HealthCheckConfig.FullyQualifiedDomainName=='${PRIMARY_ALB_DNS}'].Id" \
    --output text | awk '{print $1}')

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
  aws route53 change-resource-record-sets --hosted-zone-id "${HOSTED_ZONE_ID}" --change-batch "${CHANGE_BATCH}"
fi
```

---

## 3. Data Sync & Reconciliation Strategy

Because the primary and DR database environments do not use active-active bidirectional replication:
1. Tasks created in DR during an outage reside exclusively in the DR RDS instance (`ap-southeast-1`).
2. Before failing back, operators must perform a manual logical data export (e.g. `pg_dump` on DR RDS $\to$ `pg_restore` on Primary RDS) if tasks written during the outage must be preserved in Primary.
