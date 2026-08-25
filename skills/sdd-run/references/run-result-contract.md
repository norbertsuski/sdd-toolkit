# `FACTORY RESULT` — the run's machine-consumable outcome block

The stable semantic contract between `/sdd-run` and anything that invoked it — a human scanning the transcript, or a parent orchestrator (`/sdd-project-run`) deciding what to do next. The run report (Step 11) stays the human-facing surface; this block is the *decision* surface: a parent must never have to reverse-engineer prose to classify what happened.

**It is a transcript surface, not a persistence surface.** It is printed, never written to its own file. Orchestration history stays in `factory-log.md` (per run) and, one level up, in the project log (`../../sdd-project-run/references/project-log-format.md`). If the block is lost with the transcript, the load-bearing fields survive on disk anyway: `Outcome`/`Progress` re-derive from `## Progress` and `change.md`, `Verification` and **`Project impact`** are written into `factory-log.md`'s closing lines (see `factory-log-format.md`), and stop detail lives in the STOP block's artifacts. Only the prose niceties (`Discoveries`, `Recommended next`) are transcript-only.

## When it is emitted

At **every terminal point** of a `/sdd-run` invocation — after the run report when one is printed, and *also* on Step 2 preparation stops (which print no run report and write no `factory-log.md` entry; they still emit this block, with most fields `—`, so a parent gets one uniform surface). Exactly one block per invocation, as the last output.

## Format

Fixed keys, one per line, in this order. A parent greps `^Outcome:`, `^Stop class:`, etc. — key names and the value enums are the contract; free text lives only after the enum or in the list fields. The three list fields (`Impact notes`, `Discoveries`, `Human actions`) carry multiple values by **repeating their key**, one line per value (see the second example); every other key appears exactly once.

```
FACTORY RESULT — <change-id>
Outcome: completed | stopped
Stop class: — | missing-prep | gate-failure | structural-mismatch | human-decision | environment
Verification: APPROVED | NEEDS ATTENTION (<n> findings) | REJECTED (<n> findings) | SKIPPED (trivial) | SKIPPED (declined) | —
Progress: <done>/<total> Automated rows
Execution profile: light | standard | deep | critical | mixed | —
Project impact: none | spec | architecture | roadmap    (comma-separate when several)
Impact notes: <one line per named impact, or —>
Discoveries: <one line each, or none>
Human actions: <one line each, or none>
Recommended next: <command, or —>
```

## Field semantics

- **Outcome** — `completed` means every pending Automated row the run set out to execute is `[x]` and the verification step ran (or was recorded as skipped). Everything else is `stopped`. There is no third value: a run that "mostly worked" is `stopped`, with the honest stop class. One deliberate consequence: a **REJECTED verification is encoded as `Outcome: completed` + `Verification: REJECTED` + `Stop class: —`** — the implementation work finished and the verdict alone carries the failure (the Step 8 STOP block still prints for the human; a parent classifies on the verdict, never on prose).
- **Stop class** (only when `stopped`; `—` when `completed`):
  - `missing-prep` — Step 2 routed to a missing interview-driven artifact (change folder, frame, research, plan) and the run could not proceed (unattended), or the user declined the inline prep (attended).
  - `gate-failure` — a defect exhausted its bounded budget (criteria red after self-fix + replacement, failed integration check, out-of-scope modification). Retrying inside `/sdd-run` is already spent; a parent must not blindly re-invoke.
  - `structural-mismatch` — the plan cannot be followed as written (missing dependency, architecture differs, referenced API absent). The fix is a plan/spec correction, not a retry.
  - `human-decision` — a genuine decision no artifact answers (ambiguous spec, contradiction, destructive op, reserved architectural call). `Human actions` names the concrete question.
  - `environment` — tooling/runtime failure unrelated to the change (command not runnable, host capability missing, git preflight blocked by unrelated dirt/index).
