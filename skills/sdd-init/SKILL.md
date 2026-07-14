---
name: sdd-init
description: Initialize a `context/` directory for the SDD workflow. Accepts an optional target directory (`/sdd-init [dir]`) so teams can place `context/` next to their own code; with no argument it initializes at the repo root. Scaffolds `context/`, a root `README.md` documenting the flat layout, and `.sdd.yml` (`layout: flat`). Also asks the operator's audience preference and records it in a gitignored, per-operator `.sdd.local.yml` (never committed). A repo may hold several roots; the entry skills let the user pick which one to work in.
---

# /sdd-init — Initialize /context Directory

Scaffold a `context/` directory and its root `README.md`, which documents the flat artifact layout the `/sdd-*` skills follow. Idempotent: the directory, the README, `.sdd.yml`, `.sdd.local.yml`, and `.gitignore` are each independently create-if-absent; re-running on an initialized root is a no-op.

Takes an optional `[target-dir]` argument: `/sdd-init [target-dir]`. Let `ROOT = <target-dir>/context`, where `<target-dir>` defaults to `.` (so `ROOT = context`). This lets a repo hold multiple roots — one at the repo root, and/or one under any team directory (e.g. `/sdd-init frontend/posting` creates `frontend/posting/context/`). Each root is self-contained; the entry skills discover every root and ask the user which to use (see `../sdd-shape/references/context-resolution.md`).

Per-change folders (`ROOT/{foundation,changes,archive}/`) are **not** created here — they are created lazily the first time `/sdd-shape` (or `/sdd-plan`) writes an artifact into this root. `/sdd-init` only lays down the root so the conventions have a home and a place to be documented.

This skill is the explicit entry point for users who want to scaffold the workflow conventions up-front. It is NOT a precondition for the other skills — they self-bootstrap their own folders on demand.

## Process

### Step 0: Resolve `ROOT`

Read the optional `[target-dir]` argument. Set `ROOT = <target-dir>/context` (default `<target-dir>` = `.`, so `ROOT = context`).

### Step 1: Scaffold `ROOT`

If the directory exists, leave it untouched and note `present`. Otherwise create it with `mkdir -p "$ROOT"` and note `created`.

### Step 2: Scaffold `ROOT/README.md`

If `ROOT/README.md` exists, leave it untouched and note `present`. Otherwise write it with this canonical content (embedded inline — no separate template file):

```
# Context — Spec-Driven Development artifacts

Artifacts produced by the `/sdd-*` skills live here, in a flat layout:

    context/
    ├── foundation/         # cross-change living docs
    │   └── <project-slug>/ # shape-notes.md, prd.md, roadmap.md per project/feature
    ├── changes/            # in-flight changes (<change-id>/: change.md, plan.md, …)
    └── archive/            # completed changes, moved here on archive

A repo may contain several `context/` roots — one at the repo root and/or one
under any team directory (`/sdd-init frontend/posting` creates
`frontend/posting/context/`). Each root is self-contained and flat, and is
marked by its own `.sdd.yml` (`layout: flat`). The `/sdd-*` entry skills
discover every root in the repo and ask which one to use before writing
anything, so teams can keep their artifacts next to their own code instead of
sharing one root. Legacy workspace-partitioned roots created by older versions
of this skill (a per-workspace subfolder under `context/`, no `layout:` key)
remain readable — the entry skills still resolve the workspace subfolder and
operate on them as before.

## The three kinds

- **foundation/** — cross-change living documents (product requirements, roadmap,
  tech-stack, glossary, lessons). Edit-in-place; when a doc is fully superseded, move it to
  `foundation/archive/YYYY-MM-DD-<doc>.md`. Shape/PRD/roadmap outputs are grouped per
  project/feature in a `<project-slug>/` subfolder.
- **changes/** — in-flight changes, one folder per change at `changes/<change-id>/`,
  identified by a `change.md` identity file. Holds research, frame, plan, reviews. Created
  via `/sdd-plan` (or `/sdd-new`).
- **archive/** — completed changes, moved here from `changes/` when archived. Read-only by
  convention; skills refuse to write here.
```

### Step 2.5: Record the layout marker, and resolve the operator's audience preference

Two separate files, two separate concerns:

- `ROOT/.sdd.yml` — **committed**, shared by the whole team. Marks this root as flat
  (`layout: flat`) only. No `audience:` key belongs here.
- `ROOT/.sdd.local.yml` — **gitignored**, per-operator. Records which voice (`plain` or
  `technical`) this individual operator wants, per the audience resolution contract in
  `../sdd-shape/references/plain-mode.md`. Each teammate answers this once, in their own clone;
  it is never shared or committed.

**`ROOT/.sdd.yml` (layout only).** Idempotent:

