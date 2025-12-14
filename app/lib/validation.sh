# Usage: validate-theme-dir [-v|--verbose] <theme_dir>
validate-theme-dir() {
   local verbose=false
   local theme_dir=""

   while [[ "$#" -gt 0 ]]; do
       case $1 in
           -v|--verbose) verbose=true; shift ;;
           *) theme_dir="$1"; shift ;;
       esac
   done

   local theme_yml="$theme_dir/theme.yml"
   local has_errors=0

   # Validate theme directory
   if [ ! -e "$theme_dir" ]; then
        log.error "Theme dir '$theme_dir' does not exist"
        return 1
   fi

   if [ ! -d "$theme_dir" ]; then
        log.error "'$theme_dir' is not a directory"
        return 1
   fi

   # -------------- Manifest ----------------
   # Validate theme.yml file
   ! [ -f "$theme_yml" ] && {
      log.error "Theme dir '$theme_dir' does not contain a theme.yml"
      return 1
   }

   # Validate theme.yml file is not empty
   ! [ -s "$theme_yml" ] && {
      log.error "theme.yml is empty in '$theme_dir'."
      return 1
   }
   $verbose && log.success "Has valid Manifest"

   # --------------- Check required fields --------------

   # 1. Check version field
   local theme_version
   theme_version="$(yq '.version' "$theme_yml" 2>/dev/null | tr -d '\0')"

   if [ -z "$theme_version" ] || [ "$theme_version" == "null" ]; then
        log.error "Missing required field: ${YELLOW}'version'${NC}"
        has_errors=1
   elif ! echo "$theme_version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
        log.error "Invalid ${YELLOW}'version'${NC}: ${BLUE}must be semantic X.Y.Z${NC}"
        has_errors=1
   else
        $verbose && log.success "Has valid version"
   fi

   # 2. Check author field
   local theme_author
   theme_author="$(yq '.author' "$theme_yml" 2>/dev/null | tr -d '\0')"

   if [ -z "$theme_author" ] || [ "$theme_author" == "null" ]; then
        log.error "Missing required field: ${YELLOW}'author'${NC}"
        has_errors=1
   else
        $verbose && log.success "Has valid author"
   fi

   # 3. Check url field
   local theme_url
   theme_url="$(yq '.url' "$theme_yml" 2>/dev/null | tr -d '\0')"

   if [ -z "$theme_url" ] || [ "$theme_url" == "null" ]; then
        log.error "Missing required field: ${YELLOW}'url'${NC}"
        has_errors=1
   elif ! echo "$theme_url" | grep -qE '^https?://'; then
        log.error "Invalid ${YELLOW}'url'${NC}: ${BLUE}must start with http:// or https://${NC}"
        has_errors=1
   else
        $verbose && log.success "Has valid URL"
   fi

   # 4. Check config key exists and is an object
   local config_check
   config_check="$(yq '.config' "$theme_yml" 2>/dev/null)"

   if [ -z "$config_check" ] || [ "$config_check" == "null" ]; then
        log.error "Missing required field: ${YELLOW}'config'${NC}"
        has_errors=1
   elif ! yq -e '.config | type' "$theme_yml" 2>/dev/null | grep -q 'map'; then
        log.error "Invalid ${YELLOW}'config'${NC} field: ${BLUE}must be an object/map${NC}"
        has_errors=1
   else
        $verbose && log.success "Has valid config object"
   fi

   # Return based on whether errors were found
   return $has_errors
}


