#!/bin/bash
# =============================================================================
# Policy Deployment Script
# Deploys policies to the OPAL server for distribution
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_ROOT="${SCRIPT_DIR}/.."

# Configuration
OPAL_SERVER_URL="${OPAL_SERVER_URL:-http://opal-server.policy-system.svc.cluster.local:7002}"

echo "=========================================="
echo "Nabla Enclave - Policy Deployment"
echo "=========================================="

# Step 1: Validate policies before deployment
echo ""
echo "[1/3] Validating policies..."
"${POLICY_ROOT}/tests/test_policies.sh"

# Step 2: Build policy bundle
echo ""
echo "[2/3] Building policy bundle..."
BUNDLE_DIR=$(mktemp -d)
trap "rm -rf ${BUNDLE_DIR}" EXIT

# Copy Cedar files
cp -r "${POLICY_ROOT}/cedar/schema" "${BUNDLE_DIR}/"
cp -r "${POLICY_ROOT}/cedar/policies" "${BUNDLE_DIR}/"
cp -r "${POLICY_ROOT}/cedar/entities" "${BUNDLE_DIR}/"

# Create manifest
cat > "${BUNDLE_DIR}/manifest.json" << EOF
{
  "version": "$(git -C "${POLICY_ROOT}" rev-parse --short HEAD 2>/dev/null || echo 'dev')",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "schema": "schema/nabla.cedarschema",
  "policies": [
    "policies/core",
    "policies/applications",
    "policies/compliance"
  ],
  "entities": [
    "entities/groups.json",
    "entities/namespaces.json",
    "entities/applications.json",
    "entities/databases.json",
    "entities/storage.json"
  ]
}
EOF

echo "Bundle created at: ${BUNDLE_DIR}"

# Step 3: Trigger OPAL update (if not using Git sync)
echo ""
echo "[3/3] Notifying OPAL server..."

if command -v curl &> /dev/null; then
    # Trigger policy refresh
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "${OPAL_SERVER_URL}/policy/refresh" \
        -H "Content-Type: application/json" \
        2>/dev/null || echo "000")

    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "202" ]; then
        echo "✓ OPAL server notified successfully"
    elif [ "$HTTP_CODE" = "000" ]; then
        echo "⚠ Could not connect to OPAL server (this is OK if using Git sync)"
    else
        echo "⚠ OPAL server returned HTTP $HTTP_CODE"
    fi
else
    echo "⚠ curl not found, skipping OPAL notification"
fi

echo ""
echo "=========================================="
echo "Policy deployment complete!"
echo "=========================================="
echo ""
echo "If using Git-based sync, commit and push your changes:"
echo "  git add ."
echo "  git commit -m 'Update policies'"
echo "  git push origin main"
