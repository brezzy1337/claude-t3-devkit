# Wiring reference

Detail for assembling the ship workflow. Read this when generating the slash command, the hook,
or the Slack glue. Verify command syntax against current `gh`, Claude Code, and Slack docs.

## Contents
- gh CLI patterns (default driver)
- Making the gates real
- Slack: agent path (default) vs webhook hook (backstop)
- Where state lives
- Slash-command frontmatter recap
- GitHub connector alternative

## gh CLI patterns

The default driver is the `gh` CLI inside Claude Code — no extra setup beyond `gh auth login`.

- Open: `gh pr create --base <base> --title "<title>" --body "<body>"`
- Post a review: `gh pr comment <number|url> --body "<consolidated review>"` (or `gh pr review`)
- Inspect: `gh pr view --json number,title,url,state,body`
- Merge: `gh pr merge <number|url> --squash` (style per repo)

Scope these in agent/command `allowed-tools` with patterns, e.g. `Bash(gh pr view:*)`. Note that
`gh pr create` and `gh pr merge` are deliberately left unscoped so they prompt — see gates below.

## Making the gates real

Two gates: open and merge. Enforce them with permissions, not just instructions.

- **Interactive use:** leave `git push`, `gh pr create`, and `gh pr merge` OUT of the command's
  `allowed-tools`. Claude Code then asks for permission when it reaches them — that prompt is the
  human gate. Everything read-only (status, diff, `gh pr view`) is pre-authorized so the pipeline
  flows up to each gate without nagging.
- **Headless / auto modes** (`--dangerously-skip-permissions`, CI): no prompt exists, so add
  explicit rules in `.claude/settings.json`:
  ```json
  { "permissions": { "ask": ["Bash(gh pr create:*)", "Bash(gh pr merge:*)", "Bash(git push:*)"] } }
  ```
  Or `deny` them outright in fully automated runs so a human must finish the step by hand.

## Slack: agent path vs webhook hook

**Default — agent path (MCP).** The command invokes `slack-notifier` at each transition; the agent
posts through the Slack MCP. Reliable because it's a defined command step, and it can thread:
the first post returns a thread timestamp, stored in the PR body, that later posts reply to.

**Backstop — webhook hook.** A `SubagentStop` hook can fire even if the chain is abandoned, but a
hook runs a shell command and **cannot call the Slack MCP**. So it posts via a Slack incoming
webhook. Example `.claude/scripts/notify-slack.sh`:
```bash
#!/usr/bin/env bash
# Requires SLACK_WEBHOOK_URL in the environment.
msg="${1:-ship update}"
curl -sf -X POST -H 'Content-type: application/json' \
  --data "{\"text\":\"$msg\"}" "$SLACK_WEBHOOK_URL" >/dev/null
```
`chmod +x` it and reference it from `subagentstop-slack-hook.json`. Use the backstop only when
guaranteed firing matters; otherwise the agent path alone is enough.

## Where state lives

Don't keep pipeline state in the session — it dies with the context.
- **PR body** — the change summary and the consolidated review. Re-runnable: read it back with
  `gh pr view --json body`.
- **Slack thread** — running status. Store the thread `ts` in the PR body (a trailing
  `<!-- slack-thread: <ts> -->` line works) so a later run replies in the same thread instead of
  opening a new one.

This is what lets an interrupted `/ship` resume: it reconstructs state from the PR and thread.

## Slash-command frontmatter recap

`.claude/commands/<name>.md`; filename is the command name. Optional frontmatter: `description`,
`argument-hint`, `allowed-tools`, `model`, `disable-model-invocation`. Body is the prompt;
`$ARGUMENTS` (or `$1`, `$2`) inject input, `@path` references a file, and `` !`cmd` `` runs a
command inline before the prompt (requires the matching `Bash(...)` in `allowed-tools`).

## GitHub connector alternative

A GitHub MCP/connector can replace `gh` if PR actions are needed from outside Claude Code (e.g.
kicking off a PR from a chat) or for richer GitHub queries. If used, swap the `Bash(gh ...)` tools
in `pr-author` and the command for the connector's tools, and apply the same gate idea: keep the
create/merge tools un-pre-authorized so they prompt. For an in-terminal workflow, `gh` is simpler
and the default recommendation.
