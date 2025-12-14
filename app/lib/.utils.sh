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
    local key value json_flag="" default_value=""
    local conf_file="$CONFIG_FILE" root_key=".packaging"
    local silent_mode=false
    local yq_status

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -j|--json)
                json_flag="-o=json"
                shift
                ;;
            -s|--silent)
                silent_mode=true
                shift
                ;;
            -d|--default)
                if [[ -z "$2" ]]; then
                    log.fatal "Option $1 requires an argument"
                    return 1
                fi
                default_value="$2"
                shift 2
                ;;
            -c|--config)
                if [[ -z "$2" ]]; then
                    log.fatal "Option $1 requires an argument"
                    return 1
                fi
                conf_file="$2"
                shift 2
                ;;
            *)
                # Positional argument (the key)
                if [[ -z "$key" ]]; then
                    key="$1"
                else
                    log.fatal "Only 1 key is allowed, received: '$key' and '$1'"
                    return 1
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$key" ]]; then
        log.error "Configuration key must be provided."
        return 1
    elif [[ ! -f "$conf_file" ]]; then
        log.fatal "Config file '$conf_file' not found or is not readable."
    elif [[ "$conf_file" != "$CONFIG_FILE" ]]; then
        root_key="."
    fi

    value="$(yq $json_flag eval "${root_key}.${key}" "$conf_file" 2>/dev/null)"
    yq_status=$?

    if [[ "$yq_status" -ne 0 ]] || [[ "$value" == "null" ]] || [[ -z "$value" ]]; then

        if [[ -n "$default_value" ]]; then
            echo "$default_value"
            return 0
        fi

        if [ "$silent_mode" = false ]; then
            if [[ "$yq_status" -ne 0 ]]; then
                log.error "yq failed (non-zero exit status $yq_status) for key '$key' in '$conf_file'"
            else
                log.error "Config key '$key' not found or is empty/null in '$conf_file'"
            fi
        fi
        return 1
    fi

    echo "$value"
    return 0
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

    stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || exit 1
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
        local index_size=$(get-file-size "$output_dir/index.json") || exit 1
        total_bytes=$((total_bytes + index_size))
    fi

    # Calculate all theme files (archives and versions.json)
    while IFS= read -r -d '' file; do
        local size=$(get-file-size "$file")
        total_bytes=$((total_bytes + size))
    done < <(find "$output_dir" -type f \( -name "*.tar.gz" -o -name "versions.json" \) -print0)

    # Show total repository size
    echo -e "Repo Size = $(format-size "$total_bytes")"
}

# Usage: gen-hash <file> <md5|sha1|sha256|sha512>
# Prints the hex digest.
# Returns 0 on success; non-zero on error.
gen-hash() {
    local file="$1"
    local algo="${2:-sha256}"

    if [ -z "$file" ]; then
        log.error "File not specified"
        return 1
    elif [ -z "$algo" ]; then
        log.error "Algorithm not specified"
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
    local repo_mirrors=""
    local max_versions=""
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
            -ml|--mirror-list)
                repo_mirrors="$2"
                shift 2
                ;;
            -mv|--max-versions)
                max_versions="$2"
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
                echo "Usage: create-repo-index -rn <repo_name> -rt <release_time> -ml <mirror_list> -mv <max_versions> [-th <theme_object>] [-o <output_file>]"
                echo "Flags:"
                echo "  -rn|--repo-name <repo_name>        Repository name (e.g., 'official')"
                echo "  -rt|--release-time <timestamp>     Repository release time (UNIX timestamp)"
                echo "  -ml|--mirror-list <json_array>     Source URLs as JSON array"
                echo "  -mv|--max-versions <number>        Maximum versions to keep"
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
    if [ -z "$repo_name" ] || [ -z "$repo_release_time" ] || [ -z "$repo_mirrors" ] || [ -z "$max_versions" ]; then
        log.error "Missing required arguments"
        log.error "Use -h or --help for usage information"
        return 1
    fi

    # --- 1. Validation Check ---
    # Check if all URLs in the provided JSON array contain ${{theme}} and ${{file}}.
    if ! echo "$repo_mirrors" | jq -e 'all( .[] ; (contains("${{theme}}") and contains("${{file}}")) )' > /dev/null; then
        log.fatal "All source URLs must contain \${{theme}} and \${{file}}."
    fi

    # --- 2. Create index.json ---
    # Create the index.json file using jq to construct the object.
    # Use --argjson for numeric and array inputs to maintain data type integrity.
    jq -n \
        --arg repo_name "$repo_name" \
        --argjson release_time "$repo_release_time" \
        --argjson max_versions "$max_versions" \
        --argjson repo_mirrors "$repo_mirrors" \
        --argjson theme_object "$theme_object" \
        '{
            schema_ver: 2,
            repo_name: $repo_name,
            release: $release_time,
            max_versions: $max_versions,
            mirrors: $repo_mirrors,
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


