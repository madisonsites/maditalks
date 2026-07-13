#!/usr/bin/env bash
set -euo pipefail

# Find recently merged PRs that touched the same directories as the current branch.
# Used by craft-pr to build test plans on prior work rather than starting from scratch.
# Returns JSON to stdout, progress to stderr.
#
# Usage: related-prs.sh [--base master] [--since "60 days ago"] [--limit 10] [--min-overlap 1]

BASE="master"
SINCE="60 days ago"
LIMIT=10
MIN_OVERLAP=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE="$2"; shift 2 ;;
    --since) SINCE="$2"; shift 2 ;;
    --limit) LIMIT="$2"; shift 2 ;;
    --min-overlap) MIN_OVERLAP="$2"; shift 2 ;;
    --help)
      cat >&2 <<'USAGE'
Usage: related-prs.sh [--base master] [--since "60 days ago"] [--limit 10] [--min-overlap 1]

Finds recently merged PRs that overlap with the current branch's changed directories.

Options:
  --base BRANCH       Base branch (default: master).
  --since PERIOD      How far back to search (default: "60 days ago").
  --limit N           Max PRs to fetch from GitHub (default: 10).
  --min-overlap N     Minimum overlapping directories to include a PR (default: 1).

Dependencies: git, gh, jq, python3

Examples:
  related-prs.sh
  related-prs.sh --base main --since "30 days ago"
  related-prs.sh --min-overlap 2 --limit 20
USAGE
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Convert relative date to ISO format
SINCE_DATE=$(python3 -c "
from datetime import datetime, timedelta
import re, sys
s = sys.argv[1].lower().strip()
m = re.match(r'(\d+)\s*(day|week|month)s?\s*ago', s)
if m:
    n, unit = int(m.group(1)), m.group(2)
    if unit == 'day': delta = timedelta(days=n)
    elif unit == 'week': delta = timedelta(weeks=n)
    elif unit == 'month': delta = timedelta(days=n*30)
    else: delta = timedelta(days=30)
    print((datetime.now() - delta).strftime('%Y-%m-%d'))
else:
    print((datetime.now() - timedelta(days=30)).strftime('%Y-%m-%d'))
" "$SINCE" 2>/dev/null || date -v-60d +%Y-%m-%d 2>/dev/null || date -d "60 days ago" +%Y-%m-%d)

# Get directories changed in the current branch
MERGE_BASE=$(git merge-base "origin/${BASE}" HEAD 2>/dev/null || echo "")

if [[ -z "$MERGE_BASE" ]]; then
  echo '{"success":false,"error":"Could not determine merge base. Is origin/'"${BASE}"' available?"}' | jq .
  exit 1
fi

CHANGED_FILES=$(git diff --name-only "${MERGE_BASE}..HEAD" 2>/dev/null || echo "")

if [[ -z "$CHANGED_FILES" ]]; then
  jq -n '{success: true, prs: [], count: 0, reason: "No changed files on current branch."}'
  exit 0
fi

# Extract unique parent directories (one level deep from common Rails paths)
CHANGED_DIRS=$(echo "$CHANGED_FILES" | while IFS= read -r f; do
  dirname "$f"
done | sort -u | jq -R . | jq -s '.')

CHANGED_DIRS_COUNT=$(echo "$CHANGED_DIRS" | jq 'length')
echo "Current branch touches ${CHANGED_DIRS_COUNT} directories. Searching merged PRs since ${SINCE_DATE}..." >&2

# Fetch recently merged PRs
MERGED_PRS=$(gh pr list \
  --state merged \
  --base "$BASE" \
  --search "merged:>=${SINCE_DATE}" \
  --limit "$LIMIT" \
  --json number,title,mergedAt,url,body,files 2>/dev/null || echo "[]")

MERGED_COUNT=$(echo "$MERGED_PRS" | jq 'length')
echo "Found ${MERGED_COUNT} merged PRs. Checking directory overlap..." >&2

# Filter to PRs with overlapping directories
RESULTS=$(echo "$MERGED_PRS" | jq --argjson changed_dirs "$CHANGED_DIRS" --argjson min_overlap "$MIN_OVERLAP" '
  [.[] |
    . as $pr |
    # Get directories from the PR files
    [.files[]?.path // empty | split("/")[:-1] | join("/")] | unique as $pr_dirs |
    # Find overlapping directories
    [$pr_dirs[] | select(. as $d | $changed_dirs | index($d))] as $overlap |
    select(($overlap | length) >= $min_overlap) |
    {
      number: .number,
      title: .title,
      merged_at: .mergedAt,
      url: .url,
      body: .body,
      overlapping_dirs: $overlap
    }
  ]
')

RESULT_COUNT=$(echo "$RESULTS" | jq 'length')

jq -n \
  --arg since "$SINCE_DATE" \
  --arg base "$BASE" \
  --argjson min_overlap "$MIN_OVERLAP" \
  --argjson changed_dirs "$CHANGED_DIRS" \
  --argjson prs "$RESULTS" \
  --argjson count "$RESULT_COUNT" \
  '{
    success: true,
    since: $since,
    base: $base,
    min_overlap: $min_overlap,
    branch_dirs: $changed_dirs,
    prs: $prs,
    count: $count
  }'
