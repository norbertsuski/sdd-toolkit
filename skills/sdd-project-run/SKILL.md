---
name: sdd-project-run
description: >
  Drive an SDD project from whatever stage it is in toward completion — the
  Project Factory, one level above /sdd-run. Derives the project's stage from
  its artifacts (context root, shape-notes, PRD, stack docs, roadmap), routes
  missing preparation to the owning interview skills, treats the roadmap as the
  project dependency graph, selects the next executable roadmap item, delegates
  its execution to /sdd-run (one change at a time), observes the structured
  result, feeds roadmap-impacting discoveries back into planning, applies the
  closeout policy, and loops until the project is complete, blocked, or a human
  decision is required. Resume-first: re-running reconstructs state from disk.
  Use when the user says "run the project", "drive the whole project", "keep
  going until the roadmap is done", "sdd project run", "project factory",
  "poprowadź projekt", "przeprowadź cały projekt", or wants one command that
  continues a project from its current point. For a single change, use /sdd-run;
  for direct control of one step, use that step's own skill.
---

# /sdd-project-run — Project Factory (Agent Factory for a Whole Project)

One command that takes a project from its current lifecycle stage toward completion. It is a **composition and control layer over the existing `sdd-*` skills and over `/sdd-run`, not a replacement** for any of them — the project-level sibling of the single-change factory.

The design principle, inherited from `/sdd-run` and applied one level up:

> The project factory contains no product or software-development knowledge of its own. It inspects project state, routes missing preparation to the owning skills, selects the next executable roadmap item, delegates the change to `/sdd-run`, observes the structured result, and re-plans before continuing.

```
IDEA / EXISTING PROJECT
        │
        ▼
 derive stage            (artifacts on disk — references/project-state.md §1)
 route missing prep      (init / shape / prd / stack / roadmap — owning skills, never invented here)
 derive roadmap state    (item states from roadmap + changes/ + archive/ — §2)
 select next item        (resume in-flight first; else the roadmap's own hand-off rule — §3)
 delegate the change     (/sdd-run <change-id> — the change factory, unchanged)
 observe the result      (FACTORY RESULT — ../sdd-run/references/run-result-contract.md)
 re-evaluate on impact   (roadmap re-evaluation gate — §4)
 closeout                (policy: /sdd-mr, /sdd-archive — owning skills, human-gated)
 loop · complete · STOP  (completion policy — §5)
 persist + report        (project-log.md — references/project-log-format.md)
```

The hierarchy has three layers with explicit responsibility boundaries:

```
PROJECT FACTORY   /sdd-project-run — project lifecycle, roadmap sequencing,
   │              change selection, observation, replanning, project log
   └── CHANGE FACTORY   /sdd-run — one change's lifecycle, prep routing,
          │             execution strategy, workers, integration, verification
          └── SPECIALIST SKILLS   shape · prd · roadmap · frame · research ·
                                  plan · implement · review · mr · archive · …
```

This skill is an **entry skill**: it resolves `CONTEXT_ROOT` per `../sdd-shape/references/context-resolution.md` (discovery + pick), then hands the resolved root to everything it composes. `app:` may be absent for flat roots; do not require it.

## When to use, when to skip

**Use when**: the user wants a *project* driven — "take this from idea to done", "continue the project from wherever it is", "work through the roadmap" — including returning to a half-done project after an interruption.