# Compare two files and return 0 if identical, 1 if they differ
# Auto-detects whether to use diff (text) or cmp (binary) based on file extension
# Usage: cmp-files <file1> <file2>
cmp-files() {
    local file1="$1"
    local file2="$2"
    
    # Get file extension
    local ext="${file1##*.}"
    
    # Text file extensions
    case "$ext" in
        html|htm|css|js|jsx|ts|tsx|json|xml|txt|md|mdx|yml|yaml|toml|py|c|cc|cpp|hpp|h|sh|bash|zsh|rs|go|zig|gitignore)
            # Use diff for text files
            diff -q "$file1" "$file2" &>/dev/null
            return $?
            ;;
        *)
            # Use cmp for binary files or unknown extensions
            cmp -s "$file1" "$file2"
            return $?
            ;;
    esac
}


# Usage: init-meta
init-meta() {
    local output_dir="${OUTPUT_DIR}" \
          gen_readme=true gen_index=true \
          index_template="$SRC_DIR/meta/index.html" index_html_tpl \
          index_js="$SRC_DIR/meta/index.js"

    # Check config for what to generate
    local val
    val=$(yq eval ".packaging.meta.readme" "$CONFIG_FILE" 2>/dev/null)
    gen_readme="${val:-true}"  # Default to true if null
    
    val=$(yq eval ".packaging.meta.index-html" "$CONFIG_FILE" 2>/dev/null)
    gen_index="${val:-true}"  # Default to true if null

    # Usage: _copy <source> <dest> [required]
    _copy() {
        local src="$1"
        local dest="$2"
        local required="${3:-true}"
        local desc="$(basename "$dest")"
        
        if [ ! -f "$src" ]; then
            if [ "$required" == "true" ]; then
                log.error "$desc not found"
                return 1
            else
                log.warn "$desc not found: $src"
                return 0
            fi
        elif [ ! -f "$dest" ] || ! cmp-files "$src" "$dest"; then
            cp "$src" "$dest" || {
                log.error "Failed to copy $desc"
                return 1
            }
            log.success "$desc"
        else
            log.info "Skipped: $desc (same)"
        fi
        return 0
    }

    # Generate index.html if enabled
    if [ "$gen_index" == "true" ]; then

        # Generate index.html
        if [ -f "$index_template" ]; then
            index_html_tpl=$(<"$index_template")
        else
            index_html_tpl="$INDEX_CONTENT"
        fi

        echo "$index_html_tpl" > "$output_dir/index.html"
        log.success "index.html"

        # Copy CSS, JS, and favicon
        _copy  "$index_js"                "$output_dir/index.js"     || return 1
        _copy  "$SRC_DIR/meta/index.css"  "$output_dir/index.css"    || return 1
        _copy  "$SRC_DIR/icon.ico"        "$output_dir/favicon.ico"  || return 1
    else
        # Clean up related files if generation is disabled
        [ -f "$output_dir/index.html"  ] && rm "$output_dir/index.html"  && log.info "Deleted index.html"
        [ -f "$output_dir/index.js"    ] && rm "$output_dir/index.js"    && log.info "Deleted index.js"
        [ -f "$output_dir/index.css"   ] && rm "$output_dir/index.css"   && log.info "Deleted index.css"
        [ -f "$output_dir/favicon.ico" ] && rm "$output_dir/favicon.ico" && log.info "Deleted favicon.ico"
    fi

    # Generate README.md if enabled
    if [ "$gen_readme" == "true" ]; then
        echo "$README_CONTENT" > "$output_dir/README.md"
        log.success "README.md"
    else
        # Clean up README.md if generation is disabled
        [ -f "$output_dir/README.md" ] && rm "$output_dir/README.md" && log.info "Deleted README.md"
    fi
}
