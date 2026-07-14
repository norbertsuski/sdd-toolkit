# sdd-toolkit

Personal Claude Code marketplace. Currently ships one plugin:

- **sdd-skills** — the spec-driven development (SDD) skill family (23 `sdd-*` skills).

## Install

```
/plugin marketplace add https://gitlab.com/norbert.suski/sdd-toolkit.git
/plugin install sdd-skills@sdd-toolkit
```

## Update

```
# after pushing changes (and bumping "version" in .claude-plugin/plugin.json)
/plugin marketplace update
/plugin update
```

## Local testing (no install)

Run Claude Code in any project with this repo as a plugin dir:

```
claude --plugin-dir /path/to/sdd-toolkit
```

## Install for Cursor

Cursor has native [Skills](https://cursor.com/docs/skills) that use the **same
`SKILL.md` format** as Claude Code (same `name` / `description` frontmatter, same
`references/` bundling, automatic or manual activation). So there's no conversion —
you just copy the skill folders into a Cursor skills directory:

- **Per project:** `.cursor/skills/` in the target repo
- **All projects:** `~/.cursor/skills/` (global)

Copy the whole `sdd-*` folders (so each keeps its `references/` subfolder and the
cross-skill relative links like `../sdd-shape/references/context-resolution.md`
still resolve — Cursor discovers skills recursively):

```
# global (all projects)
mkdir -p ~/.cursor/skills
cp -R /path/to/sdd-toolkit/skills/sdd-* ~/.cursor/skills/

# or per project
mkdir -p .cursor/skills
cp -R /path/to/sdd-toolkit/skills/sdd-* .cursor/skills/
```

That's it — Cursor picks them up on the next start. Invoke a skill by typing `/`
in Agent chat and picking it, or let the agent auto-select based on the skill's
`description`.

Prefer to let an agent do it? Paste this into Cursor's Agent (Cmd/Ctrl-L):

```
Install the SDD skills into Cursor for me.

First ask me one question: install for THIS project only (.cursor/skills/) or
globally for all projects (~/.cursor/skills/)? Use my answer as DEST.

Then:
1. Get the source: use my local clone of
   https://gitlab.com/norbert.suski/sdd-toolkit.git if I have one open, otherwise
   clone it to a temp directory.
2. Copy every `skills/sdd-*` folder into DEST, preserving each folder's structure
   (its SKILL.md and any references/ subfolder) so cross-skill relative links like
   `../sdd-shape/references/context-resolution.md` keep resolving. Do not modify
   the files — these are already native Cursor Skills (SKILL.md format), no
   conversion needed.
3. List the installed skill names under DEST so I can confirm.
```

Notes:
- The frontmatter is already compatible: `name` and `description` are what Cursor
  reads. To make a skill command-only (no automatic activation), add
  `disable-model-invocation: true` to its `SKILL.md` frontmatter.
- Cursor can also import remote skills via **Customize → Remote Rule (GitHub)** with
  a repo URL — but this repo is on GitLab, so the `cp -R` above (or a local clone)
  is the reliable path.

## The SDD skills

Spec-driven development workflow, invoked as `/sdd-*`:

Listed roughly in pipeline order.

| Skill | Purpose |
|---|---|
| `sdd-help` | Overview and entry point / map for the SDD workflow |
| `sdd-init` | Bootstrap the `context/` structure in a project |
| `sdd-shape` | Facilitate discovery, turn an idea into shape-notes |
| `sdd-prd` | Write the product requirements (PRD) |
| `sdd-tech-stack-selector` | Pick a starter/stack from the PRD (greenfield) |
| `sdd-stack-assess` | Assess an existing stack for agent-friendliness (brownfield) |
| `sdd-health-check` | Audit deps/security/tests/CI of an existing project (brownfield) |
| `sdd-roadmap` | Decompose the PRD into dependency-ordered slices |
| `sdd-test-plan` | Orchestrate a phased test rollout (brownfield) |
| `sdd-new` | Open a change folder up-front |
| `sdd-frame` | Challenge the *what* — fix / scope / design choice |
| `sdd-research` | Map the codebase before planning |
| `sdd-plan` | Produce the phased implementation plan |
| `sdd-plan-review` | Review a plan for substance/feasibility before building |
| `sdd-implement` | Implement the plan phase by phase |
| `sdd-tdd` | Drive testable phases test-first (red→green→refactor) |
| `sdd-e2e` | Drive browser-level (E2E) phases against the running app |
| `sdd-goal-implement` | Autonomous/unattended plan execution |
| `sdd-impl-review` | Review the implementation against the plan (interactive) |
| `sdd-impl-review-ci` | Run implementation review non-interactively in CI |
| `sdd-mr` | Open a merge request for a completed change (plain-mode hand-off) |
| `sdd-lesson` | Capture a recurring rule / lesson |
| `sdd-archive` | Archive a completed change |

## Notes

- Versioning is manual — bump `version` in `.claude-plugin/plugin.json` before publishing an update.
- A few skills reference `/sdd-*` commands that are not shipped here (`sdd-bootstrapper` — the greenfield scaffolder — and the optional `sdd-contract`). `sdd-help` documents them as not-installed; the conceptual step still exists in the method, the command just isn't in this plugin.
- Origin of these skills: extracted from an internal team plugin and genericized for standalone use.