# check if index.json is valid
## AI co-authored
validate-index() {
    local index_json_path="${1:-${OUTPUT_DIR:-./dist}/index.json}"
    local has_errors=0

    if ! validate-json "$index_json_path"; then
        return 1
    fi

    log.success "Has valid JSON"

    # --------------- Check required fields --------------

    # 1. Validate schema_ver == 2
    local schema_ver
    schema_ver="$(jq -r '.schema_ver // "null"' "$index_json_path" 2>/dev/null)"

    if [ "$schema_ver" = "null" ] || [ -z "$schema_ver" ]; then
        log.error "Missing required field: ${YELLOW}'schema_ver'${NC}"
        has_errors=1
    elif [ "$schema_ver" != "2" ]; then
        log.error "Invalid ${YELLOW}'schema_ver'${NC}: ${BLUE}expected 2${NC}"
        has_errors=1
    else
        log.success "Has valid schema_ver"
    fi

    # 2. Validate repo_name non-empty string
    local repo_name
    repo_name="$(jq -r '.repo_name // "null"' "$index_json_path" 2>/dev/null)"

    if [ "$repo_name" = "null" ] || [ -z "$repo_name" ]; then
        log.error "Missing required field: ${YELLOW}'repo_name'${NC}"
        has_errors=1
    else
        log.success "Has valid repo_name"
    fi

    # 3. Validate release timestamp
    local release_val
    release_val="$(jq -r '.release // "null"' "$index_json_path" 2>/dev/null)"

    if [ "$release_val" = "null" ] || [ -z "$release_val" ]; then
        log.error "Missing required field: ${YELLOW}'release'${NC}"
        has_errors=1
    elif ! printf "%s" "$release_val" | awk 'BEGIN{ok=1} { if ($0 !~ /^[0-9]+$/) ok=0 } END{ exit ok==1 ? 0 : 1 }'; then
        log.error "Invalid ${YELLOW}'release'${NC}: ${BLUE}must be integer seconds${NC}"
        has_errors=1
    else
        # Release time checks:
        # - not in the future
        # - not before Jan 1, 2005 -> 1104537600
        local current_time
        current_time="$(date +%s)"

        if [ "$release_val" -lt 1104537600 ]; then
            log.error "Invalid ${YELLOW}'release'${NC}: ${BLUE}too old (must be >= 1104537600 [2005-01-01])${NC}"
            has_errors=1
        elif [ "$release_val" -gt "$current_time" ]; then
            log.error "Invalid ${YELLOW}'release'${NC}: ${BLUE}timestamp is in the future${NC}"
            has_errors=1
        else
            log.success "Has valid release timestamp"
        fi
    fi

    # 4. Validate src_urls array
    if ! jq -e 'has("src_urls") and (.src_urls | type == "array")' "$index_json_path" >/dev/null 2>&1; then
        log.error "Missing or invalid ${YELLOW}'src_urls'${NC}: ${BLUE}must be an array${NC}"
        has_errors=1
    elif ! jq -e '.src_urls | length > 0' "$index_json_path" >/dev/null 2>&1; then
        log.error "Invalid ${YELLOW}'src_urls'${NC}: ${BLUE}array cannot be empty${NC}"
        has_errors=1
    elif ! jq -e 'all(.src_urls[]; (type == "string") and (contains("${{theme}}")) and (contains("${{file}}")))' "$index_json_path" >/dev/null 2>&1; then
        log.error "Invalid ${YELLOW}'src_urls'${NC}: ${BLUE}each URL must contain \${{theme}} and \${{file}} placeholders${NC}"
        has_errors=1
    else
        log.success "Has valid src_urls"
    fi

    # 5. Validate themes object
    if ! jq -e 'has("themes") and (.themes | type == "object")' "$index_json_path" >/dev/null 2>&1; then
        log.error "Missing or invalid ${YELLOW}'themes'${NC}: ${BLUE}must be an object${NC}"
        has_errors=1
    elif ! jq -e '(.themes | to_entries | all(.value | (has("latest") and (.latest | type == "string"))))' "$index_json_path" >/dev/null 2>&1; then
        log.error "Invalid ${YELLOW}'themes'${NC}: ${BLUE}each theme must have a 'latest' string field${NC}"
        has_errors=1
    else
        # Validate each theme.latest is semver X.Y.Z
        local semver_regex='^[0-9]+\\.[0-9]+\\.[0-9]+$'
        local invalid_versions
        invalid_versions="$(jq -r '.themes | to_entries | map(.value.latest) | .[]' "$index_json_path" | awk -v re="$semver_regex" 'BEGIN{invalid=0} { if ($0 !~ re) { print $0; invalid=1 } } END{ if (invalid==0) exit 1 }')"

        if [ -n "$invalid_versions" ]; then
            log.error "Invalid ${YELLOW}'themes'${NC}: ${BLUE}theme 'latest' versions must be semantic X.Y.Z${NC}"
            has_errors=1
        else
            log.success "Has valid themes object"
        fi
    fi

    # Return based on whether errors were found
    return $has_errors
}

