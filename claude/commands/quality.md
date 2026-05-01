---
description: "Code quality framework — runs targeted quality agents against your current git diff. Usage: /quality [aspects]"
argument-hint: "[code] [arch] [refactor] [tests] [security] [simplify] [process] [delivery] [distributed] [patterns] [persistence] — or omit for all"
allowed-tools: ["Bash", "Glob", "Grep", "Read", "Task"]
---

# Quality Framework

Run quality agents against the current git diff. Spawn relevant agents in parallel, then aggregate findings into a prioritized action plan.

**Requested aspects:** "$ARGUMENTS"

---

## Step 1 — Get the Diff

First, check we're in a git repo:
```bash
git rev-parse --is-inside-work-tree 2>/dev/null
```

**If not a git repo:** ask the user which files or directories to review explicitly. Skip the diff steps and pass file paths directly to agents.

**If in a git repo:**
```bash
git diff
git diff --name-only
git status --short
```

If `git diff` is empty, check staged changes:
```bash
git diff --cached
git diff --cached --name-only
```

If still empty, ask the user which files to review.

---

## Step 2 — Determine Applicable Agents

Parse `$ARGUMENTS` for aspect keywords:
- `code` → quality-code-quality
- `arch` or `architecture` → quality-architecture
- `refactor` → quality-refactor (Mode 2: full refactor plan)
- `simplify` → quality-refactor (Mode 1: light simplify pass)
- `tests` or `test` → quality-test-quality
- `security` → quality-security-review
- `review` → quality-review (confidence-scored review with PR lenses)
- `process` → quality-process
- `delivery` or `deploy` → quality-delivery
- `distributed` or `dist` → quality-distributed
- `patterns` or `pattern` → quality-patterns
- `persistence` or `db` or `database` → quality-persistence
- No arguments / `all` → run all applicable agents (see rules below)

**Note on simplify routing:** `quality-refactor` now handles both modes. Mode is selected by the aspect keyword: `simplify` → Mode 1 (light), `refactor` → Mode 2 (full plan). The existing `code-simplifier` agent is no longer routed by this orchestrator.

**Auto-selection rules (when no arguments provided)**

These rules use signals detectable from `git diff --name-only` and the diff content itself, not from agent output.

| Detectable signal | Agent to run |
|-------------------|-------------|
| Any source files changed | quality-code-quality (always) |
| New files added (`A` in `git status`) OR diff touches imports/dependencies OR new classes/modules | quality-architecture |
| Test files in diff (`*.test.*`, `*.spec.*`, `*_test.*`, `test_*.py`) | quality-test-quality |
| Files in auth/payment/api paths OR diff touches input handling, sessions, secrets | quality-security-review |
| Migration files (`migrations/`, `db/migrate/`, `alembic/`, `prisma/migrations/`) OR Dockerfiles, k8s manifests, CI/CD configs (`.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`) OR feature-flag config OR `.env*` template changes | quality-delivery |
| Service-to-service HTTP/gRPC calls (`axios`, `fetch`, `http.Client`, `requests`, `RestTemplate`, `grpc`) OR message-queue imports (`kafka`, `rabbitmq`, `sqs`, `pubsub`, `nats`, `eventbridge`) OR files under `services/` crossing service boundaries | quality-distributed |
| ORM imports (`hibernate`, `sqlalchemy`, `prisma`, `typeorm`, `sequelize`, `mongoose`, `ActiveRecord`, `EntityFramework`) OR `*.sql`, `*.prisma`, schema files OR repository / DAO files OR raw SQL in diff | quality-persistence |
| After other reviews complete (always last, on recently modified code) | quality-refactor in Mode 1 (Simplify) |

**Opt-in only — never auto-spawned:**
- `quality-refactor` in Mode 2 (full plan) — invoke via `/quality refactor` when smells need named refactoring moves prescribed
- `quality-process` — invoke via `/quality process` when reviewing planning discipline of a significant change
- `quality-patterns` — invoke via `/quality patterns` for pattern recognition / anti-pattern audit (auto-detection of "this should be a Strategy" is unreliable; prefer explicit invocation, often after `quality-code-quality` finds smells)
- `quality-review` — invoke via `/quality review` for the full PR-style review with confidence scoring and lenses; redundant with the auto-selection above for normal pre-commit use

**Suggestion behavior:** When auto-spawning produces findings, suggest follow-up agents that aren't auto-spawned:
- If `quality-code-quality` flags multiple smells (Switch on type code, Long Method with branches, etc.) → suggest `/quality patterns` for prescribed pattern recognition AND `/quality refactor` for Fowler moves
- If significant changes were made → suggest `/quality process` for planning audit
- If `quality-distributed` flags partial-failure issues → suggest `/quality arch` for the underlying resilience patterns
- If `quality-persistence` flags N+1 or migration issues → ensure `quality-delivery` ran (or suggest it) for migration safety

When in doubt: run `quality-code-quality` only.

---

## Step 3 — Display Plan

Before spawning, show:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 QUALITY ► REVIEWING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Changed files: [list from git diff --name-only]

◆ Spawning agents in parallel...
  → [agent name] — [what it checks]
  → [agent name] — [what it checks]
  ...
