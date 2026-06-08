---
description: Wire the claude-t3-devkit into an existing repo — enable the plugin, then generate tailored CLAUDE.md orchestration + agents (no scaffolding)
argument-hint: [optional notes on domains or ordering constraints]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(git rev-parse:*), Bash(git branch:*), Bash(git status:*), Bash(ls:*)
---

# Add to project

Onboard the **current existing repository** to the claude-t3-devkit so its orchestration, code-todo,
and ship workflows are available here. Do NOT scaffold anything — adapt to what already exists. Treat
$ARGUMENTS as extra context about domains or ordering constraints.

Context (gathered for you):
- Repo root: !`git rev-parse --show-toplevel 2>/dev/null || echo "not a git repo"`
- Branch: !`git branch --show-current`
- Top-level layout: !`ls -1`

1. **Verify the repo.** Confirm this is the existing project you want wired. If it isn't a git repo,
   stop and tell me — this command adds to existing projects; use `/claude-t3-devkit:new-project` to
   scaffold a fresh one.

2. **Enable the plugin here.** Write or MERGE into `.claude/settings.json` so this repo (and
   collaborators on folder-trust) get the marketplace + plugin. Preserve any existing keys — merge,
   don't overwrite:
   ```json
   {
     "extraKnownMarketplaces": {
       "claude-t3-devkit": { "source": { "source": "github", "repo": "brezzy1337/claude-t3-devkit" } }
     },
     "enabledPlugins": ["claude-t3-devkit@claude-t3-devkit"]
   }
   ```

3. **Inspect before generating.** Map the real directories to non-overlapping file globs (the
   parallel-split boundaries), find the dependency chains (what must exist before what), read the
   stack and any existing CLAUDE.md, and record the dependency posture (lockfile, pinned vs floating,
   release-age cooldown, install scripts). Never invent paths — mark any glob you can't verify as a
   placeholder.

4. **Generate orchestration config.** Use the `subagent-orchestration` skill to author or APPEND a
   CLAUDE.md routing section tailored to THIS repo and, where roles recur, `.claude/agents/`
   specialists with least-privilege tools. Append to any existing CLAUDE.md rather than duplicating
   it.

5. **Confirm the workflows.** Make sure the generated CLAUDE.md references
   `/claude-t3-devkit:code-todo` and `/claude-t3-devkit:ship` so the implement → review → ship chain
   works here. If you want the optional MCP servers or the Slack hook, point me at the `.mcp.json` /
   hooks setup.

6. **Next steps.** Print: run `/reload-plugins`, then try `/claude-t3-devkit:code-todo` on a small
   change to confirm the chain. Note that teammates are prompted to install on folder-trust.

Stop and ask rather than guessing this repo's domain boundaries or paths.
