---
name: sdd-help
description: >
  Explain the Spec-Driven Development (SDD) workflow in this repo — what the
  sdd-* skills do, in what order, and what artifacts they produce. Read-only:
  never writes or edits files. With NO argument it explains how to start a new
  flow from scratch using all the sdd-* skills. With a skill/topic argument it
  answers that targeted question. With a project name it reports where that
  project stands and the single next command. Use when the user asks "how does
  SDD work", "what is sdd", "how do I start", "which sdd skill do I run",
  "explain the sdd skills", "sdd help", "where am I in the chain", "jak działa
  sdd", "od czego zacząć", or is unsure how shape → prd → roadmap fit together.
  This is the map and entry point for the SDD skill family — start here when in
  doubt.
---

# /sdd-help — How the Spec-Driven Development Workflow Works

This skill is the **map** for the `sdd-*` skill family. It explains the approach and shows the pipeline. How it responds depends on the argument:

- **No argument** → a **getting-started walkthrough**: how to start a brand-new SDD flow using all the `sdd-*` skills, in order. It does **not** probe what's already in progress.
- **A skill or topic** (`/sdd-help shape`, `/sdd-help prd`) → a targeted answer about that one thing.
- **A project name** (`/sdd-help brickworks-personalisations`) or a status request → a "you are here" report for that project plus the single next command.

It is **read-only**: it never creates, edits, or moves files. For scaffolding, shaping, or generating, it points at the skill that owns that step; it never does that work itself.

## What SDD is

Spec-Driven Development turns an idea into shipped code through a chain of small, single-purpose skills. Each skill consumes the previous one's artifact and produces the next, so the specification is built up incrementally and reviewed by a human at every handoff — rather than jumping straight from a vague idea to code.

### Plain mode (for non-technical operators)

Every `sdd-*` skill resolves an `audience` setting (`plain` or `technical`, default `technical`) as a **per-operator preference**, read from a gitignored `$CONTEXT_ROOT/.sdd.local.yml` — never from a committed artifact. If that file has no `audience:` yet, the skill asks the plain question once and writes the answer there (creating the file, and adding `.sdd.local.yml` to `$CONTEXT_ROOT/.gitignore`, if needed). When a non-technical operator (product owner / project manager) runs the workflow in **plain mode**, the skills speak in plain language, hide the schema/jargon/shell, and make the technical decisions for you — logging each one to an `## Auto-decisions (for review)` note a developer checks later. The plain-mode journey runs idea → shape → PRD → roadmap → plan → build → **open a merge request** (`/sdd-mr`), where a developer reviews and merges. Because it's per-operator, each person answers the question once for themselves (via `/sdd-init` or the first audience-aware skill they run) rather than it being set once for the whole project. When `audience: plain`, explain this path in plain terms and name steps by what they do, not by their slash commands. The full resolution and behavior contract is `skills/sdd-shape/references/plain-mode.md`. (This skill itself remains read-only.)

Five principles run through every skill in the family; internalize them before explaining any individual step:

1. **Facilitate or generate — never invent.** `/sdd-shape` facilitates a discovery conversation and writes down only what the user said. `/sdd-prd` and `/sdd-roadmap` generate documents strictly from their input. None of them invents domain decisions, business rules, success criteria, or requirements. Anything missing becomes an explicit `# TODO` routed to an `## Open Questions` section, not a guessed value.
2. **The schema is the contract.** `shape-notes.md`, `prd.md`, and `roadmap.md` all conform to a locked schema (`sdd-shape/references/prd-schema.md` for the first two). Section names and frontmatter keys are load-bearing; downstream skills grep for them. Drift between a skill and the schema is the failure mode the family is built to prevent.
3. **Gaps surface, they don't hide.** Thin input produces a document full of named TODOs and Open Questions, not a hollow document that looks complete. Every skill warns (a soft gate) when its input is too thin, but lets the user override with eyes open.
4. **Never chain automatically.** Each skill ends by *announcing* the next command (and copying it to the clipboard), never by invoking it. The human reviews each artifact before moving on.
5. **Product-level, stack-open.** The PRD describes *what* the product is and *who* it's for — never *how* it's built. Frameworks, databases, file paths, and deployment targets are deliberately kept out of `shape-notes.md` and `prd.md`; they belong to downstream stack-selection / planning steps.

### Repo profile

The shaping/PRD skills apply two defaults, auto-adapted per repo:

