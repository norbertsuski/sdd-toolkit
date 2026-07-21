---
name: sdd-archive-project
description: Archive a completed project by moving its foundation/<slug> folder into context/<app>/foundation/archive/ and stamping roadmap.md with archived status
---

# /sdd-archive-project — Close a Project

Move a completed project's foundation folder from `context/<app>/foundation/<project-slug>/` to `context/<app>/foundation/archive/<created-date>-<project-slug>/` (the same app's foundation archive), stamp `roadmap.md` frontmatter with `status: archived` + `archived_at`, use `git mv` so file history follows, and commit.

This is the project-level sibling of `/sdd-archive`. Where `/sdd-archive` closes a single **change** (`changes/<change-id>/`), this closes an entire **project** — its `shape-notes.md`, `prd.md`, `roadmap.md`, and any `prd-vN.md` versioned saves — once all its work is done.

`<app>` is the resolved workspace directory's name (e.g. `assets`, `campaigns`, `crm`); it is derived from the resolved foundation-folder path (see "Resolution"). **Repos with no workspace layout** keep the flat `context/foundation/…` layout — drop the `<app>` segment from every path below.

The gate is **lenient warn-only** with **three hard blocks**: uncommitted edits inside the project folder, pre-existing staged changes anywhere, and any in-flight change still pointing at this project (archiving would orphan it). Everything else — unfinished roadmap slices, open PRD questions — is surfaced as a warning followed by a confirmation prompt; the user can still archive.

After archiving, other sdd skills refuse to write inside `context/*/foundation/archive/…` — archived projects are read-only by convention.

## Initial Response

When this command is invoked:

1. **An argument was provided** → parse it (see "Argument Parsing") and proceed to "Resolution".
2. **No argument** → respond with this message and **STOP**:

```
I'll archive a completed project. Please provide a project slug or path:

Examples:
  /sdd-archive-project brickworks-preview-panel
  /sdd-archive-project @context/assets/foundation/brickworks-preview-panel/

List active projects with: `ls -d context/*/foundation/*/ | grep -v /foundation/archive/`
```

Then **wait** for the user to provide an argument.

## Argument Parsing

Take the first whitespace-delimited token. Normalize:

1. Strip a leading `@` if present.
2. Strip a trailing `/` if present.
3. If the result contains `/`, take the last non-empty path segment.

The result is `<project-slug>`.

## Resolution

1. Resolve `<project-slug>` to a foundation folder by globbing `context/*/foundation/<project-slug>/` (never match under `.../foundation/archive/…`). A valid project folder contains at least one of `shape-notes.md`, `prd.md`, `roadmap.md`.
   - **Exactly one match** → use it. Derive `<app>` from the matched path (`context/<app>/foundation/…`).
   - **More than one match** → the same slug exists under multiple apps. Ask the user which app to archive, then proceed with the chosen path.
   - **Zero matches** → it may already be archived. Check `context/*/foundation/archive/*-<project-slug>` for a directory whose name ends with `-<project-slug>`. If found, print `error: project "<project-slug>" is already archived at <path>.` and STOP. Otherwise print `error: no project folder at context/*/foundation/<project-slug>/. Run `ls -d context/*/foundation/*/ | grep -v /foundation/archive/` to list active projects.` and STOP.

   _(Flat-layout repos: glob `context/foundation/<project-slug>/` and `context/foundation/archive/*-<project-slug>` instead; there is no `<app>` segment.)_

## Hard blocks

Three pre-flight checks. Any failing blocks the archive.

**1. Uncommitted edits inside the project folder.** Run `git status --porcelain "context/<app>/foundation/<project-slug>/"`. If output is non-empty, block and print:

```
✗ Cannot archive: context/<app>/foundation/<project-slug>/ has uncommitted changes.

  <one line per offending path>

Commit or stash them first, then re-run /sdd-archive-project.
```

**2. Pre-existing staged changes anywhere.** The archive commit bundles whatever is staged. Run `git diff --cached --quiet`. If exit code is non-zero, block and print:

```
✗ Cannot archive: pre-existing staged changes would be bundled into the archive commit.

  <output of `git diff --cached --name-only`>

Commit them first or `git reset` to unstage, then re-run /sdd-archive-project.
```

**3. In-flight changes still pointing at this project.** Glob `context/<app>/changes/*/change.md`. For each, read its frontmatter `roadmap:` and `status:`. If `roadmap:` resolves to this project's `context/<app>/foundation/<project-slug>/roadmap.md` **and** `status:` is not `archived`, collect that change-id. If any were collected, block and print:

```
✗ Cannot archive: these active changes still point at this project:

  <change-id>  (status: <status>)
  ...

Finish and /sdd-archive each of them first — archiving the project now would orphan them.
```

Either check 1/2 failing, or a non-empty list in check 3 → STOP. These are hard blocks; do not proceed to the warn prompt.

If `git` is not available or the repo is not a git repo, print `warning: not a git repository — skipping uncommitted-changes blocks.` and continue (checks 1–2 skipped; check 3 still runs — it reads files, not git). Archive still works without git; we just lose history-preservation via `git mv` and skip the commit step.

## Soft warnings (non-blocking)

