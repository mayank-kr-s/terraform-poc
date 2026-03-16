#!/bin/bash
# ─────────────────────────────────────────────
# Generate Ansible inventory from Terraform output
# ─────────────────────────────────────────────
# Run this after: terraform apply
# Usage: bash scripts/generate-inventory.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform/environments/dev"
INVENTORY_FILE="$PROJECT_ROOT/ansible/inventory/hosts.ini"
KEY_FILE="~/.ssh/terraform-poc-key.pem"

echo ">>> Fetching EC2 instance IPs from Terraform..."

# Get ASG name from Terraform output
ASG_NAME=$(terraform -chdir="$TERRAFORM_DIR" output -raw asg_name 2>/dev/null)

if [ -z "$ASG_NAME" ]; then
    echo "ERROR: Could not get ASG name. Have you run 'terraform apply'?"
    exit 1
fi

echo ">>> ASG Name: $ASG_NAME"

# Get instance IDs from ASG
INSTANCE_IDS=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --query 'AutoScalingGroups[0].Instances[?LifecycleState==`InService`].InstanceId' \
    --output text)

if [ -z "$INSTANCE_IDS" ]; then
    echo "ERROR: No running instances found in ASG."
    exit 1
fi

echo ">>> Found instances: $INSTANCE_IDS"

# Get public IPs
PUBLIC_IPS=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_IDS \
    --query 'Reservations[].Instances[].PublicIpAddress' \
    --output text)

echo ">>> Public IPs: $PUBLIC_IPS"

# Generate inventory file
cat > "$INVENTORY_FILE" <<EOF
# ─────────────────────────────────────────────
# Auto-generated Ansible Inventory
# Generated: $(date)
# ─────────────────────────────────────────────

[webservers]
EOF

for IP in $PUBLIC_IPS; do
    echo "$IP ansible_user=ec2-user ansible_ssh_private_key_file=$KEY_FILE" >> "$INVENTORY_FILE"
done

cat >> "$INVENTORY_FILE" <<EOF

[webservers:vars]
ansible_python_interpreter=/usr/bin/python3

[all:vars]
environment=dev
project_name=terraform-poc
EOF

echo ""
echo ">>> Inventory generated at: $INVENTORY_FILE"
echo ">>> Contents:"
cat "$INVENTORY_FILE"
echo ""
echo ">>> Test connectivity with: ansible all -i $INVENTORY_FILE -m ping"