- **Brownfield when the repo already exists.** `/sdd-shape` and `/sdd-prd` auto-detect brownfield mode from project markers (git history, lockfiles) — "what exists, what's changing, what must be preserved" — and use the 11-section brownfield PRD template. A fresh/empty repo shapes as greenfield instead.
- **Product-feature delivery mode by default.** This workflow assumes a product context: features are specified by product/design and built end-to-end. The MVP-scoping and personal-timeline questions are skipped, and Success Criteria describe the full feature. A user can override back to MVP framing by explicitly saying "MVP" / "smallest slice" / "prototype".

## The pipeline

```
            ┌─────────────┐
            │  /sdd-init  │  scaffold context/ + root README (workspace-first; per-app folders lazy)
            └──────┬──────┘
                   │
            ┌──────▼──────┐
            │ /sdd-shape  │  idea ──▶ shape-notes.md   (facilitated discovery, 6 phases + quality gate)
            └──────┬──────┘
                   │
            ┌──────▼──────┐
            │  /sdd-prd   │  shape-notes.md ──▶ prd.md  (schema-conformant PRD generator)
            └──────┬──────┘
                   │
       (stack step — installed: /sdd-tech-stack-selector [greenfield]
        · /sdd-stack-assess → /sdd-health-check [brownfield])
                   │
            ┌──────▼──────┐
            │/sdd-roadmap │  prd.md ──▶ roadmap.md      (vertical slices in dependency order)
            └──────┬──────┘
                   │  (pick a slice's Change ID)
       (optional per-change prep, all before /sdd-plan: /sdd-new opens the
        change folder · /sdd-frame challenges the *what* · /sdd-research maps the code)
                   │
            ┌──────▼──────┐
            │  /sdd-plan  │  change-id ──▶ $CONTEXT_ROOT/changes/<change-id>/plan.md + plan-brief.md
            └──────┬──────┘
                   │
            ┌──────▼─────────┐
            │ /sdd-implement │  plan.md ──▶ code + commits, phase by phase (flips ## Progress)
            └──────┬─────────┘
                   │
            ┌──────▼─────────┐
            │/sdd-impl-review│  (optional) plan vs. actual ──▶ drift / safety / pattern findings
            └──────┬─────────┘
                   │
            ┌──────▼─────────┐
            │   /sdd-mr      │  open a merge request for a technical person to review & merge
            └──────┬─────────┘
                   │
            ┌──────▼──────┐
            │ /sdd-archive │  closeout — git-mv the change to $CONTEXT_ROOT/archive/, close its roadmap item
            └─────────────┘
```

Every artifact lives under a resolved **`CONTEXT_ROOT`** — a `context/` directory (anywhere in the repo) that carries a `.sdd.yml` marker. A repo may hold several roots (e.g. one per team directory); the entry skills discover all of them and let the user pick one, then every downstream skill inherits the resolved `CONTEXT_ROOT`. `/sdd-shape` runs this resolution once per session. Full discovery/pick mechanics and the flat-vs-legacy distinction live in `../sdd-shape/references/context-resolution.md` — see "Where the artifacts live" below.

**Installed in this repo (23):** the full family. The core spine (`sdd-init → sdd-shape → sdd-prd → sdd-roadmap → sdd-plan → sdd-implement → sdd-archive`); the stack steps between PRD and roadmap (`sdd-tech-stack-selector` for greenfield, `sdd-stack-assess` + `sdd-health-check` for brownfield); the per-change prep helpers (`sdd-new`, `sdd-frame`, `sdd-research`) that feed `/sdd-plan`; the plan-quality gate `sdd-plan-review`; three execution variants of `/sdd-implement` (`sdd-tdd` test-first, `sdd-e2e` browser-level, `sdd-goal-implement` unattended); the review steps (`sdd-impl-review` locally, `sdd-impl-review-ci` in CI); the phased test-rollout orchestrator `sdd-test-plan`; `sdd-mr` to open the merge request; `sdd-lesson` to bank a recurring rule; and `sdd-help` itself (this map).

**Handling uninstalled hand-offs.** A skill may occasionally name a `/sdd-*` command that isn't installed in a given project. When a hand-off names a command that isn't available, say so plainly — the conceptual step still exists in the method, the slash command just isn't in this project. Do not pretend an uninstalled command will run. (`/sdd-plan` runs even without a `/sdd-frame` or `/sdd-research` doc — those upstream artifacts just reduce how many questions it asks.)

