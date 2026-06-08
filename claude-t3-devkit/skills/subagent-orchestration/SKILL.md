---
name: subagent-orchestration
description: >-
  Author Claude Code orchestration configuration — the CLAUDE.md sub-agent routing rules and
  .claude/agents/ specialist definitions that teach a project's main session how to delegate.
  Use this skill whenever the user wants to set up, configure, audit, or improve how their
  Claude Code project uses sub-agents: writing or fixing CLAUDE.md routing rules, deciding when
  work should run in parallel vs sequentially vs in the background, defining persistent
  specialist agents, restricting agent tools or permissions, cutting token cost by routing
  sub-agents to lighter models, or fixing over- or under-parallelization and vague sub-agent
  invocations. Trigger it even when the user only describes the symptom ("my Claude Code spawns
  agents that step on each other", "how do I make my main session delegate better", "set up
  agents for my repo") without naming CLAUDE.md or .claude/agents explicitly.
---

# Sub-Agent Orchestration

## The idea

Claude Code isn't one AI — it's an orchestration system. The main session is a *central
thread* that mostly coordinates: it routes work to specialist sub-agents and stitches their
results back together. The quality of the output is bounded by two things the central thread
controls — **how it routes work** (parallel, sequential, or background) and **how completely it
briefs each sub-agent**. This skill produces the configuration that teaches a specific repo's
central thread to do both well.

You are authoring config, not running agents. The deliverables are static files the user
commits to their repo. Make them concrete and tailored — generic boilerplate barely moves the
needle, because the whole point of routing rules is that they encode *this* repo's real domain
boundaries and dependencies.

## What you produce

1. **A CLAUDE.md orchestration section** — routing rules, this repo's domain splits and
   dependency chains, background defaults, an invocation protocol, guardrails, and a dependency-
   safety policy (release-age cooldown + verify-before-add). This is the spine; produce it in
   almost every case. Start from `assets/orchestration-claude-md.md`.
2. **`.claude/agents/` specialist definitions** (optional) — persistent, focused agents with
   least-privilege tools, when the repo has clear recurring specialist roles (reviewer, test
   runner, migration writer) or the user asks. Schema lives in `references/agent-frontmatter.md`
   — read it before writing any agent file so the frontmatter is valid and current.

Decide between them from context: if the user just wants smarter delegation, the CLAUDE.md
section alone is often enough. Add agent files when there are repeatable roles worth naming.

## Step 1 — Inspect before you generate (do not skip)

Routing rules are only as good as the boundaries they name. A rule that says "frontend agent
owns the frontend" is useless unless it points at the actual directories, and a parallel split
is *unsafe* if two named domains secretly share a file. So learn the repo first:

- **Find the real domains.** Look at the directory layout and map work areas to file globs
  (e.g. `src/api/**`, `prisma/**`, `infra/**`). These become the parallel-split boundaries.
  Confirm the globs don't intersect — overlapping globs mean that work is sequential, not
  parallel.
- **Find the real dependency chains.** What must exist before what? Schema before the API that
  serves it; types before the code that imports them; a migration before the query that uses
  the new column. These become the sequential ordering rules.
- **Read the stack and existing CLAUDE.md.** Match the language and tone of any existing
  CLAUDE.md and append to it rather than duplicating. Note the test command, lint command, and
  conventions so agent definitions can reference them.
- **Scan the dependency surface.** Recent supply-chain attacks make this part of inspection, not
  an afterthought. Identify the package manager(s) and ecosystem, then read the manifest and
  lockfile and record the current posture: Is a lockfile committed? Are versions pinned or
  floating (`^`/`~`)? Is a release-age cooldown configured (pnpm `minimumReleaseAge`, Yarn
  `npmMinimalAgeGate`, Bun `minimumReleaseAge`, npm `min-release-age`, or Renovate/Dependabot
  cooldown)? Are install/lifecycle scripts allowed to run? This posture is what the dependency-
  safety rules in Step 2 either codify or fix. See `references/dependency-safety.md` for the
  per-ecosystem settings and what each check defends against.

If you have no repo access (e.g. on Claude.ai with nothing uploaded), ask the user for the
directory layout, stack, and the one or two ordering constraints that bite them most — or work
from what they describe and clearly mark every placeholder you couldn't verify. Never invent
file paths; a confidently wrong glob is worse than a labelled placeholder.

## Step 2 — Write the CLAUDE.md orchestration section

Copy the structure from `assets/orchestration-claude-md.md` and replace every `TAILOR` marker
with this repo's specifics. Keep these blocks:

- **Routing rules** — the parallel / sequential / background decision. Keep the conservative
  default (when unsure, sequential): a wrong parallel split causes merge conflicts, while a
  wrong sequential choice only costs some time.
- **Domain boundaries** — the repo's real domains, each with non-overlapping file globs.
- **Dependency chains** — the repo's real "X before Y" orderings. Note that the central thread
  owns the chain, because **sub-agents cannot spawn sub-agents** — each step runs from the main
  session, which hands the relevant output to the next.
- **Background defaults** — research/analysis/audits that shouldn't block.
- **Invocation protocol** — the four parts every dispatch must carry (context, instructions,
  file references, success criteria). This is where most setups stop, and it's the highest-
  leverage block: a sub-agent has a fresh context window and can't ask clarifying questions, so
  a thin brief is the single most common cause of a bad result. Include the weak-vs-strong
  example so the central thread has a pattern to imitate.
- **Guardrails** — against over-parallelizing (coordination + token overhead) and
  under-parallelizing (wasted wall-clock time), plus a pointer to model routing
  (`CLAUDE_CODE_SUBAGENT_MODEL`) so focused sub-agent work runs on a lighter, cheaper model
  while the central thread reasons on a stronger one.
- **Dependency safety** — the policy the central thread follows before it pulls or bumps any
  package. This matters doubly for an AI orchestrator, because the agent is often the one
  *proposing* the package — and an agent can confidently name a package that doesn't exist, which
  is exactly what slopsquatting attackers register. The block tells the central thread to
  verify-before-add, respect a release-age cooldown (the user's "at least a week old" rule), and
  defer to the repo's tooling-enforced policy. Use the ready-made block in the asset and fill in
  the repo's package manager; the per-ecosystem config and rationale live in
  `references/dependency-safety.md`.

## Step 3 — Define specialist agents (when warranted)

Read `references/agent-frontmatter.md` first. Then, for each recurring role:

- Give it a **sharp `description`** — Claude decides when to auto-delegate primarily from this
  field, so it matters more than it looks. Say what the agent is *for* and, where appropriate,
  add "use proactively" to encourage delegation.
- Grant **least-privilege tools.** A reviewer or auditor gets read-only tools (`Read, Grep,
  Glob`) and no `Edit`/`Write`; a fixer needs `Edit`; a researcher gets `WebFetch, WebSearch`.
  Narrow tools keep the agent focused and cheaper.
- Pick a **model** to fit: lighter (`haiku`/`sonnet`) for scoped or read-only work, `inherit`
  when it should match the main session.
- Write a **focused system prompt** in the body: when invoked, what to do, what to check, how to
  format the result. One job per agent.

A `dependency-auditor` is a strong default specialist when dependency safety matters: a read-only
agent the central thread delegates "should we add or bump X?" to, which checks release age,
existence/canonicalness, advisories, and provenance, then returns a go/no-go. A ready-to-use
definition is in `references/dependency-safety.md`.

## Step 4 — Verify

- **Valid YAML frontmatter**, with `name` (lowercase + hyphens) and `description` present.
- **Current naming.** Use `Agent(name)` for permission/spawn rules (the old `Task(name)` still
  works as an alias, but write the current form). Don't reproduce a blog's stale `Task(...)`
  syntax verbatim.
- **Unique agent names** across the tree — a duplicate name in one scope is silently discarded.
- **No glob overlap** between any two domains marked parallel-safe.
- **Least privilege** held throughout — no agent carries `Write`/`Edit` it doesn't use.
- **Dependency settings are real and current.** The cooldown setting name and unit differ per
  ecosystem (see the reference); don't emit a pnpm setting into a Yarn repo, and verify the
  value's unit (minutes vs seconds vs days).

## Grounding notes (keep the config honest)

- CLAUDE.md routing rules are **guidance the central thread reads**, not a hard scheduler. They
  steer delegation; they don't enforce it. Pair them with sharp agent `description` fields,
  which are the strongest lever for *automatic* delegation.
- Custom sub-agents **do** inherit CLAUDE.md (only the built-in Explore and Plan agents skip
  it), so routing rules placed there reach both the orchestrator and custom agents. A rule that
  must reach Explore/Plan has to be restated in the delegation prompt.
- Recent Claude Code models tend to **over-spawn** sub-agents. The guardrails earned their place
  — don't drop them.
- **Dependency rules in CLAUDE.md are a behavioral backstop, not the enforcement layer.** The
  durable protection is the tooling: a committed lockfile, a release-age cooldown set in the
  package manager or update bot, disabled install scripts, and a CI check. Always set those up
  too; the CLAUDE.md rule exists for the moments the agent acts outside that gate. And the agent
  should escalate to the human rather than silently disable a guard to ship faster.
- Don't oversell. Frame this as "rules that make delegation more deliberate," not "automatic
  perfect orchestration."