**Skip when**: the user wants one change driven (`/sdd-run <change-id>`), direct control of one step (the owning skill — the whole manual pipeline keeps working without this skill), a phased test rollout (`/sdd-test-plan` — its own orchestrator), or just orientation without action (`/sdd-help <slug>` — the read-only sibling of this skill's derivation).

## Relationship to other skills

| Skill | Role for the project factory |
|---|---|
| `/sdd-init`, `/sdd-shape`, `/sdd-prd`, `/sdd-tech-stack-selector`, `/sdd-stack-assess`, `/sdd-health-check`, `/sdd-roadmap` | Preparation stages. The factory **routes** to them when their artifact is missing — attended runs may invoke them inline (their interviews, their gates, unchanged) or hand off via clipboard; unattended runs STOP. It never generates a shape, PRD, stack decision, or roadmap itself. |
| `/sdd-run` | **The delegate for every change.** The project factory selects a roadmap item's Change ID and invokes `/sdd-run <change-id>` (passing `--auto` in unattended mode); `/sdd-run` owns everything below that — prep routing for the change, strategy, workers, gates, verification, retries. The project layer consumes its `FACTORY RESULT` block and never re-litigates or re-retries what the change factory already bounded. |
| `/sdd-roadmap` | Owns roadmap generation and regeneration. The factory reads `roadmap.md` as the project dependency graph and derives item states at runtime; it **never writes** roadmap statuses, items, or `## Done`. Roadmap-impacting discoveries route to the re-evaluation gate (hand-edit, `/sdd-roadmap` regeneration, or `/sdd-prd` first), never to a silent orchestrator edit. |
| `/sdd-impl-review` | Triage surface for NEEDS ATTENTION / REJECTED verdicts returned by `/sdd-run` — the loop routes there (attended) or stops naming it (unattended). |
| `/sdd-mr`, `/sdd-archive` | Closeout, human-gated. `/sdd-archive` remains the **sole writer** of a roadmap item's `done` flip and `## Done` entry. The factory invokes them only per the closeout policy (Step 7), with their own gates intact. |
| `/sdd-archive-project` | The project's closing move. Named in the completion report; never auto-run (its warnings and confirmation are a human's). |
| `/sdd-help`, `/sdd-map` | Read-only siblings: `/sdd-help` reports the same stage derivation and recommends; `/sdd-map` draws the same roadmap graph; `/sdd-project-run` acts on that derivation. |
| `/sdd-test-plan` | Peer orchestrator for the test-rollout lane; not composed by this skill. |

## Modes

- **Attended** (default) — a human is present. Interactive prep skills may run inline with every one of their gates preserved; each completed change ends at a closeout offer and a continue-gate before the next item. The factory must never produce a simplified substitute artifact to keep the pipeline moving — thin prep is the failure the prep skills exist to prevent.
- **Unattended** (`--auto`) — nobody is watching. The factory applies the family's non-interaction policy (`/sdd-goal-implement`'s posture, `/sdd-run --auto` for delegation): no interactive questions, explicit automatic policies, and a STOP with a concrete human action whenever a stage or decision is human-dependent — missing interview-driven artifacts (shape, PRD, stack, roadmap, plan), unresolved blocking Unknowns, ambiguous requirements, destructive operations, architecture choices, NEEDS ATTENTION / REJECTED verdicts, and any roadmap-impacting discovery. Inventing answers to keep automation moving is prohibited.

