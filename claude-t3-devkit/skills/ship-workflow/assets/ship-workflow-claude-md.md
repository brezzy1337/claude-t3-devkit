## Ship workflow

The `/ship` command runs a sequential pipeline on the current branch: preflight -> open PR ->
review -> merge -> notify. The central thread owns the chain (sub-agents cannot spawn sub-agents);
it runs each stage and passes output to the next.

Stages and ownership:
- **Preflight** — run tests + lint; if dependencies changed, delegate to `dependency-auditor`. A
  red preflight stops the pipeline.
- **Open PR** — `pr-author` drafts the title/body; **opening requires human approval** (push and
  `gh pr create` are not pre-authorized, so they prompt).
- **Review** — fan out to the read-only panel (`factual-reviewer`, `architecture-reviewer`,
  `security-reviewer`, `consistency-reviewer`, `redundancy-checker`) in parallel, scaled to the
  diff size. The central thread then consolidates the reports into one prioritized review and
  posts it to the PR.
- **Merge** — **merging requires human approval** (`gh pr merge` is not pre-authorized).
- **Notify** — `slack-notifier` posts each transition to one Slack thread via the Slack MCP.

Keep the review lenses distinct — one dimension each, no overlapping roles. Each reviewer returns
findings in the same shape (severity, file, issue, fix, verdict) so consolidation is mechanical.

State lives outside this session: the PR body holds the change summary and the consolidated
review; the Slack thread holds running status (store the thread timestamp in the PR body so a
later run resumes the same thread). If the pipeline is interrupted, re-run `/ship` — it reads the
PR and thread rather than starting over.

Gates are not optional. Never work around a red preflight, a blocking review, or a merge gate to
ship faster — surface it to a human with the reason.
