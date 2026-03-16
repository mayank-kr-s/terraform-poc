#!/bin/bash
# ─────────────────────────────────────────────
# Quick Deploy Script — Full Pipeline
# ─────────────────────────────────────────────
# Runs: Terraform Apply → Generate Inventory → Ansible Playbook
# Usage: bash scripts/deploy.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "============================================"
echo "  Deploying Infrastructure + Configuration  "
echo "============================================"
echo ""

# Step 1: Terraform Apply
echo ">>> [1/4] Applying Terraform infrastructure..."
cd "$PROJECT_ROOT/terraform/environments/dev"
terraform init -input=false
terraform apply -auto-approve

echo ""
echo ">>> [2/4] Waiting for instances to boot (60 seconds)..."
sleep 60

# Step 2: Generate Inventory
echo ">>> [3/4] Generating Ansible inventory..."
cd "$PROJECT_ROOT"
bash scripts/generate-inventory.sh

# Step 3: Run Ansible
echo ">>> [4/4] Running Ansible playbook..."
cd "$PROJECT_ROOT/ansible"
ansible-playbook -i inventory/hosts.ini site.yml

echo ""
echo "============================================"
echo "  Deployment Complete!"
echo "============================================"

# Show access info
echo ""
ALB_DNS=$(terraform -chdir="$PROJECT_ROOT/terraform/environments/dev" output -raw alb_dns_name)
echo ">>> Access your application at:"
echo "    http://$ALB_DNS"
echo ""
echo ">>> Health check:"
echo "    http://$ALB_DNS/health"
echo ""
echo ">>> IMPORTANT: Run 'bash scripts/destroy.sh' when done to avoid charges!"
