# Worker contract — ephemeral, task-derived, scoped

How `/sdd-run` constructs and communicates with the short-lived workers of a multi-agent run. A worker is not a persona ("FrontendAgent", "QAAgent") — it is derived from one phase of one plan and disappears when that phase is integrated.

```
Worker = Goal (one phase)
       + Context (the minimum that keeps it correct AND coherent)
       + Skill contract (the executor rules it works under)
       + Tools (minimum the task needs, where the host can restrict)
       + Write scope (declared, verified post-hoc)
       + Execution profile (model tier · effort · context · verification · why)
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
| `execution profile` | The decision block from `execution-profiles.md`: profile, model tier, resolved host id (or inherited/default), reasoning effort, context scope, verification strength, and evidence. Pass actual model/effort overrides only when the host dispatch supports them |
| `success criteria` | The phase's `#### Automated` criteria, verbatim, with runnable commands |
| `dependencies` | The phase's DAG parents (informational — the factory already sequenced the dispatch) |
| `escalation` | Evidence that requires the worker to STOP/report rather than self-upgrade: unexpected coupling/context gap, critical-risk discovery, structural mismatch, or exhausted gates. The factory alone may select a stronger replacement profile |
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

Apply `execution-profiles.md`'s concrete `small | scoped | broad` payload bands when rendering this context. The list above is the `scoped` default; `small` removes non-direct excerpts/neighbors, while `broad` may include the full plan and cross-cutting research. Record the carrier and payload band in the factory log.

## Whole-run profiled executor (resource carrier, not decomposition)

For a `single-agent` strategy, `/sdd-run` may dispatch one model-selectable child for the whole remaining work-list when the override materially differs from the inherited session and interaction is supported. This is still one execution agent, not a per-phase worker strategy.

- Unattended: execute the full `/sdd-goal-implement` contract, including Progress, gate stack, and phase commits.
- Attended: allowed only when the host relays human questions/gates; otherwise stay inline.
- The child is the sole writer while active; the parent pauses and never integrates concurrently.
- It receives the chosen profile/context payload, full remaining work-list, and existing retry budgets; it may not spawn more agents or change its own profile.
- It returns the executor's full run report with phase SHAs/touched files. The parent appends resource/factory events, performs Step 8 independent review, and writes the final verification snapshot.

If these conditions cannot be enforced, do not dispatch this carrier: run inline and label the model/context decision advisory.

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

EXECUTION PROFILE
Profile: <light|standard|deep|critical>
Model tier: <economical|standard|strong> (resolved by parent as <id|default>)
Reasoning effort: <low|medium|high>
Context scope: <small|scoped|broad>
Why: <evidence>
If this profile/context is insufficient, STOP with evidence; do not change model,
scope, tools, or permissions yourself.

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

A worker whose STOP was a **gate failure** (or whose SUCCESS failed report verification, or whose staged work failed an integration gate that traces to this phase) gets **one** replacement: same goal/write scope + a `PRIOR ATTEMPT` context block (failing gate output, the first worker's diagnosis, its adaptations) and the evidence-based profile escalation from `execution-profiles.md`. Structural-mismatch STOPs get no replacement — they route to plan/spec correction, not a stronger model.

Before dispatching the replacement, restore the failed worker's scope to a clean state, in this order (correct whether or not integration already staged the work — `git checkout -- <path>` restores from the *index*, so a staged failed implementation must be unstaged first or the checkout is a no-op against it):

1. `git reset -- <scope paths>` — unstage anything of this worker's that integration staged (no-op when nothing was staged; also turns its staged new files back into untracked `??`).
2. `git checkout HEAD -- <tracked modified paths>` — restore tracked files explicitly from HEAD.
3. Delete the untracked files it created (its touched list ∪ porcelain `??` entries inside its scope) — checkout does not remove new files, and the replacement must not build on debris.

This restore's provenance is certain: the preflight guaranteed the scope was clean at dispatch and execution is serial, so everything dirty (or staged) in the scope is the failed worker's output — this is the **only** restore the factory ever performs on its own authority. If the replacement fails, the factory STOPs the run per the skill's Step 9.

## Host capabilities

The contract needs, in order of importance: (1) subagent dispatch with an isolated context window; (2) optional model and reasoning-effort overrides; (3) optional per-agent tool restriction; (4) — for any *future* concurrent dispatch — per-worker runtime isolation with a working toolchain inside it. Resolve resources per `execution-profiles.md`; lack of model override is a reported limitation, not a reason to invent one.

- **Claude Code**: (1) via the Task/Agent mechanism; (2) pass its model override when exposed (reasoning effort may remain a host default); (3) custom agent definitions can restrict tools — otherwise prompt restrictions + post-hoc scope checks stand in; (4) native worktrees provide isolation, but a fresh worktree lacks installed dependencies/build state, so workers remain serial in the shared tree. If isolated copies later include a working toolchain, concurrent dispatch is the extension point under the same spec.
- **Hosts without subagents**: multi-agent strategies are unavailable — the factory says so plainly and proceeds single-agent. This is graceful degradation, not failure: single-agent is the default anyway.
- **Limitation, stated honestly**: prompt-level write scopes are guardrails, not sandboxes. Enforcement is the factory's post-hoc scope check before anything is committed. Serial execution is likewise a correctness choice, not a runtime constraint dressed up as one: write-scope disjointness cannot stop a repo-wide criteria command, a shared build cache, or a test run from observing a sibling's half-finished work.