- If absent, create it fresh (see template below).
- If it already exists and has `layout:`, leave it untouched and note `present`. If it also
  still carries a stale `audience:` key from an older version of this skill, drop that key
  (audience now lives only in `.sdd.local.yml`) while leaving `layout:` and any other content
  alone.
- If it exists but is missing `layout:` (a root written by an even older version of this
  skill), backfill just that key.

```yaml
# Set by /sdd-init. layout: flat marks this as a flat context root (see
# ../sdd-shape/references/context-resolution.md). Audience preference lives in
# the gitignored .sdd.local.yml next to this file, not here — see
# skills/sdd-shape/references/plain-mode.md.
layout: flat
```

**`ROOT/.sdd.local.yml` (per-operator audience).** Idempotent, independent of the step above:

- If `ROOT/.sdd.local.yml` already exists with an `audience:` value, leave it untouched and
  note `present` — don't re-ask.
- Otherwise ask the operator one plain question (use the host's interactive-question tool):

  Ask the user: "Who will mostly be using this workflow?" with options:

  - "Developers (Recommended)" (description: "Full technical workflow — schemas, requirements, stack choices, and git are all shown.")
  - "Non-technical people, e.g. product owner / project manager" (description: "Plain-language workflow. Technical decisions are handled for you and flagged for a developer to review. You'll go from an idea to a merge request a developer reviews.")

  Map "Developers" → `technical`; the other option → `plain`. Before writing, ensure
  `ROOT/.gitignore` exists and contains a line `.sdd.local.yml` — create the file if absent, or
  append the line if the file exists but lacks it (skip if already present, so re-runs don't
  duplicate the line). Then write `ROOT/.sdd.local.yml`:

  ```yaml
  # Set by /sdd-init. Per-operator preference — gitignored, never committed.
  # Each teammate answers this once in their own clone. See
  # skills/sdd-shape/references/plain-mode.md.
  audience: <plain|technical>
  ```

`audience` in `.sdd.local.yml` is this operator's voice preference for this root. Every
audience-aware skill reads it the same way (and asks once, saving the answer here, if it is
missing) — it is never overridden by, or copied into, a committed artifact. See the audience
resolution order in `../sdd-shape/references/plain-mode.md`.

### Step 3: Print summary

Print a status block using the resolved `ROOT`, e.g.:

```
frontend/posting/context/                [created|present]
frontend/posting/context/README.md       [created|present]
frontend/posting/context/.sdd.yml        [created|present]  (layout: flat)
frontend/posting/context/.sdd.local.yml  [created|present]  (audience: <plain|technical>, gitignored)
frontend/posting/context/.gitignore      [created|present]  (contains .sdd.local.yml)
```

(With no target-dir argument, `ROOT` is simply `context/`.)

Then a one-paragraph guide on the layout and where to look next:

- This root is flat: `ROOT/{foundation,changes,archive}/`. A repo may have several roots; run `/sdd-init [dir]` again under another team directory to add one.
- Run `/sdd-shape` to start a new project/feature — it discovers the available roots (asking which to use if there's more than one), then creates `ROOT/foundation/<project-slug>/` lazily and shapes into it.
- `/sdd-plan` creates `ROOT/changes/<change-id>/` for a single change; archiving moves a completed change to `ROOT/archive/`.

Stop. Do not chain into `/sdd-shape` or any other skill; the user runs those when they have something to do.

## Notes

- **Idempotent.** Re-running `/sdd-init` on an initialized root is a no-op (with a status print). It must never overwrite existing content.
- **Folders are lazy.** `/sdd-init` does not pre-create `ROOT/foundation/`, `ROOT/changes/`, or `ROOT/archive/`. The entry skills create them (and any per-project subfolder) the first time they write into this root.
- **`lessons.md` and other foundation docs are not scaffolded here.** Those files are owned end-to-end by the skills that read and write them (e.g. `/sdd-lesson`, `/sdd-impl-review`'s triage branches), which self-bootstrap them under `ROOT/foundation/` on first use.
- **`ROOT/.sdd.yml` carries `layout: flat` only**, marking this directory as a discoverable flat context root. It is committed and shared by the whole team. Written once (idempotent; `layout:` is backfilled onto older roots that predate it; a stale `audience:` key from an older version of this skill is dropped on the next run). Read by the entry skills to resolve `CONTEXT_ROOT`. See `../sdd-shape/references/context-resolution.md`.
- **`ROOT/.sdd.local.yml` carries the per-operator `audience:` preference** (`plain` | `technical`). It is gitignored and never committed — each teammate answers the audience question once, in their own clone, and the answer stays local to them. `/sdd-init` creates `ROOT/.gitignore` (containing `.sdd.local.yml`) alongside it so the file can never accidentally land in version control. `audience:` here is the sole source of the operator's voice preference — there is no committed override; every audience-aware skill reads it (or asks once if absent). See `../sdd-shape/references/plain-mode.md` for the full audience resolution order.
