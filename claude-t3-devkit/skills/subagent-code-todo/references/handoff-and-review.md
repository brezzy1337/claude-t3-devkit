# Handoff and review reference

Detail for the two things this skill adds on top of the base skills: the **Slack-review gate** and
the **branch → `/ship` handoff**. Read this when authoring the command and the CLAUDE.md section.
For PR/review/merge/notify wiring (gh CLI, gates, state, Slack MCP vs webhook), see
`ship-workflow`'s `references/wiring.md` — don't duplicate it here.

## Contents
- The Slack-review gate (and its one honest constraint)
- The branch → `/ship` handoff contract
- Where state lives
- Relationship to `/ship`'s own gates
- Graceful degradation

## The Slack-review gate

The goal is "let me review the change on Slack before it goes anywhere." The reliable shape:

1. The central thread commits the work to the feature branch.
2. It runs `git diff` against the base, writes a short human summary (what changed, by area), and
   delegates to `slack-notifier` to post that summary + the branch name to the team thread.
3. It then **stops and waits for explicit approval in the terminal.**

**The honest constraint:** Claude Code cannot natively block a run until a Slack reply or reaction
arrives. So Slack is where you *read* the diff (on your phone or desktop), but you *approve back in
the session*. Don't wire the command to "wait for a Slack 👍" — that would require the
`slack-notifier` (or a hook) to poll the thread on a loop, which is fragile, burns tokens, and the
user explicitly chose the terminal-approval path. If a true approve-in-Slack flow is ever wanted,
it's a separate polling/automation design, not this gate.

Keep the Slack message short (summary + branch + "reply here / approve in terminal"); never paste
the full diff, file contents, or secrets — same rule as `slack-notifier` in `ship-workflow`.

## The branch → `/ship` handoff contract

`/code-todo` ends at an **approved branch**, not a PR. The handoff is one line: after approval, the
central thread invokes `/ship` on the current branch. From there `/ship` owns everything PR-shaped:
it drafts and opens the PR (its GATE 1), runs the multi-lens review panel and consolidates it,
gates on merge (its GATE 2), and posts PR notifications.

This is why `/code-todo` deliberately has **no** `git push`, `gh pr create`, or `gh pr merge` in
its `allowed-tools`: those tools belong to `/ship`, and leaving them out of `/code-todo` makes the
boundary structural rather than a matter of remembering. The contract `/ship` needs is simply:
a committed branch whose diff against the base is the change. Optionally pass `/ship` a one-line
summary as its argument (it accepts one); the diff itself is the source of truth.

## Where state lives

Don't keep pipeline state in the session — it dies with the context.
- **The branch** — the committed work and its commit message are the durable record of *what* the
  change is. An interrupted run re-reads the branch instead of re-implementing.
- **The Slack thread** — the running visibility record. (Once `/ship` takes over, it continues in
  its own thread per `ship-workflow`'s state rules — store the thread `ts` in the PR body there.)

## Relationship to `/ship`'s own gates

There are now two human checkpoints, and they are complementary, not redundant:
- **`/code-todo`'s Slack-review gate** reviews the *diff and approach before any PR exists* — it's
  a human sanity check on the implementation.
- **`/ship`'s open + merge gates** review the *opened PR* through the five-lens panel and gate the
  merge.

Reviewing twice at different altitudes is intentional. If the user finds it heavy for tiny
changes, the lighter lever is `/ship`'s existing "scale the panel to the diff" rule (skip lenses
for trivial diffs) — not removing the `/code-todo` gate, which is the human's first look.

## Graceful degradation

- **No Domain boundaries in CLAUDE.md.** The command can't route. Have it ask which paths the
  change touches, or tell the user to author the baseline section first with
  `subagent-orchestration`. Never invent globs — a confidently wrong glob is worse than asking.
- **`/ship` not installed.** The pipeline still runs; it just ends at the approved branch. The
  command should say "branch is ready to open a PR" rather than invoking a command that doesn't
  exist.
- **Slack not connected.** If `slack-notifier` isn't defined or the Slack MCP isn't connected, the
  review post can't go out. Fall back to showing the diff summary in the terminal for approval, and
  note that the Slack step needs `ship-workflow`'s `slack-notifier` + the Slack MCP to be set up.
