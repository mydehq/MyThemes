
# Usage: validate-theme-dir <theme_dir>
validate-theme-dir() {
   local theme_dir="$1"
   local theme_yml="$theme_dir/theme.yml"
   local has_errors=0

   # Validate theme directory
   ! [ -d "$theme_dir" ] && {
      log.error "Theme dir '$theme_dir' does not exist"
      return 1
   }

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
   log.success "Has valid Manifest"

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
        log.success "Has valid version"
   fi

   # 2. Check author field
   local theme_author
   theme_author="$(yq '.author' "$theme_yml" 2>/dev/null | tr -d '\0')"

   if [ -z "$theme_author" ] || [ "$theme_author" == "null" ]; then
        log.error "Missing required field: ${YELLOW}'author'${NC}"
        has_errors=1
   else
        log.success "Has valid author"
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
        log.success "Has valid URL"
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
        log.success "Has valid config object"
   fi

   # Return based on whether errors were found
   return $has_errors
}


# check if index.json is valid
## AI co-authored
validate-index() {
    local index_json_path="${1:-${OUTPUT_DIR:-./dist}/index.json}"

    # Basic existence and size checks
    if ! [ -f "$index_json_path" ]; then
        log.error "index.json not found at '$index_json_path'"
        return 1
    fi

    if ! [ -s "$index_json_path" ]; then
        log.error "index.json at '$index_json_path' is empty"
        return 1
    fi

    # Validate JSON parse
    if ! jq -e . "$index_json_path" >/dev/null 2>&1; then
        log.error "index.json contains invalid JSON"
        return 1
    fi

    # Validate schema_ver == 2
    if ! jq -e 'has("schema_ver") and (.schema_ver == 2)' "$index_json_path" >/dev/null; then
        log.error "Invalid or missing 'schema_ver' (expected 2)"
        return 1
    fi

    # Validate repo_name non-empty string
    if ! jq -e 'has("repo_name") and (.repo_name | type == "string") and (.repo_name | length > 0)' "$index_json_path" >/dev/null; then
        log.error "Invalid or missing 'repo_name' (must be a non-empty string)"
        return 1
    fi

    # Validate release numeric field exists
    if ! jq -e 'has("release") and (.release | type == "number")' "$index_json_path" >/dev/null; then
        log.error "Invalid or missing 'release' (must be a numeric Unix timestamp in seconds)"
        return 1
    fi

    # Release time checks:
    # - release should be integer seconds
    # - not in the future
    # - not before Jan 1, 2005 -> 1104537600
    current_time="$(date +%s)"
    release_val="$(jq -r '.release' "$index_json_path")"

    # Ensure release_val is an integer (jq number may be float; enforce integer string check)
    if ! printf "%s" "$release_val" | awk 'BEGIN{ok=1} { if ($0 !~ /^[0-9]+$/) ok=0 } END{ exit ok==1 ? 0 : 1 }'; then
        log.error "Invalid 'release' (must be integer seconds)"
        return 1
    fi

    # Check lower bound (>= 2005-01-01) and not in the future
    if [ "$release_val" -lt 1104537600 ]; then
        log.error "Invalid 'release' (too old; must be >= 1104537600 [2005-01-01])"
        return 1
    fi

    if [ "$release_val" -gt "$current_time" ]; then
        log.error "Invalid 'release' (timestamp is in the future)"
        return 1
    fi

    # Validate src_urls array non-empty and each string contains placeholders
    # Placeholders required: ${{theme}} and ${{file}}
    if ! jq -e '
        has("src_urls") and
        (.src_urls | type == "array") and
        (.src_urls | length > 0) and
        (all(.src_urls[]; (type == "string") and (contains("${{theme}}")) and (contains("${{file}}"))))
    ' "$index_json_path" >/dev/null; then
        log.error "Invalid 'src_urls' (must be non-empty array of strings including \${{theme}} and \${{file}})"
        return 1
    fi


    # Ensure themes is an object
    if ! jq -e 'has("themes") and (.themes | type == "object")' "$index_json_path" >/dev/null; then
        log.error "Invalid or missing 'themes' (must be an object)"
        return 1
    fi

    # If themes can be empty, that's okay; otherwise enforce presence of keys:
    # Validate each theme entry has "latest" and matches semver
    # We perform two checks:
    #   1) All entries must have a "latest" string
    #   2) All "latest" strings must match the semver regex
    if ! jq -e '
        (.themes | to_entries | all(.value | (has("latest") and (.latest | type == "string"))))
    ' "$index_json_path" >/dev/null; then
        log.error "All themes must include a 'latest' string field"
        return 1
    fi

    # Validate themes object and each theme.latest is semver X.Y.Z
    # Semver pattern: digits.digits.digits
    local semver_regex='^[0-9]+\\.[0-9]+\\.[0-9]+$'

    # Check semver pattern for each latest
    # jq does not do regex fully; we extract and test via shell
    # Collect latest versions and verify in shell
    local invalid_versions
    invalid_versions="$(jq -r '
        .themes | to_entries | map(.value.latest) | .[]
    ' "$index_json_path" | awk -v re="$semver_regex" 'BEGIN{invalid=0} { if ($0 !~ re) { print $0; invalid=1 } } END{ if (invalid==0) exit 1 }')"

    if [ -n "$invalid_versions" ]; then
        log.error "Invalid semver in theme 'latest' fields:"
        echo "$invalid_versions" | sed 's/^/  - /' >&2
        return 1
    fi

    # All good
    return 0
}

