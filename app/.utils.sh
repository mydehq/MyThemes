#!/bin/env bash

# MyThemes Utility Functions
# Shared utilities for theme management scripts

#------------ Utility Functions ------------------

has-cmd() {
  local cmd_str cmd_bin
  local missing=0

  [ "$#" -eq 0 ] && {
    log.error "No arguments provided."
    return 1
  }

  for cmd_str in "$@"; do
    # Extract binary name (first token before space)
    cmd_bin="${cmd_str%% *}"

    if ! command -v "$cmd_bin" &>/dev/null; then
      log.error "$cmd_str is required but not installed"
      missing=1
    fi
  done

  # Return 0 if all found, 1 if any were missing
  return "$missing"
}

get-conf() {
    local key json_flag=""
    local conf_file="$CONFIG_FILE" root_key=".packaging"

    # Parse flags
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -j|--json)
                json_flag="-o=json"
                shift
                ;;
            *)
                break
                ;;
        esac
    done

    # Get remaining arguments
    key="$1"

    if [ -n "$2" ]; then
        conf_file="$2"
        root_key=""
    fi

    # Get config value
    value="$(yq $json_flag eval "${root_key}.${key}" "$conf_file" 2>/dev/null)" || {
        log.error "Failed to get config value for key '$key' from '$conf_file'"
        return 1
    }

    if [ "$value" == "null" ] || [ -z "$value" ]; then
        log.error "Config key '$key' not found or empty in '$conf_file'"
        return 1
    fi

    echo "$value"
}

replace-vars() {
    local raw_value="$1" final_value
    local theme_dir="$2"
    local theme_yml="$theme_dir/theme.yml"
    local theme_name theme_ver

    theme_name="$(basename "$theme_dir")" || exit 1
    theme_ver="$(get-theme-ver "$theme_yml")" || exit 1

    # Replace template variables
    final_value="${raw_value//\$\{\{name\}\}/$theme_name}"
    final_value="${final_value//\$\{\{version\}\}/$theme_ver}"

    echo "$final_value"
}

get-theme-ver() {
    local theme_yml="$1"
    local version

    version=$(yq '.version' "$theme_yml" 2>/dev/null | tr -d '\0') || {
        log.error "Failed to get theme version from $theme_yml"
        return 1
    }

    if [ "$version" == "null" ] || [ -z "$version" ]; then
        log.error "version is not defined in theme.yml: $theme_yml"
        return 1
    fi

    echo "$version"
}

# Format bytes to human readable size (KB, MB, GB)
format-size() {
    local bytes="$1"
    local unit="B"
    local size="$bytes"

    if [ "$bytes" -ge 1073741824 ]; then
        size=$((bytes / 1073741824))
        unit="GB"
    elif [ "$bytes" -ge 1048576 ]; then
        size=$((bytes / 1048576))
        unit="MB"
    elif [ "$bytes" -ge 1024 ]; then
        size=$((bytes / 1024))
        unit="KB"
    fi

    echo "${size}${unit}"
}

# Get file size in bytes
get-file-size() {
    local file="$1"

    if [ ! -f "$file" ]; then
        log.error "File not found: $file"
        return 1
    fi

    stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null
}

# Calculate total size of theme files and index.json
show-repo-size() {
    local output_dir="$1"
    local total_bytes=0

    [ -z "$output_dir" ] && {
        log.error "Output directory not specified"
        return 1
    }

    [ ! -d "$output_dir" ] && {
        log.error "Output directory does not exist: $output_dir"
        return 1
    }

    # Calculate index.json size
    if [ -f "$output_dir/index.json" ]; then
        local index_size=$(get-file-size "$output_dir/index.json")
        total_bytes=$((total_bytes + index_size))
    fi

    # Calculate all theme files (archives and .versions.json)
    while IFS= read -r -d '' file; do
        local size=$(get-file-size "$file")
        total_bytes=$((total_bytes + size))
    done < <(find "$output_dir" -type f \( -name "*.tar.gz" -o -name ".versions.json" \) -print0)

    # Show total repository size
    echo -e "Repo Size = $(format-size "$total_bytes")"
}