# Usage: validate-versions-json [versions_json_path]
validate-versions-json() {
    # Validates the versions.json:
    #   - JSON is an array
    #   - Each entry has: ver (string), hash.value (string), hash.algo (string)
    #   - For each version, an archive "<ver>.tar.gz" exists in the same directory as the JSON
    #   - Hash of each archive matches the recorded hash

    local versions_json_path="${1:-${PWD}/versions.json}"
    local has_errors=0

    # Basic existence and size checks
    if ! [ -f "$versions_json_path" ]; then
        log.error "versions.json not found at '$versions_json_path'"
        return 1
    fi

    if ! [ -s "$versions_json_path" ]; then
        log.error "versions.json is empty"
        return 1
    fi
    log.success "Found versions.json"

    # Validate JSON parse
    if ! jq -e . "$versions_json_path" >/dev/null 2>&1; then
        log.error "versions.json contains invalid JSON"
        return 1
    fi
    log.success "Has valid JSON"

    # --------------- Check structure and fields --------------

    # 1. Validate top-level is an array and non-empty
    if ! jq -e 'type == "array"' "$versions_json_path" >/dev/null 2>&1; then
        log.error "Invalid structure: ${BLUE}must be an array${NC}"
        has_errors=1
    elif ! jq -e 'length >= 1' "$versions_json_path" >/dev/null 2>&1; then
        log.error "Invalid structure: ${BLUE}array cannot be empty${NC}"
        has_errors=1
    else
        log.success "Has valid array structure"
    fi

    # 2. Validate required fields per entry (ver, hash.value, hash.algo)
    if ! jq -e 'all(.[]; has("ver") and (.ver | type == "string") and (.ver | length > 0))' "$versions_json_path" >/dev/null 2>&1; then
        log.error "Missing or invalid ${YELLOW}'ver'${NC}: ${BLUE}each entry must have a non-empty 'ver' string${NC}"
        has_errors=1
    else
        log.success "All entries have valid 'ver' field"
    fi

    if ! jq -e 'all(.[]; has("hash") and (.hash | type == "object"))' "$versions_json_path" >/dev/null 2>&1; then
        log.error "Missing or invalid ${YELLOW}'hash'${NC}: ${BLUE}each entry must have a 'hash' object${NC}"
        has_errors=1
    elif ! jq -e 'all(.[]; .hash | (has("value") and (.value | type == "string") and (.value | length > 0)))' "$versions_json_path" >/dev/null 2>&1; then
        log.error "Missing or invalid ${YELLOW}'hash.value'${NC}: ${BLUE}must be a non-empty string${NC}"
        has_errors=1
    elif ! jq -e 'all(.[]; .hash | (has("algo") and (.algo | type == "string") and (.algo | length > 0)))' "$versions_json_path" >/dev/null 2>&1; then
        log.error "Missing or invalid ${YELLOW}'hash.algo'${NC}: ${BLUE}must be a non-empty string${NC}"
        has_errors=1
    else
        log.success "All entries have valid 'hash' object"
    fi

    # 3. Validate semver format for each 'ver' field
    local semver_regex='^[0-9]+\\.[0-9]+\\.[0-9]+$'
    local invalid_versions
    invalid_versions="$(jq -r '.[].ver' "$versions_json_path" 2>/dev/null | awk -v re="$semver_regex" 'BEGIN{invalid=0} { if ($0 !~ re) { print $0; invalid=1 } } END{ if (invalid==0) exit 1 }')"

    if [ -n "$invalid_versions" ]; then
        log.error "Invalid ${YELLOW}'ver'${NC} format: ${BLUE}must be semantic X.Y.Z${NC}"
        has_errors=1
    else
        log.success "All versions follow semantic versioning"
    fi

    # Return early if structure validation failed
    if [ $has_errors -ne 0 ]; then
        return $has_errors
    fi

    # 4. Check archive existence for each version
    local json_dir
    json_dir="$(dirname "$versions_json_path")"

    local missing_archives
    missing_archives="$(jq -r '.[].ver' "$versions_json_path" | while IFS= read -r ver; do
        archive_path="${json_dir}/${ver}.tar.gz"
        if ! [ -f "$archive_path" ]; then
            echo "$ver"
        fi
    done)"

    if [ -n "$missing_archives" ]; then
        log.error "Missing archives for versions:"
        echo "$missing_archives" | sed 's/^/  - /' >&2
        has_errors=1
    else
        log.success "All version archives exist"
    fi

    # 5. Verify hash of each archive matches the recorded hash.value
    local mismatch_list
    mismatch_list="$(jq -r '.[] | [.ver, .hash.value, .hash.algo] | @tsv' "$versions_json_path" | while IFS=$'\t' read -r ver hash_value algo; do
        archive_path="${json_dir}/${ver}.tar.gz"

        # Skip if not a file (already checked above, but be safe)
        [ -f "$archive_path" ] || continue

        # Compare computed archive hash against provided hash using specified algo
        if ! compare-hash --f1 "$archive_path" --h2 "$hash_value" --algo "$algo" 2>/dev/null; then
            echo "$ver"
        fi
    done)"

    if [ -n "$mismatch_list" ]; then
        log.error "Hash mismatches detected for versions:"
        echo "$mismatch_list" | sed 's/^/  - /' >&2
        has_errors=1
    else
        log.success "All archive hashes match"
    fi

    # Return based on whether errors were found
    return $has_errors
}
