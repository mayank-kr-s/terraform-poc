# ─────────────────────────────────────────────
#  Dev Environment — Main Configuration
#  Ties all modules together
# ─────────────────────────────────────────────

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.region
}

# ─── VPC Module ───
module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  environment          = var.environment
  project_name         = var.project_name
  enable_nat_gateway   = var.enable_nat_gateway
}

# ─── ALB Module ───
module "alb" {
  source = "../../modules/alb"

  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  environment       = var.environment
  project_name      = var.project_name
}

# ─── EC2 / Auto Scaling Module ───
module "ec2" {
  source = "../../modules/ec2"

  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.public_subnet_ids  # Use public subnets (free tier — no NAT needed)
  instance_type         = var.instance_type
  key_name              = var.key_name
  alb_security_group_id = module.alb.alb_security_group_id
  target_group_arn      = module.alb.target_group_arn
  desired_capacity      = var.desired_capacity
  min_size              = var.min_size
  max_size              = var.max_size
  cpu_target_value      = var.cpu_target_value
  ssh_allowed_cidrs     = var.ssh_allowed_cidrs
  environment           = var.environment
  project_name          = var.project_name
}
