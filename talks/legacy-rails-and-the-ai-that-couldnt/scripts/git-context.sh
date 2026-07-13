#!/usr/bin/env bash
set -euo pipefail

# Gather comprehensive git context for the current branch.
# Returns JSON to stdout, errors to stderr.
#
# Usage: git-context.sh [--base main] [--max-commits 50]

BASE="master"
MAX_COMMITS=50

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE="$2"; shift 2 ;;
    --max-commits) MAX_COMMITS="$2"; shift 2 ;;
    --help)
      echo "Usage: git-context.sh [--base master] [--max-commits 50]" >&2
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")

# Extract ticket ID from branch name (e.g., yn/feature/BLOG-1234-foo -> BLOG-1234)
TICKET_ID=$(echo "$BRANCH" | grep -oE '[A-Z]+-[0-9]+' | head -1 || true)

# Fetch to ensure we have latest remote refs
git fetch origin "$BASE" 2>/dev/null || true

MERGE_BASE=$(git merge-base "origin/${BASE}" HEAD 2>/dev/null || echo "")

# Commits on this branch
if [[ -n "$MERGE_BASE" ]]; then
  COMMITS=$(git log --format='{"hash":"%h","subject":"%s","author":"%an","date":"%aI"}' \
    "${MERGE_BASE}..HEAD" --max-count="$MAX_COMMITS" 2>/dev/null | jq -s '.' || echo "[]")

  DIFF_STAT=$(git diff --stat "${MERGE_BASE}..HEAD" 2>/dev/null || echo "")

  CHANGED_FILES=$(git diff --name-only "${MERGE_BASE}..HEAD" 2>/dev/null | jq -R . | jq -s '.' || echo "[]")

  DIFF_SUMMARY=$(git diff --shortstat "${MERGE_BASE}..HEAD" 2>/dev/null | sed 's/^ *//' || echo "")
else
  COMMITS="[]"
  DIFF_STAT=""
  CHANGED_FILES="[]"
  DIFF_SUMMARY=""
fi

# Staged changes (for pre-commit context)
STAGED_FILES=$(git diff --cached --name-only 2>/dev/null | jq -R . | jq -s '.' || echo "[]")
STAGED_STAT=$(git diff --cached --shortstat 2>/dev/null | sed 's/^ *//' || echo "")

# Unstaged changes
UNSTAGED_FILES=$(git diff --name-only 2>/dev/null | jq -R . | jq -s '.' || echo "[]")

# Untracked files
UNTRACKED_FILES=$(git ls-files --others --exclude-standard 2>/dev/null | jq -R . | jq -s '.' || echo "[]")

# Check for existing PR — distinguish "no PR" from "API failed"
PR_OUTPUT=""
PR_OUTPUT=$(gh pr view --json number,title,url,state,isDraft,reviewDecision 2>&1) && PR_EXIT=0 || PR_EXIT=$?

if [[ $PR_EXIT -eq 0 ]] && echo "$PR_OUTPUT" | jq -e '.number' >/dev/null 2>/dev/null; then
  EXISTING_PR="$PR_OUTPUT"
elif echo "$PR_OUTPUT" | grep -qi 'no pull requests found'; then
  EXISTING_PR='{}'
else
  echo "WARNING: gh pr view failed (exit $PR_EXIT). PR detection may be incomplete. Ensure network access is available." >&2
  EXISTING_PR='{"error": "gh_api_failed"}'
fi

jq -n \
  --arg branch "$BRANCH" \
  --arg ticket_id "${TICKET_ID:-}" \
  --arg base "$BASE" \
  --arg merge_base "${MERGE_BASE:-}" \
  --arg diff_stat "$DIFF_STAT" \
  --arg diff_summary "$DIFF_SUMMARY" \
  --arg staged_stat "$STAGED_STAT" \
  --argjson commits "$COMMITS" \
  --argjson changed_files "$CHANGED_FILES" \
  --argjson staged_files "$STAGED_FILES" \
  --argjson unstaged_files "$UNSTAGED_FILES" \
  --argjson untracked_files "$UNTRACKED_FILES" \
  --argjson existing_pr "$EXISTING_PR" \
  '{
    branch: $branch,
    ticket_id: $ticket_id,
    base: $base,
    merge_base: $merge_base,
    commits: $commits,
    changed_files: $changed_files,
    diff_stat: $diff_stat,
    diff_summary: $diff_summary,
    staged_files: $staged_files,
    staged_stat: $staged_stat,
    unstaged_files: $unstaged_files,
    untracked_files: $untracked_files,
    existing_pr: $existing_pr
  }'
