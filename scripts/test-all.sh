#!/bin/bash
# Test All Neuro-OS Components
#
# This script runs comprehensive tests across all Neuro-OS repositories:
# - Unit tests
# - Integration tests
# - Property-based tests
# - Performance tests
# - Cross-component tests
#
# Usage:
#   ./test-all.sh [--workspace DIR] [--filter PATTERN] [--parallel N]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
WORKSPACE_DIR="${WORKSPACE_DIR:-./neuro-workspace}"
TEST_FILTER="${TEST_FILTER:-}"
PARALLEL_JOBS="${PARALLEL_JOBS:-4}"
VERBOSE=false
FAIL_FAST=false

# Test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --workspace)
                WORKSPACE_DIR="$2"
                shift 2
                ;;
            --filter)
                TEST_FILTER="$2"
                shift 2
                ;;
            --parallel)
                PARALLEL_JOBS="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --fail-fast)
                FAIL_FAST=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}Error: Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Run comprehensive tests across all Neuro-OS components.

OPTIONS:
    --workspace DIR     Workspace directory (default: ./neuro-workspace)
    --filter PATTERN    Run only tests matching pattern
    --parallel N        Number of parallel test jobs (default: 4)
    --verbose           Show detailed test output
    --fail-fast         Stop on first test failure
    --help              Show this help message

EXAMPLES:
    $0
    $0 --filter "integration" --verbose
    $0 --parallel 8 --fail-fast
EOF
}

# Run tests for a component
run_component_tests() {
    local component="$1"
    local component_dir="${WORKSPACE_DIR}/${component}"
    
    if [[ ! -d "$component_dir" ]]; then
        echo -e "${YELLOW}[SKIP]${NC} ${component} (not found)"
        return 0
    fi
    
    echo -e "${BLUE}[TEST]${NC} Testing ${component}..."
    
    local component_failed=false
    
    # Determine test command based on component
    if [[ -f "${component_dir}/Cargo.toml" ]]; then
        # Rust project
        (
            cd "$component_dir"
            
            # Unit tests
            echo -e "  ${BLUE}→${NC} Running unit tests..."
            local unit_test_result
            if [[ -n "$TEST_FILTER" ]]; then
                unit_test_result=$(cargo test --lib -- "$TEST_FILTER" 2>&1)
            else
                unit_test_result=$(cargo test --lib 2>&1)
            fi
            
            if [[ $? -eq 0 ]]; then
                echo -e "  ${GREEN}✓${NC} Unit tests passed"
                ((PASSED_TESTS++))
            else
                echo -e "  ${RED}✗${NC} Unit tests failed"
                ((FAILED_TESTS++))
                component_failed=true
                [[ "$FAIL_FAST" == "true" ]] && return 1
            fi
            
            # Integration tests
            echo -e "  ${BLUE}→${NC} Running integration tests..."
            local integration_test_result
            if [[ -n "$TEST_FILTER" ]]; then
                integration_test_result=$(cargo test --test '*' -- "$TEST_FILTER" 2>&1)
            else
                integration_test_result=$(cargo test --test '*' 2>&1)
            fi
            
            if [[ $? -eq 0 ]]; then
                echo -e "  ${GREEN}✓${NC} Integration tests passed"
                ((PASSED_TESTS++))
            else
                echo -e "  ${RED}✗${NC} Integration tests failed"
                ((FAILED_TESTS++))
                component_failed=true
                [[ "$FAIL_FAST" == "true" ]] && return 1
            fi
            
            # Doc tests
            echo -e "  ${BLUE}→${NC} Running doc tests..."
            if cargo test --doc; then
                echo -e "  ${GREEN}✓${NC} Doc tests passed"
                ((PASSED_TESTS++))
            else
                echo -e "  ${RED}✗${NC} Doc tests failed"
                ((FAILED_TESTS++))
                component_failed=true
            fi
            
        ) 2>&1 | if [[ "$VERBOSE" == "true" ]]; then cat; else grep -E "(test result:|✓|✗|→)"; fi
        
    elif [[ -f "${component_dir}/BUILD" ]] || [[ -f "${component_dir}/BUILD.bazel" ]]; then
        # Bazel project
        (
            cd "$component_dir"
            
            echo -e "  ${BLUE}→${NC} Running Bazel tests..."
            if bazel test //...; then
                echo -e "  ${GREEN}✓${NC} Bazel tests passed"
                ((PASSED_TESTS++))
            else
                echo -e "  ${RED}✗${NC} Bazel tests failed"
                ((FAILED_TESTS++))
                component_failed=true
            fi
            
        ) 2>&1 | if [[ "$VERBOSE" == "true" ]]; then cat; else grep -E "(PASSED|FAILED|✓|✗|→)"; fi
    else
        echo -e "${YELLOW}[SKIP]${NC} ${component} (no test configuration found)"
        ((SKIPPED_TESTS++))
    fi
    
    if [[ "$component_failed" == "true" ]]; then
        return 1
    else
        return 0
    fi
}

