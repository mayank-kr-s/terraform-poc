variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for EC2 instances"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "alb_security_group_id" {
  description = "Security group ID of the ALB (for ingress rules)"
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the ALB target group"
  type        = string
}

variable "desired_capacity" {
  description = "Desired number of instances"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of instances"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances"
  type        = number
  default     = 3
}

variable "cpu_target_value" {
  description = "Target CPU utilization for scaling"
  type        = number
  default     = 60.0
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed to SSH into EC2 instances"
  type        = list(string)
  default     = ["0.0.0.0/0"] # CHANGE THIS to your IP in production!
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
}
