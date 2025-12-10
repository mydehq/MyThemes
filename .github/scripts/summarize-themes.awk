#!/usr/bin/awk -f
# summarize-themes.awk
#
# Reads `git show --name-status --format="" HEAD` output from stdin
# and emits a Markdown summary grouped by theme:
# - "### Added" lists newly added versions
# - "### Deleted" lists deleted versions
#
# Expected input lines:
#   A theme-name/version.tar.gz
#   D theme-name/version.tar.gz
#
# Example usage:
#   git show --name-status --format="" HEAD \
#     | awk -f .github/scripts/summarize-themes.awk

# Helper: trim trailing .tar.gz from a filename to get the version
function strip_tar_gz(name,    v) {
  v = name
  sub(/\.tar\.gz$/, "", v)
  return v
}

# Helper: append a value to a comma-separated list map[key]
function append_csv(map, key, value,    existing) {
  existing = map[key]
  if (existing == "") {
    map[key] = value
  } else {
    map[key] = existing ", " value
  }
}

# Process each input line: "<status> <path>"
# where status is A/D and path is "theme/version.tar.gz"
$2 ~ /\.tar\.gz$/ {
  status = $1
  path   = $2

  # split path "theme/version.tar.gz"
  n = split(path, parts, "/")
  if (n >= 2) {
    theme   = parts[1]
    version = strip_tar_gz(parts[2])

    # Track any theme we see
    themes[theme] = 1

    if (status == "A") {
      append_csv(added, theme, version)
    } else if (status == "D") {
      append_csv(deleted, theme, version)
    }
  }
}

END {
  # Header
  print "## 📦 Repo Updated"
  print ""

  # Added section
  print "### Added"
  print ""

  has_added = 0
  for (t in themes) {
    if (added[t] != "") {
      has_added = 1
      printf "- `%s`: %s\n", t, added[t]
    }
  }
  if (!has_added) {
    print "_No new Themes added._"
  }

  print ""
  print "### Deleted"
  print ""

  has_deleted = 0
  for (t in themes) {
    if (deleted[t] != "") {
      has_deleted = 1
      printf "- `%s`: %s\n", t, deleted[t]
    }
  }
  if (!has_deleted) {
    print "_No Themes deleted._"
  }

  print ""
  print "---"
  print ""
  print "View all files in the [`repo`](../../tree/repo) branch."
}