Resolve `audience` per `../sdd-shape/references/plain-mode.md` ("Audience resolution") for operator-facing text; artifacts are identical in both modes. In plain mode, report the loop in product terms (what got built, what's next, what needs a person) and never print roadmap IDs, git mechanics, or slash commands to the operator (commands still go to the clipboard silently, per the contract).

Interactive prompts are host-agnostic — use whichever structured-question tool the host exposes (see `/sdd-roadmap`'s "Interactive prompts — host-agnostic" note for the discovery rule).

## Process

### Step 1: Resolve the project

`/sdd-project-run [project-slug] [--auto] [--status] [--max-changes N] [--closeout none|archive]`

- Resolve `CONTEXT_ROOT` per `../sdd-shape/references/context-resolution.md`. Unattended: zero roots → STOP (`Cannot start: no context root. Run /sdd-init.`); several roots (or a legacy root's `<app>` pick) → STOP unless the argument disambiguates.
- Resolve the project: an explicit `<project-slug>` argument selects `$CONTEXT_ROOT/foundation/<project-slug>/`; otherwise enumerate `foundation/*/` project folders — exactly one → use it; several → ask (attended) / STOP (unattended); none → the project doesn't exist yet, which is simply the `unshaped` (or `uninitialized`) stage in Step 2.
- Read `$CONTEXT_ROOT/foundation/<project-slug>/project-log.md` if present (last session's `Result` and `Next safe action` are orientation context — never authority; disk artifacts win).
- `--status` → print the derived stage, the roadmap item states, and the single recommended next move (the same derivation, read-only — an acting sibling of `/sdd-help <slug>`), then STOP without doing work.

### Step 2: Derive the project stage and route preparation

Derive the stage per `references/project-state.md` §1 (artifacts only — never frontmatter `status:` enums that nothing advances). Route on the first matching row:

| Stage | Attended action | Unattended action |
|---|---|---|
| uninitialized | Offer to run `/sdd-init` now (inline), or hand off | STOP — `Missing prerequisite: context root. Run /sdd-init.` |
| unshaped / shaping | Run `/sdd-shape` inline (its full interview and checkpoint resume), or hand off via clipboard | STOP — `Missing prerequisite: shape-notes. Run /sdd-shape interactively.` |
| shaped | Run `/sdd-prd` inline (its readiness gates and questions), or hand off | STOP — `Missing prerequisite: prd.md. Run /sdd-prd interactively.` |
| specified | Recommend the stack step (greenfield: `/sdd-tech-stack-selector`; brownfield: `/sdd-stack-assess` then `/sdd-health-check`) — run inline, or let the user explicitly skip to `/sdd-roadmap` | STOP — `Missing prerequisite: stack step (or an explicit human skip). Run it interactively.` Stack/architecture is a reserved human gate; the factory never defaults it |
| stack-informed | Run `/sdd-roadmap` inline (its capped interview, baseline probes, self-review), or hand off | STOP — `Missing prerequisite: roadmap.md. Run /sdd-roadmap interactively.` |
| roadmapped | Continue to Step 3 | Same |
| complete | Report PROJECT COMPLETE; name `/sdd-archive-project <slug>`; STOP | Same, non-interactively |

Running a prep skill **inline** means invoking that skill's process in this session with the user present — its questions, its artifacts, its collision handling, its gates, unchanged. After an inline prep completes, **re-enter this routing** (the stage advanced; derive again). When the user prefers a fresh context, use the family's clipboard handoff (copy the command, tell them to `/clear` and run it, STOP — re-running `/sdd-project-run` afterwards resumes from the new stage). Each session's entry stage and route are appended to the project log (`references/project-log-format.md`); prep-stage sessions record no iterations table.

### Step 3: Derive roadmap state

Read `roadmap.md` fully (the `## At a glance` table and every `### F-NN:`/`### S-NN:` body). Cross-check against `$CONTEXT_ROOT/changes/*/` and `$CONTEXT_ROOT/archive/*/` — scoped to changes whose `change_id` matches this roadmap's `Change ID`s; untraced or sibling-project changes get one informational line and stay outside the loop — and derive each item's state per `references/project-state.md` §2: `done`, `archived-drift`, `in-flight` (distinguishing `in-progress`, `awaiting-closeout`, and `needs-triage` via the verification evidence), `blocked`, `executable`, `waiting`. Run §3's **unresolved-impact check** (a persisted `Project impact` from a previous session with no recorded re-evaluation fires the gate now, before anything is selected). Narrate stale-label divergences in one line each (derivation wins over generation-time `ready`/`proposed` labels). Print a compact state summary:

```
Roadmap state — <slug>: 7 items
  done: F-01, S-01   in-flight: S-02 (implementing)   executable: F-02
  waiting: S-03 (needs S-02), S-04 (needs S-03)   blocked: S-05 (Unknown: vendor approval — Owner: user)
```

If every row is `done` → completion report (Step 8). If nothing is executable, in-flight, or awaiting actionable closeout → blocked report (Step 8).

### Step 4: Select the next work item — and say why

Apply the selection rule of `references/project-state.md` §3: a `needs-triage` change goes first (to `/sdd-impl-review`, not `/sdd-run`; unattended → STOP); else resume an `in-progress` change; else act on awaiting-closeout items when the closeout policy will act; else pick among executable items with `/sdd-roadmap`'s own hand-off rule (north star → its enabling Foundation → highest fan-out, tie-broken by `main_goal`). Print the decision in one block — it must be explainable and it lands in the project log:

```
Next: S-02 srs-review-session
Why:  in-flight (status implementing, 3/8 rows done) — resume before new work.
```

External-state prerequisites (prose entries) follow §2's rule: attended → confirm once per session; unattended → treat as unsatisfied.

### Step 5: Delegate to /sdd-run

Invoke `/sdd-run <change-id>` inline — attended as attended, unattended as `/sdd-run <change-id> --auto`. The change factory owns everything from here to the verified change: prep routing for the change (a missing plan is *its* Step 2, which interviews attended and stops unattended), strategy, workers, gates, verification, bounded retries, `factory-log.md`.

The project factory adds nothing during the run and touches nothing the run owns — no Progress flips, no commits, no plan edits. One change is in flight at a time; the next selection happens only after this run returns and its result is classified. (The roadmap's `Parallel with` marks *may* — future concurrent execution would slot in here, per the Notes — not *must*.)

### Step 6: Observe the result and classify

Read the run's closing `FACTORY RESULT` block (`../sdd-run/references/run-result-contract.md`) and classify it into one project-level event per `references/project-state.md` §4 — CHANGE_COMPLETED, CHANGE_NEEDS_ATTENTION, CHANGE_REJECTED, CHANGE_STOPPED (defect), SPEC_MISMATCH, HUMAN_DECISION_REQUIRED, ENVIRONMENT — and act per that table. Two hard rules:

- **No project-level retries.** `/sdd-run` already spent its bounded budgets; a `stopped` result stops the loop (attended runs may re-enter `/sdd-run` with the human present — new information, same budgets — but the factory never auto-re-invokes).
- **`Project impact` ≠ `none` fires the re-evaluation gate before any next selection** — attended: the four-option gate of §4 (proceed / hand-edit roadmap / regenerate via `/sdd-roadmap`, with the explicit `## Done`-loss warning / stop; `spec` impact routes through `/sdd-prd` first). Unattended: STOP, printing the impact notes and the options. Continuing past an invalidated assumption is the pipeline failure this layer exists to prevent: the loop is observe → decide → execute → observe → replan, not A → B → C.

Append the iteration row to `project-log.md` (item, why selected, delegate, outcome, verification, impact, closeout).

### Step 7: Closeout

After CHANGE_COMPLETED, apply the closeout policy — reusing the owning skills with their gates intact, never re-implementing them:

- **Attended** — ask once per change: **Continue without closeout** (the item counts satisfied via the awaiting-closeout derivation; closeout stays on the human-actions list) · **Archive now** (run `/sdd-archive <change-id>` inline — its warn prompt and hard blocks unchanged; this is what flips the roadmap row to `done`) · **Open the MR** (run `/sdd-mr <change-id>` inline — outward-facing, so always an explicit choice, never a default) · **Stop here**.
- **Unattended** — `--closeout none` (default): no MR, no archive; the change is reported as awaiting closeout and the loop continues on the satisfied-derivation. `--closeout archive`: run `/sdd-archive <change-id>`, answering its warn prompt only within what the flag pre-authorizes — exactly two warning classes may be accepted automatically: (a) *pending Manual rows only* (the case `/sdd-archive` itself marks "Continue archiving (Recommended)"), and (b) *missing `reviews/impl-review*.md`* when the change's verification evidence is `APPROVED` (this session's `FACTORY RESULT`, or the persisted `factory-log.md` verdict — unattended runs verify via a reviewer subagent that writes no review file, so this warning is expected). Any other warning, or any hard block, → STOP rather than answer for the human. `/sdd-mr` is never run unattended by this factory — opening a review request is an outward action a person triggers.

### Step 8: Loop, complete, or stop

- **Attended** — after closeout, the continue-gate: `Continue to the next item · Stop here (resume later with /sdd-project-run)`. On continue, re-derive from Step 3 (cheap, and it picks up anything the closeout changed).
- **Unattended** — continue automatically while results are clean (CHANGE_COMPLETED, impact `none`), re-deriving each iteration, bounded by `--max-changes N` when given. Any other event stops the loop with the event's report.
- **Terminal states** per `references/project-state.md` §5, each with its distinct report: **PROJECT COMPLETE** (name `/sdd-archive-project`), **COMPLETE PENDING CLOSEOUT** (list the pending closeouts), **PROJECT BLOCKED** (highest-leverage unknown first, with owners — never conflated with complete).

### Step 9: Persist and report

Close the session's `project-log.md` entry (re-evaluation events, stop reason, next safe action, result) and commit the log per `references/project-log-format.md`'s commit policy (attended: propose; unattended: only on a clean index; never bundle other paths; scope per root layout). One consequence to surface explicitly: an uncommitted `project-log.md` hard-blocks `/sdd-archive-project` (uncommitted paths inside `foundation/<slug>/`), so a PROJECT COMPLETE report given while the log is dirty names that commit as the step before archiving the project. End every session with the project report:

```
PROJECT RUN REPORT — <slug>

Entry stage: <derived stage at start>
Iterations:  <N>
- 1. S-01 first-gated-generation — completed, APPROVED, archived
- 2. F-02 observability-baseline — stopped (gate-failure)

Roadmap: <done>/<total> items done (<k> awaiting closeout)
Re-evaluations: <none | one line each>
Human actions:
- <pending closeouts, manual rows, decisions — or "none">

Result: <continuing | complete | complete-pending-closeout | blocked | stopped (<reason>)>
Next: <single command or human action>
```

When `audience: plain`, give the report per the plain-mode contract — what got built, what still needs a person, whether the project is finished — with no IDs, commands, or git detail in the operator-facing text.

## Failure handling

Classification comes from the delegate's `FACTORY RESULT` (stop class + verification), mapped by `references/project-state.md` §4 — execution failure, verification failure, specification problem, dependency/blocked problem, human decision, tool/environment failure each have a distinct row and action. The project layer never blind-retries: the only retry budgets in the system live inside `/sdd-run`, and they are already spent when a `stopped` result surfaces. Every stop prints: where execution stopped (stage/item/change), why (the event class + one line), what was persisted (committed phases, log entries), and the next safe action. Resume needs nothing beyond re-running `/sdd-project-run` — Step 2/3 re-derive, Step 4 re-selects deterministically, `/sdd-run` resumes its own change. Interruption-safety cases: `references/project-state.md` §6.

## Critical guardrails

1. **Compose, never re-implement.** Shape, PRD, stack, roadmap, plans, execution, verification, MR, archive — all owned by their skills, invoked with their gates intact. If the project factory is doing something no existing skill defines, it should be state derivation, selection, observation, or logging — not domain work.
2. **The roadmap is the only project DAG.** Item states are derived at runtime and never persisted anywhere else; the factory never edits `roadmap.md`. `/sdd-archive` flips `done`; `/sdd-roadmap` regenerates; a human hand-edits. A second competing representation of sequencing state is the drift this design refuses.
3. **`/sdd-run` stays the single-change factory.** The project layer passes a Change ID down and reads a `FACTORY RESULT` back — it never reaches inside the run (no Progress flips, no worker talk, no plan edits, no second opinion on retries).
4. **One change in flight.** Selection happens only after the previous result is classified and any re-evaluation resolved. Serial by design; the contracts (roadmap `Parallel with`, per-change `FACTORY RESULT`) leave room for future concurrency without redesign.
5. **Human gates are load-bearing, in both modes.** Attended runs preserve every composed skill's own pauses and add the closeout offer + continue-gate. Unattended runs STOP — with the concrete action — on anything the family defines as human-dependent. No invented artifacts, no defaulted architecture, no auto-answered warnings.
6. **Impact stops the pipeline.** A non-`none` `Project impact` is never carried silently into the next selection: attended → the re-evaluation gate; unattended → STOP. Observe → replan → continue, only when the roadmap is actionable again.
7. **Bounded everything.** No project-level retry loops; unattended iteration is bounded by clean-results-only (and `--max-changes` when given); prep routing runs each stage at most once per session before re-deriving.
8. **Outward actions are explicit.** `/sdd-mr` only on an attended yes; unattended archiving only via explicit `--closeout archive`, and even then `/sdd-archive`'s own warnings stop the run. `/sdd-archive-project` is only ever named.
9. **The project log is additive observability.** Delete-safe, append-only, one writer; if it disagrees with roadmap/Progress/change.md, they win. It never becomes required reading for any other skill.
10. **Inline composition is this skill's explicit mandate, not a family-rule change.** The specialist skills keep their never-auto-chain behavior when run standalone; invoking `/sdd-project-run` is the user's instruction to drive the chain, and every composed skill still runs its own process verbatim.

## Notes

- **Backward compatibility is a feature.** Every artifact this skill reads keeps its existing schema; the only new artifact is `project-log.md`, which nothing else depends on. All individual skills, and `/sdd-run`, keep working standalone.
- **The change↔roadmap link is the Change ID string**, matched exactly against the roadmap's `Change ID` column — the same convention `/sdd-archive` uses. This skill introduces no `roadmap:` pointer into `change.md`.
- **Known scope quirk**: `tech-stack.md` / `stack-assessment.md` / `health-check.md` are root-level (shared across projects under one root), so the stack stage can be satisfied by a sibling project's artifacts. The derivation accepts that (it mirrors `/sdd-help`), and the attended route lets the human re-run the stack step anyway.
- **Extension points, deliberately prepared but not built**: concurrent change execution (would need worktree isolation with a working toolchain, branch/merge policy, and integration-ordering rules — the serial loop, `Parallel with` marks, and per-change result contract are the seams); backlog ingestion (Jira/GitLab issues mapping onto roadmap items via `## Backlog Handoff`); CI-driven verification (`/sdd-impl-review-ci` consuming the same verdict model). None of these require redesigning this skill.
- Nothing here requires a database, queue, daemon, or external orchestrator: files, markdown, git, and the existing skills.
