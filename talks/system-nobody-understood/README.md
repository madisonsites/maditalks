# The System Nobody Understood (including AI)

A talk from SF Ruby Conf 2026.

**[View the slides (PDF)](slides/system-nobody-understood.pdf)**

## What's this about?

A Rails system built on callbacks, background jobs, and shared state ends up with too many clocks, and nobody (human or AI) can say where the fire is. Asking an AI agent to find it doesn't work when there's no shared understanding of what *could* happen, what *did* happen, and what *should* happen.

This talk walks through how we got there and how we dug out: humans defining the line first, clearing 15,000 lines of dead code with agent-driven removal workflows, gathering evidence with structured logging, field notes, and Rails Event Store, and turning that evidence into options other teams could see and act on.

## Presented at

| Event | Date | Location |
|-------|------|----------|
| SF Ruby Conf 2026 | November 10 | San Francisco, CA |

**Video:** Not yet available.

## License

- **Slides and original prose** are under [CC BY 4.0](../../LICENSE-CONTENT.md).
- **Third-party content** (screenshots, logos, trademarks) remains property of its respective owners. See [NOTICE.md](../../NOTICE.md).
