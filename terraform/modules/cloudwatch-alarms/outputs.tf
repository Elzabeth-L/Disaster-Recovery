output "sns_topic_arn" {
  description = "ARN of the SNS topic receiving CloudWatch alarm notifications."
  value       = aws_sns_topic.alerts.arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic receiving CloudWatch alarm notifications."
  value       = aws_sns_topic.alerts.name
}

output "alarm_alb_unhealthy_hosts_arn" {
  description = "ARN of the ALB UnhealthyHostCount alarm."
  value       = aws_cloudwatch_metric_alarm.alb_unhealthy_hosts.arn
}

output "alarm_ec2_status_check_arn" {
  description = "ARN of the EC2 StatusCheckFailed alarm."
  value       = aws_cloudwatch_metric_alarm.ec2_status_check.arn
}

output "alarm_rds_cpu_high_arn" {
  description = "ARN of the RDS CPUUtilization alarm."
  value       = aws_cloudwatch_metric_alarm.rds_cpu_high.arn
}

output "alarm_rds_free_storage_low_arn" {
  description = "ARN of the RDS FreeStorageSpace alarm."
  value       = aws_cloudwatch_metric_alarm.rds_free_storage_low.arn
}

output "alarm_rds_connections_high_arn" {
  description = "ARN of the RDS DatabaseConnections alarm."
  value       = aws_cloudwatch_metric_alarm.rds_connections_high.arn
}
