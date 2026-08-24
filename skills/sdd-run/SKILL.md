---
name: sdd-run
description: >
  Drive an SDD change from whatever state it is in to an implemented, verified
  result — the Agent Factory entrypoint for the sdd-* family. Inspects the
  change's lifecycle state, routes through missing preparation (frame /
  research / plan), selects an execution strategy (single-agent, sequential
  multi-agent, or parallel DAG), constructs ephemeral scoped workers when — and
  only when — decomposition pays for itself, coordinates their execution,
  verifies independently, and resumes after interruption. Use when the user
  says "run this change", "drive the change end to end", "sdd run", "execute
  the plan with agents", "agent factory", "finish this change", "przeprowadź
  zmianę", or wants one command that continues an SDD change from its current
  point. Use AFTER a change exists (or to route into creating one); individual
  skills (/sdd-plan, /sdd-implement, …) remain the direct-control path.
---

# /sdd-run — Agent Factory for a Single Change

One command that takes a change-id and drives the change from its current lifecycle state toward `implemented` + verified. It is a **composition layer over the existing `sdd-*` skills, not a replacement** for any of them.

The design principle:

> The factory contains no software-development knowledge of its own. It inspects state, selects an execution strategy, and composes existing skills, scoped context, and permissions into short-lived workers appropriate for the current specification.

```
SPEC / CHANGE
     │
     ▼
 inspect state          (change.md status + artifacts on disk)
 route missing prep     (frame / research / plan — owning skills, never invented here)
 analyze the plan       (phases, files, dependencies)
 select strategy        (single-agent default · sequential · parallel DAG)
 construct workers      (ephemeral, task-derived — only when strategy is multi-agent)
 execute                (existing executor contracts: /sdd-implement, /sdd-goal-implement)
 verify independently   (existing review dimensions)
 retry / STOP           (bounded — /sdd-goal-implement semantics)
 persist + report       (## Progress + factory-log.md)
```

This skill operates under the `CONTEXT_ROOT` it resolves for the given change-id — `app:` may be absent for flat roots; do not require it.

## When to use, when to skip

**Use when**: a change exists (or should exist) and the user wants it *driven* — "get this change done", "continue from wherever it is", "execute this plan, parallelize if it helps". Also when returning to a half-done change after an interruption.

**Skip when**: the user wants direct control of one step — run the owning skill instead (`/sdd-plan`, `/sdd-implement`, `/sdd-impl-review`, …); the whole manual pipeline keeps working without this skill. Also skip for whole-roadmap sequencing (`/sdd-roadmap`) or the phased test rollout (`/sdd-test-plan` — its own orchestrator).

## Relationship to other skills

| Skill | Role for the factory |
|---|---|
| `/sdd-new`, `/sdd-frame`, `/sdd-research`, `/sdd-plan`, `/sdd-plan-review` | Preparation stages. The factory **routes** to them when their artifact is missing; it never generates frame/research/plan content itself (they are interview-driven by design — never invent). |
| `/sdd-implement` | The attended single-agent executor. The factory hands the session to its process for single-agent attended runs, and reuses its phase-end commit ritual verbatim when committing worker output. |
| `/sdd-goal-implement` | The unattended executor. Source of the factory's non-interaction policy, per-phase gate stack, mismatch taxonomy, 2-attempt self-fix budget, and STOP block. Workers execute one phase under this contract. |
| `/sdd-tdd`, `/sdd-e2e` | Execution variants. When the user asks for test-first or browser-level execution, the factory routes the relevant phases to them instead of `/sdd-implement`. |
| `/sdd-impl-review`, `/sdd-impl-review-ci` | Independent verification. Attended runs hand off to `/sdd-impl-review`; unattended runs dispatch a reviewer subagent applying the dimensions in `../sdd-impl-review-ci/references/impl-review-instructions.md`. |
| `/sdd-mr`, `/sdd-archive` | Downstream closeout. The factory names them in its final report; it does not run them unasked. |
| `/sdd-help` | Read-only sibling. `/sdd-help` reports state and recommends; `/sdd-run` acts on that same derivation. |

