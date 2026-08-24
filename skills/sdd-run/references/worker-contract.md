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
| `skill contract` | `/sdd-goal-implement`'s per-phase rules, scoped to one phase (gates a–b, mismatch taxonomy, self-fix budget) — inlined in the prompt as the rules below, with the skill file named as canonical source |
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
   without touching an out-of-scope file, STOP and report it — do not touch it.
2. Do NOT edit plan.md, change.md, or factory-log.md. Do NOT run git commit,
   push, or any state-mutating git command. The orchestrator integrates and commits.
3. Mismatches: minor (moved file, renamed symbol, import drift) → adapt and
   record an ADAPT line. Structural (missing dependency, architecture differs,
   referenced API absent) → STOP and report. When in doubt, structural.
4. Gates, in order, after implementing: (a) run each Automated success-criteria
   command for this phase; (b) if the phase adds/changes tests, run the
   deliberate-break check (invert the protected behavior, confirm the test goes
   red, restore the file exactly). Record one verdict line per gate.
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
- break-check: PASS (test went red on broken code) | N/A
Adaptations: <ADAPT lines, or "none">
Out-of-scope needs: <paths you needed but did not touch, or "none">
Stopped because: <only when STOPPED — expected/found/why, per the STOP taxonomy>
Uncertainties: <anything a human or reviewer should double-check, or "none">
```

## Report verification (factory side, per worker)

1. Report parses and `Status` is explicit; `Touched files` present on SUCCESS.
2. **Write-scope check**: `git status --porcelain` filtered to the worker's declared write scope ∪ its touched list; any modified path outside the declared scope → treat as a gate failure of that worker (retry policy applies), never silently commit it.
3. Gate verdicts all PASS on SUCCESS; spot-check one claim against the actual diff (trust, verify one).
4. Only then: run repo-wide checks (once per wave), flip the phase's Progress rows, and run the phase-end commit ritual over `touched ∪ {plan.md, factory-log.md}` — in that order (see the skill's Step 7: rows flip only after every gate is green).

A **STOPPED** report skips steps 3–4: the factory reads its `Touched files` (plus `git status --porcelain` within the scope, in case the report is incomplete) solely to compute the restore set below, then applies the skill's Step 9 classification (gate failure → replacement; structural → STOP).

## Retry (factory side)

A worker whose STOP was a **gate failure** (or whose SUCCESS failed report verification) gets **one** replacement: same spec + a `PRIOR ATTEMPT` context block (failing gate output, the first worker's diagnosis, its adaptations). Structural-mismatch STOPs get no replacement — the skill's Step 9 escalates them directly. Before dispatching the replacement, restore the failed worker's scope to a clean state: `git checkout -- <paths>` for tracked files it modified, **and delete the untracked files it created** (from its touched list and the porcelain `??` entries inside its scope) — checkout alone does not remove new files, and the replacement must not build on debris. In a parallel wave, dispatch the replacement after the wave's successful phases are integrated and committed. If the replacement fails, the factory STOPs the run per the skill's Step 9.

## Host capabilities

The contract needs, in order of importance: (1) subagent dispatch with an isolated context window; (2) parallel dispatch in one message; (3) optional per-agent tool restriction; (4) optional worktree isolation.

- **Claude Code**: (1)+(2) via the Task/Agent mechanism with `subagent_type: "general-purpose"`; (3) via custom agent definitions when the project ships them — otherwise the prompt-level restriction + post-hoc scope check stand in; (4) exists but is intentionally unused here (disjoint write scopes make the shared worktree safe; see the skill's Step 6).
- **Hosts without subagents**: multi-agent strategies are unavailable — the factory says so plainly and proceeds single-agent. This is graceful degradation, not failure: single-agent is the default anyway.
- **Limitation, stated honestly**: prompt-level write scopes are guardrails, not sandboxes. Enforcement is the factory's post-hoc scope check before anything is committed. If a host later offers true per-agent filesystem scoping, adopt it under the same spec field without changing this contract.