# Run cross-component integration tests
run_integration_tests() {
    echo
    echo -e "${BLUE}[INTEGRATION]${NC} Running cross-component tests..."
    
    local integration_dir="${WORKSPACE_DIR}/neuro-tools/testing/integration"
    
    if [[ ! -d "$integration_dir" ]]; then
        echo -e "${YELLOW}[SKIP]${NC} Integration tests (directory not found)"
        return 0
    fi
    
    (
        cd "$integration_dir"
        
        local test_result
        if [[ -n "$TEST_FILTER" ]]; then
            test_result=$(cargo test --release -- "$TEST_FILTER" 2>&1)
        else
            test_result=$(cargo test --release 2>&1)
        fi
        
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}✓${NC} Integration tests passed"
            ((PASSED_TESTS++))
            return 0
        else
            echo -e "${RED}✗${NC} Integration tests failed"
            ((FAILED_TESTS++))
            return 1
        fi
    ) 2>&1 | if [[ "$VERBOSE" == "true" ]]; then cat; else grep -E "(test result:|✓|✗)"; fi
}

# Run property-based tests
run_property_tests() {
    echo
    echo -e "${BLUE}[PROPERTY]${NC} Running property-based tests..."
    
    local property_test="${WORKSPACE_DIR}/neuro-tools/testing/property_tests.rs"
    
    if [[ ! -f "$property_test" ]]; then
        echo -e "${YELLOW}[SKIP]${NC} Property tests (file not found)"
        return 0
    fi
    
    (
        cd "${WORKSPACE_DIR}/neuro-tools/testing"
        
        local test_result
        if [[ -n "$TEST_FILTER" ]]; then
            test_result=$(cargo test property_tests -- "$TEST_FILTER" 2>&1)
        else
            test_result=$(cargo test property_tests 2>&1)
        fi
        
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}✓${NC} Property tests passed"
            ((PASSED_TESTS++))
            return 0
        else
            echo -e "${RED}✗${NC} Property tests failed"
            ((FAILED_TESTS++))
            return 1
        fi
    ) 2>&1 | if [[ "$VERBOSE" == "true" ]]; then cat; else grep -E "(test result:|✓|✗)"; fi
}

# Print test summary
print_summary() {
    local total=$((PASSED_TESTS + FAILED_TESTS + SKIPPED_TESTS))
    
    echo
    echo "========================================"
    echo "  Test Summary"
    echo "========================================"
    echo -e "Total:   ${total}"
    echo -e "Passed:  ${GREEN}${PASSED_TESTS}${NC}"
    echo -e "Failed:  ${RED}${FAILED_TESTS}${NC}"
    echo -e "Skipped: ${YELLOW}${SKIPPED_TESTS}${NC}"
    echo "========================================"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        return 1
    fi
}

# Main function
main() {
    parse_args "$@"
    
    echo "========================================"
    echo "  Neuro-OS Test Suite"
    echo "========================================"
    echo "Workspace: ${WORKSPACE_DIR}"
    echo "Filter: ${TEST_FILTER:-<none>}"
    echo "Parallel: ${PARALLEL_JOBS}"
    echo "========================================"
    echo
    
    # Components to test
    local components=(
        "neuro-kernel"
        "neuro-services"
        "neuro-compat"
        "neuro-ai"
        "neuro-tools"
    )
    
    # Test each component
    local failed_components=()
    
    for component in "${components[@]}"; do
        if ! run_component_tests "$component"; then
            failed_components+=("$component")
            if [[ "$FAIL_FAST" == "true" ]]; then
                echo -e "${RED}[FAIL-FAST]${NC} Stopping due to test failure in ${component}"
                break
            fi
        fi
        echo
    done
    
    # Run cross-component tests
    if [[ ${#failed_components[@]} -eq 0 ]] || [[ "$FAIL_FAST" != "true" ]]; then
        run_integration_tests || true
        run_property_tests || true
    fi
    
    # Print summary
    print_summary
}

# Run main function
main "$@"