## Modes

- **Attended** (default) — a human is present. Every human gate the existing skills define is honored: the per-phase manual-verification pause, commit-message approval, mismatch decisions, dirty-path prompts. Interactive prep skills may be run inline.
- **Unattended** (`--auto`, or when running under a `/goal` session) — nobody is watching. The factory applies `/sdd-goal-implement`'s non-interaction policy wholesale: no interactive questions, explicit automatic policies, Manual Progress rows never flipped, STOP blocks on anything a policy cannot resolve. Missing preparation is a STOP, not an interview.

Resolve `audience` per `../sdd-shape/references/plain-mode.md` ("Audience resolution") for operator-facing text; artifacts are identical in both modes.

## Process

### Step 1: Resolve the change

- `/sdd-run <change-id> [--auto]` → resolve exactly as `/sdd-implement` does: glob `context/*/changes/<change-id>/` (legacy cross-root) and, for flat roots, `<dir>/context/changes/<change-id>/`; one match → use it and derive `CONTEXT_ROOT`; several → ask which root (attended) or STOP (unattended); zero → the change does not exist yet — see the `missing` row of the state table below.
- A full path argument is accepted and reveals `CONTEXT_ROOT` directly.
- **Refuse archived changes**: if the resolved path falls under `$CONTEXT_ROOT/archive/`, print "This change is archived. Open a new change with `/sdd-new` instead." and STOP.
- No argument, attended → list `$CONTEXT_ROOT/changes/*/` per discovered root and ask which change to drive. Unattended → STOP (`Cannot start: no change resolved.`).

### Step 2: Derive lifecycle state and route

Read `change.md` (status), and check which artifacts exist: `frame.md`, `research.md`, `plan.md`, `plan-brief.md`, `reviews/plan-review.md`, `reviews/impl-review*.md`, and the plan's `## Progress` completion (parse per `../sdd-plan/references/progress-format.md`: first `- [ ]` = next step; `count([x]) / count(all)` = completion). Read `$CONTEXT_ROOT/foundation/lessons.md` if present. The artifacts on disk are authoritative; `change.md.status` is cross-checked and drift is reported, not trusted over the files.

Route on the first matching row:

