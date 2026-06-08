# `.claude/agents/` frontmatter reference

Read this before writing any agent file. It is the current Claude Code schema. Use it to keep
generated agent files valid — don't rely on memory or copy stale syntax from blog posts.

## Contents
- File format and location
- Required and optional frontmatter fields
- The `model` field
- Tool access (`tools` / `disallowedTools`)
- Naming: `Agent(...)` vs the legacy `Task(...)`
- Behavior facts that affect config
- Example agents

## File format and location

A sub-agent is a Markdown file: YAML frontmatter on top, then a body that becomes the agent's
**system prompt**. The agent receives only that system prompt plus basic environment details —
not the full Claude Code system prompt.

| Location | Scope | Priority | Notes |
| --- | --- | --- | --- |
| `.claude/agents/` | This project | Higher | Commit these; they're shared with the team |
| `~/.claude/agents/` | All your projects | Lower | Personal, cross-project |

Both directories are scanned recursively, so subfolders (`agents/review/`) are fine. Identity
comes only from the `name` field, not the path. Names must be unique within a scope — a
duplicate name is kept-one-discarded-other **without warning**. Edits to files on disk load at
session start; restart the session (or use `/agents`) to pick up changes.

## Frontmatter fields

Only `name` and `description` are required.

| Field | Required | Purpose |
| --- | --- | --- |
| `name` | Yes | Unique id, lowercase letters and hyphens |
| `description` | Yes | When Claude should delegate here — the primary auto-delegation signal |
| `tools` | No | Allowlist of tools. Inherits all if omitted |
| `disallowedTools` | No | Denylist, removed from the inherited/allowed set |
| `model` | No | `sonnet` / `opus` / `haiku` / full id (e.g. `claude-opus-4-8`) / `inherit`. Defaults to `inherit` |
| `permissionMode` | No | `default`, `acceptEdits`, `auto`, `dontAsk`, `bypassPermissions`, or `plan` |
| `maxTurns` | No | Max agentic turns before the agent stops |
| `skills` | No | Skills to preload into the agent's context at startup |
| `mcpServers` | No | MCP servers scoped to this agent (inline def or name reference) |
| `hooks` | No | Lifecycle hooks scoped to this agent |
| `memory` | No | `user`, `project`, or `local` — persistent cross-session memory dir |
| `background` | No | `true` to always run as a background task. Default `false` |
| `effort` | No | `low`/`medium`/`high`/`xhigh`/`max`; overrides session effort |
| `isolation` | No | `worktree` to run in an isolated git worktree copy |
| `color` | No | UI color: red, blue, green, yellow, purple, orange, pink, cyan |

For most config-authoring work you only need `name`, `description`, `tools`, and `model`. Reach
for the rest when the user has a specific need (e.g. `memory` for an agent that should accumulate
codebase knowledge, `isolation: worktree` for risky edits, `permissionMode` for automation).

## The `model` field

- Aliases: `sonnet`, `opus`, `haiku`.
- Full ids also accepted (e.g. `claude-opus-4-8`, `claude-sonnet-4-6`). Aliases age better than
  pinned ids — prefer them unless the user wants a specific version.
- `inherit` (the default) uses the main session's model.
- Resolution order at invocation: `CLAUDE_CODE_SUBAGENT_MODEL` env var → per-invocation model →
  the agent's `model` field → the main conversation's model.

A common cost pattern: main session on Opus, sub-agents on Sonnet (or Haiku for read-only
search), set globally via `CLAUDE_CODE_SUBAGENT_MODEL` and overridden per-agent as needed.

## Tool access

Restrict with either an allowlist or a denylist:

```yaml
# Allowlist — agent gets ONLY these, nothing else (no Edit/Write, no MCP)
tools: Read, Grep, Glob, Bash
```

```yaml
# Denylist — inherit everything EXCEPT these
disallowedTools: Write, Edit
```

If both are set, `disallowedTools` applies first, then `tools` resolves against what remains; a
tool in both is removed. Least-privilege defaults by role:

- Reviewers / auditors (read-only): `Read, Grep, Glob`
- Researchers: `Read, Grep, Glob, WebFetch, WebSearch`
- Code writers / fixers: `Read, Write, Edit, Bash, Glob, Grep`

Some UI/session tools are never available to sub-agents even if listed (e.g. `AskUserQuestion`,
`Agent`) — sub-agents can't ask the user questions or spawn further sub-agents.

## Naming: `Agent(...)` vs legacy `Task(...)`

The Task tool was renamed **Agent** (v2.1.63). `Task(...)` still works as an alias, but write the
current form in new config:

```json
{ "permissions": { "deny": ["Agent(Explore)", "Agent(my-custom-agent)"] } }
```

To restrict which agents a main-thread agent may spawn, use `Agent(name)` in its `tools` field
(e.g. `tools: Agent(worker, researcher), Read, Bash`). This only applies to an agent running as
the main thread via `--agent`; ordinary sub-agents can't spawn sub-agents, so it's a no-op there.

## Behavior facts that affect config

- **Sub-agents can't spawn sub-agents.** Sequential chains are driven from the main session.
- **Custom sub-agents inherit CLAUDE.md** (and the memory hierarchy); only built-in Explore and
  Plan skip it. So routing rules in CLAUDE.md reach custom agents too.
- **Built-ins:** Explore (Haiku, read-only search), Plan (read-only, plan mode), general-purpose
  (all tools). You don't redefine these — you route around or restrict them.
- **`description` drives auto-delegation.** Make it specific; add "use proactively" to encourage
  delegation where that's wanted.

## Example agents

Read-only reviewer:

```markdown
---
name: code-reviewer
description: Expert code review specialist. Use proactively right after writing or changing code.
tools: Read, Grep, Glob, Bash
model: inherit
---

You are a senior code reviewer. When invoked:
1. Run `git diff` to see recent changes and focus on modified files.
2. Check readability, naming, duplication, error handling, exposed secrets, input validation,
   and test coverage.
3. Report findings grouped as Critical / Warnings / Suggestions, each with a concrete fix.
```

Scoped researcher on a lighter model:

```markdown
---
name: dependency-researcher
description: Researches library/API options and version constraints. Use for docs lookups so results stay out of the main context.
tools: Read, Grep, Glob, WebFetch, WebSearch
model: haiku
---

You research and summarize. Do not edit files. Return a short comparison with sources, version
constraints, and a recommendation tied to this repo's stack.
```