## The installed skills

| Skill          | Consumes                       | Produces                                  | Use it when                                                | Skip it when                                                            |
| -------------- | ------------------------------ | ----------------------------------------- | ---------------------------------------------------------- | ----------------------------------------------------------------------- |
| `/sdd-init`    | nothing                        | a `context/` root (+ root README); per-project/per-change folders created lazily | You want a `context/` root set up up-front           | Already scaffolded (it's idempotent — re-running is a no-op)            |
| `/sdd-shape`   | an idea / rough notes          | `<CONTEXT_ROOT>/foundation/<slug>/shape-notes.md` | Starting a project or shaping a meaningful change to one   | A single bug/refactor too small for a PRD; you already have a PRD       |
| `/sdd-prd`     | `shape-notes.md` (or raw notes) | `<CONTEXT_ROOT>/foundation/<slug>/prd.md`         | Shaping notes are ready and you want a PRD on disk         | Still ideating (run `/sdd-shape`); you want hand-edits to an existing PRD |
| `/sdd-tech-stack-selector` | `prd.md` (greenfield) | `<CONTEXT_ROOT>/foundation/tech-stack.md` (starter hand-off) | Greenfield: the PRD is written and you need to pick a starter/stack | Brownfield (use `/sdd-stack-assess`); no PRD yet |
| `/sdd-stack-assess` | `prd.md` (brownfield) + existing code | `<CONTEXT_ROOT>/foundation/stack-assessment.md` | Brownfield: score an existing stack against the 4 agent-friendly gates before the roadmap | Greenfield (use `/sdd-tech-stack-selector`) |
| `/sdd-health-check` | an existing project | `<CONTEXT_ROOT>/foundation/health-check.md` | Brownfield: audit deps/security/tests/CI after the stack assessment | Greenfield (use `/sdd-tech-stack-selector`) |
| `/sdd-roadmap` | `prd.md`                       | `<CONTEXT_ROOT>/foundation/<slug>/roadmap.md` (sibling of prd.md) | The PRD is populated and you want to know what to build first | The PRD is hollow (firm it up first); you want to plan a *single* change |
| `/sdd-test-plan` | `prd.md` + `roadmap.md` (brownfield) | `<CONTEXT_ROOT>/foundation/test-plan.md`; drives new→research→plan→implement per phase | You want a phased test-rollout strategy for an existing product | Greenfield; a single change (use `/sdd-plan`) |
| `/sdd-new`     | a new `<change-id>`            | `<CONTEXT_ROOT>/changes/<change-id>/change.md` (folder + identity file) | You want to open a change folder up-front — e.g. a change not traced to a roadmap slice | You're planning a roadmap slice — `/sdd-plan` creates the folder for you |
| `/sdd-frame`   | a "bug + proposed fix", scope question, or design choice | `<CONTEXT_ROOT>/changes/<change-id>/frame.md` | The *what* is in doubt (right fix? right scope?) — run BEFORE `/sdd-plan` | The what is settled and you only need the *how* |
| `/sdd-research` | a `<change-id>` + the questions to answer | `<CONTEXT_ROOT>/changes/<change-id>/research.md` | A non-trivial change needs a thorough codebase map before planning | The change is small or you already know the code area |
| `/sdd-plan`    | a roadmap slice's Change ID (+ optional `frame.md` / `research.md`) | `<CONTEXT_ROOT>/changes/<change-id>/plan.md` + `plan-brief.md` | You've picked one slice to build and want a detailed, phased implementation plan | You're still sequencing the whole project (use `/sdd-roadmap`); the change is trivial enough to just do |
| `/sdd-plan-review` | a `plan.md` | interactive findings (substance / feasibility / architectural fitness) | After `/sdd-plan`, before `/sdd-implement` — validate the plan will actually work | Trivial plans you'll eyeball yourself |
| `/sdd-implement` | `<CONTEXT_ROOT>/changes/<change-id>/plan.md` (a reviewed plan) | code changes + per-phase commits; flips the plan's `## Progress` checkboxes; updates `change.md` status | A plan exists and you're ready to build it phase by phase with verification gates | No plan yet (run `/sdd-plan`); the plan still needs review/edits |
| `/sdd-tdd` | a reviewed `plan.md` (TDD'able phases) | code + per-phase commits, red→green→refactor | You want to drive testable phases test-first | Phases that don't suit TDD (it routes those to `/sdd-implement`) |
| `/sdd-e2e` | a reviewed `plan.md` (browser-level phases) + the running app | Playwright/E2E tests, one risk at a time | Driving plan phases that genuinely need a browser, feature already built | Non-browser phases (routes to `/sdd-tdd` / `/sdd-implement`) |
| `/sdd-goal-implement` | a reviewed `plan.md` | code + per-phase commits, unattended (under `/goal`) | You want autonomous/headless plan execution with no human interaction | Interactive, gated builds (use `/sdd-implement`) |
| `/sdd-impl-review` | a completed plan (or a single `phase N`) | `<CONTEXT_ROOT>/changes/<change-id>/reviews/impl-review.md` + interactive triage | After a phase or the full plan — catch drift, unsafe decisions, pattern violations before archiving | Trivial changes you'll eyeball yourself |
| `/sdd-impl-review-ci` | a PR + its plan | `reviews/impl-review.md` committed to the PR branch + a summary comment | Non-interactive review in CI / GitHub Actions against a PR | Local interactive review (use `/sdd-impl-review`) |
| `/sdd-mr`      | a completed change (`status: implemented`) | an open GitLab MR (or the URL to open one) targeting the integration branch | You want to open a review request for a finished change — the plain-mode operator's final step | Not implemented yet (run `/sdd-implement`); you'll merge it yourself by hand |
| `/sdd-lesson`  | a recurring rule / pitfall you spotted | appends to `<CONTEXT_ROOT>/foundation/lessons.md` | You hit a *class* of bug or design pitfall worth enforcing in future reviews & plans | A one-off mistake with no recurring pattern |
| `/sdd-archive` | a completed change's `<change-id>` | git-moves the change to `<CONTEXT_ROOT>/archive/<date>-<change-id>/`, stamps `change.md` archived, closes its roadmap item | The change is implemented and you want to close it out and free up `changes/` | Still implementing; uncommitted edits in the change folder (it hard-blocks) |

## Where the artifacts live

Every artifact is written under a resolved **`CONTEXT_ROOT`** — a `context/` directory carrying a `.sdd.yml` marker. A repo can hold multiple roots (one at the repo root, and/or one per team directory); the full discovery/pick algorithm, the flat-vs-legacy layout distinction, and the `app:` frontmatter rule live in `../sdd-shape/references/context-resolution.md` — read that first for the mechanics. In short:

- **Discovery** finds every `context/.sdd.yml` in the repo (excluding vendor/build dirs). Each match's directory is a candidate root.
- **Flat roots** (the default for anything scaffolded going forward) resolve `CONTEXT_ROOT` straight to that `context/` directory — no further nesting.
- **Legacy roots** (older, app-partitioned repos with no `layout: flat` marker) resolve `CONTEXT_ROOT` to `context/<app>` after the user picks which `<app>` subdirectory to operate in. This layout still works and stays fully readable — see "legacy roots" below.

Within a resolved `CONTEXT_ROOT`, shape/PRD/roadmap outputs are grouped **per project** in a slug-named foundation subfolder (the roadmap sits beside its PRD); each planned slice gets a **per-change** folder under `changes/`:

```
<CONTEXT_ROOT>/
├── foundation/
│   └── <project-slug>/
│       ├── shape-notes.md        # /sdd-shape
│       ├── prd.md                # /sdd-prd
│       ├── prd-vN.md             # versioned PRD saves (collision resolution)
│       └── roadmap.md            # /sdd-roadmap (sibling of prd.md, per project)
├── changes/                       # in-flight per-change folders
│   └── <change-id>/
│       ├── change.md             # /sdd-plan creates it; /sdd-implement advances its status
│       ├── plan.md               # /sdd-plan writes it; /sdd-implement flips its ## Progress
│       └── plan-brief.md         # /sdd-plan (the two-pager to read first)
└── archive/                       # completed changes (moved here by /sdd-archive)
```

A `change-id` is the kebab-case identifier from a roadmap slice's `Change ID` column (e.g. `first-gated-generation`).

The project slug is derived from the project name: lowercase, each run of non-alphanumeric characters → one hyphen, trimmed. It is fixed once the subfolder is created.

**Legacy roots**: artifacts under a legacy (app-partitioned) root keep their `app: <app>` frontmatter field and remain fully readable — this skill (and every other `sdd-*` skill) still discovers and reports on them. New roots are always flat; a legacy root is never converted in place.

## Process

First, classify the argument (if any):

- **No argument** → run **Branch A** (getting-started walkthrough). Do **not** probe what's in progress.
- **Argument is a skill name or topic** (`init`, `shape`, `prd`, `roadmap`, `plan`, `implement`, or a question like "difference between shape and prd") → run **Branch B** (targeted answer).
- **Argument is a project slug** (e.g. `brickworks-personalisations`) **or a status/"where am I" request** → run **Branch C** (state probe).

When the argument is ambiguous, prefer Branch B for a single word that matches a skill name, otherwise Branch C. Run exactly one branch.

### Branch A — No argument: how to start a new flow

The user wants to know how to begin. Do **not** read `context/` or report in-progress projects. Explain the path from idea to implemented code using the installed `sdd-*` skills, in order, with the concrete command and the artifact each step produces. Keep it to the sequence below; lead with the one command they should run first.

1. **(One-time) `/sdd-init`** — scaffolds a `context/` root (+ a root README) at a target directory of the user's choosing. Per-project/per-change folders are created lazily by the entry skills. It's idempotent, so it's safe to run but a no-op once that root exists. A repo can hold several roots side by side (one per team directory); `/sdd-init` can be run again elsewhere to add another. In a repo that's already initialized, mention this exists but tell them they can skip straight to shaping.
2. **`/sdd-shape "<your idea>"` — start here.** A facilitated discovery conversation (6 phases + a quality gate). It first resolves **`CONTEXT_ROOT`** (discovers every `context/.sdd.yml` in the repo, auto-detects the root nearest cwd, and asks if several are found — or if a resolved root is legacy, asks which `<app>` subdirectory too), then writes `$CONTEXT_ROOT/foundation/<slug>/shape-notes.md`. Pass the idea inline or as a file path (`/sdd-shape @notes.md`). Repo profile: **brownfield (auto-detected) + product-feature** by default (describe what's changing in the existing system; no MVP scoping) unless they say "MVP".
3. **`/sdd-prd`** — turns the shape-notes into a schema-conformant `prd.md` in the same project subfolder (inheriting the resolved `CONTEXT_ROOT` from the path). Run it after shaping; it warns if the notes are too thin.
4. **Stack step** — between PRD and roadmap. Brownfield: `/sdd-stack-assess` scores the existing stack against the four agent-friendly quality gates, then `/sdd-health-check` audits deps/security/tests/CI. Greenfield: `/sdd-tech-stack-selector` picks a starter from the PRD. All three stack skills are installed.
5. **`/sdd-roadmap`** — decomposes the PRD into vertical, dependency-ordered slices and writes `$CONTEXT_ROOT/foundation/<slug>/roadmap.md` (beside the PRD), with a `## Backlog Handoff` table that assigns each slice a kebab-case `Change ID`.
6. **`/sdd-plan <change-id>`** — pick one `ready` slice from the roadmap and plan it. It researches the codebase, asks complexity-scaled questions, and writes `$CONTEXT_ROOT/changes/<change-id>/plan.md` + `plan-brief.md` (creating the change folder + `change.md`). Run it once per slice. *(Optional prep, all before this step: `/sdd-new` opens a change folder that isn't tied to a roadmap slice; `/sdd-frame` challenges the *what* when a fix or scope is in doubt; `/sdd-research` writes a `research.md` codebase map for a non-trivial change. `/sdd-plan` runs fine without them — they just reduce the questions it asks.)*
7. **`/sdd-implement <change-id> phase 1`** — builds the plan one phase at a time: implements the changes, runs the success-criteria checks, flips the plan's `## Progress` checkboxes, and commits per phase with a manual-verification gate between phases. Re-invoke per phase (it copies the next-phase command to the clipboard).
8. **`/sdd-impl-review <change-id>` (optional, recommended)** — after a phase or once all phases are done, review the implementation against the plan for drift, unsafe decisions, and pattern violations; it writes `reviews/impl-review.md` and walks you through triage. The "Record as lesson" triage choice hands off to `/sdd-lesson`, which appends the rule to `$CONTEXT_ROOT/foundation/lessons.md`.
9. **`/sdd-archive <change-id>`** — closeout: once the plan's phases are all done, it git-moves the change to `$CONTEXT_ROOT/archive/<date>-<change-id>/`, stamps `change.md` as archived, and closes the matching roadmap item (flips its status to `done`, adds a `## Done` entry). It hard-blocks only on uncommitted edits inside the change folder.

Present this as a numbered walkthrough (the table and pipeline above are the reference), then close with the single first action and a pointer to status:

```
► Start here: /sdd-shape "<one-line description of what you want to build or change>"
  (Run /sdd-init first only if no context/ root exists yet — it's idempotent.
   /sdd-shape will ask which root — and, for a legacy root, which app — this belongs to,
   or detect it from your cwd.)

  Already mid-flight on something? Run /sdd-help <project-slug> to see where it stands.
```

Then stop. Do not run any of the commands for the user.

### Branch B — Argument is a skill or topic

`/sdd-help shape`, `/sdd-help prd`, `/sdd-help "what's the difference between shape and prd"`, etc. — answer just that, drawn from the table and pipeline above plus, if useful, a quick read of that skill's own `SKILL.md` in `.claude/skills/sdd-<name>/`. Do not run the state probe; the user asked a targeted question, give a targeted answer. Then stop.

### Branch C — Argument is a project, or a status request: orient the user ("you are here")

Probe the project's current SDD state (read-only) and report where each project sits, then recommend exactly one next command. This probe is **multi-root**: a repo may hold several `context/` roots (see "Where the artifacts live"), so the scan enumerates every root before looking inside any of them.

The argument may be a **project slug**, a **root path**, or a status request — the probes scan across every discovered root, so any of them resolves.

```bash
# Discover every context root (per ../sdd-shape/references/context-resolution.md):
find . -name .sdd.yml \
  -not -path '*/node_modules/*' -not -path '*/.git/*' \
  -not -path '*/dist/*' -not -path '*/build/*' \
  -not -path '*/.next/*' -not -path '*/coverage/*' 2>/dev/null
```

No matches → `init: missing` (no `context/` root anywhere in the repo). One or more matches → each match's `dirname` is a candidate root; classify each as **flat** (`grep -qE '^layout:[[:space:]]*flat' <root>/.sdd.yml`) or **legacy** (no `layout: flat` — a direct `<root>/foundation/` child is flat, `<root>/*/foundation/` subfolders are legacy).

For **each discovered root `R`**, resolve its scan target(s):

- **Flat `R`** → scan `R` itself directly (no extra segment): `R` *is* a `CONTEXT_ROOT`.
- **Legacy `R`** → scan each `R/<app>/` subdirectory; every `R/<app>` is its own `CONTEXT_ROOT`.

Then, for every resolved `CONTEXT_ROOT` (across all discovered roots), run:

```bash
# Which projects have been shaped / have a PRD / have a roadmap?
ls -1 "$CONTEXT_ROOT"/foundation/*/shape-notes.md 2>/dev/null
ls -1 "$CONTEXT_ROOT"/foundation/*/prd.md 2>/dev/null
ls -1 "$CONTEXT_ROOT"/foundation/*/roadmap.md 2>/dev/null

# Which changes exist?
ls -d "$CONTEXT_ROOT"/changes/*/ 2>/dev/null
```

Each artifact's path is `<CONTEXT_ROOT>/foundation/<project-slug>/…` or `<CONTEXT_ROOT>/changes/<change-id>/…` — flat, no extra segment inside a resolved `CONTEXT_ROOT` (a legacy root's `<app>` is already folded into `CONTEXT_ROOT` above). For each project found, determine its stage from which artifacts exist. Where a `shape-notes.md` exists, you may read its frontmatter `checkpoint:` block to report the phase and quality-check status; where a `prd.md` exists, read its frontmatter `status` and count `## Open Questions` / `# TODO` entries to gauge readiness. Keep reads light — this skill orients, it doesn't audit.

Then print a state report and a single recommended next move (mirroring the family's "one recommendation, not a menu" posture), reporting **per root**:

```
═══════════════════════════════════════════════════════════
  SDD STATUS
═══════════════════════════════════════════════════════════

  Roots found:   [none | <root path> (flat) | <root path> (legacy)  ...]

  Projects (root / project):
    <CONTEXT_ROOT>/<project-slug>:  shaped: [yes/phase] | PRD: [yes/status] | roadmap: [yes/no]
    ...

  ► Next move: <one command> — <one-line reason>
═══════════════════════════════════════════════════════════
```

Recommendation logic (first match wins, per project the user is asking about — or the most recently touched one if unspecified). `CONTEXT_ROOT` is read from the artifact's path:

1. No root discovered anywhere → recommend `/sdd-init`.
2. No `shape-notes.md` for the project → recommend `/sdd-shape` (it resolves `CONTEXT_ROOT`, picking among roots if several exist).
3. `shape-notes.md` present, no `prd.md` → recommend `/sdd-prd`.
4. `prd.md` present, no `<CONTEXT_ROOT>/foundation/<slug>/roadmap.md` → recommend the stack step first: brownfield → `/sdd-stack-assess` (then `/sdd-health-check`); greenfield → `/sdd-tech-stack-selector`. Once the stack step is done — or if the user chooses to skip it — recommend `/sdd-roadmap`.
5. `roadmap.md` present, but no planned change covers a `ready` slice → recommend `/sdd-plan <change-id>`, naming a `ready` slice's `Change ID` from the roadmap's `## Backlog Handoff` table (prefer the north-star slice, else the highest fan-out `ready` one). To check what's already planned, look at `<CONTEXT_ROOT>/changes/*/` for existing `plan.md` files and cross-reference their `change.md` against the roadmap.
6. A plan exists for the slice (`<CONTEXT_ROOT>/changes/<change-id>/plan.md`) with `## Progress` rows still unchecked → recommend `/sdd-implement <change-id> phase 1` (or the next unchecked phase). Read the plan's `## Progress` section to find the first `- [ ]` and name the phase it sits under.
7. The plan's `## Progress` is fully `- [x]` (every phase done) but no `<CONTEXT_ROOT>/changes/<change-id>/reviews/impl-review*.md` exists yet → recommend `/sdd-impl-review <change-id>` to check the implementation against the plan before closing out. (Optional but recommended — `/sdd-archive` only *warns* if it's skipped, it doesn't block.)
8. The plan's `## Progress` is fully `- [x]` and the change folder is committed → recommend `/sdd-archive <change-id>` to close it out (moves it to `<CONTEXT_ROOT>/archive/` and closes its roadmap item). If the change folder has uncommitted edits, say so — `/sdd-archive` hard-blocks until they're committed.

If multiple projects are mid-flight (in the same root or across different roots), list each with its stage and recommend the next move for the one the user names (or, if they don't name one, the furthest-along project, and mention the others briefly).

Always stop after reporting. This skill never runs the recommended command for the user.

## Guardrails

1. **Read-only.** `/sdd-help` never writes, edits, moves, or deletes a file. If the user wants to *do* a step, point at the owning skill and stop. Probes are `find`/`test`/`ls`/`Read` only.
2. **Be honest about what's installed.** All 23 commands in the family are available here: `sdd-init`, `sdd-shape`, `sdd-prd`, `sdd-tech-stack-selector`, `sdd-stack-assess`, `sdd-health-check`, `sdd-roadmap`, `sdd-test-plan`, `sdd-new`, `sdd-frame`, `sdd-research`, `sdd-plan`, `sdd-plan-review`, `sdd-implement`, `sdd-tdd`, `sdd-e2e`, `sdd-goal-implement`, `sdd-impl-review`, `sdd-impl-review-ci`, `sdd-mr`, `sdd-lesson`, `sdd-archive`, and `sdd-help`. If the workflow's natural next step is ever a `/sdd-*` command that isn't installed in a given project, name it as part of the method but state clearly that it isn't installed — never imply it will run.
3. **One recommendation, not a menu.** Like `/sdd-roadmap`'s hand-off, end with a single "next move" and a one-line reason, not a list the user has to triage. They can ask for alternatives.
4. **Don't re-derive the schema.** This skill explains; it doesn't re-document the PRD schema. For schema detail, point at `sdd-shape/references/prd-schema.md`.
5. **Mirror the user's language.** If the user asks in Polish, answer in Polish (translate section names: `Open Questions` → `Otwarte pytania`, etc.), matching the family's language convention.

## Notes

- This is a **help / orientation** skill. Its output is an explanation and a recommendation — never an artifact on disk.
- The single source of truth for the PRD/shape-notes shape is `sdd-shape/references/prd-schema.md`. If anything here contradicts that file, the schema wins and this skill should be corrected.
- If the family grows (the planning/execution tail gets installed, or new `sdd-*` skills are added), update the pipeline diagram and the installed-skills table here so the map stays accurate.
