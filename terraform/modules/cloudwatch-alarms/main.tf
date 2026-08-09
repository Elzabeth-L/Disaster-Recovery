# SNS Topic for alarm notifications
resource "aws_sns_topic" "alerts" {
  name = "${var.name_prefix}-alerts"

  tags = merge(
    var.common_tags,
    {
      Name = "${var.name_prefix}-alerts"
    }
  )
}

# Email subscription (only created if alarm_email is provided)
resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# ---------------------------------------------------------------------------
# ALB: Unhealthy Host Count
# Fires when at least 1 target in the ALB target group is unhealthy
# for 2 consecutive 60-second evaluation periods.
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "${var.name_prefix}-alb-unhealthy-hosts"
  alarm_description   = "CRITICAL: ALB has unhealthy EC2 targets. Application may be unreachable."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "UnhealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  treat_missing_data  = "breaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.name_prefix}-alb-unhealthy-hosts"
    }
  )
}

# ---------------------------------------------------------------------------
# EC2: Status Check Failed
# Fires when instance-level or system-level status checks fail
# for 2 consecutive 60-second evaluation periods.
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "ec2_status_check" {
  alarm_name          = "${var.name_prefix}-ec2-status-check-failed"
  alarm_description   = "CRITICAL: EC2 instance status check is failing. Instance may be unhealthy."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  treat_missing_data  = "breaching"

  dimensions = {
    InstanceId = var.ec2_instance_id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.name_prefix}-ec2-status-check-failed"
    }
  )
}

# ---------------------------------------------------------------------------
# RDS: CPU Utilization High
# Fires when RDS CPU usage exceeds 80% for 3 consecutive 60-second periods.
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${var.name_prefix}-rds-cpu-high"
  alarm_description   = "WARNING: RDS CPU utilization is high. Investigate query load."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = var.rds_identifier
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.name_prefix}-rds-cpu-high"
    }
  )
}

# ---------------------------------------------------------------------------
# RDS: Free Storage Space Low
# Fires when available RDS storage drops below threshold (default 2 GiB).
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "rds_free_storage_low" {
  alarm_name          = "${var.name_prefix}-rds-free-storage-low"
  alarm_description   = "CRITICAL: RDS free storage is critically low. Expand storage immediately."
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Minimum"
  threshold           = var.rds_free_storage_threshold_bytes
  treat_missing_data  = "breaching"

  dimensions = {
    DBInstanceIdentifier = var.rds_identifier
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.name_prefix}-rds-free-storage-low"
    }
  )
}

# ---------------------------------------------------------------------------
# RDS: Database Connections Spike
# Fires when RDS connection count exceeds 100 for 3 consecutive periods.
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "rds_connections_high" {
  alarm_name          = "${var.name_prefix}-rds-connections-high"
  alarm_description   = "WARNING: RDS DatabaseConnections count is elevated. Investigate connection pooling."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Maximum"
  threshold           = 100
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = var.rds_identifier
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.name_prefix}-rds-connections-high"
    }
  )
}
