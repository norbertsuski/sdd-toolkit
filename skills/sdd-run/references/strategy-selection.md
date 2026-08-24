# Execution strategy selection — dependency analysis and the single-agent default

Shared contract for how `/sdd-run` turns a plan's pending phases into a dependency graph and picks an execution strategy. The bias is deliberate: **when the analysis is uncertain, the answer is single-agent.** Multi-agent orchestration must be earned by the plan, never assumed.

## Dependency analysis

Input: the pending phases of `plan.md` (each with its `### Changes Required` file paths and success criteria). Output: a DAG — nodes are phases, edges are "must complete before".

1. **Explicit declaration wins — for ordering.** A phase block may carry `**Depends on**: Phase X[, Phase Y]` (an optional line `/sdd-plan` can emit; absent in most existing plans). When present, those are the phase's exact dependencies — including `**Depends on**: —` meaning "independent of everything before it". Before actually *parallelizing* declared-independent phases, the factory still re-checks tests 1–2 below (disjoint files, no contract reference): plans drift, and a declaration that fails them gets its edge restored with a narrated note. Declarations can only relax ordering that the code still supports; they cannot force unsafe parallelism.
2. **Default without declaration: the linear chain.** Phase N depends on Phase N-1. This matches how plans are written and read today, and it is always safe.
3. **Relaxing an inferred edge** (declaring two undeclared phases independent) is allowed only when **all four** independence tests pass:

| # | Test | Fails when (examples) |
|---|---|---|
| 1 | **Disjoint files** — the phases' `Changes Required` path sets (plus their obvious test files) do not intersect | Both phases touch `src/api/routes.ts`; both edit the same config |
| 2 | **No contract reference** — neither phase's Intent/Contract text names a symbol, endpoint, schema field, or type the other phase creates or changes | Phase 3 renders a field Phase 2's API adds; Phase 4 imports a helper Phase 2 introduces |
| 3 | **No criteria coupling** — neither phase's success-criteria commands consume the other's output | Phase 3's test hits an endpoint Phase 2 implements |
| 4 | **No shared generated artifact** — no common migration, codegen output, lockfile-affecting dependency change, or global config both would mutate | Both phases add a package; both extend the same generated client |

4. **When in doubt, keep the edge.** A false dependency costs minutes of wall-clock. A false independence ships two locally-correct, globally-incompatible implementations — the exact failure mode context isolation must not create.

Cross-cutting context is the counterweight to isolation: even independent workers receive the plan's Overview / Desired End State / Key Discoveries sections (see `worker-contract.md`), so parallel work stays coherent with the whole.

## The three strategies

### single-agent (default)

All pending phases execute in order, in this session, under the existing executor contract (`/sdd-implement` attended, `/sdd-goal-implement` unattended). No workers, no dispatch overhead, full context continuity.

Choose when **any** of these holds — and note that most changes hit at least one:

- fewer than ~3 pending phases, or the graph is a pure chain;
- phases share files or contracts (tests 1–4 fail anywhere);
- per-phase scope is small (≤2–3 files) — dispatch + report + integrate costs more than it saves;
- the plan is small overall (few phases, few files, narrow blast radius), or the run is a resume with only 1–2 phases left.

### sequential multi-agent

One ephemeral worker per phase, run one at a time; the factory integrates and commits between workers. Same order as single-agent — the difference is **fresh scoped context per phase**.

Choose when the phases are still dependent (a chain) but individually heavy: very long plans, phases whose file sets are large enough to degrade one long session, or a resume where the main context is already burdened. This is the worker-shaped version of `/sdd-implement`'s existing "Clear context first" option.

### parallel DAG

Independent phases run as concurrent workers, wave by wave (a wave = all phases whose dependencies are complete). The factory integrates each wave serially: verify reports → flip Progress → repo-wide checks → per-phase commits.

Choose only when **all** of these hold:

- the DAG (after honest analysis) contains ≥2 phases in some wave;
- each parallel phase is substantial — multiple files or a distinct subsystem, real implementation work;
- write scopes are disjoint (already guaranteed by test 1, re-checked at dispatch);
- coordination cost < benefit (below).

## Coordination cost vs. parallelization benefit

Parallel execution buys wall-clock only on the workers' implementation time. Everything else is overhead the single-agent path does not pay: composing worker specs, workers re-reading context the session already had, report verification, serialized integration (repo-wide checks + commits are sequential regardless), and a wider surface for inconsistency.

Rule of thumb: parallelize a wave only when each parallel phase would plausibly take **as long as or longer than the whole integration overhead** — in practice, phases of multi-file feature scale (an API layer, a frontend surface, a migration + backfill), never one-file edits. Three trivial phases in parallel are strictly worse than one agent doing them in order.

## Worked examples

### Scenario A — small change → single-agent

Plan: `rename an API property` → P1 rename + update three components, P2 fix tests.

- P2's tests exercise P1's rename → test 3 fails → chain.
- Two small phases, shared surface.

```
Strategy: single-agent
Why: 2 phases, P2's criteria consume P1's rename (criteria coupling);
     per-phase scope is small — coordination would cost more than it saves.
Graph: P1 → P2
```

### Scenario B — parallelizable feature → parallel DAG

Plan: P1 database migration, P2 API changes, P3 frontend changes, P4 integration tests. P2 and P3 declare `**Depends on**: Phase 1`; P4 declares `**Depends on**: Phase 2, Phase 3`.

- P2 (`src/server/**`) and P3 (`src/client/**`): disjoint files, no cross contracts (both consume P1's schema, neither consumes the other), criteria independent, no shared codegen → independent.
- Both are multi-file subsystem work → substance test passes.

```
Strategy: parallel DAG
Why: P2 and P3 touch disjoint subsystems with no cross references; both
     are multi-file. P1 must land first (schema both consume); P4
     integrates both.
Graph: P1 → {P2 ∥ P3} → P4

Waves: [P1] → [P2, P3] → [P4]
```

Execution: P1 runs **inline** (single-phase wave — no dispatch overhead) → commit → workers for P2 and P3 dispatched together (disjoint write scopes: `src/server/** + tests/server/**` vs `src/client/** + tests/client/**`) → integrate in phase order (verify report → repo-wide checks once → flip Progress → commit P2, then P3) → P4 runs inline → commit → independent verification.

### Degenerate cases

- **All phases already `[x]` except one** → single-agent, regardless of the original strategy.
- **Plan with one phase** → single-agent, always.
- **Manual-only phase** (no Automated rows) → never a worker; it is a human checklist item (attended: gate on it; unattended: surface it in the report per the Manual-rows policy).
