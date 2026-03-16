# ─────────────────────────────────────────────
#  Variables for Dev Environment
# ─────────────────────────────────────────────

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "terraform-poc"
}

# ─── Networking ───
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway (COSTS MONEY — leave false for free tier)"
  type        = bool
  default     = false
}

# ─── EC2 / Auto Scaling ───
variable "instance_type" {
  description = "EC2 instance type (t2.micro = free tier)"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Name of the SSH key pair (created in AWS)"
  type        = string
  default     = "terraform-poc-key"
}

variable "desired_capacity" {
  description = "Desired number of EC2 instances"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum EC2 instances in ASG"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum EC2 instances in ASG"
  type        = number
  default     = 3
}

variable "cpu_target_value" {
  description = "Target CPU percentage for auto scaling"
  type        = number
  default     = 60.0
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed to SSH (use your IP: x.x.x.x/32)"
  type        = list(string)
  default     = ["0.0.0.0/0"] # ⚠️ CHANGE to your IP for security!
}
