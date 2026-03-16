# AWS Beginner Guide — Free Tier Survival Kit

> **Goal**: Understand every AWS service used in this project without spending a dime.

---

## 1. AWS Free Tier — What You Get for Free

When you create a **new** AWS account you get **12 months** of free-tier usage. The services we use all fall within it:

| Service | Free Tier Allowance | What We Use It For |
|---------|--------------------|--------------------|
| **EC2** | 750 hrs/month of `t2.micro` (or `t3.micro` in some regions) | Web servers |
| **ALB** | 750 hrs/month + 15 LCUs | Load balancing traffic |
| **S3** | 5 GB storage | Terraform remote state |
| **DynamoDB** | 25 GB + 25 read/write capacity units | Terraform state locking |
| **VPC** | Always free (no charge for VPC itself) | Networking |
| **NAT Gateway** | ⚠️ **NOT free** (~$0.045/hr + data) | We'll use alternatives (see below) |

### 💡 Cost-Saving Tips
- **Always stay in ONE region** (e.g., `us-east-1`).
- **Use `t2.micro`** (or `t3.micro`) — they're free-tier eligible.
- **Destroy resources when done** — run `terraform destroy` after every practice session.
- **Set up a Billing Alarm** (see below) so you never get surprise charges.
- **Avoid NAT Gateway** — we'll use a workaround (bastion host + public subnets for practice).

---

## 2. Creating an AWS Account (Step by Step)

1. Go to <https://aws.amazon.com/free> and click **Create a Free Account**.
2. Enter email, password, and an account name (e.g., `my-learning-account`).
3. Choose **Personal** account type.
4. Enter credit/debit card info — **AWS may charge $1 (refunded)** to verify.
5. Choose the **Basic (Free)** support plan.
6. Sign in to the **AWS Management Console**.

### Set Up Billing Alarm (DO THIS FIRST!)
```
Console → Billing → Budgets → Create Budget
  → Cost budget → Monthly → $5 threshold
  → Email notification
```
This alerts you if you accidentally leave resources running.

---

## 3. AWS Services Explained (Project Context)

### 3.1 VPC (Virtual Private Cloud)
Think of a VPC as **your own private data center** inside AWS.

```
┌─────────────────── VPC (10.0.0.0/16) ───────────────────┐
│                                                           │
│  ┌── Public Subnet (10.0.1.0/24) ──┐                    │
│  │  • Has Internet Gateway          │                    │
│  │  • ALB lives here                │                    │
│  │  • Bastion host (optional)       │                    │
│  └──────────────────────────────────┘                    │
│                                                           │
│  ┌── Private Subnet (10.0.2.0/24) ──┐                   │
│  │  • No direct internet access      │                   │
│  │  • EC2 web servers live here      │                   │
│  │  • Access internet via NAT        │                   │
│  └───────────────────────────────────┘                   │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

**Key Concepts:**
- **CIDR Block**: An IP address range. `10.0.0.0/16` = 65,536 IPs.
- **Subnet**: A smaller slice of the VPC. `/24` = 256 IPs.
- **Public Subnet**: Has a route to the Internet Gateway.
- **Private Subnet**: Does NOT have a direct route to the internet.

### 3.2 Internet Gateway (IGW)
The **front door** of your VPC to the internet.
- Attached to the VPC.
- Public subnets route `0.0.0.0/0` → IGW.

### 3.3 NAT Gateway
Lets **private subnet instances** access the internet (e.g., to download packages) **without** being reachable from the internet.

> ⚠️ **Free Tier Warning**: NAT Gateway costs money! For learning, we'll put EC2 instances in public subnets OR use a NAT instance (free-tier `t2.micro`).

### 3.4 EC2 (Elastic Compute Cloud)
A **virtual server** in the cloud.

```
Instance Type:  t2.micro (1 vCPU, 1 GB RAM) — FREE TIER
AMI:            Amazon Linux 2023 or Ubuntu 22.04
Key Pair:       SSH key to log into the server
Security Group: Firewall rules (which ports are open)
```

**Example — Launch EC2 via Console (for understanding):**
1. Console → EC2 → Launch Instance
2. Name: `my-web-server`
3. AMI: Amazon Linux 2023
4. Instance type: `t2.micro`
5. Key pair: Create new → Download `.pem` file
6. Network: Select your VPC and subnet
7. Security Group: Allow SSH (port 22) and HTTP (port 80)
8. Launch!

### 3.5 Security Groups
A **virtual firewall** for your EC2 instances.

```
Inbound Rules:
  ┌──────────┬──────────┬───────────────┐
  │ Protocol │ Port     │ Source        │
  ├──────────┼──────────┼───────────────┤
  │ SSH      │ 22       │ Your IP only  │
  │ HTTP     │ 80       │ 0.0.0.0/0    │
  │ HTTPS    │ 443      │ 0.0.0.0/0    │
  └──────────┴──────────┴───────────────┘

