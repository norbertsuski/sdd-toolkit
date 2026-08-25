# `project-log.md` reference

The project factory's append-only orchestration record, at `$CONTEXT_ROOT/foundation/<project-slug>/project-log.md` — the project-level sibling of `/sdd-run`'s `factory-log.md`. It answers, cheaply and after the fact: *what did the orchestrator inspect, what did it decide, why that item, what came back, why did it stop, what happens on resume.*

**It is an append-only project event ledger, not a second roadmap.** Sequencing truth lives in `roadmap.md`; execution truth in Progress; lifecycle/verification truth in `change.md`. This log durably records impact acknowledgements, MR handoffs, integration confirmations, and selection rationale that cannot be derived from those files alone. Deleting it causes conservative recovery (re-gate impacts, re-check live MR/integration); it is not consequence-free. Canonical artifacts still win on build state.

## Who writes it

Only `/sdd-project-run`. No other skill reads or requires it. `/sdd-run` keeps writing its own `factory-log.md` per change — the two records nest (project log names the change; the change's factory log carries the per-phase detail); neither duplicates the other.

## Structure

One `# Project Log — <project-slug>` H1, then one `## Session <K> — <YYYY-MM-DD>` section per `/sdd-project-run` invocation, append-only (a resumed run gets a new section; never rewrite an old one).

```markdown
# Project Log — <project-slug>

> Orchestration record written by /sdd-project-run. Sequencing truth is
> roadmap.md; execution truth is each change's plan.md ## Progress. This file
> is the append-only project event ledger; it is not a second roadmap.

## Session 1 — 2026-08-25

- **Mode**: attended | unattended
- **Entry stage**: <derived stage + one-line summary, e.g. "roadmapped — 2/7 items done, 1 in-flight (srs-review-session)">
- **Route**: <what this session did at entry, e.g. "resume in-flight srs-review-session via /sdd-run" | "stage specified → ran /sdd-roadmap inline" | "stopped: unattended, missing prd.md">

### Iterations

| # | Item | Change ID | Why selected | Profile | Delegate | Outcome | Verification | Impact |
|---|---|---|---|---|---|---|---|---|
| 1 | S-01 | first-gated-generation | north star, executable | standard (inherited/medium) | /sdd-run | completed | APPROVED | none |
| 2 | F-02 | observability-baseline | unblocks S-03, S-04 | deep (model-id/high) | /sdd-run | stopped (gate-failure) | — | none |

### Execution profile decisions

- `#1 first-gated-generation — profile=standard; tier=standard; model=inherited; effort=medium; context=scoped; verification=independent; why=<evidence>`
- `#2 observability-baseline — profile=deep; tier=strong; model=model-id; effort=high; context=broad; verification=independent; why=<evidence>`

### Closeout events

- `MR_HANDOFF_REQUESTED <change-id> source=<branch> target=<branch>`
- `INTEGRATION_CONFIRMED <change-id> target=<branch> evidence=<tool|operator>`
- `ARCHIVED <change-id>`
- `CLOSEOUT_DECLINED <change-id>`

- **Roadmap re-evaluation**: <none | one line per event: `<change-id> run <K> — <impact values> — <proceed|hand-edit|regenerate|stop>: <note>`>
- **External prerequisites confirmed**: <none | "seeded ingredient table — confirmed by operator">
- **Stopped because**: <— | one line: the event class + what blocked>
- **Next safe action**: <the single command or human action a resume needs>
- **Result**: continuing | complete | complete-pending-closeout | blocked | stopped (<one-line reason>)
```

## Rules

- **Append-only.** New invocation → new `## Session <K>` at the end. Within a session, the factory appends iteration rows as each delegated run returns and fills the closing lines at exit; it never edits earlier sessions.
- **Prep-stage sessions** (the session routed to shape/PRD/stack/roadmap and never reached the execution loop) record `Entry stage` + `Route` + the closing lines and omit the `### Iterations` table entirely.
- **`Why selected`** is the selection rule's one-liner (`project-state.md` §3), verbatim — the row must make the choice explainable without the transcript.
- **`Profile`** records the project-level execution profile plus resolved model id-or-fallback/effort from `../../sdd-run/references/execution-profiles.md`: `<profile> (<host-id|inherited|default>/<effort>)`. The printed decision block also carries model tier, context, verification, and why. Never fabricate an id.
- **Execution profile decisions** persist that full shared block in compact key/value form; the table cell is only an index. Omit the section for sessions that never delegate implementation.
- **`Outcome` / `Verification` / `Impact`** are lifted from the delegated run's `FACTORY RESULT` fields. Append the iteration row when Step 6 returns; never edit it during closeout.
- **Closeout events are separate and append-only.** State derivation uses the latest event for that change. `MR_HANDOFF_REQUESTED` blocks new work until a later `INTEGRATION_CONFIRMED` + `ARCHIVED`; opening and archiving in one session/event is invalid.
- **Re-evaluation acknowledgement identity is load-bearing.** It must name the change id, factory run number, and exact impact values so the all-change resume scan can match one acknowledgement to one factory run; a generic prose line does not clear an impact.
- **No secrets, no logs, no duplicated detail.** One line per fact; the change's `factory-log.md`, STOP blocks, and reviews carry the depth.
- **Commit policy.** The log is committed on its own, never bundled. Normally commit at session end. **Before `/sdd-mr`**, append `MR_HANDOFF_REQUESTED`, finalize the session row/closing lines, and require the log commit to succeed; only then invoke `/sdd-mr`, whose push carries that event onto the source branch/MR. If the log commit is declined/fails, STOP before opening the MR. Subjects: flat root `chore(<project-slug>): project log (session <K>)`; legacy root `chore(<app>): project log (<project-slug>, session <K>)`. Unattended commits only with an otherwise clean index. An uncommitted log is safe for change execution but blocks reliable outward closeout and `/sdd-archive-project`.
- Keep it small: this file exists to make resume and audit cheap, not to become a second project specification.
