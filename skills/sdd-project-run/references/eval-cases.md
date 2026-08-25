# Project Factory state-machine eval cases

Behavioral acceptance cases for `/sdd-project-run`, `/sdd-run`, and their shared contracts. These are prompt/agent eval fixtures: construct only the named artifacts, invoke the stated entry skill, and require the expected decision. A response that reaches the same final state through a prohibited action (silent roadmap edit, stale-review trust, next-change dispatch after MR) fails.

## Lifecycle and selection

| ID | Given | Invoke | Expected |
|---|---|---|---|
| PS-01 | no context root | `/sdd-project-run --status` | stage `uninitialized`; recommend `/sdd-init`; no writes |
| PS-02 | shape checkpoint phase 4, no PRD | `/sdd-project-run --status` | stage `shaping`; route `/sdd-shape` |
| PS-03 | PRD, no stack signal, no roadmap | `/sdd-project-run --status` | stage `specified`; stack is a human gate |
| PS-04 | roadmap, no active change, one unblocked item with satisfied prerequisites | `/sdd-project-run` | item is `executable`; select by roadmap hand-off rule |
| PS-05 | roadmap-linked change with pending Automated rows | `/sdd-project-run` | derive `in-progress`; resume it before new work |
| PS-06 | change `impl_reviewed` with current APPROVED evidence | `/sdd-project-run --status` | derive `awaiting-closeout`; its capability satisfies dependents |
| PS-07 | change `impl_reviewed` with current REJECTED evidence | `/sdd-project-run --status` | derive `needs-triage`; dependent remains unsatisfied |
| PS-08 | blocking Unknown with `Block: yes` | `/sdd-project-run --status` | item is `blocked` even if row label says `ready` |
| PS-09 | every item done or awaiting-closeout, at least one awaiting | `/sdd-project-run --status` | `COMPLETE PENDING CLOSEOUT`, not complete |

## Verification freshness

| ID | Given | Invoke | Expected |
|---|---|---|---|
| VF-01 | Automated rows complete; `change.md: implemented`; old APPROVED review exists | `/sdd-run <id>` | old review is stale; run Step 8 again; do not report done from the file alone |
| VF-02 | same artifacts but `change.md: impl_reviewed` | `/sdd-run <id>` | review disposition is current; report according to its verdict |
| VF-03 | `impl_reviewed` change gains pending implementation work | `/sdd-run <id>` | set `status: implementing` before execution, invalidating prior evidence |
| VF-04 | unattended review returns any canonical verdict/skip | `/sdd-run <id> --auto` | persist selected factory run, base verdict, fingerprint/date, and `impl_reviewed` atomically |
| VF-05 | review triage edits implementation code | `/sdd-impl-review <report>` | set `status: implemented`; require a fresh full review before closeout |
| VF-06 | phase review is APPROVED but later Automated rows remain pending | derive project state | `in-progress`; never satisfy dependents or write a full verification snapshot |

## MR and integration lifecycle

| ID | Given | Action | Expected |
|---|---|---|---|
| MR-01 | completed change on a feature branch | choose `Open the MR` | run `/sdd-mr`, record `mr`, end the project-run session `awaiting merge`; never dispatch the next item |
| MR-02 | previous session recorded `mr`; merge not confirmed/detected | resume `/sdd-project-run` | prioritize the handoff; do not start another change on that branch |
| MR-03 | operator confirms MR/change integrated | resume and choose archive | allow `/sdd-archive`, then re-derive before next selection |
| MR-04 | archive requested without integration evidence | closeout | refuse/STOP with integration action; do not archive |
| MR-05 | `change.md: impl_reviewed` | `/sdd-mr <id>` | status precondition passes |
| MR-06 | MR is merged but worktree remains on source branch or target is not fast-forwarded to origin | archive closeout | STOP; synchronize clean target branch before archive/log commits |

## Outcome and impact axes

| ID | Given result/history | Expected |
|---|---|---|
| IM-01 | `Outcome: completed`, `Verification: APPROVED`, impact `roadmap` | primary event `CHANGE_COMPLETED`; independently fire impact re-evaluation before closeout/selection |
| IM-02 | `stopped + structural-mismatch`, impact `architecture, roadmap` | primary event `SPEC_MISMATCH`; independently fire impact re-evaluation; never classify impact as a competing primary event |
| IM-03 | impact in change A; later manual activity touches change B; no acknowledgement for A | all-change scan still finds A and gates selection |
| IM-04 | unresolved impacts in A and B | list both; resolve oldest recorded run first; no item selection meanwhile |
| IM-05 | matching project-log line names change, factory run, impact, and decision after the run | that specific impact is acknowledged; do not re-fire it or clear a later run |

## Resource-aware routing

| ID | Given work | Expected |
|---|---|---|
| RP-01 | two-file mechanical docs/copy update, exact pattern, no contract risk | `light`: economical tier, low effort, small context |
| RP-02 | normal feature inside one known subsystem | `standard`: standard tier, medium effort |
| RP-03 | cross-module schema/migration change | at least `deep`: strong tier, high effort, broad context |
| RP-04 | auth/permissions boundary | `critical`: strong tier, high effort, heightened independent verification |
| RP-05 | project item is critical; one child phase only updates docs | child may be `light` only with a why explaining parent risk does not touch it; final review remains heightened |
| RP-06 | host exposes no model override | `Resolved model: inherited/default`; never claim a concrete routed model |
| RP-07 | light worker exhausts a gate with evidence suggesting insufficient reasoning | its one replacement escalates to `standard`; retry/write-scope budgets do not change |
| RP-08 | structural mismatch | STOP/replan; no stronger-model retry |
| RP-09 | direct unattended single-agent light task; host supports cheaper model | execution carrier | dispatch one profiled executor; do not run inherited inline |
| RP-10 | host supports model override but no effort override | project/change dispatch | use selected model and record effort `host-default` |
| RP-11 | light dispatched worker | context payload | only small-band plan/phase/direct excerpts; no full conversation/research |
| RP-12 | deterministic failure has complete evidence and stronger reasoning cannot help | replacement | keep same profile with recorded why; still only one replacement |

## Pre-shape logging

| ID | Given | Expected |
|---|---|---|
| LG-01 | no project slug exists before `/sdd-shape` | defer `project-log.md`; after shape creates the folder, record the original entry stage and route there; create no temporary state file |
