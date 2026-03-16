# Terraform Beginner Guide — Infrastructure as Code

> **Goal**: Learn Terraform from zero and understand every `.tf` file in this project.

---

## 1. What is Terraform?

Terraform is a tool that lets you **define infrastructure in code files** instead of clicking around in the AWS Console.

```
You write code (.tf files)  →  Terraform reads it  →  Creates AWS resources
```

**Why?**
- **Reproducible**: Run the same code, get the same infrastructure every time.
- **Version Controlled**: Track changes in Git, review infrastructure changes in PRs.
- **Destroyable**: `terraform destroy` tears everything down — perfect for learning!

---

## 2. Install Terraform

### Windows
```powershell
# Option 1: Using Chocolatey
choco install terraform

# Option 2: Manual download
# Go to https://developer.hashicorp.com/terraform/downloads
# Download the Windows AMD64 zip
# Extract terraform.exe to a folder in your PATH (e.g., C:\terraform)
# Add to PATH: System Properties → Environment Variables → Path → Add C:\terraform
```

### macOS
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

### Linux
```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

### Verify
```bash
terraform version
# Terraform v1.7.x
```

---

## 3. Terraform Core Concepts

### 3.1 Providers
A provider is a **plugin** that tells Terraform how to talk to a cloud platform.

```hcl
# Tell Terraform we're using AWS
provider "aws" {
  region = "us-east-1"
}
```

### 3.2 Resources
A resource is **one AWS thing** — an EC2 instance, a VPC, a security group, etc.

```hcl
# Create an EC2 instance
resource "aws_instance" "my_server" {
  ami           = "ami-0c02fb55956c7d316"  # Amazon Linux 2023
  instance_type = "t2.micro"               # Free tier!

  tags = {
    Name = "my-first-server"
  }
}
```

**Syntax**: `resource "<provider>_<resource_type>" "<local_name>" { ... }`

### 3.3 Variables
Make your code reusable with variables.

```hcl
# variables.tf
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

# main.tf — use the variable
resource "aws_instance" "my_server" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = var.instance_type

  tags = {
    Name        = "web-server"
    Environment = var.environment
  }
}
```

### 3.4 Outputs
Display useful info after `terraform apply`.

```hcl
# outputs.tf
output "server_public_ip" {
  description = "Public IP of the web server"
  value       = aws_instance.my_server.public_ip
}

output "server_id" {
  description = "Instance ID"
  value       = aws_instance.my_server.id
}
```

### 3.5 Data Sources
Read **existing** AWS resources (don't create, just look up).

```hcl
# Look up the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Use it
resource "aws_instance" "my_server" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
}
```

---

## 4. The Terraform Workflow (The Big 3 Commands)

```
┌────────────────┐     ┌────────────────┐     ┌────────────────┐
│  terraform      │     │  terraform      │     │  terraform      │
│    init         │ ──→ │    plan         │ ──→ │    apply        │
│                 │     │                 │     │                 │
│ Downloads       │     │ Shows what will │     │ Actually creates│
│ providers       │     │ be created      │     │ the resources   │
└────────────────┘     └────────────────┘     └────────────────┘
```

### Step by Step
```bash
# 1. Initialize — download AWS provider plugin
terraform init

# 2. Plan — preview what Terraform WILL do (doesn't change anything)
terraform plan

# 3. Apply — actually create/modify the resources
terraform apply
# Type "yes" when prompted

# 4. Destroy — tear everything down (IMPORTANT for free tier!)
terraform destroy
# Type "yes" when prompted
```

---

## 5. Terraform State

When you run `terraform apply`, Terraform creates a **state file** (`terraform.tfstate`) that maps your `.tf` code to real AWS resources.

```
terraform.tfstate says:
  "aws_instance.my_server" = "i-0abc123def456"
