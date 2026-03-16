# ─────────────────────────────────────────────
#  Remote State Backend (S3 + DynamoDB)
# ─────────────────────────────────────────────
# IMPORTANT: Update the bucket name after running bootstrap!
# Run: cd terraform/bootstrap && terraform output s3_bucket_name

terraform {
  backend "s3" {
    bucket         = "terraform-poc-state-REPLACE_WITH_YOUR_ACCOUNT_ID"
    key            = "env/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-poc-lock"
    encrypt        = true
  }
}
