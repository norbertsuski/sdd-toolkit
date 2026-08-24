# sdd-toolkit

Personal Claude Code marketplace. Currently ships one plugin:

- **sdd-skills** — the spec-driven development (SDD) skill family (26 `sdd-*` skills), including the `/sdd-run` Agent Factory layer.

## Install

```
/plugin marketplace add https://gitlab.com/norbert.suski/sdd-toolkit.git
/plugin install sdd-skills@sdd-toolkit
```

## Update

```
# after pushing changes (and bumping "version" in .claude-plugin/plugin.json)
/plugin marketplace update
/plugin update
```

## Local testing (no install)

Run Claude Code in any project with this repo as a plugin dir:

```
claude --plugin-dir /path/to/sdd-toolkit
```

## Install for Cursor

Cursor has native [Skills](https://cursor.com/docs/skills) that use the **same
`SKILL.md` format** as Claude Code (same `name` / `description` frontmatter, same
`references/` bundling, automatic or manual activation). So there's no conversion —
you just copy the skill folders into a Cursor skills directory:

- **Per project:** `.cursor/skills/` in the target repo
- **All projects:** `~/.cursor/skills/` (global)

Copy the whole `sdd-*` folders (so each keeps its `references/` subfolder and the
cross-skill relative links like `../sdd-shape/references/context-resolution.md`
still resolve — Cursor discovers skills recursively):

```
# global (all projects)
mkdir -p ~/.cursor/skills
cp -R /path/to/sdd-toolkit/skills/sdd-* ~/.cursor/skills/

# or per project
mkdir -p .cursor/skills
cp -R /path/to/sdd-toolkit/skills/sdd-* .cursor/skills/
```

That's it — Cursor picks them up on the next start. Invoke a skill by typing `/`
in Agent chat and picking it, or let the agent auto-select based on the skill's
`description`.

Prefer to let an agent do it? Paste this into Cursor's Agent (Cmd/Ctrl-L):

```
Install the SDD skills into Cursor for me.

First ask me one question: install for THIS project only (.cursor/skills/) or
globally for all projects (~/.cursor/skills/)? Use my answer as DEST.

Then:
1. Get the source: use my local clone of
   https://gitlab.com/norbert.suski/sdd-toolkit.git if I have one open, otherwise
   clone it to a temp directory.
2. Copy every `skills/sdd-*` folder into DEST, preserving each folder's structure
   (its SKILL.md and any references/ subfolder) so cross-skill relative links like
   `../sdd-shape/references/context-resolution.md` keep resolving. Do not modify
   the files — these are already native Cursor Skills (SKILL.md format), no
   conversion needed.
3. List the installed skill names under DEST so I can confirm.
```

Notes:
- The frontmatter is already compatible: `name` and `description` are what Cursor
  reads. To make a skill command-only (no automatic activation), add
  `disable-model-invocation: true` to its `SKILL.md` frontmatter.
- Cursor can also import remote skills via **Customize → Remote Rule (GitHub)** with
  a repo URL — but this repo is on GitLab, so the `cp -R` above (or a local clone)
  is the reliable path.

## The SDD skills

Spec-driven development workflow, invoked as `/sdd-*`:

Listed roughly in pipeline order.

| Skill | Purpose |
|---|---|
| `sdd-help` | Overview and entry point / map for the SDD workflow |
| `sdd-init` | Bootstrap the `context/` structure in a project |
| `sdd-shape` | Facilitate discovery, turn an idea into shape-notes |
| `sdd-prd` | Write the product requirements (PRD) |
| `sdd-tech-stack-selector` | Pick a starter/stack from the PRD (greenfield) |
| `sdd-stack-assess` | Assess an existing stack for agent-friendliness (brownfield) |
| `sdd-health-check` | Audit deps/security/tests/CI of an existing project (brownfield) |
| `sdd-roadmap` | Decompose the PRD into dependency-ordered slices |
| `sdd-test-plan` | Orchestrate a phased test rollout (brownfield) |
| `sdd-new` | Open a change folder up-front |
| `sdd-frame` | Challenge the *what* — fix / scope / design choice |
| `sdd-research` | Map the codebase before planning |
| `sdd-plan` | Produce the phased implementation plan |
| `sdd-plan-review` | Review a plan for substance/feasibility before building |
| `sdd-implement` | Implement the plan phase by phase |
| `sdd-tdd` | Drive testable phases test-first (red→green→refactor) |
| `sdd-e2e` | Drive browser-level (E2E) phases against the running app |
| `sdd-goal-implement` | Autonomous/unattended plan execution |
| `sdd-run` | **Agent Factory**: drive a change from its current state — route prep, select strategy, spawn scoped workers, verify |
| `sdd-impl-review` | Review the implementation against the plan (interactive) |
| `sdd-impl-review-ci` | Run implementation review non-interactively in CI |
| `sdd-mr` | Open a merge request for a completed change (plain-mode hand-off) |
| `sdd-map` | Draw the roadmap dependency graph (Mermaid) |
| `sdd-lesson` | Capture a recurring rule / lesson |
| `sdd-archive` | Archive a completed change |
| `sdd-archive-project` | Archive a whole completed project (foundation folder) |

## The Agent Factory (`/sdd-run`)

The `sdd-*` skills above are **capabilities** — reusable procedures a person drives one command at a time. `/sdd-run` adds a composition layer on top:

```
Skill          = reusable procedure / capability
Agent (worker) = goal + scoped context + skill contract + tools + write scope
Agent Factory  = /sdd-run — decides which workers (if any) are needed and how they cooperate
```

The factory does not contain software-development knowledge of its own, and it does not replace any skill. Given a change-id it:

1. **Inspects state** — `change.md` status + which artifacts exist (`frame.md`, `research.md`, `plan.md`, reviews, the plan's `## Progress`).
2. **Routes missing preparation** to the owning skill (`/sdd-frame`, `/sdd-research`, `/sdd-plan` are interview-driven — the factory never invents their artifacts; unattended runs STOP on missing prep).
3. **Analyzes the plan** — builds a dependency graph over the pending phases (an optional per-phase `**Depends on**:` line makes dependencies explicit; without it, phases form a conservative linear chain).
4. **Selects a strategy and says why** — `single-agent` (the default), `sequential multi-agent` (fresh scoped context per phase), or `multi-agent DAG` (only when ≥2 phases are provably independent — disjoint files, no shared contracts — and substantial enough to justify workers). Multi-agent is never automatic.
5. **Executes** — single-agent runs hand the session to the existing executors (`/sdd-implement` attended, `/sdd-goal-implement` unattended). Multi-agent runs dispatch ephemeral, task-derived workers (no fixed persona catalog), each with one phase as its goal, minimum context, and a declared write scope — executed **one at a time, even in a DAG** (write-scope disjointness is not runtime isolation; a sibling's tests or a repo-wide typecheck must never observe half-finished work). The DAG buys dependency-true ordering and failure isolation between independent phases, not concurrency. Workers never commit, never stage, never touch `plan.md`; the factory runs the full gate stack at integration (stage → deliberate-break check → repo-wide checks → commit) and is the sole writer of `## Progress` and sole author of the per-phase Conventional Commits.
6. **Verifies independently, as part of completion** — the implementer is not the authority on its own work: attended runs run `/sdd-impl-review` (declining is recorded as `Verification: SKIPPED`); unattended runs dispatch a reviewer subagent that reads the **full plan** (including "What We're NOT Doing") and returns the canonical APPROVED / NEEDS ATTENTION / REJECTED verdict — REJECTED stops the run.
7. **Retries bounded, STOPs honestly** — 2 self-fix attempts per gate inside a worker, one fresh replacement worker per failed phase, then a STOP block (goal-implement format). Escalation to a human is reserved for genuine decisions (ambiguous spec, contradictions, destructive ops), not routine failures.
8. **Persists and resumes** — execution state stays in the plan's `## Progress` (unchanged, canonical); orchestration state (strategy, graph, worker outcomes, retries) is appended to `changes/<change-id>/factory-log.md`. Re-running `/sdd-run <change-id>` after an interruption skips completed phases and continues.

Human gates are honored, not bypassed: attended runs pause at every gate `/sdd-implement` defines (manual verification per phase, commit approval, mismatch decisions); unattended runs follow `/sdd-goal-implement`'s policies (Manual checklist rows are never auto-checked — they end up in the run report).

**Example — small change (single-agent).** `/sdd-run rename-visibility-prop` on a 2-phase plan (rename + update components; fix tests). Phase 2's tests exercise phase 1's rename → linear chain, small scope:

```
Strategy: single-agent
Why: 2 phases, P2's criteria consume P1's rename; per-phase scope is small —
     coordination would cost more than it saves.
Graph: P1 → P2
```

…then the run proceeds exactly as `/sdd-implement` would, and ends with the standard run report.

**Example — parallelizable feature (DAG).** `/sdd-run listing-visibility` on a 4-phase plan (P1 migration; P2 API `**Depends on**: Phase 1`; P3 frontend `**Depends on**: Phase 1`; P4 integration tests `**Depends on**: Phase 2, Phase 3`):

```
Strategy: multi-agent DAG
Why: P2 and P3 touch disjoint subsystems (src/server/** vs src/client/**)
     with no cross references; both are multi-file. P1 must land first;
     P4 integrates both. Execution is serialized; the graph isolates
     failures between P2 and P3.
Graph: P1 → {P2 ∥ P3} → P4
```

P1 runs and is integrated + committed; P2 then P3 run as scoped workers, one at a time, each integrated through the full gate stack and committed; P4 runs last; the reviewer pass closes the run. If P2 fails after its bounded retry, P3 (independent) still lands before the run stops — that failure isolation, not concurrency, is what the DAG buys.

Individual skills remain the direct-control path — nothing routes you through the factory. See `skills/sdd-run/SKILL.md` and its `references/` for the full contracts (strategy selection, worker spec, factory-log format).

## Notes

- Versioning is manual — bump `version` in `.claude-plugin/plugin.json` before publishing an update.
- A few skills reference `/sdd-*` commands that are not shipped here (`sdd-bootstrapper` — the greenfield scaffolder — and the optional `sdd-contract`). `sdd-help` documents them as not-installed; the conceptual step still exists in the method, the command just isn't in this plugin.
- Origin of these skills: extracted from an internal team plugin and genericized for standalone use.
