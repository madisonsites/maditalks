---
name: craft-dev
description: >-
  Test-first development workflow with mandatory human review gate.
  Use when implementing features, fixing bugs, or making any code changes.
  Enforces TDD with explicit human approval before implementation.
---

# TDD Development Skill

**Test-Driven Development with a mandatory human review gate.**
Agents **must** obtain explicit human approval of tests **before** any implementation.

---

## When to Use This Skill

Use this skill when:
- Implementing any feature, fix, or refactor
- Transitioning from investigation to writing code
- Writing tests or making code changes of any kind

**This skill is opt-in.** Invoke it explicitly (e.g., `/craft-dev`). It is not auto-applied — this avoids forcing TDD on the entire org.

---

## Dynamic Guideline Loading

Load guidelines **only as needed** — never all at once. Use section-level loading for large files:

1. **Read the first 30 lines** of the guideline file to see its Section Index (an HTML comment listing sections with line ranges and keywords)
2. **Load only the sections relevant** to the current task using `offset`/`limit`
3. **Load the full file** only when the task spans most sections or the file is under 300 lines

| File | When to Load | Purpose |
|------|-------------|---------|
| `testing-guidelines.md` | **Always when writing tests** | RSpec patterns, factories, stubbing rules |
| `service-guidelines.md` | Service objects | Callable pattern, command extraction |
| Additional guideline files | As needed per domain | Controllers, views, frontend, etc. |

Post a **Loaded-Files ACK** after every guideline load:

```
ACK:
- Loaded: testing-guidelines.md (sections: Stubbing, Factory Creation)
- Next to load: service-guidelines.md (implementing a new command)
```

---

## Mandatory TDD Workflow

### 0. Plan the Commit Sequence

Before writing any tests, plan the work as a sequence of atomic commits. Each commit is a step in the plan.

Present a **simple numbered list of tasks** in plain language:

```
1. Add feature flag for new functionality
2. Add service with permission gating
3. Add index view with placeholder content
4. Add navigation tab to settings page
```

**STOP and wait for the user to confirm or adjust the plan.** Do not proceed to Step 1 or make any file changes until explicitly approved.

### 1. Load Guidelines

- Load `testing-guidelines.md` when writing tests.
- Load additional files as needed per the table above.
- Post a **Loaded-Files ACK**.

### 2. Write Failing Tests (No Implementation)

- Work in `spec/**` only. Mirror the `app/` directory structure.
- **Unexpected green?** Strengthen expectations until red.

### 3. Verify Red

- Run tests and show failing examples (trim noise).
- If tests can't run due to environment issues, try common fixes (bundle install, database check) before giving up.

### 4. Mandatory Pause (Human Gate)

Present the **Test-Only Review Package**:
- Command used (or would use) to verify red + why it fails
- RSpec outline (bulleted `describe` / `context` / `it`)

Follow with a **reflective challenge prompt**: a genuine question about the tests that invites the reviewer to think critically. Vary the tone and phrasing each time.

Then present structured response options:
- **shipit** — tests look good, proceed to implementation
- 1-2 context-specific options (e.g., "Add concurrency tests", "Improve test names")
- **Something else** — reviewer has different feedback

**Do not edit non-test files until the reviewer selects "shipit".**

### 5. Address Feedback

If the reviewer selects a non-shipit option, act on it and return to Step 4.

### 6. Implement Minimally

After approval, implement the smallest change to pass tests.

### 7. Green, Refactor, Lint

- Refactor while green, fix lints, keep changes atomic.
- Run linting on all changed files before presenting the commit.

### 8. Atomic Commits

Every commit must be **independently green** (all tests pass) and **independently revertable**.

Core rule: **spec files ship with their implementation** in the same commit.

| File type | Commit strategy |
|-----------|----------------|
| Implementation + its spec | Always together in one commit |
| Config with no dedicated test | Separate commit, ordered before the spec+impl commit |
| UI integration with no test | Separate commit, can come after |

Present the changed files and commit message, then offer to commit.

### 9. Next Cycle or Wrap Up

- If the task breakdown has remaining pieces, loop back to Step 1.
- If all cycles are complete, surface any unrelated issues noticed during the work.

### 10. Offer PR Creation

Once all work is done, ask if the user wants a draft PR.

If yes, invoke `craft-pr` to generate the PR description. For long sessions (3+ TDD cycles), launch a fresh sub-agent with a **Development Context Brief** — a distillation of decisions, trade-offs, and testing insights from the session — so the PR description captures context the diff alone can't convey.

---

## Conversation Checkpoints

| Before Action | Ask Yourself |
|---------------|-------------|
| Proposing changes | "Am I under TDD with review gate?" |
| Writing plans | "Did I load testing guidelines + ACK?" |
| Writing tests | "Will I pause for review + request shipit?" |
| Modifying code | "Did I receive shipit before implementing?" |
