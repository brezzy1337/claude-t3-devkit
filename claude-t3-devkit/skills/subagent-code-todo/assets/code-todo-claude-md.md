<!--
  Template: the "Feature implementation (/code-todo)" section for a project's CLAUDE.md.
  Append it BELOW the "Sub-Agent Orchestration" section — it relies on that section's Domain
  boundaries and invocation protocol. Replace every `TAILOR:` marker, then delete the markers.
  Match the file's existing tone.
-->

## Feature implementation (/code-todo)

`/code-todo` is the implement-and-review front end to shipping. It reuses this file's **Domain
boundaries** (to route a change to the right agent) and **invocation protocol** (to brief each
agent), and it ends by handing an approved branch to `/ship`. It does **not** open PRs, push, or
merge — that's `/ship`'s job.

The central thread owns the chain (sub-agents cannot spawn sub-agents):

1. **Read** the change request.
2. **Route** to domain(s) per Domain boundaries — one `implementer` per non-overlapping domain in
   parallel; dependent domains in sequence, each step's output handed to the next.
3. **Implement** via `implementer` sub-agent(s) with the full four-part brief. Route any new or
   bumped dependency through `dependency-auditor` first; stop on a NO-GO.
4. **Gate.** Commit to a feature branch, then post the diff summary to Slack via `slack-notifier`
   and wait for human approval **in the terminal**. Slack gives visibility into the diff; approval
   comes back in the session — the run does not poll Slack.
5. **Hand off.** On approval, invoke `/ship` on the branch.

**Boundaries that keep the two halves clean:**
- The gate is not optional. Do not open a PR, push, or hand off before approval.
- Implementers edit only their domain's globs. A slice that needs to cross a boundary is a routing
  decision for the central thread, not a widening the implementer does on its own.
- Only the central thread commits; implementers edit and verify.
- For a single-domain change, dispatch one implementer — don't over-spawn.

**State** lives on the branch (the work + commit message) and the Slack thread, not in the
session, so an interrupted run resumes from the branch.

<!-- TAILOR: name the repo's feature-branch convention (e.g. `feat/<slug>`) and the exact test/lint commands the implementer should run. -->
