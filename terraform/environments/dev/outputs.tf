# ─────────────────────────────────────────────
#  Outputs — Useful info after deployment
# ─────────────────────────────────────────────

# ─── Networking ───
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

# ─── ALB ───
output "alb_dns_name" {
  description = "ALB DNS name — access your app here!"
  value       = module.alb.alb_dns_name
}

output "target_group_arn" {
  description = "Target Group ARN"
  value       = module.alb.target_group_arn
}

# ─── EC2 ───
output "asg_name" {
  description = "Auto Scaling Group name"
  value       = module.ec2.asg_name
}

output "ami_id" {
  description = "AMI used for instances"
  value       = module.ec2.ami_id
}

# ─── Quick Access ───
output "app_url" {
  description = "Application URL"
  value       = "http://${module.alb.alb_dns_name}"
}