```

### Local State (Default)
- Stored in `terraform.tfstate` in your project folder.
- **Problem**: If two people run Terraform at the same time, state gets corrupted.

### Remote State (What We Use — S3 + DynamoDB)
- State file stored in **S3 bucket**.
- **DynamoDB table** provides **locking** (only one person can modify at a time).

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket-12345"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock-table"
    encrypt        = true
  }
}
```

---

## 6. Terraform Modules (Reusable Code)

A module is a **folder of .tf files** that you can reuse.

### Folder Structure
```
modules/
├── vpc/
│   ├── main.tf        # VPC, subnets, IGW, route tables
│   ├── variables.tf   # Input parameters
│   └── outputs.tf     # Values to pass to other modules
├── ec2/
│   ├── main.tf        # EC2, security groups
│   ├── variables.tf
│   └── outputs.tf
└── alb/
    ├── main.tf        # ALB, target group, listener
    ├── variables.tf
    └── outputs.tf
```

### Using a Module
```hcl
# main.tf (root)
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr         = "10.0.0.0/16"
  public_subnets   = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets  = ["10.0.3.0/24", "10.0.4.0/24"]
  environment      = "dev"
}

module "ec2" {
  source = "./modules/ec2"

  vpc_id    = module.vpc.vpc_id          # ← output from vpc module
  subnet_id = module.vpc.public_subnet_ids[0]
}
```

---

## 7. Common Terraform Syntax Patterns

### Loops with `count`
```hcl
# Create 2 subnets
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}
```

### Loops with `for_each`
```hcl
variable "subnets" {
  default = {
    "public-1" = "10.0.1.0/24"
    "public-2" = "10.0.2.0/24"
  }
}

resource "aws_subnet" "public" {
  for_each          = var.subnets
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value

  tags = {
    Name = each.key
  }
}
```

### Conditional Resources
```hcl
# Only create NAT Gateway if create_nat is true
resource "aws_nat_gateway" "main" {
  count         = var.create_nat ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id
}
```

### String Interpolation
```hcl
tags = {
  Name = "${var.environment}-web-server"    # "dev-web-server"
}
```

---

## 8. Your First Terraform Project (Hands-On)

Create a folder and try this:

### Step 1: Create `main.tf`
```hcl
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
  region = "us-east-1"
}

# Create a VPC
resource "aws_vpc" "my_first_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "my-first-vpc"
  }
}

# Create a subnet
resource "aws_subnet" "my_first_subnet" {
  vpc_id                  = aws_vpc.my_first_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "my-first-subnet"
  }
}
```

### Step 2: Run It
```bash
terraform init      # Download AWS provider
terraform plan      # See what will be created
terraform apply     # Create it! (type "yes")
terraform destroy   # Clean up (type "yes")
```

---

## 9. Terraform Command Cheat Sheet

```bash
terraform init              # Initialize, download providers
terraform plan              # Preview changes
terraform apply             # Apply changes
terraform destroy           # Destroy all resources
terraform fmt               # Format code nicely
terraform validate          # Check syntax errors
terraform output            # Show output values
terraform state list        # List resources in state
terraform state show <name> # Show details of one resource
terraform import <addr> <id># Import existing resource into state
terraform refresh           # Refresh state from real resources
```

---

## 10. Common Mistakes & Fixes

| Mistake | Fix |
|---------|-----|
| `Error: No valid credential sources found` | Run `aws configure` and set your keys |
| `Error: creating S3 Bucket: BucketAlreadyExists` | S3 bucket names are global. Add random suffix. |
| `Error: InvalidParameterValue: instance type t2.micro is not supported` | Try `t3.micro` or change region |
| Resources still exist after `terraform destroy` | Check the console manually; some resources need manual cleanup |
| State file conflict | Use remote state with DynamoDB locking |

---

## Next Steps
- Read [03-Ansible-Beginner-Guide.md](03-Ansible-Beginner-Guide.md) to learn Configuration Management.
- Read [04-Step-by-Step-Project-Guide.md](04-Step-by-Step-Project-Guide.md) to build the full project.
