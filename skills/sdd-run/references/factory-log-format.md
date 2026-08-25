# `factory-log.md` reference

The factory's append-only orchestration record, at `$CONTEXT_ROOT/changes/<change-id>/factory-log.md`. It answers "which strategy ran, why, what happened" for resumed runs and reviewing humans.

**It is a durable orchestration/event record, not a second progress tracker.** Execution truth lives in `plan.md`'s `## Progress`; lifecycle and verification identity live in `change.md`. Strategy can be re-derived, but persisted retry budgets, selected factory verification sources, and unacknowledged `Project impact` are safety inputs. Deleting the file forces conservative recovery (fresh verification/retry confirmation and project-impact inspection); it is no longer claimed to be consequence-free. If phase outcomes disagree with Progress, Progress wins.

## Who writes it

Only `/sdd-run` writes it; workers never do. `/sdd-project-run` reads persisted `Project impact` for crash-safe all-change gating, and `change.md.verified_source` may select one run's Verification line. It lives inside the change folder and is committed with the change, **one commit behind** for phase SHA rows; closing verification/impact lines and the matching verification snapshot must land together in the closing commit. After a crash, any unstaged tail is picked up by the next run — see Rules.

## Structure

One `# Factory Log — <change-id>` H1, then one `## Run <K> — <YYYY-MM-DD>` section per factory invocation, append-only (a resumed/interrupted run gets a new section; never rewrite an old one).

```markdown
# Factory Log — <change-id>

> Append-only orchestration event ledger written by /sdd-run. Execution truth is plan.md ## Progress; retry, verification-source, and project-impact events are crash-safety inputs.

## Run 1 — 2026-08-24

- **Mode**: attended | unattended
- **Entry state**: <lifecycle state found, e.g. "planned, 0/9 progress rows done">
- **Plan fingerprint**: <hash of plan.md with the ## Progress section stripped — e.g. `sha256:1f3a9c…` (first 12 hex chars are enough)>
- **Strategy**: single-agent | sequential multi-agent | multi-agent DAG
- **Why**: <the one-block rationale printed at selection, verbatim>
- **Graph**: `P1 → {P2 ∥ P3} → P4`   (omit for single-agent)

### Phases

| Phase | Worker | Profile | Model / effort | Outcome | Retries | Commit |
|---|---|---|---|---|---|---|
| P1 <title> | inline | standard | inherited / medium | done | 0 | abc1234 |
| P2 <title> | w1-phase-2 | light | <host-id> / low | done | 0 | def5678 |
| P3 <title> | w2-phase-3 | deep | <host-id> / high | done | 1 | 9abcdef |
| P4 <title> | w3-phase-4 | standard | default / medium | stopped | 1 | — |

### Execution profile decisions

- `P1 — profile=standard; tier=standard; model=inherited; effort=medium; context=scoped; verification=independent; why=<evidence>`
- `P2 — profile=light; tier=economical; model=<host-id>; effort=low; context=small; verification=normal; why=<evidence>`
- `reviewer — profile=deep; tier=strong; model=<host-id>; effort=high; context=broad; verification=independent; why=<evidence>`

- **Reviewer profile**: <profile — model/resolution — effort — why>
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
- **Profile / Model / effort** follow `execution-profiles.md`. Concrete model ids appear only when the host exposed and accepted an override; otherwise write `inherited` or `default`. On a replacement, the row records the replacement's final profile and a note below the table records `PROFILE+ P<N>: <old> -> <new> (<evidence>)`.
- **Execution profile decisions** persist the complete shared record shape (all axes + why); the phase table is only its compact index. Do not rely on transcript-only rationale.
- **Retries** counts fresh replacement workers for that phase (0 or 1 under the standard budget) — worker-internal self-fix attempts are not tallied here (they are narrated in the transcript and, on STOP, in the report). The budget spans runs: a later run reads this column and, when the fingerprint is unchanged, does not silently re-retry a phase that already stopped after a replacement. Known bounded gap: a crash can lose the last uncommitted row, which at worst grants that one phase one extra replacement on the next run — never an unbounded loop.
- **Scope expansions** (`SCOPE+`) are recorded as a one-line note under the phases table when they occur: `SCOPE+ P<N>: <paths> (<why>)`.
- **Plan fingerprint** is how a later run decides whether the recorded graph is still valid: fingerprint match → reuse the graph, re-select strategy over the remaining phases; mismatch → re-derive. Hash the plan file with the `## Progress` section stripped, so the factory's own row-flipping never invalidates the graph.
- **Commit** is the phase's closing short SHA, mirroring the Progress SHA suffix; `—` for stopped or empty-diff phases.
- **Project impact** persists the run's `FACTORY RESULT` impact classification (`run-result-contract.md`) so it survives the transcript: a parent orchestrator resuming later must be able to see that a run discovered something roadmap-reaching even when the session that printed the block is gone. `none` is written explicitly.
- **Safety-critical loss behavior**: if the file/specific selected run is missing, `verified_source: factory-log:run-<K>` is stale and unresolved-impact recovery cannot prove acknowledgement. Re-run verification and conservatively re-evaluate known impact; never silently assume `none`.
- **No secrets, no full logs.** Failure summaries are one line; the transcript and STOP block carry detail.
- Keep it small: this file exists to make three questions cheap on resume — *what strategy, why, where did it stop* — not to duplicate the transcript.
