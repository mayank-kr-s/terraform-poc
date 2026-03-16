output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.web.id
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.web.name
}

output "asg_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.web.arn
}

output "ec2_security_group_id" {
  description = "Security Group ID of the EC2 instances"
  value       = aws_security_group.ec2.id
}

output "ami_id" {
  description = "AMI ID used for the instances"
  value       = data.aws_ami.amazon_linux.id
}
