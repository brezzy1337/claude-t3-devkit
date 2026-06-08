---
description: Scaffold a fresh create-t3-turbo monorepo and wire it to the claude-t3-devkit (settings, CLAUDE.md orchestration, agents)
argument-hint: [new project directory name]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(pwd:*), Bash(ls:*), Bash(mkdir:*), Bash(pnpm:*), Bash(bunx:*), Bash(bun:*), Bash(npm:*), Bash(git init:*), Bash(git add:*), Bash(git commit:*)
---

# New project

Scaffold a brand-new create-t3-turbo monorepo and wire it to the claude-t3-devkit so the team's
orchestration, code-todo, and ship workflows work from day one. Treat $ARGUMENTS as the new project
directory name. You (the central thread) own the sequence end to end.

Context (gathered for you):
- Here: !`pwd`

1. **Confirm the target.** $ARGUMENTS is the new directory name. If none was given, ask me for one
   before scaffolding. Refuse if `./<name>` already exists — this command creates a fresh project;
   use `/claude-t3-devkit:add-to-project` to wire an existing repo.

2. **Scaffold the monorepo.** Run the create-t3-turbo initializer with the first available package
   manager (prefer pnpm › bun › npm):
   - `pnpm create t3-turbo@latest <name>`
   - else `bunx create-t3-turbo@latest <name>`
   - else `npm create t3-turbo@latest -- <name>`
   If none are installed, stop and tell me. (The bundled `bootstrap.sh` does the same from a plain
   terminal if you'd rather scaffold before opening Claude Code.) Stop and report if scaffolding
   fails.

3. **Wire the marketplace.** Write `<name>/.claude/settings.json` so this marketplace + plugin are
   enabled and collaborators are prompted on folder-trust. Merge into any file the scaffold already
   wrote — never clobber it:
   ```json
   {
     "extraKnownMarketplaces": {
       "claude-t3-devkit": { "source": { "source": "github", "repo": "brezzy1337/claude-t3-devkit" } }
     },
     "enabledPlugins": ["claude-t3-devkit@claude-t3-devkit"]
   }
   ```

4. **Generate orchestration config.** Work inside the new project and use the
   `subagent-orchestration` skill to author a CLAUDE.md routing section and, where roles recur,
   `.claude/agents/` specialists — tailored to the **actual** scaffolded layout (`apps/*`,
   `packages/*`, `tooling/*`). Inspect real directories for domain globs; never invent paths.

5. **Confirm the workflows.** Make sure the generated CLAUDE.md references
   `/claude-t3-devkit:code-todo` and `/claude-t3-devkit:ship` so the implement → review → ship chain
   is ready to use.

6. **Next steps.** Print clear instructions: `cd <name>`, run `/reload-plugins`, then drive the
   first change with `/claude-t3-devkit:code-todo`. Note that teammates pick up the plugin on
   folder-trust.

Stop and ask if anything is ambiguous rather than guessing project structure or paths.
