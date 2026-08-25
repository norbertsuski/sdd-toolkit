---
name: sdd-run
description: >
  Drive an SDD change from whatever state it is in to an implemented, verified
  result — the Agent Factory entrypoint for the sdd-* family. Inspects the
  change's lifecycle state, routes through missing preparation (frame /
  research / plan), selects an execution strategy (single-agent, sequential
  multi-agent, or multi-agent DAG), constructs ephemeral scoped workers when — and
  only when — decomposition pays for itself, selects model/effort execution
  profiles for workers and review, coordinates their execution,
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
 select strategy        (single-agent default · sequential · multi-agent DAG)
 classify resources     (per-phase model tier · effort · context · verification)
 construct workers      (ephemeral, task-derived — only when strategy is multi-agent)
 execute                (existing executor contracts: /sdd-implement, /sdd-goal-implement)
 verify independently   (existing review dimensions)
 retry / STOP           (bounded — /sdd-goal-implement semantics)
 persist + report       (## Progress + factory-log.md)
```

This skill operates under the `CONTEXT_ROOT` it resolves for the given change-id — `app:` may be absent for flat roots; do not require it.

## When to use, when to skip

**Use when**: a change exists (or should exist) and the user wants it *driven* — "get this change done", "continue from wherever it is", "execute this plan, parallelize if it helps". Also when returning to a half-done change after an interruption.

**Skip when**: the user wants direct control of one step — run the owning skill instead (`/sdd-plan`, `/sdd-implement`, `/sdd-impl-review`, …); the whole manual pipeline keeps working without this skill. Also skip for whole-roadmap sequencing (`/sdd-roadmap` to generate it, `/sdd-project-run` to drive it — the project-level factory one layer above this one) or the phased test rollout (`/sdd-test-plan` — its own orchestrator).

## Relationship to other skills

| Skill | Role for the factory |
|---|---|
| `/sdd-new`, `/sdd-frame`, `/sdd-research`, `/sdd-plan`, `/sdd-plan-review` | Preparation stages. The factory **routes** to them when their artifact is missing; it never generates frame/research/plan content itself (they are interview-driven by design — never invent). |
| `/sdd-implement` | The attended single-agent executor. The factory hands the session to its process for single-agent attended runs, and reuses its phase-end commit ritual verbatim when committing worker output. |
| `/sdd-goal-implement` | The unattended executor. Source of the factory's non-interaction policy, gate stack, mismatch taxonomy, 2-attempt self-fix budget, and STOP block. Workers execute one phase under a scoped subset of this contract (criteria gates only); the factory itself runs the rest of the gate stack — staging, break-check, repo-wide checks, commit — at integration. |
| `/sdd-tdd`, `/sdd-e2e` | Execution variants. When the user asks for test-first or browser-level execution, the factory routes the relevant phases to them instead of `/sdd-implement`; their own eligibility gates rule. |
| `/sdd-impl-review`, `/sdd-impl-review-ci` | Independent verification — part of the factory's completion contract (Step 8). Attended runs run `/sdd-impl-review`; unattended runs dispatch a reviewer subagent applying `../sdd-impl-review-ci/references/impl-review-instructions.md`, including its APPROVED / NEEDS ATTENTION / REJECTED verdict model. |
| `/sdd-mr`, `/sdd-archive` | Downstream closeout. The factory names them in its final report; it does not run them unasked. |
| `/sdd-help` | Read-only sibling. `/sdd-help` reports state and recommends; `/sdd-run` acts on that same derivation. |
| `/sdd-project-run` | **Parent orchestrator** (the Project Factory). It selects a roadmap item's Change ID, invokes this skill for it — one change at a time — and consumes the `FACTORY RESULT` block (Step 11, `references/run-result-contract.md`) to decide what happens next at project level. This skill neither knows nor cares whether it was invoked by a human or by the project factory: same process, same gates, same outputs. Whole-project sequencing stays out of this skill by design. |

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
| No `plan.md`, no `research.md`, and the change is non-trivial in unfamiliar territory (intent names meaningful codebase exploration, an unfamiliar subsystem, or broad architectural surface — the same signal `/sdd-new` uses to suggest research) | Recommend `/sdd-research <change-id>` before planning; offer inline run or skip to planning (research is optional by family rule — `/sdd-plan` runs fine without it, it just asks more) | STOP — `Missing prerequisite: plan.md. Run /sdd-plan <change-id> interactively (consider /sdd-research <change-id> first).` |
| No `plan.md` | Run `/sdd-plan <change-id>` inline (it interviews the user), or hand off via clipboard | STOP — `Missing prerequisite: plan.md. Run /sdd-plan <change-id> interactively.` |
| `plan.md` exists, no `reviews/plan-review.md`, status `planned` | Ask once: proceed to execution, or run `/sdd-plan-review <change-id>` first (recommended when the plan has many phases or a wide blast radius). After an inline review completes and its findings are triaged, re-enter this routing | Proceed, and record `plan-review: skipped` in the run report (matches `/sdd-goal-implement`, which does not require review) |
| `plan.md` with pending `#### Automated` rows | **Execution path** — continue to Step 3 | Same |
| Only `#### Manual` rows pending (all Automated `[x]`) | No executable work — present the pending manual checklist and gate on it (this is the phase pause a human resolves); then continue to the completed-rows routing below | No dispatch (there is no automated worker to send — matches `/sdd-goal-implement`, where implementation completes on Automated rows). Run Step 8 verification if not yet done, surface the manual rows as the report's human checklist, and STOP — never loop |
| All Automated `[x]`, verification snapshot is absent/stale per `references/verification-freshness.md` (whether or not old review/log evidence exists) | Run fresh Step 8 (`/sdd-impl-review <change-id>`); then name `/sdd-mr` / `/sdd-archive` | Run unattended Step 8, then report |
| All Automated `[x]`, verification snapshot is current | Report according to its selected verdict; name `/sdd-mr <change-id>` only for a positive disposition (or `/sdd-archive <change-id>` if integrated) and STOP | Same, non-interactively |

Routing to an interactive prep skill **inline** means invoking that skill's process in this same session with the user present — its questions, its artifacts, its gates, unchanged. When the user prefers a fresh context, use the family's clipboard handoff instead (copy the command, tell them to `/clear` and run it, STOP). Never generate a frame, research doc, or plan by shortcut: thin prep produces exactly the misframed work the prep skills exist to prevent.

When the route lands on the execution path, apply `references/verification-freshness.md`: with pending Automated work, update `change.md` to `status: implementing` from `{planned, plan_reviewed, implemented, impl_reviewed}` and bump `updated`. The old snapshot may remain as audit fields but is stale by status.

**Status normalization on completed routes.** Progress is canonical; `change.md.status` is derived. When a route matches on "all Automated rows `[x]`" but `status` is still `implementing` (a crash landed between the last flip and the executor's status update), normalize: set `status: implemented`, `updated: <today>`, narrate the normalization, and stage `change.md` into the run's closing commit (the epilogue, or the verification-only `chore` commit from Step 10). Never the reverse — a status claiming more than Progress shows is drift to *report*, not to trust.

### Step 3: Parse the plan and the remaining work

Read `plan.md` fully (never limit/offset), plus every artifact it references (`research.md`, `frame.md`). Extract, for each phase with pending Progress rows:

- phase number, title, and `### Changes Required` file paths,
- an optional `**Depends on**: Phase X[, Phase Y]` line in the phase block (plans may declare dependencies explicitly; absent = the phase depends on the previous one),
- Automated / Manual success criteria and their commands,
- whether the phase is code-producing or verification/manual-only.

Completed phases (`[x]`) are **done** — trust them (re-verify only if something looks off, per `/sdd-implement`'s resume rule). The **work-list** is every phase with pending `#### Automated` rows, matching `/sdd-goal-implement`'s resume rule. A phase whose only pending rows are Manual is not executable work: attended runs gate on it at that phase's manual-verification pause; unattended runs surface it on the report's human checklist and move on.

If `factory-log.md` exists in the change folder (a previous factory run), read its last run record. When its **plan fingerprint** matches the current plan (fingerprint = a hash of `plan.md` with the `## Progress` section stripped — Progress churn must not read as a plan change), **reuse the recorded dependency graph** and re-select the strategy over the *remaining* phases in Step 5 (a resumed multi-agent DAG with one phase left is just single-agent — expected, not a downgrade). On a fingerprint mismatch, re-derive everything.

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
| **multi-agent DAG** | One ephemeral worker per phase, executed in DAG order. Independence buys failure isolation (a stopped phase never blocks a genuinely independent sibling) and honest integration waves — **not concurrent dispatch; workers run one at a time** (see Step 6, invariant 3, for why). | ≥2 provably independent phases, each substantial (multiple files or an independent subsystem). |

Multi-agent execution is **never automatic**. `rename a prop + update components + fix tests` is a single-agent job however its plan slices the phases. Print the decision in one block so it is explainable and lands in `factory-log.md`:

```
Strategy: multi-agent DAG
Why: P2 (API) and P3 (frontend) touch disjoint file sets with no cross
     references; both are multi-file. P1 must land first (schema they
     both consume); P4 integrates both. Execution is serialized;
     the graph isolates failures between P2 and P3.
Graph: P1 → {P2 ∥ P3} → P4
```

Validate the graph before executing: an unknown phase in a `**Depends on**:` line, or a dependency cycle, is a plan defect — print the STOP block (structural) naming it; the fix belongs in the plan.

Independently of strategy, classify each pending phase (or inseparable inline phase group) under `references/execution-profiles.md`. Use plan scope, code boundaries, uncertainty, blast radius, and trust/data signals; inherit the parent change profile from `/sdd-project-run` when supplied as risk/context input, not as a blanket model floor. Print the full decision block for each dispatched agent and persist the profile/tier/effort in `factory-log.md`. Resolve concrete host model ids only from capabilities the active dispatch interface actually exposes; inline execution records `Resolved model: inherited`.

Select a separate reviewer profile now as a verification floor: at least the strongest risk signal across the change, with `critical` always producing heightened independent review. A mechanical child phase may be cheaper than its parent only when the decision block explains why the parent risk does not touch it.

### Step 6: Construct workers (multi-agent strategies only)

For each phase that will run as a worker, derive an **ephemeral worker spec** — from the actual task, never from a fixed persona catalog — per `references/worker-contract.md`. Each spec names: goal (the one phase), scoped context (that phase's plan block, the plan's header sections, relevant research/frame excerpts, `lessons.md`, the phase's files), the skill contract it executes under (a scoped subset of `/sdd-goal-implement`'s rules — mismatch taxonomy, self-fix budget, criteria gates; staging, break-check, and commits stay with the factory), a **write scope** (the phase's declared files + their tests; new files only within it), success criteria, the Step 5 **execution profile** (profile, model tier/resolved id, effort, context, verification, why), escalation conditions, and termination conditions (success · unrecoverable failure · self-fix budget exhausted · policy requires a human).

Three invariants keep multi-agent execution safe without extra infrastructure:

1. **Workers never write `plan.md`, never write `factory-log.md`, never run any git command that mutates state (no staging, no commits), and never perform the deliberate-break check.** They implement, run their phase's success-criteria commands, and return a structured WORKER REPORT (format in the reference).
2. **The factory is the sole writer of `## Progress`, the sole author of commits, and the owner of the full gate stack at integration.** After each worker returns it verifies the report, then runs `/sdd-goal-implement`'s gate-stack steps 2–5 over the worker's touched set — stage, deliberate-break check, repo-wide checks, commit ritual (`/sdd-implement` attended · `/sdd-goal-implement` unattended). Staging *before* the break-check is what makes the break-check's restore exact — the same reason that order exists in `/sdd-goal-implement`; a worker running the break-check unstaged would restore HEAD over its own implementation. Per-phase Conventional Commits, SHA write-back, and `change.md` bumps stay byte-identical to the existing contract.
3. **Workers execute one at a time, even inside a DAG wave.** Write scopes are disjoint, but write isolation is not runtime isolation: a phase's success-criteria commands may legitimately be repo-wide (`npm run typecheck` is a stock plan criterion), builds share caches and generated artifacts, and test runs observe the whole tree — a concurrent sibling would see half-finished work. The host's worktree isolation could give true runtime isolation, but a fresh worktree lacks installed dependencies and build state, and merging results back is machinery this family refuses; serial execution costs only wall-clock and buys correctness. The DAG still earns its keep: dependency-true ordering, failure isolation between independent siblings (Step 9), and integration waves.

### Step 7: Execute

**Dirty-tree preflight (any strategy).** Before executing, check `git status --porcelain` against the pending phases' file sets. Uncommitted changes inside a pending phase's scope **have no provenance** — they may be leftovers of an interrupted run, or the user's own uncommitted work; a path overlap proves nothing. The factory never destroys work on an assumption:

- **Attended** → present the paths via the existing dirty-path prompt: continue on top of them, restore them (the human vouches they are factory leftovers), or abort to sort it out manually.
- **Unattended** → **STOP**. Print the dirty paths and: `Cannot start unattended: uncommitted changes overlap pending phase scopes. Commit, stash, or clean them — or run /sdd-run <change-id> attended.` No `git checkout`, no deletion, ever, on preflight.

Dirty paths *outside* every pending scope are never touched either way: list them as `DIRTY (not staged)` per `/sdd-goal-implement`. **The git index is part of the preflight**: `git status --porcelain` shows staged entries too, and additionally run `git diff --cached --name-only` — a pre-existing staged entry outside the pending scopes ∪ workflow metadata would be silently bundled into every commit this run authors (`git commit` commits the whole index). Such entries get the same treatment: attended → prompt (the executor ritual's index options: abort / unstage with consent / include); unattended → STOP. The only restore the factory ever performs itself is the mid-run replacement-worker restore (Step 9), where provenance is certain: the preflight guaranteed a clean scope at dispatch, so everything dirty in a just-failed worker's scope is that worker's output.

**Execution carrier (orthogonal to strategy).** If the host exposes a model override that materially differs from the inherited session, prefer a dispatched carrier so the profile is real, not decorative:

- `single-agent` strategy: unattended (or attended with interactive relay) -> dispatch one **profiled executor** for the whole remaining work-list per `worker-contract.md`; it follows the owning full executor, is the sole writer while active, and returns its run report. Without relay in attended mode, execute inline and label the model/context axes advisory.
- any one-phase/singleton DAG wave: dispatch the normal scoped phase worker when an override is available and worth its fixed overhead; do not force inline merely because the wave has one node.
- pass model and reasoning effort independently. Model-only hosts still dispatch with host-default effort. If no meaningful override exists, inline remains the cheapest carrier.

**single-agent**: use the carrier decision above. Inline follows `/sdd-implement` attended or `/sdd-goal-implement` unattended. A profiled executor follows the same full contract in its isolated child and returns control before Step 8. Add `factory-log.md` to the factory's next closing staging set; when inline, keep adding it to every phase commit as today.

**sequential multi-agent / multi-agent DAG**: walk the DAG in waves and execute one phase at a time. A singleton uses the carrier rule above: profiled worker when a real override materially helps; inline otherwise. Per phase, in wave order:

1. **Dispatch one worker** via the host's subagent mechanism with exactly its spec from Step 6 — not the whole repo, not the full conversation — and pass the resolved model/effort override when that mechanism exposes one. If it exposes neither, use the host default and preserve the honest `Resolved model: default` record.
2. **When it returns, verify the report**: criteria narrated green; touched files ⊆ write scope (run `git status --porcelain` and diff against the declared scope — out-of-scope modifications are a gate failure, not a formality; a *reported-but-untouched* out-of-scope need follows the scope-expansion policy in Step 9); spot-check one or two claims against the diff.
3. **Run the integration gate stack** — `/sdd-goal-implement`'s gate-stack steps 2–5 over the worker's touched set, in its canonical order:
   1. **Stage** the touched set by explicit path (∪ `{plan.md, factory-log.md}`).
   2. **Deliberate-break check** (only when the phase added or changed tests): break the protected behavior worktree-only, confirm the test goes red, restore via `git checkout -- <file>` — exact *because* the implementation is staged.
   3. **Repo-wide checks** (full suite / lint / typecheck as the plan or repo defines; command discovery per `/sdd-goal-implement`'s preflight). **An integration failure here is the factory's to fix** (it is the integrator): 2 self-fix attempts under the standard budget; when the failure clearly traces to this phase, the replacement-worker path (Step 9) applies instead, with the failing output as evidence; otherwise STOP. Re-stage after any fix.
   4. **Flip Progress** rows for the phase — only now, with every gate green (Automated rows only in unattended mode; Manual rows stay `[ ]` per `/sdd-goal-implement`'s Manual-rows policy). Flipping after the gates keeps rows honest: a STOP never leaves `[x]` rows whose work failed integration.
   5. **Commit** via the executor ritual (attended: manual-verification pause + message approval; unattended: autonomous ritual). The ritual stages its set by explicit path at commit time — which **re-stages the just-flipped `plan.md`**, so the commit durably records the `[x]` rows (`git show HEAD:…/plan.md` shows the flip), never the pre-flip copy staged in sub-step 1. The ritual's unrelated-staged-paths check applies here like everywhere else.
4. **Append the phase's outcome row to `factory-log.md`** (format: `references/factory-log-format.md`) — after the commit, because the row carries the commit's SHA. Like the Progress SHA write-back, this trailing edit lands in the *next* phase's commit, or in the epilogue for the last phase.

Attended runs pause at the same points `/sdd-implement` would: the manual-verification gate per phase (present a wave's phases together when that reads better), and the continue/clear decision between waves.

### Step 8: Independent verification

The worker (or session) that implemented a phase is not the final authority on it. **Verification is part of `/sdd-run`'s completion contract**, not an optional extra — the factory claims "implemented + verified", so it verifies. After all phases complete:

- **Attended**: run `/sdd-impl-review <change-id>` (full-plan review with interactive triage). The user may decline when asked once; a declined review is recorded honestly as `Verification: SKIPPED (declined)` in the run report and `factory-log.md`.
- **Unattended**: dispatch one reviewer subagent using the separate reviewer profile selected in Step 5 and its resolved host model/effort. Reviewers get **broader context than implementers** — coherence beats minimization here. Give it: the **full `plan.md`** (read-only — including Desired End State, success criteria, architectural decisions, and `## What We're NOT Doing`, which is how prohibited-scope drift gets caught), `frame.md`/`research.md` when present, the run's changed-file list, and the review criteria in `../sdd-impl-review-ci/references/impl-review-instructions.md`. It reads code and reports; it edits nothing.

The unattended reviewer returns the **canonical verdict model** from the reference — per-dimension PASS/WARNING/FAIL and an overall **APPROVED / NEEDS ATTENTION / REJECTED** — never a bare findings list. The factory acts on the verdict, not on string-matching one severity label:

| Verdict | Factory action |
|---|---|
| APPROVED | Run completes; findings (if any) listed in the report |
| NEEDS ATTENTION | Run completes, marked `Verification: NEEDS ATTENTION` — report lists the findings and names `/sdd-impl-review <change-id>` for triage; not silently treated as success |
| REJECTED | STOP block naming the failing dimensions/findings; the human triages via `/sdd-impl-review` on return |

Record the verdict in `factory-log.md`. Skip the reviewer subagent only for trivial runs (a single phase touching ≤2 files with green gates and no `deep`/`critical` signal) — record `Verification: SKIPPED (trivial)` and say so. At every full completed disposition — APPROVED, NEEDS ATTENTION, REJECTED, SKIPPED (trivial), or attended SKIPPED (declined) — atomically write the snapshot from `references/verification-freshness.md`: `status: impl_reviewed`, exact `verified_source: factory-log:run-<K>` (or the saved attended review path), verdict, recomputed implementation fingerprint, date, and `updated`. Stage snapshot + selected evidence in the same Step 10 closing commit. The verdict controls positive/triage/rejected; status means current. Never let a worker claim substitute for integration gates.

### Step 9: Failure, retry, STOP

Inherit `/sdd-goal-implement`'s semantics wholesale — mismatch taxonomy (minor → adapt + narrate; structural → STOP), the 2-attempt self-fix budget per gate, never weakening tests/lint/types to pass, and the STOP block format. The factory adds one bounded layer on top, and classifies from the worker's `Stopped because` line:

- **Gate-failure STOPs** (a defect: the phase's criteria red after 2 self-fix attempts, a failed integration break-check that traces to this phase, an out-of-scope *modification*) get **one** fresh replacement worker — same goal/scope **plus** the failure evidence (failing output, the prior attempt's diagnosis). Apply `references/execution-profiles.md`'s evidence-based escalation: `light -> standard`, `standard -> deep`, and `deep -> critical` only when a newly discovered critical-risk signal justifies it; a deterministic failure with complete evidence may keep its profile when more reasoning would not help (record why). The replacement starts from a restored-clean scope; escalation never expands permissions or retry count.
- **Structural-mismatch STOPs** (the plan cannot be followed as written: missing dependency, architecture differs, referenced API absent) get **no** replacement — a fresh worker faces the same wall. Print the STOP block directly; the fix is a plan correction, which is a human's call.
- **Scope-expansion requests are not failures.** A worker that reports an out-of-scope need *without touching it* (`Out-of-scope needs` in its report) gets this policy: the factory verifies the claim against the code (the file exists — or is a new file the phase's Intent/Contract clearly implies; the phase genuinely requires it; it is not owned by another pending phase — if it is, that is a dependency the graph missed → structural STOP), **and then runs the new paths through the same dirty-tree preflight gate as Step 7** — the original preflight never looked at paths outside the declared scopes, so an expansion target may hold the user's own uncommitted or staged work. Clean → re-dispatch the same worker spec with the widened scope, narrate `SCOPE+: <paths> (<why>)`, and record it in `factory-log.md`. Dirty or staged → the expansion must not take ownership: attended → the Step 7 dirty-path prompt; unattended → STOP (no restore, no reset, no deletion — ever). No restore precedes an accepted re-dispatch — the widened worker continues on top of its own prior in-scope work, and the phase integrates **once**, after the widened attempt returns. One expansion re-dispatch per phase; a second expansion request means the plan's file map is wrong → structural STOP. Unverifiable or plan-contradicting requests → STOP. Routine, evidenced expansion never needs a human; it only needs to be observable.
- If a replacement also fails, print the STOP block (goal-implement format, plus a `Worker:` line naming the phase/worker) and halt the run. Dependent phases never start; a genuinely independent sibling in the same wave (per the DAG) may still be executed and committed before halting, so the STOP leaves maximum durable progress.
- **The replacement budget spans runs.** If the previous run's `factory-log.md` shows this same phase already stopped after a replacement and the plan fingerprint is unchanged, do not silently retry again: attended → ask; unattended → STOP immediately, pointing at the prior failure. Re-running the factory must not become an unbounded retry loop. (A crash can lose the last uncommitted log row, which at worst grants one extra replacement once — bounded, and noted in the reference.)

Escalate to the human — instead of retrying — when the failure is a **decision, not a defect**: ambiguous or contradictory specification, a product choice no artifact answers, a destructive/irreversible operation, or an architectural call the plan reserved for review. Routine implementation failures are retried within budget, never escalated.

STOP hygiene: completed rows stay flipped, committed phases stay committed, in-progress work stays uncommitted in the worktree, `factory-log.md` records the failure. Resume needs nothing extra — the next run's dirty-tree preflight surfaces the leftovers (attended: prompt; unattended: STOP with the paths — it never cleans them unasked).

### Step 10: State and resume

Two persistence surfaces, both existing conventions:

- **`## Progress` in `plan.md`** — the single source of truth for *work* state, exactly as today. The factory (or its executors) flips rows and writes SHAs; nothing new.
- **`$CONTEXT_ROOT/changes/<change-id>/factory-log.md`** — append-only record of *orchestration* state: per run, the strategy + why, the plan fingerprint, the dependency graph, per-phase execution profiles/outcomes/retries, reviewer profile, verification result. Format and parsing contract: `references/factory-log-format.md`. It exists so a resumed run (and a reviewing human) can see which strategy/resources were chosen and why without re-deriving — it is **not** a second progress tracker; if it disagrees with Progress, Progress wins. Mid-run entries land with each phase commit (Step 7); the closing lines (reviewer profile, verification, project impact, result, and `change.md -> impl_reviewed`) are staged into the executor's epilogue commit alongside `plan.md` and `change.md`. A run that authored **no** phase commits still commits its log entry and freshness transition in one small `chore(<change-id>): factory log (verification)` commit; never leave the record stranded uncommitted.

Re-running `/sdd-run <change-id>` after an interruption: Step 2 re-derives state from disk, Step 3 finds the pending Automated rows, completed phases are skipped, and the recorded graph is reused when the plan fingerprint matches (Step 3). No other state is needed.

### Step 11: Final report

End every run that reached execution or verification — complete or stopped — with a run report (the `/sdd-goal-implement` report, extended with the factory sections). A run that stopped in Step 2 on missing preparation prints its routing message only: nothing was orchestrated, so there is no report and no `factory-log.md` entry — but it still emits the `FACTORY RESULT` block below (with `Stop class: missing-prep` and most fields `—`), so a parent orchestrator gets one uniform surface at every terminal point.

```
RUN REPORT — <change-id>

Strategy: <single-agent | sequential multi-agent | multi-agent DAG> — <one-line why>
Graph:    <compact DAG, multi-agent only>
Profiles: <P1 light, P2 deep, reviewer deep — include resolved model ids only when host exposed them>

Phases: <completed>/<total>
- P1 <title> — <sha> (worker: inline | w1; gates: PASS)
- P2 <title> — <sha> (worker: w2; gates: PASS)
- P3 <title> — <sha> (worker: w3; retries: 1)
- P4 <title> — STOPPED (<reason>)          ← when applicable

Verification: <impl-review: <verdict> | reviewer: APPROVED / NEEDS ATTENTION / REJECTED (N findings) | SKIPPED (trivial) | SKIPPED (declined)>
Retries: <per-phase counts, or "none">
Human interventions: <list, or "none">

Pending manual verification (human checklist):
- <phase>.<index> <title>

Suggested follow-up: /sdd-impl-review <change-id>   (or /sdd-mr <change-id> when reviewed)
```

When `audience: plain`, give the report per the plain-mode contract (what got built, what still needs a person) and suggest `/sdd-mr` instead of `/sdd-impl-review`.

**Emit the `FACTORY RESULT` block** as the very last output of every invocation — after the run report when one was printed, alone after a Step 2 preparation stop. Format, field semantics, and the `Project impact` derivation rules: `references/run-result-contract.md`. This block is the stable outcome contract a parent orchestrator (`/sdd-project-run`) consumes — classify honestly (`Outcome`, `Stop class`, `Verification`, `Project impact`), keep each list line to one sentence, and never suppress a roadmap-reaching discovery to make the run look cleaner. The block itself is a transcript surface, but its **`Project impact` classification is also persisted** — written into the run's `factory-log.md` closing lines (`references/factory-log-format.md`) alongside the verification verdict, so a parent resuming after this session can still see that the run discovered something roadmap-reaching.

## Critical guardrails

1. **Compose, never re-implement.** Prep artifacts come only from their owning skills. Execution follows the existing executor contracts. Verification reuses the existing review dimensions. If the factory is doing something no existing skill defines, it should be orchestration — not domain work.
2. **Single-agent is the default.** Multi-agent execution requires provable phase independence *and* enough per-phase substance to beat coordination cost. The strategy decision is always printed and logged.
3. **One writer for state and git.** In multi-agent runs, only the factory mutates `## Progress`, `change.md`, `factory-log.md`, or authors commits. Workers report; the factory integrates. Never let two writers touch the plan.
4. **Write scopes are guardrails, checked post-hoc.** A worker's out-of-scope *modification* is a gate failure; a *reported* out-of-scope need goes through the evidenced scope-expansion policy (Step 9). Scopes come from the phase's own declared files — never invent artificial boundaries that make the phase unimplementable.
5. **Bounded everything.** 2 self-fix attempts per gate (worker-internal and factory-integration alike), 1 fresh worker per failed phase, 1 scope-expansion re-dispatch per phase, then STOP. No loops without budgets.
6. **Honor every existing human gate.** Attended runs pause where `/sdd-implement` pauses. Unattended runs never flip Manual rows and never invoke interactive tools. Escalation is for genuine human decisions, not routine failures.
7. **Never destroy uncommitted work on an assumption.** Dirty files without provenance are the human's, until the human says otherwise (attended prompt) — unattended runs STOP instead. The only autonomous restore is the mid-run replacement restore, where the preflight's clean-scope guarantee makes provenance certain.
8. **Progress stays canonical; durable events stay durable.** `factory-log.md` never becomes a second progress tracker, but its retry, selected verification, and Project-impact events are consumed by resume/project orchestration. Missing event history triggers conservative recovery, never silent success.
9. **Archived is read-only.** Refuse to operate under `$CONTEXT_ROOT/archive/…`, like every other writing skill in the family.
10. **Resource routing is evidence-based and honest.** Apply `references/execution-profiles.md`; choose the cheapest profile supported by task evidence, escalate only within the existing bounded replacement, and never claim a model/effort override the host did not expose.

## Notes

- Backward compatibility is additive: `change.md` gains optional verification identity/fingerprint fields per `references/verification-freshness.md`; legacy reviewed changes are conservatively re-verified once. Existing fields remain. `factory-log.md` is also the durable source selected by unattended snapshots and project-impact resume checks. Individual skills keep working standalone under the shared freshness contract.
- The `FACTORY RESULT` block (`references/run-result-contract.md`) is additive: it changes no artifact, and a human-driven run loses nothing by ignoring it. Its consumer is the project-level factory (`/sdd-project-run`), which delegates one change at a time to this skill and classifies the outcome from the block instead of parsing prose.
- The optional per-phase `**Depends on**:` line (see `/sdd-plan`) is the plan author's way to declare phase independence explicitly; without it the factory infers conservatively and mostly stays sequential — which is correct, not a limitation.
- Host capability mapping (what the factory needs from the runtime, and what degrades how) lives in `references/worker-contract.md` — subagent dispatch with isolated context, and per-agent tool restriction where supported. Concurrent dispatch is deliberately not used (Step 6, invariant 3); if a future host provides worktree isolation with a working toolchain inside it, that is the extension point for real concurrency. Nothing here requires a database, broker, daemon, or external orchestrator: files, markdown, git, subagents.
- Model/effort routing and its host-agnostic tier mapping live in `references/execution-profiles.md`. The stable contract is profile + tier + effort + evidence; concrete model names are resolved and logged at runtime because vendor catalogs drift.
- Phase-type execution routing (test-first, browser-level) rides on the executors' own gates: `/sdd-tdd` and `/sdd-e2e` already decide per phase whether they fit and redirect otherwise. The factory does not duplicate that detection — when the user asks for a variant, it routes the relevant phases there and lets the variant's gate rule.
