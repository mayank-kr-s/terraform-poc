# Step-by-Step Project Guide
## Highly Available Cloud Infrastructure & Configuration Automation

> **Estimated Time**: 4-6 hours (first time) | **Cost**: $0 if destroyed within free-tier limits  
> **Prerequisites**: AWS account, Terraform installed, Ansible installed (via WSL on Windows)

---

## Table of Contents
1. [Phase 0: Prerequisites & Setup](#phase-0-prerequisites--setup)
2. [Phase 1: Remote State (S3 + DynamoDB)](#phase-1-remote-state-s3--dynamodb)
3. [Phase 2: VPC & Networking (Terraform)](#phase-2-vpc--networking-terraform)
4. [Phase 3: Security Groups (Terraform)](#phase-3-security-groups-terraform)
5. [Phase 4: ALB & Auto Scaling (Terraform)](#phase-4-alb--auto-scaling-terraform)
6. [Phase 5: Ansible Configuration](#phase-5-ansible-configuration)
7. [Phase 6: Testing & Validation](#phase-6-testing--validation)
8. [Phase 7: Cleanup (CRITICAL!)](#phase-7-cleanup-critical)
9. [Cost Optimization Tips](#cost-optimization-tips)

---

## Phase 0: Prerequisites & Setup

### Step 0.1: Create AWS Account
1. Go to https://aws.amazon.com/free → Create account.
2. Use a fresh email for a new 12-month free tier.
3. Add a credit/debit card (required but won't be charged if you stay in free tier).

### Step 0.2: Create IAM User
**DO NOT use your root account for this project.**

```
AWS Console → IAM → Users → Create User
  Name: terraform-admin
  → Attach policies directly → AdministratorAccess
  → Create user
  → Security credentials → Create access key → CLI → Download CSV
```

### Step 0.3: Install Tools

**AWS CLI:**
```powershell
# Windows — download from https://awscli.amazonaws.com/AWSCLIV2.msi
# Run the installer, then verify:
aws --version
```

**Terraform:**
```powershell
# Windows — download from https://developer.hashicorp.com/terraform/downloads
# Extract terraform.exe to C:\terraform and add to PATH
terraform version
```

**Ansible (requires WSL on Windows):**
```powershell
# If WSL not installed:
wsl --install
# Restart PC, then in Ubuntu terminal:
sudo apt update && sudo apt install -y ansible python3-pip
pip3 install boto3 botocore
ansible --version
```

### Step 0.4: Configure AWS CLI
```bash
aws configure
# AWS Access Key ID:     AKIA...your-key...
# AWS Secret Access Key: ...your-secret...
# Default region:        us-east-1
# Output format:         json

# Verify it works:
aws sts get-caller-identity
```

### Step 0.5: Create SSH Key Pair
```bash
# Create a key pair for EC2 access
aws ec2 create-key-pair \
  --key-name terraform-poc-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/terraform-poc-key.pem

# Set permissions (Linux/WSL)
chmod 400 ~/.ssh/terraform-poc-key.pem
```
> On Windows PowerShell, save to `C:\Users\<you>\.ssh\terraform-poc-key.pem`

### Step 0.6: Set Up Billing Alert
```
Console → Billing → Budgets → Create Budget
  → Cost budget → Monthly → Amount: $5 → Add email notification
```

### Step 0.7: Clone/Create Project Structure
```bash
cd /path/to/terraform-poc
# The project code is already set up in this repo!
```

---

## Phase 1: Remote State (S3 + DynamoDB)

> **What**: Create S3 bucket + DynamoDB table for Terraform state management.  
> **Why**: Safe concurrent deployments, state backup, locking.

### Step 1.1: Bootstrap Remote State
We use a separate Terraform config to create the backend resources first.

```bash
cd terraform/bootstrap
terraform init
terraform plan
terraform apply
# Type "yes"
```

This creates:
- ✅ S3 bucket: `terraform-poc-state-<account-id>` (versioned, encrypted)
- ✅ DynamoDB table: `terraform-poc-lock` (for state locking)

### Step 1.2: Note the Output Values
```bash
terraform output
# s3_bucket_name = "terraform-poc-state-123456789"
# dynamodb_table_name = "terraform-poc-lock"
```

**Update** `terraform/environments/dev/backend.tf` with these values if they differ from defaults.

### Step 1.3: Verify in Console
```
S3 Console → You should see the bucket
DynamoDB Console → You should see the table
```

---

## Phase 2: VPC & Networking (Terraform)

> **What**: Create VPC, subnets (public + private), IGW, route tables.  
> **Why**: Isolated, secure network for your infrastructure.

### Step 2.1: Review the Code
```bash
# Review what will be created
cat terraform/modules/vpc/main.tf
```

The VPC module creates:
- 1 VPC (10.0.0.0/16 = 65,536 IPs)
- 2 Public subnets (10.0.1.0/24 and 10.0.2.0/24) in different AZs
- 2 Private subnets (10.0.3.0/24 and 10.0.4.0/24) in different AZs
- 1 Internet Gateway
- Route tables linking public subnets → IGW
- NAT Gateway (optional — disabled by default to save money)

### Step 2.2: Deploy the Infrastructure
```bash
cd terraform/environments/dev
terraform init        # Initialize with remote backend
terraform plan        # Review the plan carefully!
terraform apply       # Deploy (type "yes")
```

### Step 2.3: Verify
```bash
# Check outputs
terraform output

# Verify in AWS
aws ec2 describe-vpcs --filters "Name=tag:Environment,Values=dev" --output table
aws ec2 describe-subnets --filters "Name=tag:Environment,Values=dev" --output table
```

---

## Phase 3: Security Groups (Terraform)

> **What**: Firewall rules for ALB and EC2 instances.  
> **Why**: Only allow necessary traffic — defense in depth.

The security groups are part of the ALB and EC2 modules and are created automatically:

**ALB Security Group:**
| Direction | Port | Source | Purpose |
|-----------|------|--------|---------|
| Inbound | 80 | 0.0.0.0/0 | HTTP from internet |
| Outbound | All | 0.0.0.0/0 | Health checks to EC2 |

**EC2 Security Group:**
| Direction | Port | Source | Purpose |
|-----------|------|--------|---------|
| Inbound | 80 | ALB SG | HTTP from ALB only |
| Inbound | 22 | Your IP | SSH access |
| Outbound | All | 0.0.0.0/0 | Download packages |

These are already included in the `terraform apply` from Phase 2.

---

## Phase 4: ALB & Auto Scaling (Terraform)

> **What**: Application Load Balancer + Auto Scaling Group.  
> **Why**: High availability, fault tolerance, and cost optimization.

### Step 4.1: How It Works
```
Internet → ALB (public subnets) → Target Group → ASG → EC2 instances (public subnets)
                                                         ↑
                                                    Scaling Policy:
                                                    Min: 1, Desired: 2, Max: 3
                                                    Scale at CPU > 60%
```

### Step 4.2: What Terraform Creates
- **Launch Template**: Blueprint for EC2 instances (AMI, type, security group, user data)
- **Auto Scaling Group**: Manages the fleet of EC2 instances
- **ALB**: Distributes traffic across EC2 instances
- **Target Group**: Registers EC2 instances for health checks
- **Listener**: Routes port 80 traffic to the target group
- **Scaling Policy**: Adds/removes instances based on CPU

### Step 4.3: Deploy (Already done in Phase 2)
Everything is deployed together. Check the ALB DNS:
```bash
terraform output alb_dns_name
# e.g., dev-alb-123456789.us-east-1.elb.amazonaws.com
```

### Step 4.4: Wait for Instances
After deploy, wait 2-3 minutes for EC2 instances to launch and pass health checks.

```bash
# Check instance status
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=dev" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].{ID:InstanceId,IP:PublicIpAddress,State:State.Name}' \
  --output table

# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)
```

---

## Phase 5: Ansible Configuration

> **What**: Configure EC2 instances — Nginx, security hardening.  
> **Why**: Automated, consistent server configuration.

### Step 5.1: How Ansible Connects
The EC2 instances have a **user data script** that installs basic packages on boot. Ansible takes over for advanced configuration.

### Step 5.2: Update Inventory
After Terraform deploy, get the EC2 IPs:
```bash
cd ../../..  # Back to project root
cd ansible/

# Option A: Manually update inventory
terraform -chdir=../terraform/environments/dev output -json ec2_public_ips
# Edit inventory/hosts.ini with the IPs

# Option B: Use the helper script
bash scripts/generate-inventory.sh
```

### Step 5.3: Test Connectivity
```bash
# From WSL or Linux
ansible all -i inventory/hosts.ini -m ping
```

If you see `SUCCESS`, Ansible can reach your servers!

### Step 5.4: Run the Playbook
```bash
# Dry run first (check mode)
ansible-playbook -i inventory/hosts.ini site.yml --check

# If it looks good, run for real
ansible-playbook -i inventory/hosts.ini site.yml
```

### Step 5.5: What the Playbook Does
1. **Common Role**: Updates packages, sets hostname, configures timezone.
2. **Nginx Role**: Installs Nginx, deploys reverse proxy config, starts service.
3. **Security Role**: Hardens SSH, sets firewall rules, configures fail2ban.

---

## Phase 6: Testing & Validation

### Test 1: ALB Health Check
```bash
# Get ALB DNS
ALB_DNS=$(terraform -chdir=terraform/environments/dev output -raw alb_dns_name)

# Test HTTP
curl http://$ALB_DNS
# Should return HTML page

# Test health endpoint
curl http://$ALB_DNS/health
# Should return "healthy"
```

### Test 2: Load Distribution
```bash
# Hit the ALB 10 times — you should see different server hostnames
for i in {1..10}; do
  curl -s http://$ALB_DNS | grep "Server:"
done
```

### Test 3: High Availability — Kill an Instance
```bash
# Find one instance ID
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=dev" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)

# Terminate it
aws ec2 terminate-instances --instance-ids $INSTANCE_ID

# Wait 2-3 minutes, then check — ASG should launch a replacement
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=dev" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].InstanceId' --output text

# ALB should still respond
curl http://$ALB_DNS
```

### Test 4: SSH into an Instance
```bash
# Get a public IP
EC2_IP=$(terraform -chdir=terraform/environments/dev output -json ec2_public_ips | jq -r '.[0]')

ssh -i ~/.ssh/terraform-poc-key.pem ec2-user@$EC2_IP

# Once connected:
systemctl status nginx     # Nginx should be running
cat /etc/ssh/sshd_config   # Root login should be disabled
```

---

## Phase 7: Cleanup (CRITICAL!)

> ⚠️ **ALWAYS destroy resources when done practicing. Even free-tier resources can accumulate costs if left running.**

### Step 7.1: Destroy Main Infrastructure
```bash
cd terraform/environments/dev
terraform destroy
# Type "yes"
# Wait for all resources to be destroyed (3-5 minutes)
```

### Step 7.2: Verify Everything is Gone
```bash
# Check no instances running
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].InstanceId' --output text
# Should be empty

# Check no load balancers
aws elbv2 describe-load-balancers --output text
# Should be empty
```

### Step 7.3: Destroy Bootstrap (Optional)
Only if you're completely done with the project:
```bash
cd terraform/bootstrap

# First, empty the S3 bucket
aws s3 rm s3://$(terraform output -raw s3_bucket_name) --recursive

terraform destroy
# Type "yes"
```

### Step 7.4: Double-Check Console
Log into AWS Console and manually verify:
- EC2 → No running instances
- VPC → Only default VPC remains
- S3 → State bucket removed (or keep for next time)
- Load Balancers → None

---

## Cost Optimization Tips

### Free Tier Strategy
| Resource | Keep Running? | Cost if Left Running |
|----------|:------------:|---------------------|
| EC2 t2.micro | Only during practice | Free (750 hrs/month total) |
| ALB | Only during practice | Free (750 hrs/month) but LCU charges possible |
| S3 | ✅ Keep (tiny storage) | Free (5 GB) |
| DynamoDB | ✅ Keep (tiny table) | Free (25 GB) |
| NAT Gateway | ❌ AVOID | $0.045/hr = $32/month! |
| Elastic IP (unattached) | ❌ DESTROY | $0.005/hr = $3.60/month |

### Rules of Thumb
1. **Always `terraform destroy` after practice** — takes 5 minutes to recreate.
2. **Keep S3 + DynamoDB** — they're within free tier and needed for state.
3. **Never use NAT Gateway for learning** — use public subnets instead.
4. **Set a $5 budget alarm** — sleep peacefully.
5. **Check billing dashboard weekly** during your first month.

### Alternative: Use LocalStack (100% Free)
For purely local testing without any AWS charges:
```bash
# Install LocalStack
pip install localstack
localstack start

# Configure Terraform to use LocalStack
provider "aws" {
  endpoints {
    s3       = "http://localhost:4566"
    dynamodb = "http://localhost:4566"
    ec2      = "http://localhost:4566"
  }
  region     = "us-east-1"
  access_key = "fake"
  secret_key = "fake"
}
```
> ⚠️ LocalStack has limited free features. Real AWS free tier is better for this project.

---

## Troubleshooting

### "Error: No valid credential sources"
```bash
aws configure   # Re-enter your keys
aws sts get-caller-identity   # Verify
```

### "Error: creating EC2 Instance: UnauthorizedOperation"
Your IAM user lacks permissions. Ensure `AdministratorAccess` policy is attached.

### "ssh: Connection timed out"
- Check security group allows SSH (port 22) from your IP.
- Your IP may have changed — update the security group.
- Check the instance is in a public subnet with a public IP.

### "Ansible: UNREACHABLE"
- Ensure SSH key path in inventory is correct.
- Ensure `ansible_user=ec2-user` (Amazon Linux) or `ansible_user=ubuntu` (Ubuntu).
- Try: `ssh -i key.pem ec2-user@<ip>` manually first.

### "terraform destroy" hangs
- Some resources take time. Wait 5-10 minutes.
- If stuck, check AWS Console and delete manually.
- Common culprit: Non-empty S3 bucket (empty it first).

---

## What You Can Say in Interviews

After building this project, you can confidently discuss:

1. **"I architected a VPC with public/private subnets across 2 AZs"** — Explain the CIDR blocks, route tables, IGW.
2. **"I used Terraform modules for reusability"** — Show the module structure, explain inputs/outputs.
3. **"I set up remote state with S3 and DynamoDB locking"** — Explain why concurrent access needs locking.
4. **"I reduced provisioning time 80% with Ansible"** — Compare manual SSH + commands vs. one playbook run.
5. **"The ALB + ASG provides 99.9% uptime"** — Explain health checks, auto-replacement, multi-AZ.
6. **"I hardened the OS with Ansible"** — Disabled root SSH, password auth, configured fail2ban.

---

## Next: Build It!
Go to the `terraform/` and `ansible/` directories and start deploying. The code is ready.
