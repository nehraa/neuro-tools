#!/usr/bin/env bash
# Neuro-OS Performance Profiling Script
#
# This script provides integrated profiling capabilities for Neuro-OS using
# Linux perf tools. It captures performance data, generates flamegraphs,
# and provides detailed analysis of CPU and memory usage.
#
# Features:
# - CPU profiling with sampling
# - Call graph generation
# - Flamegraph visualization
# - Cache miss analysis
# - Branch prediction analysis
# - Memory access profiling
#
# Usage:
#   ./profile.sh <command> [options]
#
# Commands:
#   cpu <target>         - Profile CPU usage of a target binary
#   memory <target>      - Profile memory access patterns
#   cache <target>       - Analyze cache performance
#   flamegraph <target>  - Generate interactive flamegraph
#   report <perf.data>   - Generate detailed report from perf data

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PERF_DATA="perf.data"
FLAMEGRAPH_DIR="${FLAMEGRAPH_DIR:-/opt/flamegraph}"
OUTPUT_DIR="${OUTPUT_DIR:-./profile-output}"

# Ensure perf is available
check_dependencies() {
    if ! command -v perf &> /dev/null; then
        echo -e "${RED}Error: perf not found. Install with: apt-get install linux-tools-generic${NC}"
        exit 1
    fi
    
    # Check if FlameGraph tools are available
    if [[ ! -d "$FLAMEGRAPH_DIR" ]] && [[ "$1" == "flamegraph" ]]; then
        echo -e "${YELLOW}Warning: FlameGraph not found at $FLAMEGRAPH_DIR${NC}"
        echo "Clone it with: git clone https://github.com/brendangregg/FlameGraph $FLAMEGRAPH_DIR"
    fi
}

# Profile CPU usage with sampling
profile_cpu() {
    local target="$1"
    local frequency="${2:-999}"  # Sample frequency in Hz
    local duration="${3:-30}"     # Duration in seconds
    
    echo -e "${GREEN}Profiling CPU usage of: $target${NC}"
    echo "Frequency: $frequency Hz, Duration: $duration seconds"
    
    # Record CPU profile
    sudo perf record \
        -F "$frequency" \
        -g \
        --call-graph dwarf \
        -o "$PERF_DATA" \
        -- "$target" &
    
    local perf_pid=$!
    
    # Wait for duration or until process exits
    sleep "$duration" || true
    
    # Stop profiling
    sudo kill -SIGINT "$perf_pid" 2>/dev/null || true
    wait "$perf_pid" 2>/dev/null || true
    
    echo -e "${GREEN}Profile data saved to: $PERF_DATA${NC}"
    
    # Generate quick report
    generate_report "$PERF_DATA"
}

# Profile memory access patterns
profile_memory() {
    local target="$1"
    
    echo -e "${GREEN}Profiling memory access of: $target${NC}"
    
    # Record memory events
    sudo perf record \
        -e mem:0:r \
        -e mem:0:w \
        -g \
        -o "$PERF_DATA" \
        -- "$target"
    
    echo -e "${GREEN}Memory profile saved to: $PERF_DATA${NC}"
    
    # Analyze memory access
    sudo perf report -i "$PERF_DATA" --stdio | head -50
}

# Analyze cache performance
profile_cache() {
    local target="$1"
    
    echo -e "${GREEN}Analyzing cache performance of: $target${NC}"
    
    # Record cache events
    sudo perf stat \
        -e cache-references \
        -e cache-misses \
        -e L1-dcache-loads \
        -e L1-dcache-load-misses \
        -e LLC-loads \
        -e LLC-load-misses \
        -- "$target"
    
    echo ""
    echo "Cache Analysis Complete"
}

# Generate flamegraph visualization
generate_flamegraph() {
    local target="$1"
    
    check_dependencies "flamegraph"
    
    echo -e "${GREEN}Generating flamegraph for: $target${NC}"
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Record profile with call graph
    sudo perf record \
        -F 999 \
        -g \
        --call-graph dwarf \
        -o "$PERF_DATA" \
        -- "$target"
    
    # Convert perf data to flamegraph format
    sudo perf script -i "$PERF_DATA" > "$OUTPUT_DIR/perf.script"
    
    # Generate folded stacks
    "$FLAMEGRAPH_DIR/stackcollapse-perf.pl" "$OUTPUT_DIR/perf.script" > "$OUTPUT_DIR/perf.folded"
    
    # Generate flamegraph SVG
    "$FLAMEGRAPH_DIR/flamegraph.pl" "$OUTPUT_DIR/perf.folded" > "$OUTPUT_DIR/flamegraph.svg"
    
    echo -e "${GREEN}Flamegraph saved to: $OUTPUT_DIR/flamegraph.svg${NC}"
    echo "Open in browser: file://$PWD/$OUTPUT_DIR/flamegraph.svg"
}