# Usage: gen-hash <file> <md5|sha1|sha256|sha512>
# Prints the hex digest.
# Returns 0 on success; non-zero on error.
gen-hash() {
    local file="$1"
    local algo="${2:-sha256}"

    if [ -z "$file" ] || [ -z "$algo" ]; then
        log.error "Usage: gen-hash <file> <md5|sha1|sha256|sha512>"
        return 1
    fi

    if [ ! -f "$file" ]; then
        log.error "File not found: $file"
        return 1
    fi

    # Normalize algorithm
    algo="$(echo "$algo" | tr '[:upper:]' '[:lower:]')"

    case "$algo" in
        md5)
            if has-cmd md5sum; then
                md5sum "$file" | awk '{print $1}'
                return $?
            elif has-cmd "md5 -q"; then
                md5 -q "$file"
                return $?
            else
                log.error "md5 hashing tool not found (need md5sum or md5)"
                return 1
            fi
            ;;
        sha1)
            if has-cmd sha1sum; then
                sha1sum "$file" | awk '{print $1}'
                return $?
            elif has-cmd "shasum -a 1"; then
                shasum -a 1 "$file" | awk '{print $1}'
                return $?
            else
                log.error "sha1 hashing tool not found (need sha1sum or shasum)"
                return 1
            fi
            ;;
        sha256)
            if has-cmd sha256sum; then
                sha256sum "$file" | awk '{print $1}'
                return $?
            elif has-cmd "shasum -a 256"; then
                shasum -a 256 "$file" | awk '{print $1}'
                return $?
            else
                log.error "sha256 hashing tool not found (need sha256sum or shasum)"
                return 1
            fi
            ;;
        sha512)
            if has-cmd sha512sum; then
                sha512sum "$file" | awk '{print $1}'
                return $?
            elif has-cmd "shasum -a 512"; then
                shasum -a 512 "$file" | awk '{print $1}'
                return $?
            else
                log.error "sha512 hashing tool not found (need sha512sum or shasum)"
                return 1
            fi
            ;;
        *)
            log.error "Unsupported hash algorithm: $algo"
            return 1
            ;;
    esac
}


# Usage:
#   compare-hash --f1 <path>|--h1 <hex> --f2 <path>|--h2 <hex> [--algo|-a <algo>]
# Exactly one of --f1/--h1 and one of --f2/--h2 must be provided.
# Returns 0 if hashes match, 1 otherwise.
compare-hash () {
    local file1=""
    local file2=""
    local algo="sha256"
    local hash_input=""
    local hash_input2=""

    # require exactly one of --f1/--h1 and one of --f2/--h2
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --f1) file1="$2"; shift 2;;
            --f2) file2="$2"; shift 2;;
            --h1) hash_input="$2"; shift 2;;
            --h2) hash_input2="$2"; shift 2;;
            --algo|-a) algo="$2"; shift 2;;
            --help)
                echo "Usage:"
                echo "  compare-hash --f1 <path>|--h1 <hex> --f2 <path>|--h2 <hex> [--algo|-a <algo>]"
                return 0;;
            *)
                log.error "Unknown argument: $1"
                return 1;;
        esac
    done

    # Exclusivity checks per side
    if { [ -n "$file1" ] && [ -n "$hash_input" ]; } || { [ -z "$file1" ] && [ -z "$hash_input" ]; }; then
        log.error "Exactly one of --f1 or --h1 must be provided"
        return 1
    fi
    if { [ -n "$file2" ] && [ -n "$hash_input2" ]; } || { [ -z "$file2" ] && [ -z "$hash_input2" ]; }; then
        log.error "Exactly one of --f2 or --h2 must be provided"
        return 1
    fi

    # Normalize algo
    algo="$(echo "$algo" | tr '[:upper:]' '[:lower:]')"

    local h1 h2

    # Compute or accept side 1 hash
    if [ -n "$hash_input" ]; then
        h1="$hash_input"
    else
        if [ -z "$file1" ] || [ ! -f "$file1" ]; then
            log.error "File not found: $file1"
            return 1
        fi
        h1="$(gen-hash "$file1" "$algo")" || return 1
    fi

    # Compute or accept side 2 hash
    if [ -n "$hash_input2" ]; then
        h2="$hash_input2"
    else
        if [ -z "$file2" ] || [ ! -f "$file2" ]; then
            log.error "File not found: $file2"
            return 1
        fi
        h2="$(gen-hash "$file2" "$algo")" || return 1
    fi

    [ "$h1" = "$h2" ]
}

