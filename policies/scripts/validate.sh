#!/bin/bash
# =============================================================================
# Pre-commit Validation Script
# Run this before committing policy changes
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_ROOT="${SCRIPT_DIR}/.."

echo "Validating Cedar policies..."

# Run the test suite
"${POLICY_ROOT}/tests/test_policies.sh"

echo ""
echo "Pre-commit validation passed!"