Collect these, then present all at once with a single confirmation prompt.

1. **Unfinished slices**: if `roadmap.md` exists, parse its `## At a glance` table and count rows whose **Status** column is not `done`. If any, queue: `<N> roadmap slices not done: <comma-separated "<Change ID> (<Status>)" tokens, truncated to 5 with "…">.`
2. **Open PRD items**: if `prd.md` exists, check its `## Open Questions` section for entries and scan for `# TODO` markers. If any remain, queue: `PRD still has <N> open item(s) (Open Questions / TODO).`
3. **No roadmap**: if `roadmap.md` is absent, queue: `Project has no roadmap.md — it was never roadmapped.`

If at least one warning was queued, print:

```
⚠ /sdd-archive-project warnings for <project-slug>:

  - <warning 1>
  - <warning 2>
```

Then ask (use the interactive prompt mechanism):

- question: `Archive project "<project-slug>" anyway?`
  header: `Archive project`
  options:
  - label: `Continue archiving`
    description: `Move foundation/<project-slug>/ to foundation/archive/ despite the warnings.`
  - label: `Cancel`
    description: `Don't archive. Exit cleanly.`
    multiSelect: false

- **Continue archiving** → proceed to "Move and stamp".
- **Cancel** → print `Cancelled. Project unchanged.` and STOP.

If no warnings were queued, skip the prompt and proceed directly.

## Move and stamp

1. **Compute the archive destination.**
   - `DATE` = the project's created date: read `created:` frontmatter from `shape-notes.md`, else `roadmap.md`, else `prd.md` (first that exists and has a `YYYY-MM-DD` value). If none is found, use today: `date -u +%F`.
   - `DEST="context/<app>/foundation/archive/${DATE}-<project-slug>"`.
   - If `$DEST` already exists, print `error: archive destination "<DEST>" already exists. Inspect manually.` and STOP.

2. **Stamp `roadmap.md`** (in place, before the move; skip this step if the project has no `roadmap.md`):
   - Set `status: archived`.
   - Set `archived_at: <ISO-8601 datetime, today, UTC>` — `date -u +"%Y-%m-%dT%H:%M:%SZ"`.
   - Set `updated: <today as YYYY-MM-DD>`.
   - Edit only these three frontmatter lines. Leave `created`, `version`, `main_goal`, etc. alone. If `status:`/`archived_at:` keys are absent from the frontmatter, add them.

3. **Move the folder.**
   - Prefer `git mv "context/<app>/foundation/<project-slug>" "$DEST"` so history follows.
   - If `git mv` fails, fall back to `mkdir -p "context/<app>/foundation/archive"` then `mv "context/<app>/foundation/<project-slug>" "$DEST"`. Print a warning if the fallback was used.
   - Confirm post-move: `[ -d "$DEST" ] && [ ! -d "context/<app>/foundation/<project-slug>" ]`. If either fails, print a diagnostic and STOP.

4. **Stage the stamp into the rename** (only if `roadmap.md` exists): `git add "$DEST/roadmap.md"` so the frontmatter stamp lands in the same commit as the rename.

5. **Commit.**

   ```bash
   git commit -m "$(cat <<'EOF'
   chore(<app>): archive project <project-slug>
   EOF
   )"
   ```

   The scope is the **`<app>`** the project lives under (e.g. `chore(assets): archive project brickworks-preview-panel`). This repo's commitlint enforces a fixed scope list of package/app names and rejects a literal `archive` scope, so the app is the correct, accepted scope. (Flat-layout repos with no scope-enum may use `chore(archive): archive project <project-slug>`.) Never pass `--no-verify` or signing-bypass flags; if a pre-commit hook fails, fix the cause and create a new commit. Skip this step entirely if `git` is unavailable.

6. **Print confirmation:**

```
✓ Archived project <project-slug>
  context/<app>/foundation/<project-slug>/  →  <DEST>/

roadmap.md updated:      ← print this block only if the project had a roadmap.md
  status:       archived
  archived_at:  <ISO datetime>
  updated:      <today>

Committed as: <short SHA> chore(<app>): archive project <project-slug>

The folder is now read-only by convention.
```

## Error handling

- Any unexpected filesystem error during the move leaves the source folder in place; the `roadmap.md` stamp lands before the move, so on partial failure you may see `status: archived` in `context/<app>/foundation/<project-slug>/roadmap.md` while the folder is still under `foundation/`. Inspect manually; re-running is safe (Resolution detects the already-archived copy).
- Do NOT attempt rollback — the stamp is intent-marking and partial state is recoverable by hand.

## What this skill does NOT do

- Does not close roadmap items — the whole roadmap moves with the project; there is no per-item flip like `/sdd-archive` does.
- Does not touch the app-level change archive `context/<app>/archive/` — that is `/sdd-archive`'s domain. This skill only writes under `context/<app>/foundation/archive/`.
- Does not archive individual changes — run `/sdd-archive <change-id>` for those first (hard block 3 enforces this).
- Does not push. The archive commit lands locally; `git push` is the user's call.
- Does not run tests/build as a gate — the gate is lenient warn-only by design.
- Does not unarchive. To revisit an archived project, reference the archived folder for context.
