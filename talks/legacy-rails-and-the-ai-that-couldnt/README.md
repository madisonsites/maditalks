# Legacy Rails and the AI That Couldn't

Companion resources for my RubyConf 2026 talk.

**[View the slides (PDF)](slides/legacy-rails-and-the-ai-that-couldnt.pdf)**

## What's this about?

AI coding agents are impressive on greenfield projects and well-documented frameworks. Drop one into a legacy Rails monolith with a decade of conventions, implicit patterns, and institutional knowledge? It falls apart fast.

This talk is about what I learned trying to make AI agents actually useful in that environment -- not by waiting for better models, but by building the context layer myself: guidelines that teach the agent how we write code, skills that define multi-step workflows with human checkpoints, and a feedback loop that gets better over time.

## Who this is for

- Engineers working in legacy or large Rails codebases who want to use AI agents without fighting them
- Anyone curious about what it takes to go from "AI wrote some code" to "AI wrote code I'd actually ship"
- People who've tried AI coding tools and found them frustrating in real-world codebases

## What's included

### [Slides](slides/)

| File | Description |
|------|-------------|
| [legacy-rails-and-the-ai-that-couldnt.pdf](slides/legacy-rails-and-the-ai-that-couldnt.pdf) | 120-page slide deck |

### [Skills](skills/) (active workflows)

Skills are markdown files that define multi-step workflows an agent follows when invoked. They're opt-in -- you invoke them explicitly.

| File | Description |
|------|-------------|
| [craft-dev.md](skills/craft-dev.md) | TDD workflow with a mandatory human review gate. Write failing tests, pause for approval, then implement. |
| [craft-pr.md](skills/craft-pr.md) | PR description generator that pulls context from tickets, related PRs, and the dev session. Embeds a checksum for the feedback loop. |
| [review-retro.md](skills/review-retro.md) | Self-improvement loop: compare what the agent drafted vs. what you actually posted, classify the differences, propose updates to skill files. |

### [Guidelines](guidelines/) (coding conventions)

Guidelines are markdown files that define coding conventions. Agents read them before writing code, the same way a new team member would read your team's docs.

| File | Description |
|------|-------------|
| [testing-guidelines.md](guidelines/testing-guidelines.md) | ~900 lines of RSpec conventions with Good/Bad pairs. Stubbing, factories, parameterization, assertions. Includes a Section Index for selective loading. |
| [service-guidelines.md](guidelines/service-guidelines.md) | Callable pattern, command extraction, callbacks vs. explicit orchestration, hash parameter handling. |
| [contributing-to-guidelines.md](guidelines/contributing-to-guidelines.md) | Meta-guidelines for writing guidelines: non-domain examples, integration over addition, section index maintenance. |
| [pr-review-voice-checklist.md](guidelines/pr-review-voice-checklist.md) | Template showing how specific you need to get with AI about communication style. Fill in your own voice preferences. |

### [Scripts](scripts/) (shell helpers)

Shell scripts that return structured JSON for agent consumption. Progress goes to stderr, data goes to stdout.

| File | Description |
|------|-------------|
| [diff-summary.sh](scripts/diff-summary.sh) | Rails-aware diff categorizer. Groups changes by file type (specs, models, services, etc.). |
| [feedback.sh](scripts/feedback.sh) | Fetches merged PRs with agent-generated checksums and their full edit history via GitHub's GraphQL API. Powers the self-improvement flywheel. Supports `--config` for reading org values from a YAML file. |
| [git-context.sh](scripts/git-context.sh) | Gathers branch context in a single call: branch name, ticket ID, commits, changed files, diff stats, existing PR. |
| [related-prs.sh](scripts/related-prs.sh) | Finds recently merged PRs that touched the same directories as your current branch. Used for building test plans on prior work. |

### [Examples](examples/)

| File | Description |
|------|-------------|
| [config.yml](examples/config.yml) | Centralized config template. All skills read this for org-specific values instead of hardcoding paths, URLs, or credentials. |

## Getting started

These files assume you're using an AI coding agent that can read markdown files (Cursor, Claude Code, Windsurf, etc.).

1. **Copy `examples/config.yml`** to wherever your agent reads config and fill in your org's values
2. **Start with one guideline.** Drop `testing-guidelines.md` or `service-guidelines.md` into your agent's rules/context directory. See how it affects the code your agent writes before adding more.
3. **Try a skill.** Copy `craft-dev.md` into your agent's skills directory and invoke it explicitly (e.g., `/craft-dev` in Cursor). The mandatory pause at Step 4 is the whole point -- don't skip it.
4. **Edit the guidelines when the agent gets something wrong.** That's the whole point. Every correction is a chance to update a guideline so the mistake doesn't happen again.
5. **Set up the feedback loop (optional).** The scripts, `craft-pr`, and `review-retro` form a self-improvement cycle. This is the most advanced piece -- get comfortable with guidelines and skills first.

### Prerequisites

- An AI coding agent that reads markdown (the guidelines are agent-agnostic; the skills use [Cursor-style YAML frontmatter](https://docs.cursor.com/context/skills) but the workflows they describe are portable)
- A Ruby/Rails codebase for the testing and service guidelines (the patterns apply broadly, but the examples are Rails-specific)
- [GitHub CLI (`gh`)](https://cli.github.com/) for the shell scripts
- [`jq`](https://jqlang.github.io/jq/) for JSON processing in the scripts
- `python3` with `PyYAML` for config file support in `feedback.sh`

### A note on safety

These resources help AI agents write better code, but they don't make the agent infallible. Please:

- **Review every command** before running it. The scripts make API calls and Git operations.
- **Don't blindly ship AI-generated code.** The human gate in `craft-dev` exists for a reason.
- **Start small.** One guideline, one skill. See how it changes your workflow before adopting everything.
- **Treat the agent's output as a first draft**, not a finished product. The feedback loop exists because first drafts always need editing.

### Agent-specific notes

- **Skills** use Cursor-style YAML frontmatter (`name`, `description`). If your agent doesn't support frontmatter, the markdown content still works -- the frontmatter is just metadata.
- **Guidelines** are plain markdown with no agent-specific syntax. They work with any agent that reads context files.
- **Section Indexes** (the HTML comments at the top of large guideline files) are designed for agents that support `offset`/`limit` file reading. If yours doesn't, the agent just reads the whole file -- it still works, it's just less efficient.

## Presented at

| Event | Date | Location |
|-------|------|----------|
| RubyConf 2026 | July 16 | Red Rocks Casino Resort in Las Vegas, NV (Breakout 1 - Red Rock A&D) |

**Video:** Coming soon.

## About these resources

These are adapted and generalized examples based on patterns I use in production. All examples use a blog platform domain (posts, authors, comments, tags) so nothing maps to any real codebase. The patterns, structure, and philosophy are real -- only the domain has been swapped.

The "leave it better than you found it" philosophy applies to the guidelines themselves. Every time you correct the agent, consider whether the correction belongs in a guideline so it doesn't happen again.

## License

- **Code, scripts, skills, guidelines, and config examples** are under the [MIT License](../../LICENSE).
- **Slides and original prose** are under [CC BY 4.0](../../LICENSE-CONTENT.md).
- **Third-party content** (screenshots, logos, trademarks) remains property of its respective owners. See [NOTICE.md](../../NOTICE.md).
