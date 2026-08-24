# Execution strategy selection — dependency analysis and the single-agent default

Shared contract for how `/sdd-run` turns a plan's pending phases into a dependency graph and picks an execution strategy. The bias is deliberate: **when the analysis is uncertain, the answer is single-agent.** Multi-agent orchestration must be earned by the plan, never assumed.

## Dependency analysis

Input: the pending phases of `plan.md` (each with its `### Changes Required` file paths and success criteria). Output: a DAG — nodes are phases, edges are "must complete before".

1. **Explicit declaration wins — for ordering.** A phase block may carry `**Depends on**: Phase X[, Phase Y]` (an optional line `/sdd-plan` can emit; absent in most existing plans). When present, those are the phase's exact dependencies — including `**Depends on**: —` meaning "independent of everything before it". Before *treating* declared-independent phases as independent, the factory still re-checks **all four** independence tests below: plans drift, and disjoint paths alone prove nothing — a phase whose criteria exercise another phase's behavior (test 3), or that shares a generated artifact (test 4), is semantically dependent however the plan labels it. A declaration that fails any test gets its edge restored with a narrated note. Declarations can only relax ordering that the code still supports; they cannot force unsafe independence.
2. **Default without declaration: the linear chain.** Phase N depends on Phase N-1. This matches how plans are written and read today, and it is always safe.
3. **Relaxing an inferred edge** (declaring two undeclared phases independent) is allowed only when **all four** independence tests pass:

| # | Test | Fails when (examples) |
|---|---|---|
| 1 | **Disjoint files** — the phases' `Changes Required` path sets (plus their obvious test files) do not intersect | Both phases touch `src/api/routes.ts`; both edit the same config |
| 2 | **No contract reference** — neither phase's Intent/Contract text names a symbol, endpoint, schema field, or type the other phase creates or changes | Phase 3 renders a field Phase 2's API adds; Phase 4 imports a helper Phase 2 introduces |
| 3 | **No criteria coupling** — neither phase's success-criteria commands consume the other's output | Phase 3's test hits an endpoint Phase 2 implements |
| 4 | **No shared generated artifact** — no common migration, codegen output, lockfile-affecting dependency change, or global config both would mutate | Both phases add a package; both extend the same generated client |

4. **When in doubt, keep the edge.** A false dependency costs minutes of wall-clock. A false independence ships two locally-correct, globally-incompatible implementations — the exact failure mode context isolation must not create.
5. **Validate the graph.** Every phase named in a `**Depends on**:` line must exist, and the edge set must be acyclic (walk it; a cycle means two phases each claim to need the other first). Either violation is a plan defect → structural STOP naming it; the fix belongs in the plan, not in a guessed ordering.

Cross-cutting context is the counterweight to isolation: even independent workers receive the plan's Overview / Desired End State / Key Discoveries sections (see `worker-contract.md`), so independent work stays coherent with the whole.

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

### multi-agent DAG

One ephemeral worker per phase, executed in DAG order, wave by wave (a wave = all phases whose dependencies are complete). **Execution is serial even inside a wave** — write-scope disjointness is not runtime isolation: a phase's criteria commands may be repo-wide (`npm run typecheck` is a stock plan criterion), builds share caches, and test runs observe the whole tree, so a concurrent sibling would see half-finished work (the skill's Step 6, invariant 3). What the DAG buys instead of wall-clock:

- **dependency-true ordering** — a phase never runs before its actual prerequisites, and never waits on a false one;
- **failure isolation** — when a phase STOPs after its retry, a genuinely independent sibling can still execute and commit before the run halts; a linear chain would abandon it;
- **honest integration** — each phase is verified, break-checked, repo-wide-checked, and committed at a wave boundary, one at a time.

Choose only when **all** of these hold:

- the DAG (after honest analysis) contains ≥2 phases in some wave;
- each such phase is substantial — multiple files or a distinct subsystem, real implementation work;
- write scopes are disjoint (already guaranteed by test 1, re-checked at dispatch);
- coordination cost < benefit (below).

## Coordination cost vs. benefit

Workers cost what a single agent does not pay: composing specs, re-reading context the session already had, report verification, and a wider surface for inconsistency. What they buy is **fresh scoped context per phase** (a heavy phase gets a clean window instead of a degraded one) and, for the DAG, the failure isolation above — not wall-clock; execution is serial either way.

Rule of thumb: give a phase its own worker only when the phase is of multi-file feature scale (an API layer, a frontend surface, a migration + backfill) — never for one-file edits. Three trivial phases as three workers are strictly worse than one agent doing them in order.

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

### Scenario B — parallelizable feature → multi-agent DAG

Plan: P1 database migration, P2 API changes, P3 frontend changes, P4 integration tests. P2 and P3 declare `**Depends on**: Phase 1`; P4 declares `**Depends on**: Phase 2, Phase 3`.

- P2 (`src/server/**`) and P3 (`src/client/**`): disjoint files, no cross contracts (both consume P1's schema, neither consumes the other), criteria independent, no shared codegen → independent.
- Both are multi-file subsystem work → substance test passes.

```
Strategy: multi-agent DAG
Why: P2 and P3 touch disjoint subsystems with no cross references; both
     are multi-file. P1 must land first (schema both consume); P4
     integrates both. Execution is serialized; the graph isolates
     failures between P2 and P3.
Graph: P1 → {P2 ∥ P3} → P4

Waves: [P1] → [P2, P3] → [P4]
```

Execution: P1 runs **inline** (single-phase wave — no dispatch overhead) → integrate + commit → worker for P2 (write scope `src/server/** + tests/server/**`) → integrate (verify report → stage → break-check → repo-wide checks → flip Progress → commit) → worker for P3 (write scope `src/client/** + tests/client/**`) → same integration → P4 runs inline → integrate + commit → independent verification. If P2 stops after its retry, P3 still executes and commits before the run halts — that failure isolation is what the graph buys; the workers themselves never run concurrently.

### Degenerate cases

- **All phases already `[x]` except one** → single-agent, regardless of the original strategy.
- **Plan with one phase** → single-agent, always.
- **Manual-only phase** (no Automated rows) → never a worker; it is a human checklist item (attended: gate on it; unattended: surface it in the report per the Manual-rows policy).
