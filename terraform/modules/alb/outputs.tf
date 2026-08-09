output "alb_arn" {
  description = "ARN of the Application Load Balancer."
  value       = aws_lb.main.arn
}

output "alb_arn_suffix" {
  description = "ARN suffix used by CloudWatch ApplicationELB metrics."
  value       = aws_lb.main.arn_suffix
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer."
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Canonical hosted zone ID of the Application Load Balancer (for Route 53 alias)."
  value       = aws_lb.main.zone_id
}

output "security_group_id" {
  description = "ID of the ALB security group."
  value       = aws_security_group.alb.id
}

output "target_group_arn" {
  description = "ARN of the ALB target group."
  value       = aws_lb_target_group.app.arn
}

output "target_group_arn_suffix" {
  description = "Target group ARN suffix used by CloudWatch ApplicationELB metrics."
  value       = aws_lb_target_group.app.arn_suffix
}

output "listener_arn" {
  description = "ARN of the HTTP listener."
  value       = aws_lb_listener.http.arn
}
