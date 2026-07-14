---
name: sdd-mr
description: >
  Open a merge request for a completed change so a technical person can review
  and merge it. Reads the change's plan-brief and its Auto-decisions block,
  ensures the branch is pushed, and opens a GitLab MR — via glab, the GitLab
  MCP, or plain git push options — degrading gracefully when none are
  authenticated (falling back to printing the MR-create URL). Use after a
  change is implemented, especially in plain mode where a non-technical
  operator hands work off to a developer. Trigger phrases: "open a merge
  request", "open an MR", "create the MR", "raise a merge request", "hand
  this off for review", "otwórz merge request", "poproś o review".
---

# /sdd-mr — Open a Merge Request for a Completed Change

This is the closing hand-off skill for the build tail. Its single job: take a change that has been implemented and open a **merge request** for it, so a technical person reviews and merges. It is the point where a non-technical operator's journey ends — they never merge, and they never edit code. `/sdd-mr` never merges, never force-pushes, and never rewrites history.

It resolves `audience` per `../sdd-shape/references/plain-mode.md`'s "Audience resolution": in plain mode it speaks in plain language ("I opened a review request a developer will look at"); in technical mode it reports the MR/CLI detail. The MR it opens is identical either way.

This skill operates under the `CONTEXT_ROOT` it resolves for the given change-id (or is handed by an upstream skill) — it does not run broader root discovery beyond locating the one change. `app:` may be absent for flat roots; do not require it.

## When to use, when to skip

**Use when**: a change's `change.md` has `status: implemented` and its commits are on a branch, and you want to open a review request. Typical trigger: `/sdd-implement` (or `/sdd-goal-implement`) just finished and, in plain mode, offered to open the MR.

**Skip when**: the change isn't implemented yet (run `/sdd-implement` first), or there are uncommitted edits in the change folder (commit them first — this skill does not commit code for you). Merging and code review are the technical reviewer's job, not this skill's.

## Relationship to other skills

- `/sdd-implement`, `/sdd-goal-implement` — upstream. In plain mode they hand off here when the plan's phases are all done.
- `/sdd-impl-review`, `/sdd-impl-review-ci` — the reviewer's tools, downstream of the MR. This skill does not run them; the human reviewer (or CI) does.
- `/sdd-archive` — runs after the MR is merged, to close the change out.

## Interactive prompts & tools — host-agnostic

