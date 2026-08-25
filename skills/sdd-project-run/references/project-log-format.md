# `project-log.md` reference

The project factory's append-only orchestration record, at `$CONTEXT_ROOT/foundation/<project-slug>/project-log.md` — the project-level sibling of `/sdd-run`'s `factory-log.md`. It answers, cheaply and after the fact: *what did the orchestrator inspect, what did it decide, why that item, what came back, why did it stop, what happens on resume.*

**It is observability, not a state machine.** Sequencing truth lives in `roadmap.md`; execution truth lives in each change's `plan.md` `## Progress`; lifecycle truth in each `change.md`. If this file is deleted, nothing breaks — the next run re-derives everything from those artifacts (`project-state.md`). If it ever disagrees with them, they win.

## Who writes it

Only `/sdd-project-run`. No other skill reads or requires it. `/sdd-run` keeps writing its own `factory-log.md` per change — the two records nest (project log names the change; the change's factory log carries the per-phase detail); neither duplicates the other.

## Structure

One `# Project Log — <project-slug>` H1, then one `## Session <K> — <YYYY-MM-DD>` section per `/sdd-project-run` invocation, append-only (a resumed run gets a new section; never rewrite an old one).

```markdown
# Project Log — <project-slug>

> Orchestration record written by /sdd-project-run. Sequencing truth is
> roadmap.md; execution truth is each change's plan.md ## Progress. This file
> is additive observability. Append-only.

## Session 1 — 2026-08-25

- **Mode**: attended | unattended
- **Entry stage**: <derived stage + one-line summary, e.g. "roadmapped — 2/7 items done, 1 in-flight (srs-review-session)">
- **Route**: <what this session did at entry, e.g. "resume in-flight srs-review-session via /sdd-run" | "stage specified → ran /sdd-roadmap inline" | "stopped: unattended, missing prd.md">

### Iterations

| # | Item | Change ID | Why selected | Delegate | Outcome | Verification | Impact | Closeout |
|---|---|---|---|---|---|---|---|---|
| 1 | S-01 | first-gated-generation | north star, executable | /sdd-run | completed | APPROVED | none | archived |
| 2 | F-02 | observability-baseline | unblocks S-03, S-04 | /sdd-run | stopped (gate-failure) | — | none | — |

- **Roadmap re-evaluation**: <none | one line per event: the impact, the option taken (proceed / hand-edit / regenerate / stop)>
- **External prerequisites confirmed**: <none | "seeded ingredient table — confirmed by operator">
- **Stopped because**: <— | one line: the event class + what blocked>
- **Next safe action**: <the single command or human action a resume needs>
- **Result**: continuing | complete | complete-pending-closeout | blocked | stopped (<one-line reason>)
```

## Rules

- **Append-only.** New invocation → new `## Session <K>` at the end. Within a session, the factory appends iteration rows as each delegated run returns and fills the closing lines at exit; it never edits earlier sessions.
- **Prep-stage sessions** (the session routed to shape/PRD/stack/roadmap and never reached the execution loop) record `Entry stage` + `Route` + the closing lines and omit the `### Iterations` table entirely.
- **`Why selected`** is the selection rule's one-liner (`project-state.md` §3), verbatim — the row must make the choice explainable without the transcript.
- **`Outcome` / `Verification` / `Impact`** are lifted from the delegated run's `FACTORY RESULT` fields, abbreviated to their enum values (`Impact` = the `Project impact` value; the notes live in the change's own record and, when a re-evaluation fired, in the `Roadmap re-evaluation` line).
- **`Closeout`** ∈ `— | mr | archived | mr+archived | declined` — what actually happened this session, not the policy.
- **No secrets, no logs, no duplicated detail.** One line per fact; the change's `factory-log.md`, STOP blocks, and reviews carry the depth.
- **Commit policy.** The log is committed on its own, never bundled: at session end, stage exactly this file and commit it. Subject follows the same scope rule as `/sdd-archive`: **flat root** → `chore(<project-slug>): project log (session <K>)`; **legacy root** → `chore(<app>): project log (<project-slug>, session <K>)` (legacy repos enforce a commitlint scope-enum of app names and reject other scopes). Attended → propose the commit; the operator may decline. Unattended → author the commit only when the git index is otherwise clean (`git diff --cached --quiet`); a non-empty index means unrelated staged work would ride along, so leave the file uncommitted and note it in the session's closing lines. An uncommitted log is safe for `/sdd-run` (it sits outside every change's phase scopes and is merely listed as `DIRTY (not staged)`), **but it hard-blocks `/sdd-archive-project`** — that skill refuses on any uncommitted path inside `foundation/<slug>/`. So a completion report given while the log is dirty must say "commit the project log first", and the factory offers that commit before naming `/sdd-archive-project`. A crash can lose the last unappended row — bounded, and recoverable by re-derivation, same as `factory-log.md`'s crash note.
- Keep it small: this file exists to make resume and audit cheap, not to become a second project specification.