- **Verification** — the canonical verdict from Step 8, verbatim; `—` when the run stopped before verification.
- **Progress** — Automated-row completion at exit (`count([x]) / count(all Automated)` over the whole plan), so a parent can see partial durable progress without opening the plan.
- **Execution profile** — the strongest profile actually used by implementation workers/inline phase groups, or `mixed` when several materially different profiles were used and the strongest alone would misdescribe routing; `—` before execution. Concrete model ids and effort live in `factory-log.md`, not this semantic block.
- **Project impact** — does anything this run learned reach *beyond this change*? `none` is the default and must be earned by absence of signal, not by omission:
  - `spec` — the PRD/frame is ambiguous, contradictory, or wrong in a way that outlives this change (a mismatch decision exposed a requirements hole).
  - `architecture` — reality differs from an architectural assumption other work relies on (a structural STOP whose `Found:` describes the system, not the plan's typo).
  - `roadmap` — a discovery invalidates other roadmap items' assumptions, reveals a missed dependency between items, or makes a future item obsolete/necessary.
  Sources to scan when composing this field: structural-mismatch STOP blocks, ADAPT lines that changed an assumption (not merely a path), scope expansions that revealed a wrong file map on a shared surface, reviewer findings that generalize beyond the diff, and mismatch decisions taken attended. A `completed` run can still carry impact. This field is how the feedback loop from execution back into project planning starts — the parent acts on it (re-evaluation gate); `/sdd-run` only *reports* it and never edits the roadmap or PRD itself.
- **Impact notes** — one line per named impact: what was discovered and what it touches. `—` when impact is `none`.
- **Discoveries** — durable, change-local learnings worth a reader's attention that don't rise to project impact (or that elaborate it): adaptations, surprising couplings, candidate lessons. `none` is fine and common.
- **Human actions** — everything that now needs a person: pending Manual rows (summarized, not re-listed if the run report already lists them — `see run report checklist (N rows)` is enough), the decision behind a `human-decision` stop, triage of a NEEDS ATTENTION / REJECTED verdict.
- **Recommended next** — the single next command, matching the run report's suggestion (`/sdd-impl-review <change-id>`, `/sdd-mr <change-id>`, `/sdd-plan <change-id>` after a structural stop, the missing prep command after `missing-prep`).

## Examples

Completed, clean:

```
FACTORY RESULT — listing-visibility
Outcome: completed
Stop class: —
Verification: APPROVED
Progress: 9/9 Automated rows
Execution profile: standard
Project impact: none
Impact notes: —
Discoveries: none
Human actions: see run report checklist (2 Manual rows)
Recommended next: /sdd-mr listing-visibility
```

Stopped structurally, with roadmap-reaching impact:

```
FACTORY RESULT — srs-review-session
Outcome: stopped
Stop class: structural-mismatch
Verification: —
Progress: 3/8 Automated rows
Execution profile: deep
Project impact: architecture, roadmap
Impact notes: architecture — plan assumes a per-user review queue; the deck store is per-deck, no user dimension exists.
Impact notes: roadmap — S-04 (review reminders) assumes the same per-user queue and inherits this gap.
Discoveries: none
Human actions: decide queue ownership model, then revise the plan (/sdd-plan srs-review-session)
Recommended next: /sdd-plan srs-review-session
```

Preparation stop (Step 2, unattended):

```
FACTORY RESULT — minimal-auth-for-generation
Outcome: stopped
Stop class: missing-prep
Verification: —
Progress: 0/0 Automated rows
Execution profile: —
Project impact: none
Impact notes: —
Discoveries: none
Human actions: run /sdd-plan minimal-auth-for-generation interactively
Recommended next: /sdd-plan minimal-auth-for-generation
```

## Rules

- **Additive and backward-compatible.** No existing artifact schema changes; skipping this block breaks nothing for a human-driven run — but a run invoked by a parent orchestrator must always emit it.
- **Never invent impact, never suppress it.** `Project impact` is the one field where optimism does damage in both directions: a fabricated impact stalls the project loop on noise; a suppressed one lets the loop execute work built on an invalidated assumption.
- **The block classifies; it does not narrate.** Detail lives in the STOP block, the run report, and `factory-log.md`. Each list line here is one sentence.
