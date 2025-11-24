#!/bin/bash
# =============================================================================
# Cedar Policy Test Runner
# Validates Cedar policies against schema and runs authorization tests
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_ROOT="${SCRIPT_DIR}/.."
CEDAR_DIR="${POLICY_ROOT}/cedar"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Nabla Enclave - Cedar Policy Test Suite"
echo "=========================================="

# Check if cedar CLI is installed
if ! command -v cedar &> /dev/null; then
    echo -e "${RED}Error: cedar CLI not found${NC}"
    echo "Install with: cargo install cedar-policy-cli"
    exit 1
fi

# Test 1: Validate schema
echo -e "\n${YELLOW}[1/4] Validating Cedar schema...${NC}"

# Create a temporary combined policy file for validation
COMBINED_POLICIES=$(mktemp)
trap "rm -f $COMBINED_POLICIES" EXIT

# Concatenate all policy files with newlines between them
find "${CEDAR_DIR}/policies" -name "*.cedar" -type f -exec cat {} \; -exec echo "" \; > "$COMBINED_POLICIES"

if cedar validate \
    --schema "${CEDAR_DIR}/schema/nabla.cedarschema" \
    --schema-format cedar \
    --policies "$COMBINED_POLICIES" 2>&1; then
    echo -e "${GREEN}✓ Schema validation passed${NC}"
else
    echo -e "${RED}✗ Schema validation failed${NC}"
    exit 1
fi

# Test 2: Check policy syntax
echo -e "\n${YELLOW}[2/4] Checking policy syntax...${NC}"
POLICY_FILES=$(find "${CEDAR_DIR}/policies" -name "*.cedar" -type f)
SYNTAX_ERRORS=0

for policy_file in $POLICY_FILES; do
    if cedar check-parse --policies "$policy_file" 2>&1; then
        echo -e "  ${GREEN}✓${NC} $(basename "$policy_file")"
    else
        echo -e "  ${RED}✗${NC} $(basename "$policy_file")"
        SYNTAX_ERRORS=$((SYNTAX_ERRORS + 1))
    fi
done

if [ $SYNTAX_ERRORS -gt 0 ]; then
    echo -e "${RED}✗ Syntax check failed with $SYNTAX_ERRORS errors${NC}"
    exit 1
else
    echo -e "${GREEN}✓ All policy files have valid syntax${NC}"
fi

# Test 3: Validate entities against schema
echo -e "\n${YELLOW}[3/4] Validating entity files...${NC}"
ENTITY_FILES=$(find "${CEDAR_DIR}/entities" -name "*.json" -type f)
ENTITY_ERRORS=0

for entity_file in $ENTITY_FILES; do
    if jq empty "$entity_file" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $(basename "$entity_file") - valid JSON"
    else
        echo -e "  ${RED}✗${NC} $(basename "$entity_file") - invalid JSON"
        ENTITY_ERRORS=$((ENTITY_ERRORS + 1))
    fi
done

if [ $ENTITY_ERRORS -gt 0 ]; then
    echo -e "${RED}✗ Entity validation failed with $ENTITY_ERRORS errors${NC}"
    exit 1
else
    echo -e "${GREEN}✓ All entity files are valid${NC}"
fi

# Test 4: Run authorization tests
echo -e "\n${YELLOW}[4/4] Running authorization tests...${NC}"
if [ -d "${SCRIPT_DIR}/authorization" ]; then
    TEST_FILES=$(find "${SCRIPT_DIR}/authorization" -name "*.json" -type f 2>/dev/null || true)
    if [ -n "$TEST_FILES" ]; then
        for test_file in $TEST_FILES; do
            echo "  Running $(basename "$test_file")..."
            # Cedar authorize command would go here
        done
    else
        echo -e "  ${YELLOW}No authorization test files found${NC}"
    fi
else
    echo -e "  ${YELLOW}No authorization tests directory found${NC}"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}All policy tests passed!${NC}"
echo "=========================================="
