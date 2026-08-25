# Verification freshness — one lifecycle contract

Canonical contract reused by `/sdd-run`, every executor variant, `/sdd-impl-review`, `/sdd-project-run`, `/sdd-help`, and closeout skills.

## Meaning of statuses

- `implementing` — executable work is in progress; no earlier verification is current.
- `implemented` — all intended implementation may exist, but current verification is absent or stale.
- `impl_reviewed` — all Automated Progress rows are complete **and** `change.md` points to a verification snapshot that matches the current implementation scope. The verdict may still be NEEDS ATTENTION or REJECTED; the status means current, not positive.

Any executor that finds pending implementation work transitions `{planned, plan_reviewed, implemented, impl_reviewed} -> implementing` before editing. All executor variants use this exact rule. Finishing implementation writes `implemented`. A phase-only review never writes `impl_reviewed`.

## Verification identity in `change.md`

A full current verification writes these additive frontmatter fields together:

```yaml
status: impl_reviewed
verified_source: review:reviews/impl-review.md | factory-log:run-<K>
verified_verdict: APPROVED | NEEDS ATTENTION | REJECTED | SKIPPED (trivial) | SKIPPED (declined)
verified_fingerprint: sha256:<hex>
verified_at: YYYY-MM-DD
```

`verified_source` selects exactly one evidence record; readers never choose between an old review file and a newer factory log by precedence or mtime. The selected record's verdict must equal `verified_verdict`.

## Implementation fingerprint

Build the verification scope deterministically from:

1. every implementation/test path in the plan's `Changes Required` blocks;
2. every touched file recorded for phase commits in `factory-log.md` or the executor's run report;
3. every non-SDD-metadata path in commits referenced by Progress SHA suffixes.

Exclude the change's orchestration/spec metadata (`change.md`, `plan.md`, `plan-brief.md`, `factory-log.md`, `reviews/**`, `follow-ups/**`) and project-log/roadmap-only files. Sort unique repo-relative paths. For each path, hash the path plus its current content (or an explicit missing marker), then hash that canonical stream as `sha256:<hex>`. Store the final value as `verified_fingerprint`.

On every state derivation, rebuild the same scope/fingerprint. A mismatch, missing selected source, verdict mismatch, missing snapshot field, pending Automated row, or dirty verification-scope path means **stale** -> derive `in-progress` and run fresh verification. Legacy `impl_reviewed` changes without the snapshot fields are conservatively stale once under this contract; the next review migrates them.

This fingerprint is scoped so later verified dependent changes on the same branch do not invalidate their prerequisite merely by changing unrelated files. Scope-expansion and actual phase-commit paths keep it broader than the plan's predicted file map.

## Writers

- `/sdd-impl-review`, full-plan only after all Automated rows complete: source is the saved review path; verdict comes from its report.
- `/sdd-run` unattended reviewer or explicit skip: source is the exact factory run number; verdict comes from that run's closing Verification line.
- Triage that edits implementation or the reviewed plan sets status back to `implemented`; snapshot fields may remain as history but readers ignore them until a new full review overwrites all fields.

Write the snapshot and its selected evidence in the same closing commit. Never set `impl_reviewed` first and fill identity later.