```

---

## Step 4 — Spawn Agents in Parallel

Pass the full diff content and file list to each agent. Example:

```
Task(
  prompt="Review the following git diff for code quality issues.
  
  Changed files: [list]
  
  Diff:
  [full git diff output]
  
  Focus on: naming, function design, code smells, complexity, comments.
  Use the checklist in your instructions.",
  subagent_type="quality-code-quality",
  description="Code quality review"
)
```

Spawn all selected agents simultaneously (parallel, not sequential).

**Note on simplify:** Always spawn `quality-refactor` (Mode 1) LAST, after other reviews complete, so it polishes rather than duplicates findings. Pass `mode=simplify` in the prompt so the agent picks the correct mode.

---

## Step 5 — Aggregate Results

After all agents complete, aggregate by severity (every agent now reports Critical/Important/Minor with consistent semantics):

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 QUALITY ► RESULTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Critical — Fix Before Committing
- [agent] file:line — description

## Important — Fix Before PR
- [agent] file:line — description

## Minor — Worth Doing
- [agent] file:line — description

## Strengths
- [what's done well across agents]

─────────────────────────────────────────────────

Agents run: [list] | Issues: [X critical, Y important, Z minor]
Verdict: [SHIP IT / NEEDS WORK / SIGNIFICANT ISSUES]
```

**Aggregation rules:**
- Deduplicate findings that multiple agents flagged for the same file:line
- Preserve the most severe rating when agents disagree on severity
- **Severity normalization** — different agents use different scales; normalize to Critical/Important/Minor before aggregating:

  | Agent's native scale | Mapped to |
  |---------------------|-----------|
  | Critical (CVSS) → quality-security-review | Critical |
  | High (CVSS) → quality-security-review | Critical |
  | Medium (CVSS) → quality-security-review | Important |
  | Low (CVSS) → quality-security-review | Minor |
  | All other agents (already use Critical/Important/Minor) | passthrough |

  Security findings get elevated weight: a CVSS-High vulnerability is treated as Critical for aggregation since security issues block ship more readily than other categories.

- Final verdict from normalized severity counts:
  - Any Critical → `SIGNIFICANT ISSUES`
  - No Critical, ≥1 Important → `NEEDS WORK`
  - No Critical, no Important → `SHIP IT`

**Suggest next steps if applicable:**
- If `quality-code-quality` flagged smells: suggest `/quality refactor` for prescribed moves
- If significant changes were made: suggest `/quality process` for planning audit
- If results were strong: confirm ready to commit

---

## Usage Examples

```
/quality                              # Run all applicable agents on git diff (auto-routed)
/quality code                         # Naming, functions, smells only
/quality arch                         # SOLID, dependencies, coupling, resilience
/quality refactor                     # Smell catalog, safe refactoring plan (Mode 2)
/quality simplify                     # Light behavior-preserving cleanup (Mode 1)
/quality tests                        # Test suite quality audit
/quality security                     # OWASP/CWE adversarial scan + SAST/SCA tools
/quality review                       # Confidence-scored PR-style review with lenses
/quality process                      # Planning discipline — edge cases, deps, Big-O
/quality delivery                     # CD pipeline readiness, 12-Factor, migrations
/quality distributed                  # Service boundaries, idempotency, replication
/quality patterns                     # GoF pattern recognition + anti-pattern audit
/quality persistence                  # ORM patterns, N+1, transactions, migrations
/quality code arch                    # Code quality + architecture
/quality code arch refactor           # Three-way review
/quality persistence delivery         # DB layer + deploy/migration audit (common pair)
/quality distributed arch             # Distributed concerns + structural review
```

---

## Tips

- **Run before committing**, not after. Critical issues block the commit.
- **`/quality`** — default; runs always-on agents based on what changed. Best as a pre-commit pass.
- **`/quality code`** — fast, focused. Naming, smells, FP, error handling, performance, structure.
- **`/quality arch`** — before large features. Catches structural problems + resilience-pattern gaps before they're baked in.
- **`/quality refactor`** — before adding to messy code. Make the change easy, then make the easy change.
- **`/quality tests`** — when tests feel brittle. Find the smells before a refactor breaks them.
- **`/quality security`** — before any code touching auth, payments, user input, or external API surface goes live.
- **`/quality review`** — full PR-style review with the Google design-first priority order; ideal before opening a PR.
- **`/quality process`** — for significant features. Audits whether edge cases, dependencies, alternatives, and Big-O were considered.
- **`/quality simplify`** — final polish pass. Run it last, after other reviews pass.
- **`/quality delivery`** — when touching schema migrations, deployment config, feature flags, or anything that affects the deploy pipeline. Catches deploy-coupled changes that break rolling deploys.
- **`/quality distributed`** — when crossing service boundaries (HTTP, gRPC, queues) or touching replication, partitioning, distributed transactions. Reduces every distributed bug to one of Waldo's four categories.
- **`/quality patterns`** — after `/quality code` finds smells. Names the GoF pattern that prescribes the fix, OR flags pattern misuse (Singleton-as-global, Visitor abuse). Often invoked alongside `refactor`.
- **`/quality persistence`** — when ORM, repositories, queries, or migrations are in the diff. Catches N+1, deploy-coupled migrations, missing transaction boundaries, persistence leaking into domain.

### Common multi-aspect combinations

- `/quality persistence delivery` — DB code + migration safety. Run together when touching schema.
- `/quality distributed arch` — service-to-service work + the resilience patterns underneath.
- `/quality code patterns refactor` — when reviewing structural code: smells + pattern recognition + prescribed moves.
- `/quality security review` — pre-PR pass on any user-facing or auth code.
