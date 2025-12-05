#!/bin/env bash

# MyThemes Size Checker
# Shows file sizes of theme archives and index.json

set -e

# Determine project root directory
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ "$(basename "$PWD")" == "scripts" ]]; then
    PROJECT_ROOT=".."
else
    PROJECT_ROOT="."
fi

OUTPUT_DIR="$PROJECT_ROOT/dist"

# Source utility functions
source "$SCRIPT_DIR/.utils.sh"

# Show help
show-help() {
    cat << EOF
MyThemes Size Checker

DESC:
    Shows file sizes of theme archives and index.json

USAGE:
    $0 [OPTIONS]

FLAGS:
    -h, --help              Show this help message
    -o, --output-dir DIR    Check sizes in specified directory (default: $OUTPUT_DIR)
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show-help
            exit 0
            ;;
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        *)
            log.error "Unknown option: $1"
            show-help
            exit 1
            ;;
    esac
done

# Check if output directory exists
if [ ! -d "$OUTPUT_DIR" ]; then
    log.error "Output directory not found: $OUTPUT_DIR"
    log.info "Run 'scripts/package.sh' first to generate theme archives"
    exit 1
fi

# Show sizes
show-sizes "$OUTPUT_DIR"