Whenever this skill says "ask the user", use whichever interactive-question tool the host exposes (see `/sdd-roadmap`'s "Interactive prompts — host-agnostic" note for the discovery rule). If none exists, fall back to a plain message listing the options.

## Process

### Step 1: Resolve the change

- If invoked as `/sdd-mr <change-id>`, glob `context/*/changes/<change-id>/` (legacy cross-root search) — one match → use it (derive `CONTEXT_ROOT`, and `<app>` for legacy roots, from the path); more than one → ask which root/app; zero → fall back to the flat layout `$CONTEXT_ROOT/changes/<change-id>/`, else STOP with "No change found for `<change-id>`."
- Read `change.md` (for `status`, `app`) and `plan-brief.md` (for the summary + any `## Auto-decisions (for review)` block). Resolve `audience` per `../sdd-shape/references/plain-mode.md`'s "Audience resolution": read `$CONTEXT_ROOT/.sdd.local.yml`, else ask+write there; default `technical`.

### Step 2: Preconditions

- **`change.md` status must be `implemented`.** If it's earlier (`planned`, `implementing`), STOP: in plain mode say "This isn't finished being built yet — let's finish it first"; in technical mode name the status and point at `/sdd-implement`.
- **No uncommitted edits in the change folder.** Run `git status --porcelain "$CONTEXT_ROOT/changes/<change-id>/"` (legacy: `context/<app>/changes/<change-id>/`); if non-empty, STOP and ask the operator to let the build finish/commit first (plain) or list the paths (technical). This skill does not commit code.
- **Determine the current branch** (`git rev-parse --abbrev-ref HEAD`). If it is the integration branch itself (`develop`/`main`/`master`), STOP: work must be on a feature branch to open an MR. (In plain mode: "This needs to be on its own branch first — a developer can help set that up.")

### Step 3: Determine the target branch

Default target is the repo's integration branch. Detect it: if a `develop` branch exists (`git rev-parse --verify --quiet develop` / `origin/develop`), target `develop`; otherwise target the default branch (`main`/`master`). In technical mode, confirm the target with the user (offer the detected default + an override). In plain mode, use the detected default silently and name it plainly in the result ("…for the team's main line of work").

### Step 4: Build the MR title and description

- **Title**: derive from the change — prefer `change.md`'s title/one-liner; else the `plan-brief.md` heading. Keep it a conventional, human-readable summary.
- **Description**: assemble from `plan-brief.md` — a plain "what & why" summary, then, if present, the change's `## Auto-decisions (for review)` block copied verbatim under a clear "Decisions a developer should confirm" heading, then a one-line note that this MR was prepared for technical review. Write the description to a temp file (e.g. the scratch dir) to avoid shell-quoting issues.

### Step 5: Open the MR — degradation ladder

Push the branch first: `git push -u origin <branch>` (a normal push; never `--force`). Then open the MR by trying these rungs in order, using the first that works:

1. **`glab` (authenticated).** If `command -v glab` succeeds AND `glab auth status` reports the remote's host as authenticated, run:
   `glab mr create --source-branch <branch> --target-branch <target> --title "<title>" --description-file <desc-file> --yes`
   (add `--squash`/labels only if the user asks; never `--remove-source-branch` by default). Capture the MR URL from the output.
2. **GitLab MCP (authenticated).** Else, if a GitLab MCP tool for creating merge requests is available and authenticated (discover via ToolSearch), create the MR through it with the same title/description/target.
3. **Plain git push options.** Else, re-push with GitLab push options to create the MR with nothing but git:
   `git push -o merge_request.create -o merge_request.target=<target> -o merge_request.title="<title>" origin <branch>`
   (If the branch was already pushed and is up to date, this no-ops without creating an MR — in that case skip to rung 4.) Capture the MR URL GitLab prints.
4. **Print the URL + instructions.** Else (or if rung 3 could not create one), construct the MR-create URL from the remote — for GitLab: `<remote-web-url>/-/merge_requests/new?merge_request%5Bsource_branch%5D=<branch>&merge_request%5Btarget_branch%5D=<target>` — and print it with the title and description for the operator to paste. In plain mode: "Your work is saved and pushed. Click this link to open the review request:" + the URL.

Detect which rung succeeded and report only that outcome. Never claim an MR was created when only the URL was printed.

### Step 6: Hand off

- **Technical mode**: print the MR URL (or the create-URL), the source→target branches, and note that CI / a reviewer will take it from here; mention `/sdd-archive <change-id>` runs after merge.
- **Plain mode**: say, plainly, that you've opened (or prepared) a review request for a developer, give the link, and explain the next step is a developer reviewing and merging it — that's the finish line for them. Do not print git commands, branch mechanics, or `/sdd-archive` to a plain operator.

STOP. Never merge the MR, never force-push, never delete the source branch.

## Critical guardrails

1. **Never merge, never force-push, never rewrite history.** This skill opens a review request; a human decides the rest.
2. **Never commit code.** If the change folder has uncommitted edits, STOP and defer to the build step. This skill only pushes an already-committed branch and opens the MR.
3. **Degrade gracefully.** Do not assume `glab` or the GitLab MCP is authenticated. The `git push -o merge_request.create` rung and the printed-URL rung must both work with nothing but git push access. Report honestly which rung was used.
4. **Audience-aware.** Follow `../sdd-shape/references/plain-mode.md` for operator-facing text. In plain mode, no git/shell/branch jargon; the operator's takeaway is "a developer will review and merge this."
5. **The Auto-decisions block is load-bearing.** When `plan-brief.md` carries `## Auto-decisions (for review)`, copy it into the MR description verbatim — it is how the reviewer learns what was auto-decided on the operator's behalf.
