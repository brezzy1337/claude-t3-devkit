---
name: subagent-code-todo
description: >-
  Author a Claude Code "/code-todo" workflow that implements a feature or change through
  domain-routed sub-agents, gates on a human Slack review of the diff, then hands the approved
  branch to the /ship pipeline. Use this skill whenever the user wants to set up or improve an
  implement-review-handoff pipeline for a Claude Code project: reading a change request, routing
  it to the right domain, dispatching implementer sub-agents with a full brief, posting the diff
  to Slack for approval, and handing off to /ship for PR/review/merge. It builds on the
  subagent-orchestration baseline (domain boundaries, invocation protocol, dependency safety) and
  the ship-workflow skill (slack-notifier, gh/gate/state wiring) — see those skills for the shared
  mechanics. Trigger it even when the user only describes the goal ("route my feature to the right
  subagent and ship it", "implement, let me review on Slack, then open a PR") without naming the
  command.
---

# Sub-agent code-todo

## The idea

This is the front half of shipping: take a change request, get it *implemented* by the right
specialist, let a human approve the diff, and hand a clean branch to `/ship`. It's the
`subagent-orchestration` chain (route → brief → run) aimed at implementation, with one human gate
(a Slack review) and a handoff at the end. The central thread owns the chain — sub-agents can't
spawn sub-agents — so it routes the work, briefs each agent completely, manages all git state,
and performs the handoff.

Author this **on top of** the two base skills; do not restate their rules here:

- From `subagent-orchestration`: the **Domain boundaries** (how a change maps to an agent), the
  **routing** decision (parallel/sequential), the four-part **invocation protocol**, and
  **dependency safety** (`dependency-auditor` + cooldown). This skill *applies* those; it doesn't
  redefine them.
- From `ship-workflow`: the `slack-notifier` agent and the gh / gate / state **wiring**. The PR,
  the multi-lens review panel, the merge gate, and PR notifications all belong to `/ship` — this
  skill stops at an approved branch and invokes `/ship`.

The deliverables are static files the user commits. Keep them concrete and tailored to the repo;
generic boilerplate barely helps, because the value is in naming *this* repo's real domains,
commands, and branch conventions.

## Boundary with /ship (read once, then design to it)

`/code-todo` and `/ship` are two halves that must not overlap:

| | `/code-todo` owns | `/ship` owns |
| --- | --- | --- |
| Work | read → route → implement → verify | PR → review panel → merge → notify |
| Git | branch + commits | push, `gh pr create`, `gh pr merge` |
| Human gate | Slack-review of the diff (approve in terminal) | open gate + merge gate |
| Ends at | an approved branch | a merged PR |

So `/code-todo` deliberately has **no** `git push` / `gh pr create` / `gh pr merge` in its tools —
those would double up with `/ship`. The two gates are complementary, not redundant: `/code-todo`
reviews the *diff and approach before any PR exists*; `/ship` reviews the *opened PR* through its
panel. Honor the same gate discipline in both.

## What you produce

1. **An entry point** — `.claude/commands/code-todo.md`, the slash command that runs the chain.
   Start from `assets/code-todo-command.md`. (Filename = command name; rename if the user wants a
   different handle.)
2. **One specialist agent** — `.claude/agents/implementer.md`, a code-writer that implements a
   single scoped slice and verifies it. Start from `assets/implementer.md`. Reuse
   `ship-workflow`'s `slack-notifier` for the review post — do **not** redefine it (a duplicate
   `name` in one scope is silently dropped).
3. **A CLAUDE.md "Feature implementation (/code-todo)" section** — records the chain, the gate,
   the handoff contract, and where state lives. Start from `assets/code-todo-claude-md.md`; append
   it below the baseline's "Sub-Agent Orchestration" section, which it depends on.

The review-gate mechanics, the branch→`/ship` handoff contract, and graceful-degradation cases
are in `references/handoff-and-review.md`.

## Step 1 — Inspect first (do not skip)

Same rule as the base skills: tailor to the real repo, never invent. Before generating, confirm:

- **Domain boundaries exist.** This skill *routes* using the baseline's Domain boundaries section
  in CLAUDE.md. If it's missing, install/author it first with `subagent-orchestration`, or have
  the command ask which paths a change touches — never guess globs.
- **Test and lint commands.** The implementer runs these to verify; put the real commands in the
  agent and command bodies, not a guess.
- **Branch convention.** What do feature branches look like (`feat/...`, `username/...`)? The
  command creates one; match the repo's style.
- **Is `/ship` installed?** The handoff invokes it. If it isn't present, the pipeline still works
  but ends at "approved branch" — say so rather than calling a command that doesn't exist.
- **Slack is reachable.** Is `slack-notifier` already defined (from `ship-workflow`) and the Slack
  MCP connected, and which channel/thread? If not, the review post needs that setup first.

If you can't read the repo, ask for these (or mark them as labelled placeholders).

## Step 2 — Author the entry point (`/code-todo`)

Start from `assets/code-todo-command.md`. Preserve these design choices:

- **The central thread owns git.** Implementers edit files only; the command creates the branch
  and is the only thing that commits. This avoids parallel-commit races and keeps the implementer
  at least privilege.
- **Route with the baseline, default safe.** One domain → one implementer; multiple
  non-overlapping domains → parallel; dependent domains → a sequential chain the command drives.
  When unsure, sequential (a wrong parallel split causes conflicts; a wrong sequence only costs
  time).
- **Brief completely.** Every implementer dispatch carries the four-part brief (context,
  instructions, exact file references, success criteria) plus the domain globs and the test/lint
  commands — a thin brief is the top cause of a bad sub-agent result.
- **Make the gate real.** After commit, post the diff to Slack via `slack-notifier`, then STOP for
  explicit terminal approval. Leave push/create/merge out of `allowed-tools` entirely — this
  command never opens a PR.
- **Stop on red.** A failed implementation, failed tests, or a `dependency-auditor` NO-GO halts
  the chain and reports; it never works around the failure.

## Step 3 — Author the `implementer` agent

Read the baseline's `references/agent-frontmatter.md` for the current schema first. Then keep the
template's shape:

- **Code-writer tools, nothing more** — `Read, Write, Edit, Bash, Glob, Grep`. No PR/push/merge
  tools; no `Agent` (it can't spawn sub-agents anyway).
- **Stay in lane.** Its prompt forbids editing outside the briefed domain globs; if the slice
  seems to need a cross-domain edit, it reports back rather than reaching across — that's a
  routing decision for the central thread.
- **Verify, don't commit.** It runs the repo's tests/lint and reports results, but never commits,
  pushes, or opens PRs (the central thread holds git state).
- **A fixed output contract** — what changed (by file), how it was verified (commands + result),
  and any blockers or assumptions, stated plainly. That shape is what lets the central thread
  assemble parallel slices and write the Slack summary mechanically.
- **No self-service dependencies.** If a slice needs a new package, it reports it so the central
  thread routes it through `dependency-auditor` — it never adds one on its own.

Pick the model to fit (`inherit`, or a lighter one via `CLAUDE_CODE_SUBAGENT_MODEL` for scoped
slices). Do not redefine `slack-notifier`; reuse the one from `ship-workflow`.

## Step 4 — Author the CLAUDE.md section

Use `assets/code-todo-claude-md.md`. It records the chain, marks the Slack-review as an
approval-required gate (with the honest note that approval returns in the terminal, the run does
not poll Slack), states the handoff contract (branch only; `/ship` opens the PR), and says where
state lives (the branch + the Slack thread) so an interrupted run resumes from the branch instead
of restarting. Append it below the baseline section it relies on; match the file's tone.

## Step 5 — The handoff and the review gate

See `references/handoff-and-review.md` for the detail: how the Slack-review gate works and its one
honest constraint, the exact branch→`/ship` contract, where state lives, and how to degrade
gracefully when the baseline domains or `/ship` aren't present.

## Step 6 — Verify

- **No PR/push/merge tools** in the command or the implementer — the handoff boundary is enforced,
  not just described.
- **Least privilege** — the implementer can't push, commit, or open PRs; it edits and verifies
  only.
- **Routing references the baseline** — the command reads Domain boundaries from CLAUDE.md rather
  than hard-coding globs, and falls back to asking when they're absent.
- **No duplicate agents** — `slack-notifier` is reused, not redefined; `implementer` is a new,
  unique `name`.
- **Valid frontmatter** — command fields (`description`, `argument-hint`, `allowed-tools`) and
  agent fields (`name`, `description`, `tools`) present and correct; `Agent(...)` not legacy
  `Task(...)` if you reference spawn/permission rules.
- **Real values** — the test/lint commands, branch convention, and Slack channel are the repo's
  actual ones, not leftover placeholders.
- **Gate and stop-on-red are explicit** in the command body, and the dependency path goes through
  `dependency-auditor`.

## Grounding notes

- **The Slack review is visibility, not a remote control.** The run posts the diff to Slack and
  then waits for approval *in the terminal*. Don't claim it blocks on a Slack reply or reaction —
  that needs a polling/hook mechanism the user didn't ask for, and promising it would be wrong.
- **Routing rules are guidance the central thread reads, not a scheduler.** They steer delegation;
  the implementer's `description` is the strongest lever for automatic delegation.
- **The central thread owns the chain.** Sub-agents can't spawn sub-agents, so the implementer
  can't call `dependency-auditor` or `/ship` itself — the command does, between steps.
- **Recent Claude Code models over-spawn.** For a single-domain change, that's one implementer,
  not three. Keep the baseline's anti-over-parallelize guardrail.
- **Depends on its neighbors.** Without the baseline's Domain boundaries the command should ask
  rather than guess; without `/ship` the pipeline ends at an approved branch. State both plainly
  instead of failing silently.
- **Don't oversell.** This makes implementation a routed, reviewable step that hands a clean
  branch to shipping — not a hands-off auto-coder.