# Generate detailed report from perf data
generate_report() {
    local perf_file="${1:-$PERF_DATA}"
    
    echo -e "${GREEN}Generating report from: $perf_file${NC}"
    
    mkdir -p "$OUTPUT_DIR"
    
    # Text report
    echo "=== Top Functions ===" > "$OUTPUT_DIR/report.txt"
    sudo perf report -i "$perf_file" --stdio --no-children | head -50 >> "$OUTPUT_DIR/report.txt"
    
    echo "" >> "$OUTPUT_DIR/report.txt"
    echo "=== Call Graph ===" >> "$OUTPUT_DIR/report.txt"
    sudo perf report -i "$perf_file" --stdio -g --no-children | head -100 >> "$OUTPUT_DIR/report.txt"
    
    # Display summary
    cat "$OUTPUT_DIR/report.txt" | head -30
    
    echo ""
    echo -e "${GREEN}Full report saved to: $OUTPUT_DIR/report.txt${NC}"
}

# Profile CPU hotspots with annotation
profile_annotate() {
    local target="$1"
    
    echo -e "${GREEN}Profiling and annotating: $target${NC}"
    
    # Record profile
    sudo perf record \
        -F 999 \
        -g \
        -o "$PERF_DATA" \
        -- "$target"
    
    # Get top function
    local top_func=$(sudo perf report -i "$PERF_DATA" --stdio --no-children | grep "^\s*[0-9]" | head -1 | awk '{print $NF}')
    
    echo "Top hotspot: $top_func"
    
    # Annotate the top function
    sudo perf annotate -i "$PERF_DATA" "$top_func"
}

# Profile with hardware performance counters
profile_hardware() {
    local target="$1"
    
    echo -e "${GREEN}Hardware performance counters for: $target${NC}"
    
    sudo perf stat \
        -e cycles \
        -e instructions \
        -e cache-references \
        -e cache-misses \
        -e branches \
        -e branch-misses \
        -e bus-cycles \
        -e ref-cycles \
        -e L1-dcache-loads \
        -e L1-dcache-load-misses \
        -e L1-icache-loads \
        -e L1-icache-load-misses \
        -e LLC-loads \
        -e LLC-load-misses \
        -e dTLB-loads \
        -e dTLB-load-misses \
        -e iTLB-loads \
        -e iTLB-load-misses \
        -- "$target"
}

# Live monitoring with top-like interface
profile_top() {
    local interval="${1:-1}"
    
    echo -e "${GREEN}Starting live performance monitor (interval: ${interval}s)${NC}"
    echo "Press Ctrl+C to stop"
    
    sudo perf top -F 999 --call-graph dwarf -d "$interval"
}

# Main command dispatcher
main() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  cpu <target> [freq] [duration]  - Profile CPU usage"
        echo "  memory <target>                 - Profile memory access"
        echo "  cache <target>                  - Analyze cache performance"
        echo "  flamegraph <target>             - Generate flamegraph"
        echo "  report [perf.data]              - Generate report from perf data"
        echo "  annotate <target>               - Profile with source annotation"
        echo "  hardware <target>               - Profile hardware counters"
        echo "  top [interval]                  - Live performance monitor"
        echo ""
        echo "Examples:"
        echo "  $0 cpu ./my_program 999 30"
        echo "  $0 flamegraph ./my_program"
        echo "  $0 cache ./my_program"
        exit 1
    fi
    
    local command="$1"
    shift
    
    check_dependencies "$command"
    
    case "$command" in
        cpu)
            profile_cpu "$@"
            ;;
        memory)
            profile_memory "$@"
            ;;
        cache)
            profile_cache "$@"
            ;;
        flamegraph)
            generate_flamegraph "$@"
            ;;
        report)
            generate_report "$@"
            ;;
        annotate)
            profile_annotate "$@"
            ;;
        hardware)
            profile_hardware "$@"
            ;;
        top)
            profile_top "$@"
            ;;
        *)
            echo -e "${RED}Error: Unknown command: $command${NC}"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