Outbound Rules:
  All traffic → 0.0.0.0/0 (allow all outbound by default)
```

### 3.6 Application Load Balancer (ALB)
Distributes incoming web traffic across **multiple EC2 instances**.

```
Internet → ALB (port 80) → Target Group → EC2-1, EC2-2, EC2-3
```

**Components:**
- **Listener**: Checks for connection requests (port 80).
- **Target Group**: A group of EC2 instances to send traffic to.
- **Health Check**: ALB pings `/health` on each EC2; unhealthy ones are removed.

### 3.7 Auto Scaling Group (ASG)
Automatically **adds or removes** EC2 instances based on demand.

```
Min: 1 instance   (always running at least 1)
Desired: 2         (normally run 2)
Max: 4             (scale up to 4 during traffic spikes)
```

**Scaling Policies:**
- **Target Tracking**: Keep CPU at ~60%.
- **Step Scaling**: If CPU > 80% → add 1 instance.

### 3.8 S3 (Simple Storage Service)
Object storage — we use it to store **Terraform state files**.

```
Bucket: my-terraform-state-bucket-unique-name
  └── env/
      └── dev/
          └── terraform.tfstate    ← Terraform writes this
```

### 3.9 DynamoDB
A NoSQL database — we use a simple table for **Terraform state locking**.

```
Table: terraform-lock-table
  Partition Key: LockID (String)
```
When someone runs `terraform apply`, it writes a lock. Others must wait.

---

## 4. AWS CLI Setup

### Install AWS CLI
```bash
# Windows (download MSI installer)
# https://awscli.amazonaws.com/AWSCLIV2.msi

# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### Configure Credentials
```bash
aws configure
# AWS Access Key ID:     <your-key>
# AWS Secret Access Key: <your-secret>
# Default region name:   us-east-1
# Default output format: json
```

**To get Access Keys:**
1. Console → IAM → Users → Your User → Security Credentials
2. Create Access Key → Choose "CLI" → Download `.csv`

> ⚠️ **NEVER** commit AWS keys to Git. Use `aws configure` or environment variables.

### Verify Setup
```bash
aws sts get-caller-identity
# Should show your account ID and user ARN
```

---

## 5. IAM Best Practices (Even for Personal Accounts)

1. **Don't use the root account** for daily work.
2. Create an **IAM user** with **AdministratorAccess** policy.
3. Enable **MFA** on both root and IAM user.
4. Use **IAM roles** for EC2 instances (not access keys on servers).

```
Console → IAM → Users → Add User
  → User name: terraform-admin
  → Attach policy: AdministratorAccess
  → Create access key for CLI
```

---

## 6. Useful AWS CLI Commands (Cheat Sheet)

```bash
# List all EC2 instances
aws ec2 describe-instances --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name,Type:InstanceType}' --output table

# List all VPCs
aws ec2 describe-vpcs --output table

# List S3 buckets
aws s3 ls

# List DynamoDB tables
aws dynamodb list-tables

# Check your current identity
aws sts get-caller-identity

# Get your account's available AZs
aws ec2 describe-availability-zones --region us-east-1 --output table
```

---

## 7. Architecture Overview for Our Project

```
                    Internet
                       │
                 ┌─────┴─────┐
                 │    IGW     │
                 └─────┬─────┘
                       │
              ┌────────┴────────┐
              │      VPC        │
              │  10.0.0.0/16    │
              │                 │
  ┌───────────┴───┐   ┌───┴───────────┐
  │ Public Sub 1  │   │ Public Sub 2  │
  │ 10.0.1.0/24   │   │ 10.0.2.0/24   │
  │    (AZ-a)     │   │    (AZ-b)     │
  │               │   │               │
  │  ┌─── ALB ────┤   │               │
  └───────────────┘   └───────────────┘
              │
  ┌───────────┴───┐   ┌───────────────┐
  │ Private Sub 1 │   │ Private Sub 2 │
  │ 10.0.3.0/24   │   │ 10.0.4.0/24   │
  │    (AZ-a)     │   │    (AZ-b)     │
  │               │   │               │
  │   EC2 (ASG)   │   │   EC2 (ASG)   │
  └───────────────┘   └───────────────┘
```

> **Free-Tier Adaptation**: For practice, we'll place EC2 instances in **public subnets** to avoid NAT Gateway costs, then show how to move them to private subnets in production.

---

## Next Steps
- Read [02-Terraform-Beginner-Guide.md](02-Terraform-Beginner-Guide.md) to learn Infrastructure as Code.
- Read [03-Ansible-Beginner-Guide.md](03-Ansible-Beginner-Guide.md) to learn Configuration Management.