# Usage: validate-versions-json [versions_json_path]
validate-versions-json() {
    # Validates the .versions.json:
    #   - JSON is an array
    #   - Each entry has: version (string), hash.value (string), hash.algo (string)
    #   - For each version, an archive "<version>.tar.gz" exists in the same directory as the JSON

    local versions_json_path="${1:-${PWD}/.versions.json}"

    # Existence and non-empty check
    if ! [ -f "$versions_json_path" ]; then
        log.error ".versions.json not found at '$versions_json_path'"
        return 1
    fi

    if ! [ -s "$versions_json_path" ]; then
        log.error ".versions.json at '$versions_json_path' is empty"
        return 1
    fi

    # Validate JSON parse
    if ! jq -e . "$versions_json_path" >/dev/null 2>&1; then
        log.error ".versions.json contains invalid JSON"
        return 1
    fi

    # Validate top-level is an array and non-empty (allow empty? here we require at least 1 entry)
    if ! jq -e 'type == "array" and (length >= 1)' "$versions_json_path" >/dev/null; then
        log.error ".versions.json must be a non-empty array"
        return 1
    fi

    # Validate required fields per entry
    if ! jq -e '
        all(.[];
            (has("version") and (.version | type == "string") and (.version | length > 0)) and
            (has("hash") and (.hash | type == "object") and
                (.hash | has("value") and (.value | type == "string") and (.value | length > 0)) and
                (.hash | has("algo") and (.algo | type == "string") and (.algo | length > 0))
            )
        )
    ' "$versions_json_path" >/dev/null; then
        log.error "Each entry in .versions.json must include 'version', 'hash', 'hash.value', and 'hash.algo'"
        return 1
    fi

    # Check archive existence for each version
    local json_dir
    json_dir="$(dirname "$versions_json_path")"

    local missing_archives
    missing_archives="$(jq -r '.[].version' "$versions_json_path" | while IFS= read -r ver; do
        archive_path="${json_dir}/${ver}.tar.gz"
        if ! [ -f "$archive_path" ]; then
            echo "$archive_path"
        fi
    done)"

    if [ -n "$missing_archives" ]; then
        log.error "Missing archives for listed versions:"
        echo "$missing_archives" | sed 's/^/  - /' >&2
        return 1
    fi

    # Verify hash of each archive matches the recorded hash.value using compare-hash --hash
    local mismatch_list
    mismatch_list="$(jq -r '.[] | [.version, .hash.value, .hash.algo] | @tsv' "$versions_json_path" | while IFS=$'\t' read -r ver hash_value algo; do
        archive_path="${json_dir}/${ver}.tar.gz"

        # Skip if not a file (already checked above, but be safe)
        [ -f "$archive_path" ] || { echo "$ver (archive missing)"; continue; }

        # Compare computed archive hash against provided hash using specified algo
        if ! compare-hash --f1 "$archive_path" --h2 "$hash_value" --algo "$algo"; then
            echo "$ver (hash mismatch for $archive_path)"
        fi
    done)"

    if [ -n "$mismatch_list" ]; then
        log.error "Hash mismatches detected for archives:"
        echo "$mismatch_list" | sed 's/^/  - /' >&2
        return 1
    fi

    log.success ".versions.json is valid"
    return 0
}
