# Worker contract — ephemeral, task-derived, scoped

How `/sdd-run` constructs and communicates with the short-lived workers of a multi-agent run. A worker is not a persona ("FrontendAgent", "QAAgent") — it is derived from one phase of one plan and disappears when that phase is integrated.

```
Worker = Goal (one phase)
       + Context (the minimum that keeps it correct AND coherent)
       + Skill contract (the executor rules it works under)
       + Tools (minimum the task needs, where the host can restrict)
       + Write scope (declared, verified post-hoc)
       + Success criteria (the phase's own)
       + Termination (success · failure · budget exhausted · human-only decision)
```

## The worker spec

Composed by the factory per phase, then rendered into the dispatch prompt:

| Field | Source |
|---|---|
| `id` | `w<K>-phase-<N>` (run-local) |
| `goal` | "Implement Phase <N> of the plan" + the phase title |
| `context` | See "Context assignment" below |
| `skill contract` | A scoped subset of `/sdd-goal-implement`'s per-phase rules (criteria gates, mismatch taxonomy, self-fix budget) — inlined in the prompt as the rules below, with the skill file named as canonical source. Staging, the deliberate-break check, repo-wide checks, and commits are **not** the worker's: they run factory-side at integration, where the touched set is staged first and the break-check's restore is therefore exact |
| `tools` | Read/Grep/Glob/Edit/Write/Bash — the implementation set. No subagent spawning, no interactive questions. Where the host supports per-agent tool restriction (agent definitions, `allowedTools`), apply it; otherwise the prompt's restrictions are the guardrail and the factory's post-hoc checks the enforcement |
| `write scope` | The phase's `Changes Required` paths + their natural test locations, as concrete paths or narrow globs (e.g. `src/server/**`, `tests/server/**`). New files allowed only inside the scope |
| `success criteria` | The phase's `#### Automated` criteria, verbatim, with runnable commands |
| `dependencies` | The phase's DAG parents (informational — the factory already sequenced the dispatch) |
| `termination` | success · structural mismatch (STOP) · 2 self-fix attempts exhausted on a gate (STOP) · decision requiring a human (STOP) |

## Context assignment

Isolation and coherence pull against each other; the split below is the balance. A worker receives:

**Always (coherence — prevents locally-correct, globally-incompatible work):**
- the plan's `## Overview`, `## Desired End State`, `### Key Discoveries`, `## What We're NOT Doing`, and any `## Critical Implementation Details`;
- `$CONTEXT_ROOT/foundation/lessons.md` content (accepted recurring rules bind workers too).

**Per phase (isolation — the actual task):**
- the full `## Phase <N>` block (Changes Required with Intent/Contract, Success Criteria);
- that phase's rows from `## Progress` (so the worker knows step numbering — it reports against them, it does not flip them);
- excerpts of `research.md` / `frame.md` that the phase's files or contracts touch (sections, not whole documents);
- the list of files in scope, plus named neighboring interfaces the Contract references (the worker reads the actual files itself).

**Never:**
- other phases' Changes Required (their existence + one-line titles are enough for orientation);
- the conversation history of the factory session;
- unrelated foundation docs, the whole roadmap, or other changes' folders.

## The dispatch prompt template

Render the spec into this shape (adapt wording, keep every numbered rule):

```
You are an ephemeral implementation worker for one phase of an approved SDD plan.
Nobody is watching; never ask questions — follow the policies below.

GOAL
Implement Phase <N>: <title> of <change-id>. Plan file: <path> (read-only for you).

CONTEXT
<plan header sections> <phase block> <progress rows for this phase>
<research/frame excerpts> <lessons.md content>
Files in scope (read them fully before editing): <list>

RULES (scoped /sdd-goal-implement contract — canonical: skills/sdd-goal-implement/SKILL.md)
1. WRITE SCOPE: you may create or modify files ONLY under: <scope globs/paths>.
   Everything else in the repo is read-only. If the phase cannot be completed
   without touching an out-of-scope file, report it under "Out-of-scope needs"
   with one line of evidence why — do not touch it. Finish everything the phase
   allows within scope first (a scope expansion re-dispatch may follow).
2. Do NOT edit plan.md, change.md, or factory-log.md. Do NOT run ANY git command
   that mutates state — no commit, no push, no add/stage, no checkout/restore,
   no stash. Read-only git (status, diff, log) is fine. The orchestrator stages,
   verifies, and commits.
3. Mismatches: minor (moved file, renamed symbol, import drift) → adapt and
   record an ADAPT line. Structural (missing dependency, architecture differs,
   referenced API absent) → STOP and report. When in doubt, structural.
4. Gates, after implementing: run each Automated success-criteria command for
   this phase, in order. Record one verdict line per command. Do NOT perform the
   deliberate-break check — the orchestrator runs it at integration with your
   implementation staged (unstaged, a break-restore would wipe your work).
5. A failing gate gets at most 2 self-fix attempts. Never weaken an assertion,
   delete a test, or relax lint/type rules to pass. Third failure → STOP and report.
6. Do NOT run the repo-wide full suite — the orchestrator runs it at integration.

REPORT (your entire final message is this block — no prose around it)
WORKER REPORT — <worker-id>
Phase: <N> <title>
Status: SUCCESS | STOPPED
Steps completed: <N.M ids from the Progress rows given to you>
Touched files:
- <repo-relative path, one per line — every file you created or modified>
Gates:
- <criterion/command>: PASS | FAIL (attempt k/2, summary)
Adaptations: <ADAPT lines, or "none">
Out-of-scope needs: <paths you needed but did not touch, or "none">
Stopped because: <only when STOPPED — expected/found/why, per the STOP taxonomy>
Uncertainties: <anything a human or reviewer should double-check, or "none">
```

