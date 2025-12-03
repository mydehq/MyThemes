#!/bin/env bash

# MyThemes Package Builder
# Builds theme packages & generates index.json

set -e

# Determine project root directory
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

if [[ "$(basename "$PWD")" == "scripts" ]]; then
    PROJECT_ROOT=".."
else
    PROJECT_ROOT="."
fi


#--------------- Config ----------------

INPUT_DIR="$PROJECT_ROOT/themes"
OUTPUT_DIR="$PROJECT_ROOT/dist"
CONFIG_FILE="$PROJECT_ROOT/config.yml"
TEMP_DIR="$PROJECT_ROOT/.tmp"
README_TEMPLATE="$PROJECT_ROOT/src/repo-readme-template.md"

#------------ functions ------------------

# Source utility functions
source "$SCRIPT_DIR/.utils.sh"


show-help() {
    cat << EOF
MyCTL Theme Builder & Bundler

DESC:
    Builds theme packages, generates SHA256 checksums,
    creates an index.json with metadata, builds README.md.

USAGE:
    $0 [OPTIONS]

FLAGS:
    -h, --help                Show this help message
    -i, --input-dir DIR       Override input directory from config
    -o, --output-dir DIR      Override output directory from config
    -c, --config FILE         Set config file (default: $CONFIG_FILE)
    -rt,--repo-template FILE  Set README template file (default: $README_TEMPLATE)
EOF
}


#-------------- entry point ------------------

echo

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    log.error "This script should not be sourced."
    exit 1
fi


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
        -i|--input-dir)
            INPUT_DIR="$2"
            shift 2
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -rt|--readme-template)
            README_TEMPLATE="$2"
            shift 2
            ;;
        *)
            log.error "Unknown option: $1"
            show-help
            exit 1
            ;;
    esac
done

has-cmd yq jq tar awk || exit 1


#------ Start Build --------

# Create output dir and temp dir
mkdir -p "$OUTPUT_DIR" "$TEMP_DIR"

# Set up cleanup trap
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Initialize themes array, archives list, theme_count
echo '[]' >"$TEMP_DIR/themes.json"
archives=()
theme_count=0

log.info "Packaging Themes: "
for theme_dir in "$INPUT_DIR"/*; do

    validate-theme-dir "$theme_dir" || exit 1

    theme_yml="$theme_dir/theme.yml"

    # Get theme name, replace spaces with `-`
    theme_name="$(basename "$theme_dir")" && theme_name="${theme_name// /-}"

    theme_version=$(get-theme-ver "$theme_yml") || exit 1
    archive_name="$(get-conf 'build.archive_name' "$theme_dir").tar.gz" || exit 1
    archive_path="$OUTPUT_DIR/$archive_name"


    # generrate theme archive
    tar -czf "$archive_path" -C "$theme_dir" .

    ! [ -f "$archive_path" ] && {
        log.error "Failed to create archive for theme '$theme_name'"
        exit 1
    }

    # generate sha256 hash
    archive_hash=$(sha256sum "$archive_path" | awk '{print $1}')

    printf "   "; log.success "Packaged: $archive_name"

    theme_json=$(jq -n --arg name "$theme_name" --arg version "$theme_version" --arg file "$archive_name" --arg hash "$archive_hash" \
        '{
            name: $name,
            version: $version,
            file: $file,
            hash: $hash
        }')

    # Add to themes array
    jq --argjson theme "$theme_json" '. += [$theme]' \
      "$TEMP_DIR/themes.json" >"$TEMP_DIR/themes_new.json" && mv "$TEMP_DIR/themes_new.json" "$TEMP_DIR/themes.json"

    # Track archive name
    archives+=("$archive_name")
    theme_count=$((theme_count + 1))
done

log.success "Packaged $theme_count theme(s)."
echo

#--------- packaging ------------

if [ "$theme_count" -eq 0 ]; then
    log.error "No valid Themes found to package"
    exit 1
fi

release_time=$(date +%s) || {
    log.error "Failed to get release time"
    exit 1
}


log.info "Building index.json"

schema_version=$(get-conf -r "index.schema_version" "") || {
    log.error "Failed to get schema version"
    exit 1
}

repo_name=$(get-conf -r "index.repo_name" "") || {
    log.error "Failed to get repo name"
    exit 1
}

download_url=$(get-conf -r "index.download_url" "") || {
    log.error "Failed to get download URL"
    exit 1
}

printf "   "; log.success "schema_version: $schema_version"
printf "   "; log.success "repo_name: $repo_name"
printf "   "; log.success "release_time: $release_time"
printf "   "; log.success "download_url: $download_url"
printf "   "; log.success "themes: $theme_count"


# Build final index.json
jq -n \
    --arg schema_version "$schema_version" \
    --arg repo_name "$repo_name" \
    --arg release_time "$release_time" \
    --arg download_url "$download_url" \
    --arg hash_algo "sha256" \
    --argjson themes "$(< "$TEMP_DIR/themes.json")" \
    '{
        "schema_version": $schema_version,
        "repo_name": $repo_name,
        "release_time": ($release_time | tonumber),
        "download_url": $download_url,
        "hash_algo": $hash_algo,
        "themes": $themes
    }' > "$OUTPUT_DIR/index.json"

log.success "Built index.json"
echo

#--------- Build README ------------

log.info "Building README.md"

if [ ! -f "$README_TEMPLATE" ]; then
    log.error "README template not found: $README_TEMPLATE"
    exit 1
fi

awk '
BEGIN { in_comment = 0; found_first_comment = 0 }
/^<!--/ && !found_first_comment { in_comment = 1; found_first_comment = 1; next }
/^-->$/ && in_comment { in_comment = 0; next }
!in_comment { print }
' "$README_TEMPLATE" > "$OUTPUT_DIR/README.md" || {
    log.error "Failed to process README template"
    exit 1
}

printf "   "; log.success "copied Template."
printf "   "; log.success "Processed Template."

log.success "Built README.md"
echo

# Cleanup
rm -rf "$TEMP_DIR"


# Show file sizes
echo -e "----------- Summary ---------------\n"
calc-theme-sizes "$OUTPUT_DIR"

# Output for GitHub Actions (if running in CI)
if [ -n "$GITHUB_OUTPUT" ]; then
  printf -v archive_list '%s,' "${archives[@]}"
  archive_list="${archive_list%,}"
  echo "theme-archives=$archive_list" >>"$GITHUB_OUTPUT"
  echo "release-number=$release_time" >>"$GITHUB_OUTPUT"
fi
