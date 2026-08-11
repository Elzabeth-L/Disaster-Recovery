# 09. DR Detection & Failover Mechanics — Comprehensive Notes

## 1. Overview

Traffic redirection during a regional outage is controlled by Amazon Route 53 using an **Active-Passive Failover Routing Policy** configured under hosted zone `dr.vaultrix.in`.

---

## 2. Route 53 Configuration Details

### Primary Health Check (`terraform/environments/primary/ec2/main.tf`)
```hcl
resource "aws_route53_health_check" "primary_ec2" {
  fqdn              = module.alb.alb_dns_name
  port              = 80
  type              = "HTTP"
  resource_path     = "/health"
  request_interval  = 30
  failure_threshold = 3

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-primary-alb-health-check" })
}
```

---

### Primary DNS Failover Record (`PRIMARY`)
```hcl
resource "aws_route53_record" "primary_ec2_alias" {
  zone_id = local.global_route53_zone_id
  name    = "ec2.${local.global_route53_zone_name}"
  type    = "A"

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier  = "PRIMARY"
  health_check_id = aws_route53_health_check.primary_ec2.id

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}
```

---

### DR DNS Failover Record (`SECONDARY`) (`terraform/environments/dr/ec2/main.tf`)
```hcl
resource "aws_route53_record" "dr_ec2_alias" {
  zone_id = local.global_route53_zone_id
  name    = "ec2.${local.global_route53_zone_name}"
  type    = "A"

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier  = "SECONDARY"
  health_check_id = aws_route53_health_check.dr_ec2.id

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}
```

---

## 3. Scripted Failover Execution ([`scripts/failover/ec2-failover.sh`](file:///c:/Users/smine/Disaster-Recovery/scripts/failover/ec2-failover.sh))

The failover script can be executed in two modes:

### Mode A: Monitor Mode (`./ec2-failover.sh`)
- Retrieves Route 53 Hosted Zone ID for `dr.vaultrix.in`.
- Checks DR health check status in `ap-southeast-1`.
- Tests DR ALB endpoint `/health` via `curl`.
- Confirms Route 53 automatic failover routing state.

---

### Mode B: Emergency Forced Override (`FORCE_FAILOVER=true ./ec2-failover.sh`)
When Primary is unresponsive and immediate manual DNS override is required:

```bash
FORCE_FAILOVER=true ./scripts/failover/ec2-failover.sh
```

#### Code Logic:
1. Fetches current `PRIMARY` record set payload.
2. Extracts ALB Alias target DNS name and hosted zone ID.
3. Re-upserts `PRIMARY` record **without** `HealthCheckId` and with `EvaluateTargetHealth = false`:
   ```json
   {
     "Changes": [
       {
         "Action": "UPSERT",
         "ResourceRecordSet": {
           "Name": "ec2.dr.vaultrix.in",
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
   ```
4. Without a health check association, Route 53 immediately evaluates `PRIMARY` as unavailable and directs 100% of incoming DNS queries to `SECONDARY` (DR ALB).
