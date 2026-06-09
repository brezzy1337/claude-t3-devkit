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
│   ├── design-reviewer.md         design-foundations-reviewer.md   # UI-diff design lenses
├── commands/                # /claude-t3-devkit:<name>
│   ├── new-project.md        # scaffold a fresh T3 repo + wire the devkit
│   ├── add-to-project.md     # wire the devkit into an existing repo
│   ├── subagent-orchestration.md
│   ├── code-todo.md
│   └── ship.md
├── hooks/hooks.json         # OPTIONAL Slack backstop on review completion
├── scripts/notify-slack.sh  # used by the optional hook (needs SLACK_WEBHOOK_URL)
├── scripts/preview-shots.cjs # screenshot-harness template for the design lenses (copy into repo, edit ROUTES)
├── bootstrap.sh             # one-shot terminal scaffolder (create-t3-turbo + settings)
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

Commands are namespaced: `/claude-t3-devkit:new-project`, `/claude-t3-devkit:add-to-project`,
`/claude-t3-devkit:ship`, `/claude-t3-devkit:code-todo`, `/claude-t3-devkit:subagent-orchestration`.
Run `/reload-plugins` after installing.

For zero-touch onboarding, install at **project scope** so it auto-loads for everyone on the repo
(adds to `.claude/settings.json`).

## Project setup commands

Two commands bootstrap a repo onto the devkit — pick the one that matches your starting point:

| Command | Use it for | What it does |
|---------|-----------|--------------|
| `/claude-t3-devkit:new-project <name>` | a brand-new project | Scaffolds a `create-t3-turbo` monorepo (prefers pnpm › bun › npm), writes its `.claude/settings.json` so collaborators pick up this marketplace on folder-trust, then generates a tailored CLAUDE.md orchestration section + `.claude/agents/` specialists. |
| `/claude-t3-devkit:add-to-project` | a repo you already have | No scaffolding — enables the plugin in the current repo, inspects the real directory layout, and generates a CLAUDE.md orchestration section + agents that fit the existing code. |

Both adapt to the **actual** repo layout (never inventing file paths) and finish by pointing you at
the day-to-day workflow: `/claude-t3-devkit:code-todo` → `/claude-t3-devkit:ship`.

To scaffold from a plain terminal *before* the plugin is installed, the standalone `bootstrap.sh`
runs the same scaffold + settings step:

```
./bootstrap.sh <project-name> <marketplace-repo>   # e.g. ./bootstrap.sh my-app brezzy1337/claude-t3-devkit
```

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
