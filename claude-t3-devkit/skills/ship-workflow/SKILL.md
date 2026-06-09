---
name: ship-workflow
description: >-
  Author a Claude Code "ship" pipeline that opens a pull request, runs code and security review
  via sub-agents, and posts Slack notifications — built on top of the subagent-orchestration
  baseline. Use this skill whenever the user wants to set up, configure, or improve an automated
  PR / review / notify workflow for a Claude Code project: a /ship (or /open-pr) slash command,
  specialist agents like pr-author, a multi-lens review panel (factual, architecture, security,
  consistency, redundancy), and slack-notifier,
  approval gates before opening or merging, Slack updates on PR events, or wiring these together
  with hooks and the gh CLI. Trigger it even when the user only describes the goal ("get my
  changes reviewed and tell the team on Slack", "automate opening PRs with a review step", "set
  up a ship command") without naming the pieces. For the routing rules, invocation protocol, and
  dependency safety this depends on, see the subagent-orchestration skill.
---

# Ship workflow

## The idea

This is the `subagent-orchestration` chain applied to shipping a change. The pipeline —
preflight → open PR → review → merge → notify — is just that skill's "Implement → Test → Review"
chain extended with PR creation at the front and Slack notification at the back. The central
thread owns it (sub-agents can't spawn sub-agents): it runs each stage and hands output to the
next. So author this on top of the baseline, don't restate the baseline's routing or invocation
rules here.

Design for two audiences. **Intuitive for the user:** one handle (`/ship`) starts the chain, and
two human gates (open, merge) keep them in control while Slack gives visibility. **Effective for
the model:** each stage is a focused agent with least-privilege tools and a clear input/output
contract, the glue is deterministic (permission gates and hooks, not remembered prose), and state
lives in durable places (the PR body and one Slack thread) so an interrupted run can resume.

## What you produce

1. **An entry point** — `.claude/commands/ship.md`, a slash command that runs the pipeline.
2. **Specialist agents** in `.claude/agents/` — a five-lens review panel (`factual-reviewer`,
   `architecture-reviewer`, `security-reviewer`, `consistency-reviewer`, `redundancy-checker`),
   two design lenses for UI diffs (`design-reviewer`, `design-foundations-reviewer`), plus the
   pipeline mechanics `pr-author` and `slack-notifier`. Reuse the baseline's
   `dependency-auditor` in preflight rather than duplicating it.
3. **A CLAUDE.md "Ship workflow" section** describing the chain, the gates, and where state lives.
4. **Optional** — a `SubagentStop` Slack hook as a notification backstop (see Step 5).

Templates for all of these are in `assets/`; the wiring detail (gh CLI, gates, Slack paths,
state) is in `references/wiring.md`.

## Step 1 — Inspect first

Same rule as the baseline: tailor to the real repo. Before generating, learn:

- **Git host & CLI.** Is `gh` available and authenticated? That's the default driver for PR
  create/review/merge. (A GitHub connector/MCP is the alternative — see the reference — worth it
  only if PR actions are needed from outside Claude Code.)
- **Test and lint commands.** The preflight stage runs these; put the real commands in the
  command body, not a guess.
- **Base branch.** What do PRs target (`main`, `develop`)? The command needs it for the diff and
  for `gh pr create --base`.
- **Slack destination.** Which channel/thread should updates go to, and is the Slack MCP
  connected? If not, note that the notifier (or the webhook backstop) needs setup.
- **Existing agents.** If the baseline is already installed, reuse `dependency-auditor` in
  preflight; the review panel is defined here. Don't duplicate a `name` that already exists in
  the same scope — duplicates are silently dropped.

If you can't read the repo, ask for these five things (or mark them as placeholders) — don't
invent a test command or base branch.

## Step 2 — Author the entry point (`/ship`)

Start from `assets/ship-command.md`. The key design choices to preserve:

- **Make the gates real via permissions, not prose.** List only read-only/inspection commands in
  `allowed-tools` (e.g. `Bash(git status:*)`, `Bash(git diff:*)`, `Bash(gh pr view:*)`).
  Deliberately leave `git push`, `gh pr create`, and `gh pr merge` *out* of `allowed-tools` so
  Claude Code prompts for permission at exactly those points — that prompt is the human gate.
- **Spell out the stages in order** with the gate language ("show me the draft and wait for my
  explicit yes before opening"). The command body is the chain definition the central thread
  follows.
- **Stop on red.** A failed preflight or a blocking review halts the pipeline and reports; it
  never works around the failure.

## Step 3 — Author the specialist agents

Read the baseline's `references/agent-frontmatter.md` for the schema first. Then design the
agents deliberately — a specialist earns its place by getting its *own* context. When one
session has to review correctness, security, and supply-chain risk at once, those concerns
compete for attention and you get shallow, generic feedback on all three; an isolated agent that
thinks about one dimension goes deep on it. That depth is the entire reason to split, so design
each agent as a single expert lens, not a second pair of hands.

Four design rules make the split pay off:

- **One non-overlapping dimension per agent.** The common failure is stacking near-duplicate
  roles ("security expert" + "pen tester" + "vuln scanner") that all surface the same findings
  and inflate cost. Give each agent a dimension no other agent owns, and make the boundaries
  explicit in its prompt so it stays in lane.
- **Match tools to the dimension's natural instruments — then trim to least privilege.** A
  security reviewer reaches for audit/scan tools; a code reviewer reaches for the diff and the
  test command; a notifier reaches for Slack. Grant exactly those and nothing that lets it edit
  code it's only meant to inspect.
- **Define an output contract.** Each reviewer returns findings in a fixed shape — severity
  (Critical / Warning / Note), file, the risk, and a concrete fix, plus a one-line
  blocking/non-blocking verdict. A consistent shape is what makes consolidation mechanical
  instead of a re-read.
- **Reserve the fan-out for substantive diffs.** A typo or one-line change doesn't need three
  reviewers; the coordination overhead outweighs the benefit. Gate the review fan-out on the
  change being non-trivial.

For the PR review gate, use the documentation's specialist-role panel — five complementary,
non-overlapping code-quality lenses, each persisted as its own agent (templates in `assets/`):

- **`factual-reviewer`** — technical accuracy: does the change do what the PR, linked issue, and
  docs claim, and does it contradict any documented contract?
- **`architecture-reviewer`** (the senior-engineer lens) — architecture decisions and patterns:
  boundaries, coupling, abstractions, error handling, testability.
- **`security-reviewer`** — vulnerabilities and attack vectors: injection, authn/authz changes,
  secrets, unsafe deserialization, SSRF, path traversal. May run audit/scan tools.
- **`consistency-reviewer`** — standards compliance: naming, structure, import order, and idioms
  drawn from the repo's own conventions and lint/format config.
- **`redundancy-checker`** — duplicate logic: copy-paste within the diff, and existing utilities
  the new code should reuse instead.

These are the documentation's "Code Quality Review" roles turned into persistent definitions, and
they map cleanly onto the four design rules above — one dimension each, natural tools, a shared
output contract, and fan-out reserved for substantive diffs. Keep **`dependency-auditor`** in
*preflight* rather than the review panel: supply-chain age and advisory checks belong before the
PR opens, not at review time.

For user-facing changes, add the **two design lenses** (templates in `assets/`), dispatched only
when the diff touches the frontend domain globs — keep them off the default code path:

- **`design-reviewer`** — holistic visual judgment on the *rendered* result: hierarchy & rhythm,
  layout/responsive integrity, contrast in context, motion, print fidelity, and brand feel. It
  judges screenshots, so the central thread generates them first with the repo's screenshot
  harness (a `scripts/preview-shots.cjs` template ships with this plugin) and passes the paths in
  the brief. Worth a stronger model — visual taste is the most judgment-heavy lens on the panel.
- **`design-foundations-reviewer`** — mechanical, token-precise compliance against the project's
  design rules file (e.g. `.claude/rules/design.md`): exact palette tokens, type faces/scale,
  spacing scale, icon/logo rules. If the project has no design rules file, author one — this lens
  has nothing to measure against without it, and the same file briefs the implementer at creation
  time so design quality goes in up front instead of arriving as review findings.

The split mirrors the code panel's one-dimension rule: taste and compliance compete for attention
when one agent holds both, and the mechanical lens stays cheap while the holistic one goes deep.

The two non-review agents are pipeline mechanics, not review lenses, so the panel doesn't replace
them — keep them just as focused: **`pr-author`** drafts the PR title/body from the diff
(read-only git, no push/merge), and **`slack-notifier`** posts status to Slack via the Slack MCP
(denied `Write`/`Edit`/`Bash` so it can't touch code or run commands).

Because these review lenses are independent and read-only, they're the textbook *safe parallel*
case from the baseline — run them concurrently, not in sequence, with edits disabled (least-
privilege tools already enforce this; plan mode is a belt-and-suspenders option) so a reviewer
can never "helpfully" rewrite the code it's judging.

### Consolidation is the central thread's job

A pile of three separate reports isn't a review — it's homework for the human. After the fan-out,
the central thread consolidates before anything reaches the PR: merge the findings, resolve
conflicts where two lenses disagree (e.g. a pattern the code reviewer likes that the security
reviewer flags), de-duplicate overlapping notes, rank everything by impact, and post one
prioritized action list with a single overall verdict. The reviewers produce signal; the central
thread turns it into a decision. Make this an explicit step of the Review stage, not an
afterthought — it's what makes the gate worth stopping at.

## Step 4 — Author the CLAUDE.md "Ship workflow" section

Use `assets/ship-workflow-claude-md.md`. It records the chain, marks both gates as
approval-required, names the review fan-out as parallel-then-consolidated (the reviewers run
concurrently; the central thread merges and ranks their findings before the PR), and states
where state lives (PR body + one Slack thread) so a re-run resumes instead of restarting. It also
reminds the central thread that gates are not optional.

## Step 5 — Wire the notifications

Default to the **agent path**: the command's last step in each transition invokes `slack-notifier`,
which posts via the Slack MCP and keeps everything in one thread (it returns the thread timestamp;
store it in the PR body so later updates reply in-thread). This is reliable because it's a defined
command step, not an ad-hoc afterthought.

Offer the **hook backstop** only if the user wants a notification to fire even when the chain is
interrupted: a `SubagentStop` hook (`assets/subagentstop-slack-hook.json`) running a small script.
Be honest about the constraint — **a hook runs a shell command and cannot call the Slack MCP** —
so the backstop posts through a Slack incoming webhook (`SLACK_WEBHOOK_URL`), not the MCP. Don't
claim a hook can invoke MCP tools.

## Step 6 — Verify

- **Gates are enforced, not just described** — `git push`, `gh pr create`, `gh pr merge` are
  absent from the command's `allowed-tools`.
- **Least privilege** — `slack-notifier` can't edit code; every reviewer is read-only with no
  `Write`/`Edit`.
- **Review lenses stay distinct** — no two panel agents cover the same dimension (the doc's
  "overlapping roles" mistake); each has a dimension the others don't, stated in its prompt.
- **Valid frontmatter** — command fields (`description`, `argument-hint`, `allowed-tools`) and
  agent fields (`name`, `description`) are present and correct.
- **Real values** — the test/lint commands, base branch, and Slack channel are the repo's
  actual ones, not placeholders left in.
- **No nested delegation** — the chain runs from the central thread; agents don't call agents.

## Grounding notes

- The gates rely on the permission prompt, so they only hold in interactive use (or with a
  matching `permissions` policy). In headless/auto modes, add explicit `permissions.deny` /
  `ask` rules for the push/create/merge commands, or the gate won't prompt.
- Notifications via the agent are model-driven; the webhook+hook backstop is the deterministic
  layer. Pick based on how much the user needs guaranteed firing.
- Reuse the baseline agents rather than redefining them — duplicate `name`s in one scope are
  silently dropped.
- Don't oversell. This makes shipping a deliberate, visible pipeline with human control — not a
  hands-off auto-merge bot.
