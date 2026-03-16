#!/bin/bash
# ─────────────────────────────────────────────
# Destroy Script — Tear down all infrastructure
# ─────────────────────────────────────────────
# Usage: bash scripts/destroy.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "============================================"
echo "  Destroying Infrastructure                 "
echo "============================================"
echo ""
echo "⚠️  This will DESTROY all AWS resources!"
echo "    (S3 state bucket and DynamoDB will be kept)"
echo ""
read -p "Are you sure? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo ">>> Destroying main infrastructure..."
cd "$PROJECT_ROOT/terraform/environments/dev"
terraform destroy -auto-approve

echo ""
echo "============================================"
echo "  Infrastructure Destroyed!"
echo "============================================"
echo ""
echo ">>> S3 bucket and DynamoDB table are still intact (for next deploy)."
echo ">>> To destroy those too, run:"
echo "    cd terraform/bootstrap && terraform destroy"
