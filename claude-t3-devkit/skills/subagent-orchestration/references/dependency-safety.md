# Dependency safety reference

Concrete, per-ecosystem detail for the **Dependency safety** block of the CLAUDE.md section.
Read this when generating that block or a `dependency-auditor` agent. Values current as of mid-2026;
these features move fast, so confirm against the tool's own docs when in doubt.

## Contents
- Why a release-age cooldown
- Cooldown settings by ecosystem (the "at least a week old" rule)
- Update-bot cooldowns (Renovate / Dependabot / ncu)
- Other supply-chain guards
- Anti-patterns
- `dependency-auditor` agent

## Why a release-age cooldown

Most malicious package versions are detected and pulled from the registry within hours to a
couple of days. Recent examples were caught fast — the Shai-Hulud worm within ~12 hours, the
debug/chalk compromise in ~2.5 hours. A cooldown ("minimum release age") refuses to install a
version until it has been public long enough for that detection to happen. A 1-day window blocks
the smash-and-grab incidents; the user here wants 7 days, which is comfortably conservative. The
trade-off is freshness, and the standard carve-out is genuine security patches.

## Cooldown settings by ecosystem

7 days expressed in each tool's unit: **10080 minutes**, **604800 seconds**, or **7 days**.
The name and unit differ per tool — match the repo's actual package manager.

| Tool | File | Setting | Unit | 7-day value | Notes |
| --- | --- | --- | --- | --- | --- |
| pnpm (≥10.16; default-on in 11 at 1 day) | `pnpm-workspace.yaml` | `minimumReleaseAge` | minutes | `10080` | `minimumReleaseAgeExclude` for trusted/hotfix pkgs; `minimumReleaseAgeStrict: true` fails instead of falling back |
| Yarn Berry (≥4.10) | `.yarnrc.yml` | `npmMinimalAgeGate` | minutes | `10080` | Known bug ignoring day-suffix strings — pass a number of minutes |
| Bun (≥1.3, opt-in) | `bunfig.toml` `[install]` | `minimumReleaseAge` | seconds | `604800` | |
| npm (≥11.10.0) | `.npmrc` | `min-release-age` | days | `7` | Older npm has no native cooldown — use a bot or pnpm |
| Deno (≥2.6) | `deno.json` `install` | `minimumDependencyAge` | duration | `"7d"` | |
| uv (≥0.9.17, Python) | `pyproject.toml` `[tool.uv]` | `exclude-newer` | duration | `"7d"` | |
| pip (≥26.0, Python) | `pip.conf` | `uploaded-prior-to` | absolute ts | — | Absolute timestamps only; needs periodic updating |

Cargo (Rust) has only an experimental flag / third-party `cargo-cooldown`. Go, Maven, Gradle,
Composer, and Bundler have no native cooldown — for those, enforce it at the update-bot layer.

Example (pnpm):
```yaml
# pnpm-workspace.yaml
minimumReleaseAge: 10080        # 7 days, in minutes
minimumReleaseAgeStrict: true   # fail rather than silently fall back to an older version
minimumReleaseAgeExclude:
  - "@your-scope/*"             # internal packages you publish and trust
```

## Update-bot cooldowns

If updates are automated, gate them at the bot too (this also covers transitive bumps):

```json
// renovate.json  — minimumReleaseAge was formerly stabilityDays
{ "minimumReleaseAge": "7 days" }
```
```yaml
# .github/dependabot.yml  — cooldown shipped mid-2025; security updates bypass it
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule: { interval: "daily" }
    cooldown:
      default-days: 7
```
`npm-check-updates` supports `ncu --cooldown 7` (also accepts `7d`/`12h`). Some platforms apply a
cooldown by default (e.g. Snyk's ~21-day delay on automatic upgrade PRs).

## Other supply-chain guards

- **Verify before adding (anti-slopsquatting / typosquatting).** The agent proposing the package
  is itself a risk: it can name a package that doesn't exist, which attackers pre-register.
  Confirm the package exists, is canonical (repo link resolves, real adoption/history), the name
  isn't a near-miss of a popular package, and isn't an internal name a public registry can shadow
  (dependency confusion).
- **Lockfile committed + frozen install.** `npm ci`, `pnpm install --frozen-lockfile`,
  `yarn install --immutable`. The lockfile is the integrity record; don't let installs rewrite it
  unexpectedly.
- **Pin exact versions** and apply the cooldown to **transitive** deps, not just direct ones.
- **Disable install/lifecycle scripts by default.** `ignore-scripts=true` in `.npmrc`; pnpm's
  `allowBuilds` map to allowlist the few packages that legitimately need a build step. Postinstall
  scripts are a common execution path (e.g. the axios incident).
- **Block exotic sources** for transitive deps where supported (pnpm `blockExoticSubdeps: true`)
  so sub-deps can't be pulled from git/tarball/arbitrary URLs.
- **Detect weakened publishing trust.** pnpm `trustPolicy: no-downgrade` flags when a package's
  publishing authentication weakens between versions. Prefer packages publishing provenance
  attestations; `npm audit signatures` verifies them (not enforced at install time).
- **Scan.** Run `npm audit` / `pnpm audit`, `osv-scanner`, or a service (Socket, Snyk) in CI.

## Anti-patterns

- Cooling down direct deps while leaving transitive deps floating — recreates the exposure window
  one level down, where attackers increasingly aim.
- Treating the CLAUDE.md rule as the enforcement layer. It's a behavioral backstop; the lockfile,
  cooldown config, disabled scripts, and CI scan are what actually hold.
- Auto-bypassing the cooldown for "just this once." Route exceptions through a human with a reason.

## `dependency-auditor` agent

A read-only specialist the central thread delegates dependency decisions to, so the verbose audit
output stays out of the main context and the answer comes back as a clear go/no-go.

```markdown
---
name: dependency-auditor
description: Vets a package before it is added or upgraded — existence, canonicalness, release age, advisories, provenance. Use proactively before introducing or bumping any dependency.
tools: Read, Grep, Glob, Bash, WebFetch, WebSearch
model: sonnet
---

You vet dependencies. You do not modify package manifests or lockfiles — you return a verdict.

For each package and target version, check and report:
1. **Exists & canonical** — the package and version are real; the repo link resolves; adoption and
   maintainer history look legitimate; the name is not a typo of a popular package or an internal
   name a public registry could shadow.
2. **Release age** — the version's publish time. Flag anything younger than the repo's cooldown
   (default 7 days) unless it is a security patch, which you call out explicitly.
3. **Advisories** — run the available audit/scan (`npm audit` / `pnpm audit`, `osv-scanner`, etc.)
   and report known vulnerabilities or malware findings.
4. **Provenance & trust** — whether the version ships provenance attestations and whether its
   publishing trust weakened versus the prior version.
5. **Install-time risk** — whether it runs postinstall/lifecycle scripts or pulls from exotic
   sources.

Return: GO or NO-GO, the single biggest risk, and the minimum safe version if the requested one
fails the age or advisory checks.
```

## Sources

pnpm supply-chain docs (pnpm.io/supply-chain-security, /settings); Renovate minimum-release-age
docs; Dependabot cooldown docs; and cross-ecosystem cooldown roundups (cooldowns.dev,
mareksuppa.com, nesbitt.io). Verify exact setting names/units against current tool docs before
shipping, as these features are evolving quickly.
