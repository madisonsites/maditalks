#!/usr/bin/env bash
set -euo pipefail

# Produce a structured JSON summary of a git diff, categorized by Rails file type.
# Shell helper that returns machine-readable output for agent consumption.
# Returns JSON to stdout, errors to stderr.
#
# Usage: diff-summary.sh [--range REF..REF] [--staged] [--base master]

RANGE=""
STAGED=false
BASE="master"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --range) RANGE="$2"; shift 2 ;;
    --staged) STAGED=true; shift ;;
    --base) BASE="$2"; shift 2 ;;
    --help)
      cat >&2 <<'USAGE'
Usage: diff-summary.sh [--range REF..REF] [--staged] [--base master]

Options:
  --range REF..REF  Git diff range (e.g., "origin/master..HEAD"). Default: computed from --base.
  --staged          Diff staged changes only.
  --base BRANCH     Base branch for auto-range (default: master). Ignored if --range or --staged is set.

Categories: specs, routes, translations, views, models, services, workers, controllers,
            components, policies, blueprints, helpers, concerns, migrations, factories, config, other
USAGE
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ "$STAGED" == true ]]; then
  DIFF_ARGS="--cached"
  STAT_ARGS="--cached"
elif [[ -n "$RANGE" ]]; then
  DIFF_ARGS="$RANGE"
  STAT_ARGS="$RANGE"
else
  MERGE_BASE=$(git merge-base "origin/${BASE}" HEAD 2>/dev/null || echo "")
  if [[ -n "$MERGE_BASE" ]]; then
    DIFF_ARGS="${MERGE_BASE}..HEAD"
    STAT_ARGS="${MERGE_BASE}..HEAD"
  else
    echo '{"success":false,"error":"Could not determine merge base. Use --range or --staged."}' | jq .
    exit 1
  fi
fi

NUMSTAT=$(git diff --numstat $DIFF_ARGS 2>/dev/null || echo "")
NAME_STATUS=$(git diff --name-status $DIFF_ARGS 2>/dev/null || echo "")
SHORTSTAT=$(git diff --shortstat $DIFF_ARGS 2>/dev/null | sed 's/^ *//' || echo "")

if [[ -z "$NAME_STATUS" ]]; then
  jq -n '{
    success: true,
    empty: true,
    total_files: 0,
    files_added: 0,
    files_modified: 0,
    files_deleted: 0,
    lines_added: 0,
    lines_removed: 0,
    net_lines: 0,
    shortstat: "",
    by_category: {},
    files: []
  }'
  exit 0
fi

categorize() {
  local file="$1"
  case "$file" in
    spec/factories/*|spec/support/factories/*) echo "factories" ;;
    spec/*) echo "specs" ;;
    config/routes.rb|config/routes/*) echo "routes" ;;
    config/locales/*) echo "translations" ;;
    app/views/*) echo "views" ;;
    app/models/*) echo "models" ;;
    app/services/*) echo "services" ;;
    app/workers/*) echo "workers" ;;
    app/controllers/*) echo "controllers" ;;
    app/components/*) echo "components" ;;
    app/policies/*) echo "policies" ;;
    app/blueprints/*) echo "blueprints" ;;
    app/helpers/*) echo "helpers" ;;
    app/concerns/*|app/models/concerns/*) echo "concerns" ;;
    db/migrate/*) echo "migrations" ;;
    config/*) echo "config" ;;
    *) echo "other" ;;
  esac
}

FILES_JSON="[]"

while IFS=$'\t' read -r status file rest; do
  [[ -z "$status" ]] && continue

  S="${status:0:1}"

  ADDED=0
  REMOVED=0
  FILE_FOR_NUMSTAT="$file"
  if [[ "$S" == "R" ]]; then
    FILE_FOR_NUMSTAT="$rest"
    file="$rest"
  fi

  NUMLINE=$(echo "$NUMSTAT" | grep -F "$FILE_FOR_NUMSTAT" | head -1 || true)
  if [[ -n "$NUMLINE" ]]; then
    ADDED=$(echo "$NUMLINE" | awk '{print $1}')
    REMOVED=$(echo "$NUMLINE" | awk '{print $2}')
    [[ "$ADDED" == "-" ]] && ADDED=0
    [[ "$REMOVED" == "-" ]] && REMOVED=0
  fi

  CAT=$(categorize "$file")

  FILE_ENTRY=$(jq -n \
    --arg path "$file" \
    --arg status "$S" \
    --arg category "$CAT" \
    --argjson added "$ADDED" \
    --argjson removed "$REMOVED" \
    '{path: $path, status: $status, category: $category, lines_added: $added, lines_removed: $removed}')

  FILES_JSON=$(echo "$FILES_JSON" | jq --argjson f "$FILE_ENTRY" '. + [$f]')
done <<< "$NAME_STATUS"

CAT_JSON=$(echo "$FILES_JSON" | jq '
  group_by(.category) | map({
    key: .[0].category,
    value: {
      added: [.[] | select(.status == "A")] | length,
      deleted: [.[] | select(.status == "D")] | length,
      modified: [.[] | select(.status == "M" or .status == "R")] | length
    }
  }) | from_entries
')

TOTAL_FILES=$(echo "$FILES_JSON" | jq 'length')
FILES_ADDED=$(echo "$FILES_JSON" | jq '[.[] | select(.status == "A")] | length')
FILES_MODIFIED=$(echo "$FILES_JSON" | jq '[.[] | select(.status == "M" or .status == "R")] | length')
FILES_DELETED=$(echo "$FILES_JSON" | jq '[.[] | select(.status == "D")] | length')
LINES_ADDED=$(echo "$FILES_JSON" | jq '[.[].lines_added] | add // 0')
LINES_REMOVED=$(echo "$FILES_JSON" | jq '[.[].lines_removed] | add // 0')
NET_LINES=$(( LINES_ADDED - LINES_REMOVED ))

jq -n \
  --argjson total_files "$TOTAL_FILES" \
  --argjson files_added "$FILES_ADDED" \
  --argjson files_modified "$FILES_MODIFIED" \
  --argjson files_deleted "$FILES_DELETED" \
  --argjson lines_added "$LINES_ADDED" \
  --argjson lines_removed "$LINES_REMOVED" \
  --argjson net_lines "$NET_LINES" \
  --arg shortstat "$SHORTSTAT" \
  --argjson by_category "$CAT_JSON" \
  --argjson files "$FILES_JSON" \
  '{
    success: true,
    empty: false,
    total_files: $total_files,
    files_added: $files_added,
    files_modified: $files_modified,
    files_deleted: $files_deleted,
    lines_added: $lines_added,
    lines_removed: $lines_removed,
    net_lines: $net_lines,
    shortstat: $shortstat,
    by_category: $by_category,
    files: $files
  }'
