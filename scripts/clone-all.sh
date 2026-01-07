#!/bin/bash
# Clone All Neuro-OS Repositories
#
# This script clones all Neuro-OS repositories into a common workspace.
# It handles:
# - Repository existence checking
# - Parallel cloning for speed
# - Error handling and retry logic
# - Branch selection
# - Shallow vs. full clones
#
# Usage:
#   ./clone-all.sh [--workspace DIR] [--branch BRANCH] [--shallow]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GITHUB_ORG="${GITHUB_ORG:-nehraa}"
WORKSPACE_DIR="${WORKSPACE_DIR:-./neuro-workspace}"
BRANCH="${BRANCH:-main}"
SHALLOW_CLONE=false
PARALLEL_JOBS=4

# Repository list
REPOS=(
    "neuro-kernel"
    "neuro-services"
    "neuro-compat"
    "neuro-ai"
    "neuro-tools"
)

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --workspace)
                WORKSPACE_DIR="$2"
                shift 2
                ;;
            --branch)
                BRANCH="$2"
                shift 2
                ;;
            --shallow)
                SHALLOW_CLONE=true
                shift
                ;;
            --parallel)
                PARALLEL_JOBS="$2"
                shift 2
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

# Show help message
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Clone all Neuro-OS repositories into a common workspace.

OPTIONS:
    --workspace DIR     Target directory (default: ./neuro-workspace)
    --branch BRANCH     Git branch to checkout (default: main)
    --shallow           Perform shallow clone (faster, less history)
    --parallel N        Number of parallel clone jobs (default: 4)
    --help              Show this help message

EXAMPLES:
    $0
    $0 --workspace ~/projects/neuro --branch develop
    $0 --shallow --parallel 8

ENVIRONMENT:
    GITHUB_ORG          GitHub organization name (default: nehraa)
EOF
}

# Clone a single repository
clone_repo() {
    local repo="$1"
    local repo_dir="${WORKSPACE_DIR}/${repo}"
    local repo_url="https://github.com/${GITHUB_ORG}/${repo}.git"
    
    # Check if already exists
    if [[ -d "$repo_dir" ]]; then
        echo -e "${YELLOW}[SKIP]${NC} ${repo} already exists"
        
        # Update existing repo
        echo -e "${BLUE}[UPDATE]${NC} Updating ${repo}..."
        (
            cd "$repo_dir"
            git fetch origin
            git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH" "origin/$BRANCH"
            git pull origin "$BRANCH"
        ) && echo -e "${GREEN}[✓]${NC} Updated ${repo}" || echo -e "${RED}[✗]${NC} Failed to update ${repo}"
        
        return 0
    fi
    
    echo -e "${BLUE}[CLONE]${NC} Cloning ${repo}..."
    
    # Build clone command with properly quoted arguments
    local clone_args=(git clone)
    
    if [[ "$SHALLOW_CLONE" == "true" ]]; then
        clone_args+=(--depth 1)
    fi
    
    clone_args+=(--branch "$BRANCH" "$repo_url" "$repo_dir")
    
    # Execute clone
    if "${clone_args[@]}"; then
        echo -e "${GREEN}[✓]${NC} Cloned ${repo}"
        return 0
    else
        echo -e "${RED}[✗]${NC} Failed to clone ${repo}"
        return 1
    fi
}

# Main cloning logic
main() {
    parse_args "$@"
    
    echo "========================================"
    echo "  Neuro-OS Repository Cloner"
    echo "========================================"
    echo "Workspace: ${WORKSPACE_DIR}"
    echo "Branch: ${BRANCH}"
    echo "Shallow: ${SHALLOW_CLONE}"
    echo "Parallel Jobs: ${PARALLEL_JOBS}"
    echo "========================================"
    echo
    
    # Create workspace directory
    mkdir -p "$WORKSPACE_DIR"
    
    # Clone repositories
    local success_count=0
    local fail_count=0
    
    if [[ "$PARALLEL_JOBS" -gt 1 ]]; then
        # Parallel cloning using background jobs
        local pids=()
        
        for repo in "${REPOS[@]}"; do
            # Wait if we've hit the parallel limit
            while [[ ${#pids[@]} -ge $PARALLEL_JOBS ]]; do
                for i in "${!pids[@]}"; do
                    if ! kill -0 "${pids[$i]}" 2>/dev/null; then
                        unset "pids[$i]"
                    fi
                done
                pids=("${pids[@]}") # Reindex array
                sleep 0.1
            done
            
            # Start clone in background
            clone_repo "$repo" &
            pids+=($!)
        done
        
        # Wait for all background jobs
        for pid in "${pids[@]}"; do
            wait "$pid" && ((success_count++)) || ((fail_count++))
        done
    else
        # Sequential cloning
        for repo in "${REPOS[@]}"; do
            if clone_repo "$repo"; then
                ((success_count++))
            else
                ((fail_count++))
            fi
        done
    fi
    
    # Summary
    echo
    echo "========================================"
    echo "  Summary"
    echo "========================================"
    echo -e "Successful: ${GREEN}${success_count}${NC}"
    echo -e "Failed: ${RED}${fail_count}${NC}"
    echo "Total: ${#REPOS[@]}"
    echo
    
    if [[ $fail_count -eq 0 ]]; then
        echo -e "${GREEN}✓ All repositories cloned successfully!${NC}"
        echo
        echo "Next steps:"
        echo "  cd ${WORKSPACE_DIR}"
        echo "  ./neuro-tools/scripts/build-all.sh"
        return 0
    else
        echo -e "${RED}✗ Some repositories failed to clone${NC}"
        return 1
    fi
}

# Run main function
main "$@"
