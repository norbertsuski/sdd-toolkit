# `factory-log.md` reference

The factory's append-only orchestration record, at `$CONTEXT_ROOT/changes/<change-id>/factory-log.md`. It answers "which strategy ran, why, what happened" for resumed runs and reviewing humans.

**It is observability, not a state machine.** Execution truth lives in `plan.md`'s `## Progress` (see `../../sdd-plan/references/progress-format.md`); lifecycle truth lives in `change.md`. If this file is deleted, nothing breaks — the next run re-derives strategy from the plan. If it disagrees with Progress, Progress wins.

## Who writes it

Only `/sdd-run`. Workers never write it. No other skill reads or requires it. It lives inside the change folder and is committed with the change, **one commit behind** — the same chicken-and-egg the Progress SHA write-back has: a phase's outcome row carries that phase's commit SHA, so it is written *after* the commit and lands in the *next* phase's commit (the factory stages this file alongside `plan.md` in every commit it authors) or, for the last phase and the run's closing lines (verification, result), in the executor's epilogue commit (the factory extends the epilogue staging set with this file). After a crash, any unstaged tail is picked up by the next run's first commit; a crash can lose the last uncommitted row — see Rules.

## Structure

One `# Factory Log — <change-id>` H1, then one `## Run <K> — <YYYY-MM-DD>` section per factory invocation, append-only (a resumed/interrupted run gets a new section; never rewrite an old one).

```markdown
# Factory Log — <change-id>

> Orchestration record written by /sdd-run. Execution truth is plan.md ## Progress; this file is additive observability. Append-only.

## Run 1 — 2026-08-24

- **Mode**: attended | unattended
- **Entry state**: <lifecycle state found, e.g. "planned, 0/9 progress rows done">
- **Plan fingerprint**: <hash of plan.md with the ## Progress section stripped — e.g. `sha256:1f3a9c…` (first 12 hex chars are enough)>
- **Strategy**: single-agent | sequential multi-agent | multi-agent DAG
- **Why**: <the one-block rationale printed at selection, verbatim>
- **Graph**: `P1 → {P2 ∥ P3} → P4`   (omit for single-agent)

### Phases

| Phase | Worker | Outcome | Retries | Commit |
|---|---|---|---|---|
| P1 <title> | inline | done | 0 | abc1234 |
| P2 <title> | w1-phase-2 | done | 0 | def5678 |
| P3 <title> | w2-phase-3 | done | 1 | 9abcdef |
| P4 <title> | w3-phase-4 | stopped | 1 | — |

- **Verification**: <"impl-review: <verdict>" | "reviewer: APPROVED" | "reviewer: NEEDS ATTENTION (2 findings)" | "reviewer: REJECTED (…)" | "SKIPPED (trivial)" | "SKIPPED (declined)">
- **Human interventions**: <"none" | one line each>
- **Project impact**: <none | spec | architecture | roadmap — one line per named impact>   (mirrors the run's FACTORY RESULT; see `run-result-contract.md`)
- **Result**: complete | stopped (<one-line reason>)

## Run 2 — 2026-08-25

- **Entry state**: resumed — P1–P3 done per Progress, P4 pending
- **Strategy**: single-agent (carried from Run 1 graph; only P4 remains)
…
```

## Rules

- **Append-only.** New run → new `## Run <K>` section at the end. Within a run, the factory may extend its own section as waves complete (phases table rows, verification line), but never edits earlier runs.
- **Worker column**: `inline` for single-agent execution; the worker id (`w<K>-phase-<N>`) otherwise.
- **Retries** counts fresh replacement workers for that phase (0 or 1 under the standard budget) — worker-internal self-fix attempts are not tallied here (they are narrated in the transcript and, on STOP, in the report). The budget spans runs: a later run reads this column and, when the fingerprint is unchanged, does not silently re-retry a phase that already stopped after a replacement. Known bounded gap: a crash can lose the last uncommitted row, which at worst grants that one phase one extra replacement on the next run — never an unbounded loop.
- **Scope expansions** (`SCOPE+`) are recorded as a one-line note under the phases table when they occur: `SCOPE+ P<N>: <paths> (<why>)`.
- **Plan fingerprint** is how a later run decides whether the recorded graph is still valid: fingerprint match → reuse the graph, re-select strategy over the remaining phases; mismatch → re-derive. Hash the plan file with the `## Progress` section stripped, so the factory's own row-flipping never invalidates the graph.
- **Commit** is the phase's closing short SHA, mirroring the Progress SHA suffix; `—` for stopped or empty-diff phases.
- **Project impact** persists the run's `FACTORY RESULT` impact classification (`run-result-contract.md`) so it survives the transcript: a parent orchestrator resuming later must be able to see that a run discovered something roadmap-reaching even when the session that printed the block is gone. `none` is written explicitly.
- **No secrets, no full logs.** Failure summaries are one line; the transcript and STOP block carry detail.
- Keep it small: this file exists to make three questions cheap on resume — *what strategy, why, where did it stop* — not to duplicate the transcript.
