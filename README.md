# Highly Available Cloud Infrastructure & Configuration Automation

> AWS | Terraform | Ansible | EC2 | ALB | Auto Scaling

A production-grade infrastructure project that provisions a secure, highly available AWS environment using **Terraform** (IaC) and configures servers with **Ansible** automation.

---

## Architecture

```
                         Internet
                            │
                      ┌─────┴─────┐
                      │    IGW     │
                      └─────┬─────┘
                            │
                   ┌────────┴────────┐
                   │   VPC 10.0.0.0/16│
                   │                  │
       ┌───────────┴──────┐  ┌───────┴──────────┐
       │ Public Subnet 1  │  │ Public Subnet 2   │
       │  10.0.1.0/24     │  │  10.0.2.0/24      │
       │  (us-east-1a)    │  │  (us-east-1b)     │
       │                  │  │                    │
       │   ┌──── ALB ─────┤  │                   │
       │   │              │  │                    │
       │   │   EC2 (ASG)  │  │    EC2 (ASG)      │
       └──────────────────┘  └────────────────────┘
```

## What This Project Demonstrates

| Resume Bullet | Implementation |
|---------------|----------------|
| Secure VPC with public/private subnets | Terraform VPC module with IGW, route tables, 4 subnets across 2 AZs |
| Remote state with S3 + DynamoDB | Bootstrap module creates encrypted S3 bucket + lock table |
| 80% reduction in provisioning time | Ansible roles: common, nginx, security — zero-touch deployment |
| ALB + Auto Scaling for 99.9% uptime | ALB with health checks, ASG with target tracking scaling policy |

## Project Structure

```
terraform-poc/
├── docs/                                    # Learning guides
│   ├── 01-AWS-Beginner-Guide.md
│   ├── 02-Terraform-Beginner-Guide.md
│   ├── 03-Ansible-Beginner-Guide.md
│   └── 04-Step-by-Step-Project-Guide.md
│
├── terraform/
│   ├── bootstrap/                           # S3 + DynamoDB for remote state
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── modules/
│   │   ├── vpc/                             # VPC, subnets, IGW, NAT
│   │   ├── alb/                             # ALB, target group, listener
│   │   └── ec2/                             # Launch template, ASG, scaling
│   └── environments/
│       └── dev/                             # Dev environment config
│           ├── main.tf                      # Module orchestration
│           ├── backend.tf                   # Remote state config
│           ├── variables.tf
│           ├── outputs.tf
│           └── terraform.tfvars
│
├── ansible/
│   ├── ansible.cfg                          # Ansible configuration
│   ├── site.yml                             # Main playbook
│   ├── inventory/
│   │   ├── hosts.ini                        # Static inventory
│   │   └── aws_ec2.yml                      # Dynamic AWS inventory
│   ├── roles/
│   │   ├── common/                          # System updates, packages
│   │   ├── nginx/                           # Nginx reverse proxy
│   │   └── security/                        # OS security hardening
│   └── group_vars/
│       └── webservers.yml
│
├── scripts/
│   ├── deploy.sh                            # Full deploy pipeline
│   ├── destroy.sh                           # Tear down everything
│   └── generate-inventory.sh                # Generate Ansible inventory
│
├── .gitignore
└── README.md
```

## Quick Start

### Prerequisites
- AWS account (free tier eligible)
- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.5
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/) >= 2.14 (via WSL on Windows)
- [AWS CLI](https://aws.amazon.com/cli/) v2
- SSH key pair

### Step 1: Configure AWS
```bash
aws configure
# Enter your Access Key, Secret Key, region (us-east-1), output (json)
```

### Step 2: Create SSH Key
```bash
aws ec2 create-key-pair --key-name terraform-poc-key --query 'KeyMaterial' --output text > ~/.ssh/terraform-poc-key.pem
chmod 400 ~/.ssh/terraform-poc-key.pem
```

### Step 3: Bootstrap Remote State
```bash
cd terraform/bootstrap
terraform init
terraform apply
# Note the S3 bucket name from output
```

### Step 4: Update Backend Config
Edit `terraform/environments/dev/backend.tf` — replace `REPLACE_WITH_YOUR_ACCOUNT_ID` with your actual account ID.

### Step 5: Deploy Infrastructure
```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### Step 6: Configure Servers with Ansible
```bash
# Generate inventory from Terraform output
bash scripts/generate-inventory.sh

# Run Ansible playbook
cd ansible
ansible-playbook -i inventory/hosts.ini site.yml
```

### Step 7: Access Your App
```bash
terraform -chdir=terraform/environments/dev output app_url
# Open the URL in your browser!
```

### Step 8: DESTROY When Done (Important!)
```bash
bash scripts/destroy.sh
# Or manually:
cd terraform/environments/dev
terraform destroy
```

## Cost Information

| Resource | Free Tier? | Monthly Cost if Left Running |
|----------|:----------:|---------------------------|
| EC2 (t2.micro × 2) | ✅ 750 hrs/month | $0 (within limits) |
| ALB | ✅ 750 hrs/month | $0 (within limits) |
| S3 | ✅ 5 GB free | $0 |
| DynamoDB | ✅ 25 GB free | $0 |
| NAT Gateway | ❌ | ~$32/month (disabled by default) |

> **Always destroy resources after practice sessions!**

## Learning Resources

Read the docs in order:
1. [AWS Beginner Guide](docs/01-AWS-Beginner-Guide.md) — AWS services explained
2. [Terraform Beginner Guide](docs/02-Terraform-Beginner-Guide.md) — Infrastructure as Code
3. [Ansible Beginner Guide](docs/03-Ansible-Beginner-Guide.md) — Configuration Management
4. [Step-by-Step Project Guide](docs/04-Step-by-Step-Project-Guide.md) — Complete walkthrough

## Technologies

- **AWS**: VPC, EC2, ALB, ASG, S3, DynamoDB, IAM
- **Terraform**: v1.5+ with modular design and remote state
- **Ansible**: v2.14+ with roles-based playbooks
- **Nginx**: Reverse proxy with security headers
- **Linux**: Amazon Linux 2023 with security hardening
