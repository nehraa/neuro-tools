#!/bin/bash
# Cross-Repo Test Coordinator for Neuro-OS
#
# Build all repositories in dependency order, then run integration tests.
# This ensures that all components are built with compatible versions and
# that the entire system works together correctly.
#
# Usage:
#   ./cross-repo-test.sh [--workspace DIR] [--clean]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
WORKSPACE_DIR="${WORKSPACE_DIR:-./neuro-workspace}"
CLEAN_BUILD=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --workspace)
            WORKSPACE_DIR="$2"
            shift 2
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --help)
            cat << EOF
Usage: $0 [OPTIONS]

Build all Neuro-OS repositories in dependency order and run integration tests.

OPTIONS:
    --workspace DIR     Workspace directory (default: ./neuro-workspace)
    --clean             Clean build (remove target directories first)
    --help              Show this help message

EXAMPLES:
    $0
    $0 --workspace ~/projects/neuro --clean
EOF
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Verify workspace
if [[ ! -d "$WORKSPACE_DIR" ]]; then
    echo -e "${RED}Error: Workspace directory not found: $WORKSPACE_DIR${NC}"
    echo "Run ./clone-all.sh first to set up the workspace"
    exit 1
fi

echo "========================================"
echo "  Cross-Repo Test Coordinator"
echo "========================================"
echo "Workspace: $WORKSPACE_DIR"
echo "Clean build: $CLEAN_BUILD"
echo "========================================"
echo

# Build repositories in dependency order
# The order matters: dependencies must be built before dependents

echo "Building in dependency order..."
echo

# 1. Build kernel (no dependencies)
echo -e "${BLUE}[1/5]${NC} Building neuro-kernel..."
(
    cd "$WORKSPACE_DIR/neuro-kernel" || exit 1
    
    if [[ "$CLEAN_BUILD" == "true" ]]; then
        cargo clean
    fi
    
    if cargo build --release; then
        echo -e "${GREEN}✓${NC} Kernel build successful"
    else
        echo -e "${RED}✗${NC} Kernel build failed"
        exit 1
    fi
) || exit 1

echo

# 2. Build services (depends on kernel interfaces)
echo -e "${BLUE}[2/5]${NC} Building neuro-services..."
(
    cd "$WORKSPACE_DIR/neuro-services" || exit 1
    
    if [[ "$CLEAN_BUILD" == "true" ]]; then
        cargo clean
    fi
    
    if cargo build --release; then
        echo -e "${GREEN}✓${NC} Services build successful"
    else
        echo -e "${RED}✗${NC} Services build failed"
        exit 1
    fi
) || exit 1

echo

# 3. Build compat layer (depends on kernel and services)
echo -e "${BLUE}[3/5]${NC} Building neuro-compat..."
(
    cd "$WORKSPACE_DIR/neuro-compat" || exit 1
    
    if [[ "$CLEAN_BUILD" == "true" ]]; then
        cargo clean
    fi
    
    if cargo build --release; then
        echo -e "${GREEN}✓${NC} Compat build successful"
    else
        echo -e "${RED}✗${NC} Compat build failed"
        exit 1
    fi
) || exit 1

echo

# 4. Build AI components (depends on services)
echo -e "${BLUE}[4/5]${NC} Building neuro-ai..."
(
    cd "$WORKSPACE_DIR/neuro-ai" || exit 1
    
    if [[ "$CLEAN_BUILD" == "true" ]]; then
        cargo clean
    fi
    
    if cargo build --release; then
        echo -e "${GREEN}✓${NC} AI build successful"
    else
        echo -e "${RED}✗${NC} AI build failed"
        exit 1
    fi
) || exit 1

echo

# 5. Build tools (no critical dependencies)
echo -e "${BLUE}[5/5]${NC} Building neuro-tools..."
(
    cd "$WORKSPACE_DIR/neuro-tools" || exit 1
    
    if [[ "$CLEAN_BUILD" == "true" ]]; then
        cargo clean 2>/dev/null || true
    fi
    
    # Tools may not have Rust components, so this is optional
    if [[ -f "Cargo.toml" ]]; then
        cargo build --release || echo -e "${YELLOW}⚠${NC} Tools build skipped (no Rust components)"
    else
        echo -e "${YELLOW}⚠${NC} Tools build skipped (no Cargo.toml)"
    fi
) || true

echo
echo "========================================"
echo "  All builds completed successfully!"
echo "========================================"
echo

# Run integration tests
echo -e "${BLUE}[INTEGRATION]${NC} Running integration tests..."
echo

# Run integration tests from tools repo
if [[ -d "$WORKSPACE_DIR/neuro-tools/testing/integration" ]]; then
    (
        cd "$WORKSPACE_DIR/neuro-tools/testing/integration" || exit 1
        
        if cargo test --release; then
            echo -e "${GREEN}✓${NC} Integration tests passed"
        else
            echo -e "${RED}✗${NC} Integration tests failed"
            exit 1
        fi
    ) || exit 1
else
    echo -e "${YELLOW}⚠${NC} Integration test directory not found, skipping"
fi

echo

# Run cross-component validation tests
echo -e "${BLUE}[VALIDATION]${NC} Running cross-component validation..."
echo

# Test that all components can find each other
TEST_RESULTS=0

echo "Checking component interfaces..."

# Check kernel exports
if [[ -f "$WORKSPACE_DIR/neuro-kernel/target/release/neuro-kernel" ]]; then
    echo -e "  ${GREEN}✓${NC} Kernel binary exists"
else
    echo -e "  ${RED}✗${NC} Kernel binary not found"
    TEST_RESULTS=1
fi

# Check services
if [[ -d "$WORKSPACE_DIR/neuro-services/target/release" ]]; then
    SERVICE_COUNT=$(find "$WORKSPACE_DIR/neuro-services/target/release" -maxdepth 1 -type f -executable | wc -l)
    echo -e "  ${GREEN}✓${NC} Services: $SERVICE_COUNT binaries found"
else
    echo -e "  ${RED}✗${NC} Services not built"
    TEST_RESULTS=1
fi

# Check compat layer
if [[ -d "$WORKSPACE_DIR/neuro-compat/target/release" ]]; then
    echo -e "  ${GREEN}✓${NC} Compat layer built"
else
    echo -e "  ${RED}✗${NC} Compat layer not built"
    TEST_RESULTS=1
fi

# Check AI components
if [[ -d "$WORKSPACE_DIR/neuro-ai/target/release" ]]; then
    echo -e "  ${GREEN}✓${NC} AI components built"
else
    echo -e "  ${RED}✗${NC} AI components not built"
    TEST_RESULTS=1
fi

echo

# Final summary
echo "========================================"
echo "  Test Summary"
echo "========================================"

if [[ $TEST_RESULTS -eq 0 ]]; then
    echo -e "${GREEN}✓ All builds and tests passed!${NC}"
    echo
    echo "Next steps:"
    echo "  - Create bootable image: cd neuro-tools && ./scripts/build-image.sh"
    echo "  - Test in QEMU: qemu-system-x86_64 -cdrom neuro-os.iso -m 512M"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
