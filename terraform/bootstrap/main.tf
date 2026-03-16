# Bootstrap - Creates S3 bucket and DynamoDB table for Terraform remote state

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

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# ─── S3 Bucket for Terraform State ───
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-state-${data.aws_caller_identity.current.account_id}"

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = false # Set to true in production
  }

  tags = {
    Name        = "${var.project_name}-terraform-state"
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# Enable versioning — keeps history of state files
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access to the state bucket
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ─── DynamoDB Table for State Locking ───
resource "aws_dynamodb_table" "terraform_lock" {
  name         = "${var.project_name}-lock"
  billing_mode = "PAY_PER_REQUEST" # Free tier: 25 read/write capacity units
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "${var.project_name}-terraform-lock"
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}
