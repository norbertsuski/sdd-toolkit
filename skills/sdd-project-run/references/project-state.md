# Project state — derivation, selection, and completion semantics

Shared contract for how `/sdd-project-run` answers, from artifacts on disk only, the questions a project orchestrator must answer deterministically: *what stage is this project in, which roadmap item runs next, is human input required, is the project done?*

**Nothing in this document is persisted.** Every state below is re-derived on every invocation from the existing SDD artifacts. The roadmap remains the single source of sequencing truth; each change's `## Progress` remains the single source of execution truth; the project log (`project-log-format.md`) is additive observability. There is deliberately no project state file — a state that can be derived reliably must not also be stored, or the two copies will drift.

## 1. Project stage (lifecycle, derived)

Evaluated top-down; the first matching row is the stage. `<slug>` is the project's foundation subfolder (`$CONTEXT_ROOT/foundation/<slug>/`).

| Stage | Detected by | Owning skill to route to |
|---|---|---|
| **uninitialized** | no context root discovered (no `context/.sdd.yml` anywhere) | `/sdd-init` |
| **unshaped** | root exists; target project has neither `foundation/<slug>/shape-notes.md` nor `foundation/<slug>/prd.md` | `/sdd-shape` |
| **shaping** | `shape-notes.md` exists with frontmatter `checkpoint.current_phase < 8`; no `prd.md` | `/sdd-shape` (it resumes from its own checkpoint) |
| **shaped** | `shape-notes.md` with `checkpoint.current_phase: 8` (its `quality_check_status` is `warned` or `accepted` at that point); no `prd.md` | `/sdd-prd` |
| **specified** | `prd.md` exists; no `roadmap.md`; the stack signal (below) is absent | the stack step — greenfield: `/sdd-tech-stack-selector`; brownfield: `/sdd-stack-assess` then `/sdd-health-check` |
| **stack-informed** | `prd.md` exists; stack signal present; no `roadmap.md` | `/sdd-roadmap` |
| **roadmapped** | `roadmap.md` exists, at least one `## At a glance` row not `done` | the execution loop (§2–§4) |
| **complete** | `roadmap.md` exists, every `## At a glance` row `done` | `/sdd-archive-project` (named, never auto-run) |

Notes that keep this table honest:

- **`prd.md` presence wins over shape state.** A hand-written PRD without shape-notes is legitimate; detection never demands the upstream artifact exist.
- **Do not gate on `prd.md`/`roadmap.md` frontmatter `status:`.** Their enums (`draft | reviewed | locked`, `draft | active | locked`) exist but nothing in this family ever advances them past `draft` — file presence plus the owning skill's own readiness gates are the real signals. `/sdd-roadmap` runs its PRD-readiness heuristic itself when invoked; the orchestrator routes, it does not duplicate that check.
- **The stack signal** is file presence only (no status field marks the step complete): greenfield (`prd.md` frontmatter `context_type: greenfield`) → `$CONTEXT_ROOT/foundation/tech-stack.md`; brownfield → `$CONTEXT_ROOT/foundation/stack-assessment.md` (with `health-check.md` recommended alongside). These three are **root-level** artifacts, not per-project — in a root hosting several projects they are shared, and their presence satisfies the stage for every project under that root.
- **The stack step is skippable by a human, never by policy.** Attended runs recommend it and accept "skip to `/sdd-roadmap`"; unattended runs STOP at `specified` — stack and architecture choices are exactly the human gate the family reserves (`missing-prep`-class stop, not an auto-default).
- **Greenfield scaffolding gap, stated honestly**: `/sdd-tech-stack-selector` hands off to `/sdd-bootstrapper`, which is not shipped in this plugin. The orchestrator treats a written `tech-stack.md` as the stage signal and routes on to `/sdd-roadmap`; actual scaffolding is the operator's step outside this toolkit (say so, don't pretend).
- **Multiple projects under a root** (`foundation/*/` has several subfolders with shape/prd/roadmap): an explicit `<project-slug>` argument selects; otherwise attended runs ask, unattended runs STOP unless exactly one project exists.