## Report verification (factory side, per worker)

1. Report parses and `Status` is explicit; `Touched files` present on SUCCESS.
2. **Write-scope check**: `git status --porcelain` filtered to the worker's declared write scope ∪ its touched list; any modified path outside the declared scope → treat as a gate failure of that worker (retry policy applies), never silently commit it. A path listed only under `Out-of-scope needs` (reported, untouched) is NOT a failure — it routes to the skill's Step 9 scope-expansion policy.
3. Gate verdicts all PASS on SUCCESS; spot-check one claim against the actual diff (trust, verify one).
4. Only then run the integration gate stack, in `/sdd-goal-implement`'s canonical order (the skill's Step 7): **stage** the touched set ∪ `{plan.md, factory-log.md}` → **deliberate-break check** (when the phase added/changed tests; restore is exact because the implementation is staged) → **repo-wide checks** → **flip** the phase's Progress rows → **commit** via the executor ritual (the ritual always re-stages `plan.md`, so the flip rides the same commit). Rows flip only after every gate is green.

A **STOPPED** report skips steps 3–4: the factory reads its `Touched files` (plus `git status --porcelain` within the scope, in case the report is incomplete), then applies the skill's Step 9 classification — gate failure → replacement (Touched files become the restore set below); structural → STOP; scope-expansion request → widen and re-dispatch after the new paths pass the same clean-scope gate as the Step 7 preflight — dirty or user-staged expansion targets are never taken over (no restore: the widened worker continues on top of its own prior in-scope work, and the phase integrates once, after the widened attempt returns).

## Retry (factory side)

A worker whose STOP was a **gate failure** (or whose SUCCESS failed report verification, or whose staged work failed an integration gate that traces to this phase) gets **one** replacement: same spec + a `PRIOR ATTEMPT` context block (failing gate output, the first worker's diagnosis, its adaptations). Structural-mismatch STOPs get no replacement — the skill's Step 9 escalates them directly.

Before dispatching the replacement, restore the failed worker's scope to a clean state, in this order (correct whether or not integration already staged the work — `git checkout -- <path>` restores from the *index*, so a staged failed implementation must be unstaged first or the checkout is a no-op against it):

1. `git reset -- <scope paths>` — unstage anything of this worker's that integration staged (no-op when nothing was staged; also turns its staged new files back into untracked `??`).
2. `git checkout HEAD -- <tracked modified paths>` — restore tracked files explicitly from HEAD.
3. Delete the untracked files it created (its touched list ∪ porcelain `??` entries inside its scope) — checkout does not remove new files, and the replacement must not build on debris.

This restore's provenance is certain: the preflight guaranteed the scope was clean at dispatch and execution is serial, so everything dirty (or staged) in the scope is the failed worker's output — this is the **only** restore the factory ever performs on its own authority. If the replacement fails, the factory STOPs the run per the skill's Step 9.

## Host capabilities

The contract needs, in order of importance: (1) subagent dispatch with an isolated context window; (2) optional per-agent tool restriction; (3) — for any *future* concurrent dispatch — per-worker runtime isolation with a working toolchain inside it.

- **Claude Code**: (1) via the Task/Agent mechanism with `subagent_type: "general-purpose"`; (2) via custom agent definitions when the project ships them — otherwise the prompt-level restriction + post-hoc scope check stand in. (3) exists as native worktree isolation, but a fresh worktree has no installed dependencies or build state, so a worker's criteria commands cannot run there without setup cost — one reason workers execute serially in the shared tree instead (the skill's Step 6, invariant 3). If a host ever provides isolated copies with a working toolchain, concurrent dispatch becomes the extension point — under this same spec, no contract change.
- **Hosts without subagents**: multi-agent strategies are unavailable — the factory says so plainly and proceeds single-agent. This is graceful degradation, not failure: single-agent is the default anyway.
- **Limitation, stated honestly**: prompt-level write scopes are guardrails, not sandboxes. Enforcement is the factory's post-hoc scope check before anything is committed. Serial execution is likewise a correctness choice, not a runtime constraint dressed up as one: write-scope disjointness cannot stop a repo-wide criteria command, a shared build cache, or a test run from observing a sibling's half-finished work.
