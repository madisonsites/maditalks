---
name: review-retro
description: >-
  Learn from the gap between drafted and posted PR review comments, and from
  edits to agent-generated PR descriptions. Updates tone rules, patterns,
  quality lens, and voice profile. Use when the user says "review-retro",
  "review learn", "pr retro", or "learn from my PRs".
---

# Review Retro

Self-improvement feedback loop for the PR review skill. Compares what was drafted against what was actually posted or merged, classifies the differences, and proposes targeted updates to the artifact files that the review skill reads.

This is the technical implementation of the "leave it better than you found it" flywheel.

## Configuration

Read `config.yml` for `github.username`, `github.org`, `github.repo`.

| Key | Purpose |
|-----|---------|
| TONE_RULES | How to communicate in reviews (compression, hedges, severity markers) |
| PATTERNS | Architectural patterns to check for in PRs |
| QUALITY_LENS | PR description and test plan quality standards |
| VOICE_PROFILE | Your personal voice profile for review comments |
| STATE_FILE | Machine-readable metadata tracking learning status |
| LEARNINGS_FILE | Human-readable append-only log of learnings |
| FEEDBACK_SCRIPT | `feedback.sh` — fetches PR edit histories |

## Input Parsing

| Trigger | Mode |
|---------|------|
| `review-retro` or `review learn` | Both modes in sequence (descriptions then comments) |
| `review-retro comments` | Comment mode only |
| `review-retro descriptions` or `pr retro` | Description mode only |

## Core Comparison Logic

Both modes follow the same pattern:

1. **Collect pairs**: (generated version, final version) for each item
2. **Normalize**: Strip mechanical noise before comparing
3. **Diff**: Compare normalized generated vs final
4. **Classify**: Categorize each change (tone adjustment, missing context, wrong framing, etc.)
5. **Propose updates**: Group proposed changes by target artifact file
6. **Apply with approval**: Present changes, user approves per-group

### Normalization

- **Comments**: Strip whitespace differences, normalize GitHub markdown rendering differences
- **Descriptions**: Strip checksum lines, bot-authored edits, and auto-appended reference links

### Classification

Each diff can trigger multiple categories. Each category maps to one or more target artifact files. Examples:

- "Too formal" -> update tone rules
- "Missing codebase context" -> update patterns
- "Wrong severity" -> update tone rules (severity markers section)
- "Voice drift" -> update voice profile

---

## Comment Mode

1. Find PRs with saved draft comments (status: `pending`)
2. Load the drafts that were saved before posting
3. Fetch actually-posted comments via `gh api`
4. Run the comparison logic (pair, normalize, diff, classify)
5. Present proposed updates grouped by artifact file
6. On approval: update artifacts, clean up draft files, mark as `learned`

### What comment mode updates

| Artifact | Example changes |
|----------|----------------|
| Tone rules | Compression examples, hedge anti-patterns, severity marker usage |
| Patterns | New architectural patterns discovered, codebase permalink examples |
| Quality lens | New quality gap patterns from description/test-plan feedback |
| Voice profile | Phrasing patterns that consistently differ between draft and posted |

---

## Description Mode

1. Run `feedback.sh` to fetch merged PRs with edit histories
2. Identify original agent-generated version vs final merged version
3. Normalize and compare (shared logic)
4. Classify changes using description-specific categories
5. Cross-reference against current skill files (skip already-addressed learnings)
6. Distill learnings and write to state file + learnings log
7. Drop expired learnings per retention rules

### What description mode updates

Writes structured learnings consumed by a companion "evolve" skill that actually applies the changes to the PR description skill files. Separation of concerns: review-retro identifies *what* to change, the evolve skill decides *how* to change it.

---

## Output

After both modes complete:

```
=== REVIEW RETRO ===

## Description Mode
- PRs scanned: N (M modified, K accepted)
- Skipped: J (already addressed in current skill files)
- New learnings: L
- Dropped: D (expired)

## Comment Mode
- PRs processed: N
- Draft comments compared: M
- Changes classified: K

### Proposed Updates

**tone-rules.md** (N changes):
 1. [category]: description
 2. ...
 -> Approve these? [yes / skip / edit]

**patterns.md** (N changes):
 1. ...
 -> Approve?

**voice-profile.md** (N changes):
 ...
```

Present per-artifact approval options so the user can approve, skip, or edit each group independently.

---

## State Management

### state.yml

Machine-readable metadata for description mode learnings:

```yaml
last_run: "ISO-timestamp"
prs_reviewed: N
prs_modified: N
learnings:
  pr150-1:
    pr_number: 150
    pr_merged_at: "ISO-timestamp"
    date_learned: "YYYY-MM-DD"
    area: "app/services/blog"
    content: "The learning text"
    status: pending  # pending | incorporated | dropped
    incorporated_by_pr: null
    incorporated_at: null
```

Status lifecycle: `pending` -> `incorporated` -> `dropped`.

### learnings.md

Human-readable append-only log, grouped by date:

```markdown
## YYYY-MM-DD

- PR #XXX (area): Learning description.
- PR #XXX (area): Accepted without changes. [Brief note.]
```

### Retention

A learning is dropped when BOTH conditions are met:
1. `status: incorporated` AND the incorporating PR is merged
2. `pr_merged_at` is 40+ days ago

This prevents the state file from growing unbounded while keeping recent learnings available for cross-referencing.

---

## The Flywheel

```
  You write a PR description with craft-pr
          |
          v
  You edit it (add context, fix tone, restructure)
          |
          v
  review-retro detects the edits via feedback.sh
          |
          v
  Classifies what changed and why
          |
          v
  Proposes updates to skill files (with your approval)
          |
          v
  Next time craft-pr runs, it uses the improved files
          |
          v
  Fewer edits needed -> the cycle tightens
```

Each iteration makes the agent a little better at matching your standards. The human stays in the loop (approval gate), but the system does the grunt work of noticing patterns and proposing improvements.
