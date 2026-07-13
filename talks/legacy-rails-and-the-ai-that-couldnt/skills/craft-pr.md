---
name: craft-pr
description: >-
  Generate guideline-compliant PR descriptions and create draft PRs via
  `gh pr create --draft`. Use when creating pull requests, generating PR
  descriptions, or finishing work on a branch.
---

# PR Description Skill

Generate a pull request description that's actually useful as an artifact, then create a draft PR via GitHub CLI.

## When to Use This Skill

- Creating a pull request for a feature branch
- Generating a PR description from branch changes
- Finishing work and ready to open a draft PR
- User says "create PR", "generate PR", "open PR", or "craft-pr"

## Helper Scripts

This skill uses helper scripts that batch multiple CLI calls into one, returning structured JSON:

- `git-context.sh` — Gathers branch name, ticket ID, commits, changed files, diff stats
- `diff-summary.sh` — Categorizes the diff by Rails file type (specs, services, models, etc.)
- `related-prs.sh` — Finds recently merged PRs in the same area for test plan context

## Process

### Step 1: Load Guidelines and Config

Read `config.yml` for org-specific values. Load the PR formatting guidelines document for style rules.

### Step 2: Gather Git Context

Run `git-context.sh` to collect all branch information in a single call. This returns JSON with: `branch`, `ticket_id`, `base`, `commits`, `changed_files`, `diff_stat`, and `existing_pr`.

### Step 3: Analyze Branch Changes

Using the git context, determine:
- What files changed and in which domains (models, services, controllers, views, migrations, tests, config)
- What the changes do at a functional level
- Whether a PR already exists (update vs create)

### Step 4: Commit Hygiene Check

Check for WIP, fixup, or low-effort commits. If found, suggest a squash plan. This is a suggestion, not a blocker.

### Step 5: PR Size Check

If the PR exceeds ~400 meaningful lines, suggest a split based on logical boundaries. Also a suggestion, not a blocker.

### Step 6: Enrich from Ticket

If a ticket ID was found in the branch name, fetch the ticket for context:
- Description/summary for a richer "Purpose" section
- Acceptance criteria to inform test plan structure
- Comments for implementation decisions and edge cases

Do NOT extract epic sequencing, blocking relationships, or sibling ticket ordering — that's project metadata, not PR context.

### Step 7: Search Related Merged PRs

Find recently merged PRs in the same codebase area. Read their bodies to understand:
- How previous test plans were structured for this area
- What test data setup was used
- Existing test objects that can be referenced

This makes the test plan build on prior work rather than starting from scratch.

### Step 8: Generate PR Description

Build the description following these rules. Include **only relevant sections** — skip any that don't apply.

**Proportionality:** Match depth to complexity. A focused bug fix needs a brief Purpose and maybe a test plan. A multi-domain feature needs the full treatment.

#### Title
- One sentence, ~60 characters or less
- Summarize the functional change

#### Purpose (H2)
- First bullet sets the stage with "why" — use ticket context for a richer opening
- ~5 top-level bullets; functional outcomes at top level, implementation details in sub-bullets
- Clean bullets, no bold prefixes

#### Context Diagram (Optional)
Include a mermaid diagram only for architecture/refactoring PRs, complex async behavior, or multi-step flows. Skip for simple features, bug fixes, UI-only, or config changes.

#### Test Plan (H2)

**CRITICAL: Test plans are for manual testing only. Never mention automated tests or RSpec.**

- Use related PRs from Step 7 for test data setup patterns
- Assume stale dev data — create or update records rather than assuming data exists
- Console verification (calling a service in `rails console`) counts as manual verification
- Include `⚠️ **[Add screenshot here]** ⚠️` placeholder slots for post-deploy verification
- Never generate "deferred to production" test plans — push for concrete verification

#### Migration Section (Only When Relevant)
If the PR includes database migrations, analyze them for risk, compliance, and deployment timing.

#### Infrastructure Impact (Only When Relevant)
Include when changes touch ENV vars, config, performance, or infrastructure.

### Step 9: Present for Review

Output the PR description as rendered markdown. Then ask: "Create draft PR" or "I have feedback."

### Step 10: Handle Edit History (Updates Only)

When updating an existing PR, check for manual edits since the last generation:
- **Filled placeholders** (screenshots, console output) — always preserve
- **Added sections** (Loom links, demo notes) — always preserve
- **Rewrites** — default to replacing with new generation

Present a summary and let the user choose what to preserve.

### Step 11: Create or Update PR

Write a checksum into the description (for the self-improvement feedback loop):
```
<!-- craft-pr-checksum: [hash] -->
```

This hidden line lets `feedback.sh` identify agent-generated descriptions and track their edit histories over time.

```bash
# Always create as draft
gh pr create --draft --title "Title" --body-file /tmp/pr-body.md
```

**Always `--draft`.** Never create a non-draft PR.

---

## The craft-dev Handoff

When `craft-dev` finishes a session and the user wants a PR, it invokes this skill. For long sessions (3+ TDD cycles), craft-dev sends a **Development Context Brief** — a distillation of:

- What was built and why (beyond what the diff shows)
- Trade-offs and alternatives considered
- Testing insights and edge cases discovered
- Manual verification observations

This context makes the Purpose and Test Plan significantly richer than what diff analysis alone could produce.

---

## Quick Reference

| Element | Rule |
|---------|------|
| Proportionality | Match depth to PR complexity; brevity wins ties |
| Purpose | First bullet = "why"; ~5 top-level; feature flags get dashboard links |
| Test plan | Manual only; assume stale dev data; build on prior PRs |
| Diagrams | Only for architecture, async, or multi-step flows |
| Sections | Skip if not applicable (no "N/A" sections) |
| Draft mode | Always `--draft` |
| Checksum | Hidden HTML comment for the self-improvement feedback loop |
