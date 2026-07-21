---
name: sdd-map
description: >
  Draw a Mermaid dependency graph of a project's roadmap — slices as nodes,
  Prerequisites as edges, coloured by status (done / ready / blocked) with the
  north-star slice highlighted. Reads roadmap.md, writes a derived roadmap-map.md
  beside it, and opens it in the editor. Never edits the roadmap itself. The
  visual "you are here" companion to /sdd-help. Trigger phrases: "map the
  roadmap", "draw the roadmap", "show the dependency graph", "visualise the
  plan", "sdd map", "narysuj roadmapę", "pokaż zależności slice'ów". Use AFTER
  /sdd-roadmap.
---

# /sdd-map — Visualise the Roadmap as a Dependency Graph

This skill is the **visual twin of `/sdd-help`'s "you are here" probe**. Where `/sdd-help`
reports where a project stands in prose and names the single next command, `/sdd-map` renders
the roadmap's vertical slices and their dependencies as a **Mermaid graph** — so you can see the
whole plan at a glance: what's `done`, what's `ready` to start right now, and what's `blocked`.

It **reads** a project's `roadmap.md`, **writes** a derived `roadmap-map.md` beside it (a fenced
```mermaid block with a generated-on stamp), and **opens** that file in the editor. It never
edits `roadmap.md` or any other artifact — the roadmap is the source of truth and the map is a
regenerable snapshot. Re-running overwrites `roadmap-map.md` in place.

## When to use, when to skip

**Use when**: a `roadmap.md` exists and you want to *see* the slice dependency graph and each
slice's status — orientation on a project with more than a couple of slices, spotting what's
unblocked, or sharing the plan shape in a review.

**Skip when**: there's no roadmap yet (run `/sdd-roadmap` first); or you just want the next
command in prose, not a picture (that's `/sdd-help`).

## Relationship to other skills

- `/sdd-roadmap` — upstream. Produces the `roadmap.md` this reads. `/sdd-map` never edits it.
- `/sdd-help` — the prose sibling. `/sdd-help` orients + recommends the next command;
  `/sdd-map` draws the same state. They cross-reference each other.

## Initial Response — resolve the target

When this skill is invoked, resolve **which roadmap to draw** the same way `/sdd-help` resolves
a project:

1. **An argument was provided** (`/sdd-map <project-slug>` or `/sdd-map <app>`) — resolve it to a
   roadmap path:
   - Match `context/*/foundation/<slug>/roadmap.md` (workspace layout) or
     `context/foundation/<slug>/roadmap.md` (flat layout).
   - An `<app>` argument with a single project resolves to that project's roadmap; with several,
     list them and ask which one.
2. **No argument** — auto-detect: if the cwd is inside a workspace dir, use that app's roadmap;
   otherwise pick the most-recently-modified `roadmap.md` under `context/`. If more than one
   project is plausible, **list them and ask** — do not guess silently.
3. **No `roadmap.md` found** for the resolved target — say so plainly and point at the owning
   skill: "No roadmap yet — run `/sdd-roadmap` to generate one." Then stop.

## Process

The heavy lifting — parsing the roadmap table, computing `ready`/`blocked` from the prerequisite
graph, and emitting the Mermaid — is done by a deterministic script that ships **beside this
skill**: `render-roadmap-map.sh`. This skill just resolves the target, runs the script, and opens
the result — so a manual `/sdd-map` and the auto-refresh hook render *identically*.

### Step 1 — Render

Run the renderer on the resolved roadmap:

```
bash .claude/skills/sdd-map/render-roadmap-map.sh "<path/to/roadmap.md>"
```

It writes `roadmap-map.md` beside the roadmap and prints two lines: the **file path**, then a
**one-line summary** (`<slug> · N slices — X done · Y ready · Z blocked · ★ <id>`). If the
roadmap has no `## At a glance` table the script exits non-zero with a message — surface that and
stop (don't fabricate a graph).

### Step 2 — Open it

Open the written file in the editor. Try the first opener that works; never fail the run if none
do:
- `code -r "<path>"` (VS Code) or `cursor -r "<path>"` (Cursor) if on PATH;
- else `"$EDITOR" "<path>"` if `EDITOR` is set, or macOS `open "<path>"`;
- else just report the path.

### Step 3 — Confirm

Print a short confirmation — the saved path and the summary the script returned, e.g.:

```
Saved → context/<app>/foundation/<slug>/roadmap-map.md  (opened)
<slug> · 4 slices — 1 done · 2 ready · 1 blocked · ★ S-01
Prose view + next command: /sdd-help <slug>
```

Then stop.

### Keeping it fresh (automatic)

Once `roadmap-map.md` exists, an optional `PostToolUse` hook (`roadmap-map-hook.sh`, co-located —
wire it in `.claude/settings.json` per the header comment in that script) re-runs
`render-roadmap-map.sh` whenever `roadmap.md` is edited — so the map stays current without
re-invoking this skill. The guard is **"only if the map already exists"**, which makes
auto-refresh opt-in: generate the map once with `/sdd-map` and it maintains itself; delete it to
stop. The renderer is the single source of truth for how the map is drawn, whether the trigger is
this skill or the hook.

## Guardrails

1. **Writes only its own map.** The single file this skill ever writes is `roadmap-map.md` beside
   the roadmap (via the renderer). It never edits, moves, or deletes `roadmap.md` or any other
   artifact. If the user wants to *change* the plan, point at `/sdd-roadmap` and stop.
2. **Derived, not canonical.** The `roadmap.md` is the source of truth; `roadmap-map.md` is a
   regenerable snapshot with a generated-on stamp. Never hand-edit the map — regenerate it, and
   never treat it as the plan.
3. **Don't re-infer state.** The renderer reads `Status`, `Prerequisites`, and `## North star`
   straight from the schema and only *computes* `ready`/`blocked` from those fields. If the
   `## At a glance` table is missing, the script exits with a message — surface it, don't invent
   a graph.
4. **Mermaid only (v1).** No other output format. (An `ascii` fallback is a possible future, not
   part of this version.)
5. **Mirror the user's language.** If the user asks in Polish, summarise in Polish; the Mermaid
   labels stay as the roadmap wrote them.

## Notes

- This is a **visualisation / orientation** skill. Its only output is `roadmap-map.md` (the
  diagram) beside the roadmap, plus a one-line confirmation in chat.
- `render-roadmap-map.sh` (co-located) is the deterministic renderer — the single source of
  truth for how the map is drawn. The single source of truth for the roadmap *shape* is
  `sdd-roadmap` and the PRD schema (`sdd-shape/references/prd-schema.md`); if the
  `## At a glance` columns ever change there, update the renderer's parsing to match.
