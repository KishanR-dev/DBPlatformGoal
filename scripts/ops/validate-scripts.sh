#!/bin/bash
# ==============================================================================
# Script: validate-scripts.sh
# Purpose: Shell script quality, syntax & ShellCheck linter validation
# Author: DBPlatformGoal Operations Engineering
# Target: Ubuntu 26.04 LTS / Docker / ShellCheck
# ==============================================================================
set -euo pipefail

readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly RED='\033[0;31m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo -e "${BLUE}${BOLD}========================================================================${NC}"
echo -e "${BLUE}${BOLD}  DBPlatformGoal — Shell Automation Quality & Static Analysis           ${NC}"
echo -e "${BLUE}${BOLD}========================================================================${NC}"
echo -e "Scanning repository for shell scripts (*.sh)..."
echo ""

# Find all shell scripts in scripts/
mapfile -t SCRIPTS < <(find "${REPO_ROOT}/scripts" -name "*.sh" | sort)

if [[ ${#SCRIPTS[@]} -eq 0 ]]; then
    echo -e "${RED}Error: No shell scripts found in ${REPO_ROOT}/scripts${NC}" >&2
    exit 1
fi

echo -e "Found ${#SCRIPTS[@]} shell scripts to validate:"
for s in "${SCRIPTS[@]}"; do
    rel_path="${s#"${REPO_ROOT}/"}"
    echo "  - ${rel_path}"
done
echo ""

TOTAL_FAILURES=0

# 1. Syntax Validation (bash -n)
echo -e "${BOLD}1. BASH SYNTAX VERIFICATION (bash -n):${NC}"
for s in "${SCRIPTS[@]}"; do
    rel_path="${s#"${REPO_ROOT}/"}"
    echo -n "  Checking syntax: ${rel_path} ... "
    if bash -n "$s"; then
        echo -e "${GREEN}PASSED${NC}"
    else
        echo -e "${RED}FAILED${NC}"
        TOTAL_FAILURES=$(( TOTAL_FAILURES + 1 ))
    fi
done
echo ""

# 2. Static Analysis via ShellCheck
echo -e "${BOLD}2. STATIC ANALYSIS VIA SHELLCHECK (koalaman/shellcheck:stable):${NC}"
for s in "${SCRIPTS[@]}"; do
    rel_path="${s#"${REPO_ROOT}/"}"
    echo -n "  Linting: ${rel_path} ... "

    # Run ShellCheck via Docker feeding script contents through stdin to ensure path-agnostic execution
    if docker run --rm -i koalaman/shellcheck:stable - < "$s"; then
        echo -e "${GREEN}CLEAN (0 warnings)${NC}"
    else
        echo -e "${RED}WARNINGS/ERRORS DETECTED${NC}"
        TOTAL_FAILURES=$(( TOTAL_FAILURES + 1 ))
    fi
done
echo ""

echo -e "${BLUE}========================================================================${NC}"
if [[ "$TOTAL_FAILURES" -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}✓ ALL SHELL SCRIPTS PASSED SYNTAX & SHELLCHECK VALIDATION.${NC}"
    echo -e "${BLUE}========================================================================${NC}"
    exit 0
else
    echo -e "${RED}${BOLD}✗ VALIDATION FAILED: ${TOTAL_FAILURES} failure(s) detected.${NC}"
    echo -e "${BLUE}========================================================================${NC}"
    exit 1
fi