| State (from artifacts) | Attended action | Unattended action |
|---|---|---|
| No change folder | Offer to run `/sdd-new <change-id>` now (inline), or hand off | STOP — print `Missing prerequisite: change folder. Run /sdd-new <change-id>.` |
| Folder exists, no `plan.md`, intent (the `change.md` title + `## Notes`) looks bug/scope-shaped (per `/sdd-new`'s signal list) and no `frame.md` | Recommend `/sdd-frame <change-id>` first; offer inline run or skip to planning | STOP — `Missing prerequisite: framing. Run /sdd-frame <change-id> interactively.` |
| No `plan.md` | Run `/sdd-plan <change-id>` inline (it interviews the user), or hand off via clipboard | STOP — `Missing prerequisite: plan.md. Run /sdd-plan <change-id> interactively.` |
| `plan.md` exists, no `reviews/plan-review.md`, status `planned` | Ask once: proceed to execution, or run `/sdd-plan-review <change-id>` first (recommended when the plan has many phases or a wide blast radius). After an inline review completes and its findings are triaged, re-enter this routing | Proceed, and record `plan-review: skipped` in the run report (matches `/sdd-goal-implement`, which does not require review) |
| `plan.md` with pending `## Progress` rows | **Execution path** — continue to Step 3 | Same |
| `## Progress` fully `[x]`, no impl-review | Offer `/sdd-impl-review <change-id>`; then name `/sdd-mr` / `/sdd-archive` | Run the unattended verification of Step 8, then report |
| `## Progress` fully `[x]`, review exists | Report done; name `/sdd-mr <change-id>` (or `/sdd-archive <change-id>` if merged) and STOP | Same, non-interactively |

Routing to an interactive prep skill **inline** means invoking that skill's process in this same session with the user present — its questions, its artifacts, its gates, unchanged. When the user prefers a fresh context, use the family's clipboard handoff instead (copy the command, tell them to `/clear` and run it, STOP). Never generate a frame, research doc, or plan by shortcut: thin prep produces exactly the misframed work the prep skills exist to prevent.

When the route lands on the execution path, update `change.md`: `status: implementing` (only if currently in `{planned, plan_reviewed}`), `updated: <today>`.

### Step 3: Parse the plan and the remaining work

Read `plan.md` fully (never limit/offset), plus every artifact it references (`research.md`, `frame.md`). Extract, for each phase with pending Progress rows:

- phase number, title, and `### Changes Required` file paths,
- an optional `**Depends on**: Phase X[, Phase Y]` line in the phase block (plans may declare dependencies explicitly; absent = the phase depends on the previous one),
- Automated / Manual success criteria and their commands,
- whether the phase is code-producing or verification/manual-only.

Completed phases (`[x]`) are **done** — trust them (re-verify only if something looks off, per `/sdd-implement`'s resume rule). The **work-list** is every phase with pending `#### Automated` rows, matching `/sdd-goal-implement`'s resume rule. A phase whose only pending rows are Manual is not executable work: attended runs gate on it at that phase's manual-verification pause; unattended runs surface it on the report's human checklist and move on.

If `factory-log.md` exists in the change folder (a previous factory run), read its last run record. When its **plan fingerprint** matches the current plan (fingerprint = a hash of `plan.md` with the `## Progress` section stripped — Progress churn must not read as a plan change), **reuse the recorded dependency graph** and re-select the strategy over the *remaining* phases in Step 5 (a resumed parallel DAG with one phase left is just single-agent — expected, not a downgrade). On a fingerprint mismatch, re-derive everything.

### Step 4: Build the phase dependency graph

Derive edges between the pending phases per `references/strategy-selection.md` ("Dependency analysis"). In short:

1. An explicit `**Depends on**:` line wins.
2. Otherwise the default is the **linear chain** (each phase depends on the previous one). A pair of phases may be declared independent only when **every** independence test passes: disjoint `Changes Required` file sets, no contract/data reference from one to the other, no success-criteria command that consumes the other's output, and no shared schema/migration/generated artifact.
3. When in doubt, keep the edge. A false dependency costs a little wall-clock; a false independence ships an integration bug.

The result is a DAG over pending phases. Print it compactly (nodes = `P<N> <title>`, edges = `→`).

### Step 5: Select the execution strategy — and say why

Apply `references/strategy-selection.md`. The three strategies:

| Strategy | What it means | Default when |
|---|---|---|
| **single-agent** | This session (or one worker) executes all pending phases in order under the existing executor contract. | **Always the default.** Few phases, overlapping files, a linear graph, or small per-phase scope. |
| **sequential multi-agent** | One ephemeral worker per phase, run one at a time, each with fresh scoped context. | Phases are heavy/context-poisoning (long plans, large file sets) but still dependent — fresh context per phase beats one long session. |
| **parallel DAG** | Independent phases run as concurrent workers per DAG wave; dependent phases wait. | ≥2 provably independent phases, each substantial (multiple files or an independent subsystem), and coordination cost < wall-clock benefit. |

Multi-agent execution is **never automatic**. `rename a prop + update components + fix tests` is a single-agent job however its plan slices the phases. Print the decision in one block so it is explainable and lands in `factory-log.md`:

```
Strategy: parallel DAG
Why: P2 (API) and P3 (frontend) touch disjoint file sets with no cross
     references; both are multi-file. P1 must land first (schema they
     both consume); P4 integrates both.
Graph: P1 → {P2 ∥ P3} → P4
```

### Step 6: Construct workers (multi-agent strategies only)

For each phase that will run as a worker, derive an **ephemeral worker spec** — from the actual task, never from a fixed persona catalog — per `references/worker-contract.md`. Each spec names: goal (the one phase), scoped context (that phase's plan block, the plan's header sections, relevant research/frame excerpts, `lessons.md`, the phase's files), the skill contract it executes under (`/sdd-goal-implement`'s per-phase gates), a **write scope** (the phase's declared files + their tests; new files only within it), success criteria, and termination conditions (success · unrecoverable failure · self-fix budget exhausted · policy requires a human).

Two invariants make parallel execution safe without extra infrastructure:

1. **Workers never write `plan.md`, never write `factory-log.md`, and never commit.** They implement, run their phase-scoped gates, and return a structured WORKER REPORT (format in the reference).
2. **The factory is the sole writer of `## Progress` and the sole author of commits.** After each worker returns it verifies the report, flips that phase's Progress rows, and runs the existing phase-end commit ritual (`/sdd-implement` attended · `/sdd-goal-implement` unattended) over the worker's touched-file set — sequentially, even for a parallel wave. Per-phase Conventional Commits, SHA write-back, and `change.md` bumps all stay byte-identical to the existing contract.

Parallelism is additionally gated on disjoint write scopes (Step 4), so concurrent workers share the working tree safely. Git worktrees are deliberately **not** used: with disjoint scopes they solve no concurrency problem here, and their merge/reconciliation cost is exactly the overengineering this family avoids. (If a host offers worktree isolation and a future need arises — e.g. workers that must run mutually interfering build steps — that is the extension point; see the reference's "Host capabilities".)

### Step 7: Execute

**Dirty-tree preflight (any strategy).** Before executing, check `git status --porcelain` against the pending phases' file sets. Uncommitted modifications inside a pending phase's scope are leftovers of an interrupted run: attended → the existing dirty-path prompt (keep and continue from them, or restore); unattended → restore that scope to HEAD (tracked files via `git checkout -- <paths>`; untracked files the prior run created inside the scope are deleted) and narrate `RESTORED: <paths>` — a fresh worker must not build on unverified debris. Dirty paths *outside* every pending scope are never touched: list them as `DIRTY (not staged)` per `/sdd-goal-implement`.

**single-agent**: hand execution to the existing executor for all pending phases, inline in this session — attended → follow `/sdd-implement`'s process (manual gates, commit approvals, next-phase decisions); unattended → follow `/sdd-goal-implement`'s process (gate stack, narrated verdicts, autonomous commit ritual). Add `factory-log.md` to the touched-file set of **every** phase committed in this run, so the factory's record always lands with the change. This path adds nothing on top of the executors — that is the point.

**sequential multi-agent / parallel DAG**: walk the DAG in waves (a wave = all pending phases whose dependencies are complete). A **single-phase wave executes inline** (the executor process above, one phase) — dispatch overhead buys nothing there; only multi-phase waves dispatch workers.

1. Dispatch the wave's workers via the host's subagent mechanism (`subagent_type: "general-purpose"`), all in one message. Each gets exactly its spec from Step 6 — not the whole repo, not the full conversation.
2. Wait for the wave. Then integrate serially, in phase order, one phase at a time:
   - **Verify the report**: gates narrated green; touched files ⊆ write scope (run `git status --porcelain` and diff against the declared scope — out-of-scope modifications are a gate failure, not a formality); spot-check one or two claims against the diff.
   - **Run repo-wide checks** (full suite / lint / typecheck as the plan or repo defines; command discovery per `/sdd-goal-implement`'s preflight) — once before the wave's first commit, and again only when a later fix changed files. Workers run only their phase-scoped criteria; the repo-wide gate is the factory's, at the integration point — this also keeps concurrent workers from racing the same test suite. **An integration failure here is the factory's to fix** (it is the integrator): 2 self-fix attempts under the standard budget; when the failure clearly traces to one phase, that phase's replacement-worker path (Step 9) applies instead, with the failing output as evidence; otherwise STOP.
   - **Flip Progress** rows for that phase — only now, with every gate green (Automated rows only in unattended mode; Manual rows stay `[ ]` per `/sdd-goal-implement`'s Manual-rows policy). Flipping after the repo-wide gate keeps rows honest: a STOP never leaves `[x]` rows whose work failed integration.
   - **Commit** the phase via the executor ritual (attended: manual-verification pause + message approval; unattended: autonomous ritual), staging the worker's touched set ∪ `{plan.md, factory-log.md}`.
3. Append the wave's outcome to `factory-log.md` (format: `references/factory-log-format.md`), then start the next wave.

Attended runs pause at the same points `/sdd-implement` would: the manual-verification gate per phase (for a parallel wave, present the wave's phases together), and the continue/clear decision between waves.

### Step 8: Independent verification

The worker (or session) that implemented a phase is not the final authority on it. After all phases complete:

- **Attended**: offer `/sdd-impl-review <change-id>` (full-plan review with triage) — the existing skill, unchanged. Recommended, not forced (matches `/sdd-implement`'s completion offer).
- **Unattended**: dispatch one reviewer subagent (`subagent_type: "general-purpose"`) with the plan's Changes-Required text, the run's changed-file list, and the review dimensions from `../sdd-impl-review-ci/references/impl-review-instructions.md` (drift, scope, safety, patterns, criteria). It reads code and reports findings; it edits nothing. CRITICAL findings → STOP block naming them (the human triages via `/sdd-impl-review` on return); WARNING/OBSERVATION findings → listed in the run report. Record the verification outcome in `factory-log.md`.

Skip the reviewer subagent for trivial runs (a single phase touching ≤2 files with green gates) — normal gate output is sufficient verification there; say so in the report. Never let a worker's own success claim substitute for the repo-wide checks in Step 7.

### Step 9: Failure, retry, STOP

Inherit `/sdd-goal-implement`'s semantics wholesale — mismatch taxonomy (minor → adapt + narrate; structural → STOP), the 2-attempt self-fix budget per gate, never weakening tests/lint/types to pass, and the STOP block format. The factory adds one bounded layer on top, and classifies from the worker's `Stopped because` line:

- **Gate-failure STOPs** (a defect: tests red after 2 self-fix attempts, failed break-check, out-of-scope modification) get **one** fresh replacement worker — same spec **plus** the failure evidence (failing output, the prior attempt's diagnosis). Fresh context often clears what a poisoned context cannot. In a parallel wave, the replacement is dispatched after the wave's successful phases are integrated and committed, so it starts from a stable tree.
- **Structural-mismatch STOPs** (the plan cannot be followed as written: missing dependency, architecture differs, referenced API absent) get **no** replacement — a fresh worker faces the same wall. Print the STOP block directly; the fix is a plan correction, which is a human's call.
- If a replacement also fails, print the STOP block (goal-implement format, plus a `Worker:` line naming the phase/worker) and halt the run. Dependent phases never start; independent in-flight work in the same wave is allowed to finish and be committed, so the STOP leaves maximum durable progress.
- **The replacement budget spans runs.** If the previous run's `factory-log.md` shows this same phase already stopped after a replacement and the plan fingerprint is unchanged, do not silently retry again: attended → ask; unattended → STOP immediately, pointing at the prior failure. Re-running the factory must not become an unbounded retry loop.

Escalate to the human — instead of retrying — when the failure is a **decision, not a defect**: ambiguous or contradictory specification, a product choice no artifact answers, a destructive/irreversible operation, or an architectural call the plan reserved for review. Routine implementation failures are retried within budget, never escalated.

STOP hygiene: completed rows stay flipped, committed phases stay committed, in-progress work stays uncommitted in the worktree, `factory-log.md` records the failure. Resume needs nothing extra (the dirty-tree preflight in Step 7 handles the leftovers).

### Step 10: State and resume

Two persistence surfaces, both existing conventions:

- **`## Progress` in `plan.md`** — the single source of truth for *work* state, exactly as today. The factory (or its executors) flips rows and writes SHAs; nothing new.
- **`$CONTEXT_ROOT/changes/<change-id>/factory-log.md`** — append-only record of *orchestration* state: per run, the strategy + why, the plan fingerprint, the dependency graph, per-phase worker outcomes, retries, verification result. Format and parsing contract: `references/factory-log-format.md`. It exists so a resumed run (and a reviewing human) can see which strategy was chosen and why without re-deriving — it is **not** a second progress tracker; if it disagrees with Progress, Progress wins. Mid-run entries land with each phase commit (Step 7); the closing lines (verification, result) are staged into the executor's epilogue commit alongside `plan.md` and `change.md` — extend the epilogue's staging set with `factory-log.md` when the factory drove the run.

Re-running `/sdd-run <change-id>` after an interruption: Step 2 re-derives state from disk, Step 3 finds the pending Automated rows, completed phases are skipped, and the recorded graph is reused when the plan fingerprint matches (Step 3). No other state is needed.

### Step 11: Final report

End every run that reached execution — complete or stopped — with a run report (the `/sdd-goal-implement` report, extended with the factory sections). A run that stopped in Step 2 on missing preparation prints its routing message only: nothing was orchestrated, so there is no report and no `factory-log.md` entry.

```
RUN REPORT — <change-id>

Strategy: <single-agent | sequential multi-agent | parallel DAG> — <one-line why>
Graph:    <compact DAG, multi-agent only>

Phases: <completed>/<total>
- P1 <title> — <sha> (worker: inline | w1; gates: PASS)
- P2 <title> — <sha> (worker: w2; gates: PASS)
- P3 <title> — <sha> (worker: w3; retries: 1)
- P4 <title> — STOPPED (<reason>)          ← when applicable

Verification: <impl-review handed off | reviewer subagent: N findings (sev counts) | skipped (trivial)>
Retries: <per-phase counts, or "none">
Human interventions: <list, or "none">

Pending manual verification (human checklist):
- <phase>.<index> <title>

Suggested follow-up: /sdd-impl-review <change-id>   (or /sdd-mr <change-id> when reviewed)
```

When `audience: plain`, give the report per the plain-mode contract (what got built, what still needs a person) and suggest `/sdd-mr` instead of `/sdd-impl-review`.

## Critical guardrails

1. **Compose, never re-implement.** Prep artifacts come only from their owning skills. Execution follows the existing executor contracts. Verification reuses the existing review dimensions. If the factory is doing something no existing skill defines, it should be orchestration — not domain work.
2. **Single-agent is the default.** Multi-agent execution requires provable phase independence *and* enough per-phase substance to beat coordination cost. The strategy decision is always printed and logged.
3. **One writer for state and git.** In multi-agent runs, only the factory mutates `## Progress`, `change.md`, `factory-log.md`, or authors commits. Workers report; the factory integrates. Never let two writers touch the plan.
4. **Write scopes are guardrails, checked post-hoc.** A worker's out-of-scope modification is treated as a gate failure. But scopes come from the phase's own declared files — never invent artificial boundaries that make the phase unimplementable.
5. **Bounded everything.** 2 self-fix attempts per gate (worker-internal), 1 fresh worker per failed phase, then STOP. No loops without budgets.
6. **Honor every existing human gate.** Attended runs pause where `/sdd-implement` pauses. Unattended runs never flip Manual rows and never invoke interactive tools. Escalation is for genuine human decisions, not routine failures.
7. **Progress stays canonical.** `factory-log.md` is additive observability; it never becomes a second source of execution truth, and no other skill is required to read it.
8. **Archived is read-only.** Refuse to operate under `$CONTEXT_ROOT/archive/…`, like every other writing skill in the family.

## Notes

- Backward compatibility is a feature: every artifact this skill reads and writes (`change.md`, `plan.md` + `## Progress`, `reviews/*`) keeps its existing schema. The only new artifact is `factory-log.md`, which no other skill depends on. All individual skills keep working standalone.
- The optional per-phase `**Depends on**:` line (see `/sdd-plan`) is the plan author's way to unlock parallelism explicitly; without it the factory infers conservatively and mostly stays sequential — which is correct, not a limitation.
- Host capability mapping (what the factory needs from the runtime, and what degrades how) lives in `references/worker-contract.md` — subagent dispatch, parallel dispatch, per-agent tool restriction where supported. Nothing here requires a database, broker, daemon, or external orchestrator: files, markdown, git, subagents.
