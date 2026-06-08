# claude-t3-devkit

A Claude Code plugin that bundles three workflow skills for T3 / TypeScript monorepos, plus the
live agents, slash commands, and MCP server hooks they use.

> Rename note: to make this fully stack-agnostic, find/replace `claude-t3-devkit` with
> `claude-typescript-devkit` across `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`,
> and this README.

## What's inside

```
claude-t3-devkit/
├── .claude-plugin/
│   ├── plugin.json          # plugin manifest
│   └── marketplace.json     # marketplace catalog (self-references this plugin)
├── skills/                  # authoring guides (SKILL.md + assets + references)
│   ├── subagent-orchestration/
│   ├── subagent-code-todo/
│   └── ship-workflow/
├── agents/                  # live specialists
│   ├── architecture-reviewer.md   consistency-reviewer.md   factual-reviewer.md
│   ├── redundancy-checker.md      security-reviewer.md      pr-author.md
│   ├── slack-notifier.md          implementer.md            dependency-auditor.md
├── commands/                # /claude-t3-devkit:<name>
│   ├── subagent-orchestration.md
│   ├── code-todo.md
│   └── ship.md
├── hooks/hooks.json         # OPTIONAL Slack backstop on review completion
├── scripts/notify-slack.sh  # used by the optional hook (needs SLACK_WEBHOOK_URL)
└── .mcp.json                # Postgres / Slack / Notion MCP servers (fill in packages)
```

Skills are the authoring guides (they teach Claude how to generate CLAUDE.md and agents into a
target repo). The files in `agents/` and `commands/` are the live, ready-to-run versions. Both are
intentionally included: the skills let you regenerate/customize, the agents/commands work out of
the box.

## Install (team)

```
# 1. add this marketplace (once per machine)
/plugin marketplace add your-org/claude-t3-devkit

# 2. install the plugin
/plugin install claude-t3-devkit@claude-t3-devkit

# 3. companion plugins from the built-in official marketplace
/plugin install typescript-language-server@claude-plugins-official   # name may differ — see /plugin Discover
/plugin install github@claude-plugins-official
```

Commands are namespaced: `/claude-t3-devkit:ship`, `/claude-t3-devkit:code-todo`,
`/claude-t3-devkit:subagent-orchestration`. Run `/reload-plugins` after installing.

For zero-touch onboarding, install at **project scope** so it auto-loads for everyone on the repo
(adds to `.claude/settings.json`).

## Companion plugins (not bundled — and intentionally so)

The TypeScript LSP and GitHub plugins are Anthropic's, live in the built-in `claude-plugins-official`
marketplace, and should be installed from there (see step 3). For common languages the docs
recommend the official LSP plugins rather than custom ones. This plugin only bundles your own
skills/agents/commands plus MCP server references.

## MCP servers (.mcp.json)

`.mcp.json` ships with three server slots. Before use:

- Replace each `REPLACE_WITH_*_MCP_PACKAGE` with the actual MCP server you've chosen (or delete any
  server you don't want).
- Provide credentials via environment variables — each teammate supplies their own:
  - `DATABASE_URL` (Postgres / RDS)
  - `SLACK_BOT_TOKEN`, `SLACK_TEAM_ID` (so ship can post to #proj-wholesum)
  - `NOTION_TOKEN` (so workflows can read the Architecture / Development pages)

## Optional Slack hook

`hooks/hooks.json` fires a webhook after the `security-reviewer` finishes — a backstop for when the
agent chain is interrupted. It needs `SLACK_WEBHOOK_URL`. The `slack-notifier` agent (MCP) is the
primary notifier; delete the hook + script if you don't want the backstop.

## Publish

```
cd claude-t3-devkit
git init && git add -A && git commit -m "claude-t3-devkit: initial plugin"
git branch -M main
git remote add origin https://github.com/your-org/claude-t3-devkit.git
git push -u origin main
```

Then update the `repository`/`homepage` URLs in `plugin.json` to match.

## Validate before publishing

- `plugin.json` has `name` (lowercase-kebab), `version`, `description`.
- Only `plugin.json` lives in `.claude-plugin/`; `commands/`, `agents/`, `skills/`, `hooks/` are at root.
- Agent frontmatter is valid and names are unique; reviewers/auditors carry read-only tools only.
- Load locally first: `claude --plugin-dir ./claude-t3-devkit`, then `/reload-plugins`.