# Usage: validate-json <json_path>
validate-json() {
    local json_path="${1:-null}"

    if [ "$json_path" == "null" ]; then
        log.error "Json path is required"
        return 1
    fi

    # Basic existence and size checks
    if ! [ -f "$json_path" ]; then
        log.error "index.json not found at '$json_path'"
        return 1
    fi

    if ! [ -s "$json_path" ]; then
        log.error "index.json is empty"
        return 1
    fi

    # Validate JSON parse
    if ! jq -e . "$json_path" >/dev/null 2>&1; then
        log.error "index.json contains invalid JSON"
        return 1
    fi
}


# Usage: create-repo-index -rn <repo_name> -rt <release_time> -su <src_urls> [-th <theme_object>] [-o <output_file>]
# Flags:
#   -rn|--repo-name <repo_name>        Repository name (e.g., "official")
#   -rt|--release-time <timestamp>     Repository release time (UNIX timestamp)
#   -su|--src-urls <json_array>        Source URLs as JSON array (must contain ${{theme}} and ${{file}})
#   -th|--theme-obj <json_object>      Theme object as JSON (optional, defaults to {})
#   -o|--output-file <file_path>       Output file path (optional, defaults to $OUTPUT_DIR/index.json)
#
create-repo-index() {
    local repo_name=""
    local repo_release_time=""
    local repo_src_urls=""
    local theme_object=""
    local output_file=""

    # Parse flags
    while [ $# -gt 0 ]; do
        case "$1" in
            -rn|--repo-name)
                repo_name="$2"
                shift 2
                ;;
            -rt|--release-time)
                repo_release_time="$2"
                shift 2
                ;;
            -su|--src-urls)
                repo_src_urls="$2"
                shift 2
                ;;
            -th|--theme-obj)
                theme_object="$2"
                shift 2
                ;;
            -o|--output-file)
                output_file="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: create-repo-index -rn <repo_name> -rt <release_time> -su <src_urls> [-th <theme_object>] [-o <output_file>]"
                echo "Flags:"
                echo "  -rn|--repo-name <repo_name>        Repository name (e.g., 'official')"
                echo "  -rt|--release-time <timestamp>     Repository release time (UNIX timestamp)"
                echo "  -su|--src-urls <json_array>        Source URLs as JSON array"
                echo "  -th|--theme-obj <json_object>      Theme object as JSON (optional, defaults to {})"
                echo "  -o|--output-file <file_path>       Output file path (optional, defaults to \$OUTPUT_DIR/index.json)"
                return 0
                ;;
            *)
                log.error "Unknown flag: $1"
                log.error "Use -h or --help for usage information"
                return 1
                ;;
        esac
    done

    # Set default values if not provided
    if [ -z "$output_file" ]; then
        output_file="${OUTPUT_DIR}/index.json"
    fi
    if [ -z "$theme_object" ]; then
        theme_object="{}"
    fi

    # Validate required arguments
    if [ -z "$repo_name" ] || [ -z "$repo_release_time" ] || [ -z "$repo_src_urls" ]; then
        log.error "Missing required arguments"
        log.error "Use -h or --help for usage information"
        return 1
    fi

    # --- 1. Validation Check ---
    # Check if all URLs in the provided JSON array contain ${{theme}} and ${{file}}.
    if ! echo "$repo_src_urls" | jq -e 'all( .[] ; (contains("${{theme}}") and contains("${{file}}")) )' > /dev/null; then
        log.fatal "All source URLs must contain \${{theme}} and \${{file}}."
    fi

    # --- 2. Create index.json ---
    # Create the index.json file using jq to construct the object.
    # Use --argjson for numeric and array inputs to maintain data type integrity.
    jq -n \
        --arg repo_name "$repo_name" \
        --argjson release_time "$repo_release_time" \
        --argjson repo_src_urls "$repo_src_urls" \
        --argjson theme_object "$theme_object" \
        '{
            schema_ver: 2,
            repo_name: $repo_name,
            release: $release_time,
            src_urls: $repo_src_urls,
            themes: $theme_object
        }' \
    > "$output_file"

    # Check the exit status of the final jq command
    if [ $? -eq 0 ]; then
        return 0 # Success
    else
        log.fatal "Failed to create $output_file due to a jq error."
    fi
}
