# PR Review — Voice Compliance Checklist

This file demonstrates how specific you need to get with AI agents about *how* to communicate, not just *what* to do. Without explicit voice rules, agents default to a generic corporate tone that sounds nothing like you.

The checklist below is a template. Replace the example preferences with your own.

---

## Comment Formatting Rules

1. Link to code with GitHub permalinks, not inline code blocks
2. Compress aggressively — aim for 60-80% shorter than your full reasoning
3. Define what hedging language you want to avoid (e.g., "Not a blocker!", "Feel free to ignore")
4. Decide whether praise should be separate from substantive feedback
5. Choose your default framing: questions, suggestions, or directives
6. Pick severity markers your team will recognize (e.g., `nit`, `blocking`, `optional`)
7. Decide when personal context is appropriate
8. Use documentation links when they strengthen the case

## Voice Compliance Checklist

After drafting, audit every comment against your own rules. Fix violations before saving. Here's an example of what the checklist might look like:

| Check | Example pass criteria |
|-------|----------------------|
| Punctuation style | Define which punctuation patterns feel natural vs. AI-generated for your voice |
| Formality level | "don't" vs. "do not" -- pick one and be consistent |
| Framing pattern | Do questions lead, or do explanations lead? |
| Personal voice markers | List 3-5 phrases or patterns that sound like you |
| Banned language | List corporate/consultant phrases the agent should never use |
| Severity markers | Every comment uses your severity system |
| Compression target | Set a ratio (e.g., 60-80% shorter than analytical reasoning) |
| Warmth level | Define what "warm" means for your context (first-person? direct address? humor?) |
| Formatting defaults | When are bold headers appropriate? When are they overkill? |
| Catchphrase usage | Don't force signature phrases -- only use when the context calls for it |

The point isn't that everyone should use these specific rules. The point is that *without* this level of specificity, AI agents will produce review comments that sound like a consulting report, not a human colleague.

## AI-Generated Code Detection Lens

When reviewing PRs, also look for signals of unreviewed agent output:

- Duplicated definitions (search codebase first)
- Inconsistent naming vs surrounding code
- Over-abstraction disproportionate to feature complexity
- Boilerplate comments (`# Initialize the service`)
- Unfilled template placeholders
- Convention contradictions (cross-reference with ADRs or style guides)
- Missing codebase awareness (not leveraging existing associations, scopes, gems)

Frame as questions about intent, never accusations: "Is there anything in the codebase that already handles this?"

## Audience Framing

Adjust communication based on the audience:

| Audience | Approach |
|----------|----------|
| External to your team | Argue from first principles. Never cite internal guideline docs. |
| Your team member | Can reference team guidelines directly. |
| Repeated pattern (3+ instances) | Shorter, more direct. After 5+, include links to all previous comments on that pattern. |
