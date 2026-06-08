<!--
  Template: the "Sub-Agent Orchestration" section for a project's CLAUDE.md.
  Replace every `TAILOR:` marker with this repo's specifics, then delete the marker comments.
  Append to an existing CLAUDE.md rather than overwriting it; match its tone.
-->

## Sub-Agent Orchestration

This project treats the main Claude Code session as an orchestrator. It does little work
directly — it routes tasks to sub-agents and assembles their results. Output quality depends on
routing the work correctly and briefing each sub-agent completely. The rules below are how this
session decides.

### Routing: parallel, sequential, or background

Default to the safest pattern that fits. When unsure, run sequentially — a wrong parallel split
causes merge conflicts and inconsistent state, while a wrong sequential choice only costs time.

**Dispatch in parallel** only when ALL of these hold:
- The work splits into 3+ tasks in independent domains
- No task needs another task's output
- File boundaries are clean — no two agents touch the same file

**Dispatch sequentially** when ANY of these holds:
- One task depends on another's output (B needs A)
- Tasks share files or state (merge-conflict risk)
- Scope is unclear and must be understood before acting

**Dispatch in the background** when:
- The task is research or analysis, not file edits
- The result isn't blocking the current work
(Monitor background work from the agent view; press Ctrl+B to background a running task.)

### Domain boundaries (parallel splits)

When a change spans these domains, give each its own agent and keep their files from
overlapping. A parallel split is only safe when the globs below do not intersect; if two
domains share a file, that work is sequential.

<!-- TAILOR: replace with THIS repo's real domains and file globs. Delete examples that don't apply. -->
- **Frontend** — `src/components/**`, `src/app/**` (UI, forms, client state)
- **Backend** — `src/api/**`, `src/server/**` (routes, server actions, business logic)
- **Database** — `prisma/**`, `migrations/**` (schema, migrations, queries)

### Dependency chains (sequential order)

Some work must be serialized because each step consumes the previous step's output. Sub-agents
cannot spawn sub-agents, so this session owns the chain: it runs each step, then hands the
relevant output to the next.

<!-- TAILOR: replace with THIS repo's real chains. Delete examples that don't apply. -->
- Schema → API → Frontend (the data shape must exist before the interface that uses it)
- Research → Plan → Implement (understand before building)
- Implement → Test → Security review (build, validate, then audit)

### Background by default

Run these in the background so the main work continues uninterrupted:
- Web research and documentation lookups
- Codebase exploration and analysis
- Security audits and performance profiling

### Invocation protocol (every dispatch)

A sub-agent starts with a fresh context window and cannot ask follow-up questions. A thin brief
— not the agent's ability — is the most common cause of a bad result. Every dispatch carries all
four of these:

1. **Context** — what's going on and why, plus any constraint that must survive the handoff
   (e.g. "ignore the `vendor/` directory").
2. **Instructions** — the specific change or output, scoped narrowly.
3. **File references** — exact paths to read or modify (e.g. `src/lib/auth.ts`).
4. **Success criteria** — what "done" looks like, concretely.

Weak: "Fix authentication."

Strong: "Fix the OAuth redirect loop where a successful login lands on `/login` instead of
`/dashboard`. The redirect logic is in `src/lib/auth.ts`. Done = an authenticated user is routed
to `/dashboard`, verified against the existing auth-middleware test."

### Guardrails

- **Don't over-parallelize.** Splitting eight micro-tasks across eight agents costs more in
  coordination and tokens than it saves. Group related small tasks into one agent.
- **Don't under-parallelize.** Four genuinely independent analyses run one-by-one waste
  wall-clock time. Look for domain independence.
- **Match the model to the task.** Set `CLAUDE_CODE_SUBAGENT_MODEL` (for example, `sonnet`) so
  focused sub-agent work runs on a lighter, cheaper model while this session reasons on a
  stronger one. A per-agent `model` field in `.claude/agents/` overrides it.

### Dependency safety

Before adding or upgrading any package — and before delegating that work to a sub-agent — follow
these rules. The tooling listed below is the real enforcement; these rules cover the moments the
agent acts outside it.

**Verify before you add.** Never add a package just because the name sounds right. An agent can
hallucinate a plausible name that an attacker has already registered (slopsquatting). For any new
dependency, confirm it actually exists, that it's the canonical package (repo link resolves,
adoption/history look real, name isn't a near-miss typo of a popular package), and that it isn't
an internal name a public registry could shadow.

<!-- TAILOR: keep the line for THIS repo's package manager; delete the others. 7 days = 10080 minutes = 604800 seconds. -->
**Respect the cooldown — adopt versions that are at least 7 days old.** Most malicious releases
are caught and pulled within hours to a couple of days, so a one-week wait removes most exposure.
Enforce it in tooling, not by memory:
- pnpm — `minimumReleaseAge: 10080` in `pnpm-workspace.yaml` (minutes; `minimumReleaseAgeExclude` for vetted hotfixes)
- Yarn Berry — `npmMinimalAgeGate: 10080` in `.yarnrc.yml` (minutes)
- Bun — `minimumReleaseAge = 604800` under `[install]` in `bunfig.toml` (seconds)
- npm (≥ 11.10.0) — `min-release-age=7` in `.npmrc` (days)
- update bots — Renovate `minimumReleaseAge: "7 days"`; Dependabot `cooldown:` block
The one exception is a genuine security patch — evaluate it explicitly rather than auto-waiting.

**Other guards (set these up; honor them in agent work):**
- Commit the lockfile and install frozen in CI (`npm ci`, `pnpm install --frozen-lockfile`,
  `yarn install --immutable`). Don't let an install silently rewrite it.
- Pin exact versions; avoid floating `^`/`~`. Apply the cooldown to transitive deps too — cooling
  down only direct deps leaves the same gap one level down the graph.
- Don't run install/lifecycle scripts by default (`ignore-scripts=true`; pnpm `allowBuilds`
  allowlist). Postinstall scripts are a common execution path for these attacks.
- Block exotic sources (git URLs, arbitrary tarballs) for transitive deps where the manager
  supports it (e.g. pnpm `blockExoticSubdeps`).
- Run an audit/scan before merging (`npm audit` / `pnpm audit`, `osv-scanner`, or a service like
  Socket/Snyk) and prefer packages with provenance attestations.

**Escalate, don't bypass.** If shipping seems to require a sub-7-day version or disabling a guard,
surface it to a human with the reason — don't quietly weaken the policy to move faster.
