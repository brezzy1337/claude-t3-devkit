---
description: Author CLAUDE.md orchestration rules and .claude/agents specialists tailored to this repo
argument-hint: [optional notes on domains or ordering constraints]
allowed-tools: Read, Grep, Glob
---

# Subagent orchestration

Use the `subagent-orchestration` skill to set up delegation for this repo.

1. Inspect the repo first: map work areas to non-overlapping file globs (the parallel-split
   boundaries), find the real dependency chains (what must exist before what), read the stack and
   any existing CLAUDE.md, and record the dependency posture (lockfile, pinned vs floating,
   release-age cooldown, install scripts).
2. Write the CLAUDE.md orchestration section: routing rules, domain boundaries, dependency chains,
   background defaults, the four-part invocation protocol, guardrails, and a dependency-safety block.
3. If there are recurring specialist roles, add `.claude/agents/` definitions with least-privilege tools.

Treat $ARGUMENTS as extra context about domains or ordering constraints. Never invent file paths —
mark any glob you could not verify as a placeholder.
