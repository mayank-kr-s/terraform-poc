# Dev environment values
# Override defaults for your setup

region       = "us-east-1"
environment  = "dev"
project_name = "terraform-poc"

# Networking
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
enable_nat_gateway   = false # Keep false to save money!

# EC2
instance_type    = "t2.micro" # Free tier eligible
key_name         = "terraform-poc-key"
desired_capacity = 2
min_size         = 1
max_size         = 3
cpu_target_value = 60.0

# SSH access — CHANGE THIS to your IP!
# Find your IP: curl ifconfig.me
# Then set: ssh_allowed_cidrs = ["YOUR_IP/32"]
ssh_allowed_cidrs = ["0.0.0.0/0"]