## 2. Roadmap item state (derived per `## At a glance` row)

**Scope**: this derivation — and selection rule 1 below — covers only changes whose `change_id` matches a `Change ID` in *this project's* roadmap. `changes/` is root-level and shared: a sibling project's changes, and changes never traced to any roadmap item (opened ad hoc via `/sdd-new`), are reported in one informational line but are outside this loop — the factory neither resumes nor waits on them, and a completion verdict mentions any that are still open.

For each row (`ID`, `Change ID`, `Prerequisites`, `Status`), combine the roadmap with the filesystem. Evaluated top-down, first match:

| Derived state | Signals |
|---|---|
| **done** | row `Status` is `done` (`/sdd-archive` is the sole writer of that flip) |
| **archived-drift** | an `archive/*-<change-id>` folder exists but the row is not `done` — the change was archived without the roadmap close landing (hand-archived, or the Change ID didn't match at archive time). Report it; attended runs may offer to fix the row by hand; never auto-edit |
| **in-flight** | `changes/<change-id>/` exists. Sub-state belongs to `/sdd-run` (its Step 2 table) — the orchestrator only distinguishes **awaiting-closeout** (change.md `status` ∈ `{implemented, impl_reviewed}` **and** the verification evidence below is positive) from **needs-triage** (verification evidence is REJECTED, or NEEDS ATTENTION with untriaged findings) from **in-progress** (anything earlier, including implemented-but-unverified — resuming it through `/sdd-run` runs the missing verification, its Step 8). No deeper re-derivation here: delegating to `/sdd-run <change-id>` *is* the derivation |
| **blocked** | any `Unknowns` entry with `Block: yes`, or a non-`—` `Blockers` entry, in the item body — regardless of the row's `Status` label (generation-time labels go stale; the body is re-read) |
| **executable** | every Prerequisite is **satisfied** (below) and the item is not blocked |
| **waiting** | otherwise (some prerequisite unsatisfied) |

**Verification evidence** (what makes an implemented change trustworthy without the session that ran it): read, in order of authority, (1) the change's latest `reviews/impl-review*.md` — its overall verdict, and whether any `- **Decision**: PENDING` lines remain (none remaining = the human triaged the findings); (2) else the closing `Verification` line of the last run record in the change's `factory-log.md`; (3) else there is no evidence. Classify:

- **positive** — `APPROVED`, `SKIPPED (trivial)`, `SKIPPED (declined)` (an attended human's explicit call), or `NEEDS ATTENTION` whose review file has zero PENDING decisions (triaged).
- **negative** — `REJECTED` (always — triage of a rejected review is not a substitute for a passing re-review), or `NEEDS ATTENTION` untriaged.
- **absent** — no review file and no factory-log verification line: the change is implemented-but-unverified → **in-progress**, so selection rule 1 resumes it through `/sdd-run`, whose completion contract runs the verification.

The verdict lives on disk either way (the review file, or `factory-log.md` — `/sdd-run` records it there), so this derivation survives the session that produced it: a REJECTED change can never quietly become "satisfied" on a re-run.

**Satisfied** (for prerequisite evaluation and selection): a referenced item counts as satisfied when its derived state is `done` **or** `awaiting-closeout`. Rationale: `done` is flipped only by `/sdd-archive`, but a change that is implemented and *positively verified* already delivers the capability its dependents consume — requiring the archive commit before dependents may start would make closeout a false dependency. `needs-triage` items are **not** satisfied in either mode: dependents are never built on rejected or unreviewed-warning work; attended runs route to `/sdd-impl-review <change-id>`, unattended runs STOP naming it. This is a *derived* equivalence used at runtime only; it is never written into `roadmap.md`, and closeout still owes the human its step (§4 keeps surfacing it).

**External-state prerequisites** (prose entries like "seeded ingredient table"): not mechanically verifiable. Attended → ask once per session whether it holds (record the answer in the project log). Unattended → treat as unsatisfied; the item is `waiting` with the external prerequisite named. Never assume an external condition true.

**Stale-label divergence** is narrated, not trusted: a row labelled `ready` whose body carries a blocking Unknown is **blocked**; a row labelled `proposed` whose prerequisites are all satisfied is **executable**. Nothing re-generates `ready`/`proposed` labels after first write, so derivation always wins over the label — say so in one line when they diverge.

## 3. Selection rule (which item runs next)

Apply in order, first match wins:

1. **A `needs-triage` change exists → it goes first, and it is not a `/sdd-run` job**: attended → route to `/sdd-impl-review <change-id>` triage; unattended → STOP naming it. Then: **an `in-progress` change exists → resume it** via `/sdd-run`. Finish-what-you-started beats starting new work: it holds the family's one-change-in-flight discipline and keeps the dirty surface small. Several in-progress changes (a hand-driven history): attended → ask which; unattended → the one whose roadmap item comes first in the roadmap's topological order (deterministic).
2. **Awaiting-closeout changes exist and the closeout policy will act on them → close them out first** (§4 in the skill). If policy is report-only, they don't block selection — their items already count satisfied.
3. **Otherwise select among `executable` items with `/sdd-roadmap`'s own hand-off rule** — its Step 10 "selection rule for the recommended next move" is canonical; apply it with two mechanical substitutions: read "ready" as this document's derived `executable`, and skip its rule 3 (no-move case) here because §5 owns that verdict. In short: the north-star slice if executable; else an executable Foundation the north star directly depends on; else the executable item that unblocks the most downstream items (fan-out), tie-broken by the roadmap's `main_goal`. If Step 10's rule ever changes, it wins over this summary.
4. **No executable item** → §5 decides between blocked and complete.

**Unresolved-impact check (runs before any selection, including resumes).** For the most recently touched item whose change has a `factory-log.md`, read the last run record's `Project impact` line. If it names an impact and the project log's sessions show no later `Roadmap re-evaluation` line covering that change, the impact is **unresolved** — the ROADMAP_IMPACT row of §4 fires now, before selection, exactly as if the run had just returned. This closes the crash window between a run completing and its re-evaluation gate: the impact is persisted by `/sdd-run` (see `../../sdd-run/references/factory-log-format.md`), so a resumed session cannot silently continue past it.

The selection decision is printed with a one-line why and recorded in the project log — like `/sdd-run`'s strategy block, the choice must be explainable after the fact.

## 4. Outcome classification (what a `FACTORY RESULT` means to the project loop)

`/sdd-run` returns the `FACTORY RESULT` block (`../../sdd-run/references/run-result-contract.md`). The project loop classifies it into one project-level event and acts; it never re-litigates the run's internals and never retries what `/sdd-run` already retried within budget.

| Event | Signals | Attended action | Unattended action |
|---|---|---|---|
| **CHANGE_COMPLETED** | `Outcome: completed` + `Verification: APPROVED`, `SKIPPED (trivial)`, or `SKIPPED (declined)` (declining is an attended human's explicit call; it cannot occur unattended) | closeout offer, then the continue-gate | apply closeout policy, continue the loop |
| **CHANGE_NEEDS_ATTENTION** | `completed` + `NEEDS ATTENTION` | route to `/sdd-impl-review <change-id>` triage; loop pauses until triaged | STOP — findings listed; never build dependents on unreviewed warnings |
| **CHANGE_REJECTED** | `Verification: REJECTED` (this row keys on the verdict alone, whatever the `Outcome` field says) | route to `/sdd-impl-review <change-id>`; loop stops | STOP |
| **CHANGE_STOPPED (defect)** | `stopped` + `gate-failure` | present the STOP; offer an attended `/sdd-run <change-id>` re-entry (a human in the loop is new information; the bounded budgets inside `/sdd-run` still apply) | STOP — the retry budget is spent; a project-level auto-retry would be the unbounded loop the family forbids |
| **SPEC_MISMATCH** | `stopped` + `structural-mismatch` | offer plan revision (`/sdd-plan <change-id>`) or re-framing (`/sdd-frame <change-id>`) | STOP with the plan-correction action named |
| **HUMAN_DECISION_REQUIRED** | `stopped` + `missing-prep` or `human-decision` | run the owning prep skill inline (its interview, its gates), or answer the named decision, then re-enter | STOP with the concrete command/decision |
| **ENVIRONMENT** | `stopped` + `environment` | surface the failing tool/preflight; fix is outside the loop | STOP |
| **ROADMAP_IMPACT** | `Project impact` ≠ `none` — *on any outcome, including completed* | the re-evaluation gate (below) fires **before** the next selection | STOP — never continue past an invalidated assumption; print the impact notes and the re-evaluation options |

**The re-evaluation gate** (attended): present the impact notes and ask one structured question —

1. **Proceed unchanged** — the impact is noted in the project log but doesn't change sequencing (the human vouches).
2. **Edit the roadmap by hand now** — the orchestrator waits, then re-derives §2 from the edited file. This is the recommended path for incremental impact: `roadmap.md` is edit-in-place by convention, and hand-editing preserves the `## Done` section and item statuses.
3. **Regenerate via `/sdd-roadmap`** — for impact that invalidates the sequencing wholesale. Warn explicitly: regeneration is archive-then-replace from the PRD; `## Done` entries and `done` flips do **not** carry over and must be re-marked (the archived copy is the reference). If the impact is `spec`, updating the PRD (`/sdd-prd`) comes first.
4. **Stop here** — human takes over.

The orchestrator itself **never edits `roadmap.md`** — not statuses, not items, not `## Done`. `/sdd-archive` flips `done`; `/sdd-roadmap` regenerates; the human hand-edits. The project layer's whole write surface is the project log.

## 5. Completion policy (is the project done?)

Evaluated when no item is executable and nothing is in-progress or needs-triage (awaiting-closeout items are fine — they are what the second verdict exists for), and also checked at loop start:

| Verdict | Definition | Report |
|---|---|---|
| **PROJECT COMPLETE** | every `## At a glance` row is `done` | name `/sdd-archive-project <slug>` as the (human-gated) closing move. `## Parked` entries are legitimately deferred scope — they are outside the At-a-glance table and never block completion. Remaining `## Open Roadmap Questions` that gate no item are surfaced as informational |
| **COMPLETE PENDING CLOSEOUT** | every row is `done` or its item is `awaiting-closeout`; at least one of the latter | all building is finished; the remaining work is closeout (`/sdd-mr` / `/sdd-archive` per change). List each pending closeout. Not the same as complete — say which |
| **PROJECT BLOCKED** | at least one row is not `done`/satisfied, and nothing is executable or in-flight | list the blocking Unknowns/Blockers with owners, highest-leverage first (the one whose resolution unblocks the most downstream items — the same framing as `/sdd-roadmap`'s "no planning move available"). This is "nothing currently executable", **not** "project complete" — the report must never conflate them |
| **EXECUTING** | anything else | the loop continues |

## 6. Interruption safety (what a re-run finds after a stop at any point)

- **Stopped between derivation and dispatch** — nothing was persisted; the next run re-derives and re-selects deterministically (same inputs → same choice).
- **Stopped mid-`/sdd-run`** — that skill's own resume contract holds (Progress + `factory-log.md`); the item derives as `in-flight` and selection rule 1 resumes it.
- **Stopped after a run completed, before closeout** — the item derives `awaiting-closeout` (or `needs-triage`, per the verification evidence); nothing re-executes; closeout or triage is re-offered. The §3 unresolved-impact check re-reads the run's persisted `Project impact` line, so an impact discovered in that window still fires its gate on resume.
- **Stopped after `/sdd-archive`, before the project-log append** — the roadmap row is `done` (the archive commit carried it); only the log's iteration row is missing. The log is observability — an acceptable, bounded gap, same as `factory-log.md`'s crash note.
- **Stopped during an inline prep skill** — that skill's own resume mechanics hold (shape checkpoint, PRD versioning, roadmap collision handling); the stage derivation lands back on the same row.

Nothing above needs orchestrator-private state — which is the test this design has to keep passing: **if a piece of project state can't be re-derived from the standing artifacts, it belongs in one of them, not in a new sidecar.**
