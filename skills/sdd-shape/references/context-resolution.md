# Context resolution — which `context/` root a skill operates in

This contract is shared by every `sdd-*` skill that reads or writes artifacts.
It defines how a skill discovers the available `context/` roots, lets the user
pick one, and resolves the single variable **`CONTEXT_ROOT`** that all artifact
paths are relative to.

## What is a context root

A **context root** is a directory named `context/` that contains a `.sdd.yml`
marker. A repo may contain several — one at the repo root, and/or one under each
team's directory (e.g. `posting/context/`, `listing/context/`). `.sdd.yml` holds
one key:

```yaml
layout: flat            # flat | (absent = legacy app-partitioned)
```

## Discovery

List every root by finding its marker, excluding vendor/build dirs:

```bash
find . -name .sdd.yml \
  -not -path '*/node_modules/*' -not -path '*/.git/*' \
  -not -path '*/dist/*' -not -path '*/build/*' \
  -not -path '*/.next/*' -not -path '*/coverage/*' 2>/dev/null
```

Each match's directory (its `dirname`) is a context root path.

## Layout detection

For a discovered root `R`:

- If `grep -qE '^layout:[[:space:]]*flat' R/.sdd.yml` → **flat**.
- Otherwise → **legacy** (app-partitioned). Confirm by structure: a direct
  `R/foundation/` child is flat; `R/*/foundation/` subfolders are legacy.
  Roots created before this feature have no `layout:` key and are legacy.

## Resolution algorithm

1. **Discover** all roots (above).
2. **None found** → this project is not initialized. Offer to run `/sdd-init`
   (ask for a target dir; default is the repo root), then re-run discovery.
3. **One or more found** → present the list as a pick (show each root's path and
   its layout). Pre-select the root nearest to the current working directory
   (the deepest root that is an ancestor of, or equal to, cwd) as the default,
   but always show the choice. The user picks one root `R`.
4. **Set `CONTEXT_ROOT`:**
   - `R` is **flat** → `CONTEXT_ROOT = R` (e.g. `posting/context`).
   - `R` is **legacy** → resolve `<app>`: list `R/*/` subdirectories, have the
     user pick one, then `CONTEXT_ROOT = R/<app>` (e.g. `context/assets`).

## The `CONTEXT_ROOT` contract

- Every artifact path is written relative to `CONTEXT_ROOT`:
  `CONTEXT_ROOT/foundation/…`, `CONTEXT_ROOT/changes/…`, `CONTEXT_ROOT/archive/…`.
- Write-entry skills (`/sdd-shape`, `/sdd-plan`, `/sdd-new`) run this algorithm once,
  then hand the resolved `CONTEXT_ROOT` (or a fully-resolved artifact path derived from
  it) to downstream skills. Pure downstream skills (e.g. `/sdd-prd`, `/sdd-implement`,
  `/sdd-tdd`) never re-run discovery; they operate on the path they are handed.
- Standalone read entry points (`/sdd-roadmap`, `/sdd-plan-review`, `/sdd-health-check`,
  `/sdd-help`, `/sdd-archive`) are invoked directly without a live `CONTEXT_ROOT` in
  scope, so they run discovery themselves — to *locate* an existing artifact (a read),
  or to enumerate roots for a status report. This is consistent with the algorithm: the
  "never re-run discovery" rule applies only to skills handed a root by a write-entry
  skill within the same run.
- `audience` is a per-operator preference in `$CONTEXT_ROOT/.sdd.local.yml` (gitignored); see
  `plain-mode.md`. The committed `.sdd.yml` holds `layout:` only.

## Frontmatter rule

- **Flat roots**: artifacts OMIT the `app:` frontmatter field (the root's location
  is the scope).
- **Legacy roots**: preserve `app: <app>` on read; existing artifacts keep it.
  Never write new legacy-layout artifacts.
