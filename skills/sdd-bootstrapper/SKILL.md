---
name: sdd-bootstrapper
description: >
  Scaffold a greenfield project after the tech stack is picked. Reads
  $CONTEXT_ROOT/foundation/tech-stack.md (legacy: context/<app>/foundation/tech-stack.md),
  runs the chosen starter's CLI into the directory that holds the context root
  with a strict conflict policy that always preserves context/, and writes a
  verification log. Use when the user says "bootstrap the project",
  "scaffold the app", "set up the codebase", "let's start the project",
  "postaw projekt". Use AFTER /sdd-tech-stack-selector, BEFORE /sdd-roadmap.
---

# Bootstrapper: From Tech Stack to Scaffolded Project

This skill is the chain-tail of the greenfield bootstrap sequence (`/sdd-shape → /sdd-prd → /sdd-tech-stack-selector → sdd-bootstrapper`), after which the project moves on to `/sdd-roadmap`. Its single job: turn a written tech-stack hand-off into a scaffolded project in the project directory, with verification findings logged for the user to review.

**Project directory.** The scaffold lands in `<project-dir>`: the directory that contains the context root holding the hand-off. For a flat root at `context/` that is the repo root; for a flat root at `posting/context/` (created by `/sdd-init posting`) it is `posting/`; for a legacy app-partitioned root (`context/<app>`) it is the parent of `context/`. Every command in Steps 1–3 runs from `<project-dir>`. Throughout this skill and its references, "cwd" means `<project-dir>`.

**Context root.** This skill resolves `CONTEXT_ROOT` from the hand-off path it is given (`$CONTEXT_ROOT/foundation/tech-stack.md` → strip `/foundation/tech-stack.md`; legacy `context/<app>/foundation/tech-stack.md` → `context/<app>`). With no argument it runs discovery per `../sdd-shape/references/context-resolution.md` and globs `foundation/tech-stack.md` within each root (and `*/foundation/tech-stack.md` for legacy roots): exactly one hit → use it; several → ask which; none → the missing-hand-off refusal.

**Audience.** Resolve `audience` per `../sdd-shape/references/plain-mode.md`'s "Audience resolution" (read `$CONTEXT_ROOT/.sdd.local.yml`, else ask+write there; default `technical`). When `audience: plain`, follow that reference: replace the Step 0 field echo with a one-line plain summary ("I'll set up a <kind of app> project from the stack chosen earlier") and auto-select "Proceed", recording the decision in an `## Auto-decisions (for review)` block of `verification.md`; still ask the populated-directory question (it protects existing files), phrased in plain words; and close with a plain summary instead of the technical block. Scaffolding behavior and the log schema are unchanged.

The skill is a **registry consumer**, not a registry owner. The starter registry lives in `/sdd-tech-stack-selector` (`../sdd-tech-stack-selector/references/starter-registry.yaml`); bootstrapper looks up the chosen card by `starter_id`, substitutes its `cmd_template`, and dispatches to the right cwd strategy. A CI validator (`scripts/validate-structure.sh`) prevents bootstrapper from referencing a `starter_id` absent from that registry.

v1 is **chain-mode only**. Without `$CONTEXT_ROOT/foundation/tech-stack.md`, the skill refuses and redirects to `/sdd-tech-stack-selector`. There is no inline mini-handoff, no standalone-mode, no AI-as-bridge fallback for unknown stacks. v1 also does **not** generate `AGENTS.md` / `CLAUDE.md` — that responsibility belongs to a future agent-context skill.

## When to trigger

Use when `$CONTEXT_ROOT/foundation/tech-stack.md` exists and the user is ready to scaffold. Trigger phrases: "bootstrap the project", "scaffold the app", "set up the codebase", "let's start the project", "spin up the repo", or any natural follow-up to a `/sdd-tech-stack-selector` run that just wrote the hand-off.

The precondition is a single file on disk: `$CONTEXT_ROOT/foundation/tech-stack.md`. The skill never falls back to conversation history, never re-runs the tech-stack interview, never accepts a stack named inline.

## When to skip

Skip when:

- The user is mid-implementation on an existing codebase asking to add a single library or replace a single dependency — that is `/sdd-frame` territory, not bootstrap.
- The user names a stack outside the tech-stack-selector registry — redirect to `/sdd-tech-stack-selector` (it owns the registry; if a starter is missing, that is where it lands).
- `$CONTEXT_ROOT/foundation/tech-stack.md` is absent — the precondition check at Step 0 handles this with an explicit redirect.
- The project is brownfield (an existing codebase being assessed) — use `/sdd-stack-assess` and `/sdd-health-check` instead. `/sdd-health-check` runs the same three verification gates as an audit of existing code.

## Relationship to other skills

- `/sdd-tech-stack-selector` — upstream. Writes the hand-off and owns the starter registry this skill reads.
- `/sdd-roadmap` — downstream. Reads `tech-stack.md` to derive `## Foundations`; with the scaffold in place its baseline probes see real code.
- `/sdd-health-check` — brownfield counterpart. Same pre/in/post gate shape and the same `audit_commands` dispatch, applied to an existing project.

## Required inputs

1. `$CONTEXT_ROOT/foundation/tech-stack.md` (legacy: `context/<app>/foundation/tech-stack.md`) — the hand-off written by `/sdd-tech-stack-selector`. Contract: see `references/handoff-consumer.md` (which pins to `../sdd-tech-stack-selector/references/handoff-schema.md` as the authoritative schema).
2. The chosen card from `../sdd-tech-stack-selector/references/starter-registry.yaml`. Resolved by `starter_id` lookup. Carries `cmd_template`, `language_family`, `bootstrapper_confidence`, `toolchain.package_manager`, `deployment_defaults`.
3. `references/bootstrapper-config.yaml` — bootstrapper-side per-starter `cwd_strategy` overrides + `language_family → audit_command` lookup. Bundled with the skill.
4. `references/handoff-consumer.md` — bundled. Loaded at Step 0.
5. `references/refusal-protocol.md` — bundled. Loaded when any refusal condition trips.
6. `references/pre-scaffold-verification.md` — bundled. Loaded at Step 1.
7. `references/scaffold-merge.md` — bundled. Loaded at Step 2.
8. `references/post-scaffold-verification.md` — bundled. Loaded at Step 3.
9. `references/verification-log-schema.md` — bundled. Loaded at Step 4.

## Initial Response

When this skill is invoked:

1. **If a path argument was provided** (e.g. `/sdd-bootstrapper @$CONTEXT_ROOT/foundation/tech-stack-v2.md` or `/sdd-bootstrapper path/to/tech-stack.md`), strip a leading `@` if present and use the path verbatim as the hand-off location for this run. Infer `CONTEXT_ROOT` and `<project-dir>` from it.
2. **If no argument was provided**, resolve the hand-off by context-root discovery (see "Context root" above); the default location is `$CONTEXT_ROOT/foundation/tech-stack.md` (legacy: `context/<app>/foundation/tech-stack.md`).

Carry the resolved path through Step 0; the rest of the workflow operates on it as `<handoff-path>`, and on `<project-dir>` as the scaffold target.

## Workflow

### Step 0 — Hand-off precondition

Check the hand-off precondition against the resolved path:

```bash
test -f "<handoff-path>"
```

**If absent**, do exactly this and STOP — no fallback interview, no inline mini-handoff, no reading the conversation for a substitute stack pick:

```bash
echo -n "/sdd-tech-stack-selector" | pbcopy 2>/dev/null || echo -n "/sdd-tech-stack-selector" | clip.exe 2>/dev/null || echo -n "/sdd-tech-stack-selector" | xclip -selection clipboard 2>/dev/null || true
```

```powershell
# PowerShell (Windows)
Set-Clipboard "/sdd-tech-stack-selector"
```

Print verbatim (substitute the resolved path; if defaulted, this is `$CONTEXT_ROOT/foundation/tech-stack.md`):

```
Bootstrapper requires a tech-stack hand-off at `<handoff-path>`. Run `/sdd-tech-stack-selector` first, then re-invoke.
```

Then STOP. The conversation context is **not** a fallback — even if a stack pick was discussed earlier in chat, the skill demands the file on disk. See `references/refusal-protocol.md` for the full set of refusal conditions and clipboard strings.

**If present**, read it FULLY (no `limit`/`offset`) and proceed. Parse the frontmatter per `references/handoff-consumer.md` and resolve the chosen card by `starter_id` lookup against `../sdd-tech-stack-selector/references/starter-registry.yaml`. If the lookup fails, run the registry-drift refusal from `references/refusal-protocol.md` and STOP.

Echo the consumed fields back to the user as a confirm-or-correct summary:

```
Hand-off received:
  Starter:        <starter_id> — <name>
  Project name:   <project_name>
  Package manager:<package_manager | "(card default)" if omitted>
  Language:       <hints.language_family>
  Confidence:     <hints.bootstrapper_confidence>
  Path taken:     <hints.path_taken>
  Deployment:     <hints.deployment_target>
  Feature flags:  <comma list of has_* set to true, or "none">
```

Ask the user:
- question: "Proceed with this hand-off, or correct something first?"
  header: "Hand-off"
  options:
  - label: "Proceed (Recommended)"
    description: "Continue with the hand-off as read."
  - label: "Correct a value"
    description: "I'll ask which field to override for this run; the file on disk is unchanged."
  - label: "Stop — fix the hand-off first"
    description: "Exit. Re-run /sdd-tech-stack-selector to update tech-stack.md, then re-invoke."
  multiSelect: false

If "Correct a value": ask which field, capture an override, proceed with the override applied for this session only. Then run the populated-cwd guard from `references/refusal-protocol.md` (warn-and-confirm if cwd already carries a scaffold-shaped fingerprint such as `package.json`, `Cargo.toml`, `Gemfile`, `pyproject.toml`, etc.).

### Step 1 — Pre-scaffold verification

Before running the starter's CLI, run the light recency check described in `references/pre-scaffold-verification.md`. Read that reference now. The slot is read-only — no clone, no install, no filesystem changes — and is educational, not gating: every finding is WARN-AND-CONTINUE.

Sequence:

1. From the chosen card, derive the npm package name from `cmd_template` if `hints.language_family == js` and the template invokes a `create-*` CLI (e.g., `npm create next-app` → `create-next-app`, `npm create astro` → `create-astro`, `npm create vite` → `create-vite`). If the template starts with `git clone`, skip the npm step.
2. If a package name was derived, run `npm view <package> version` and `npm view <package> time.modified`.
3. From the chosen card, parse `docs_url`. If it points at `github.com/<owner>/<repo>`, run `gh api repos/<owner>/<repo> --jq '.pushed_at'`.
4. Compute severity per the thresholds in `pre-scaffold-verification.md` (fresh / aged / stale).
5. Print one summary line in conversation. Prepend a one-line "Heads-up" warning if any signal is stale. Never block — proceed to Step 2 regardless.
6. Stage the resolved package name (if any), GitHub repo URL (if any), both timestamps, and both severities into the in-memory verification record. Step 4 writes that record to disk.

If a network call fails, log the error and continue with the partial record — see "Failure mode" in the reference.

Look up `cwd_strategy` for the chosen `starter_id` from `references/bootstrapper-config.yaml` now (default to `subdir-then-move` if the id is not listed). Step 2 needs it. Look up `audit_commands[<hints.language_family>]` from the same file at the same time and stage it for Step 3 (a `null` value means Step 3 will skip the audit and note the skip in the log).

### Step 2 — Scaffold and merge

Read `references/scaffold-merge.md` now. It carries the full mechanic for the three cwd strategies, the conflict matrix, the substitution rules, and the CLI-failure HARD-STOP path.

Sequence:

1. Resolve the `cmd_template` from the chosen card. Substitute `{name}` and `{pm}` per the strategy in scope (see `scaffold-merge.md` § Substitution rules). The `{pm}` fallback is the card's `toolchain.package_manager` if the hand-off omits the field.
2. Dispatch on `cwd_strategy` (resolved at Step 1 from `bootstrapper-config.yaml`, defaulting to `subdir-then-move`):
   - **`subdir-then-move`** — run the resolved command with `{name}=.bootstrap-scaffold`. On exit code 0, apply the conflict matrix moving files up into cwd, then delete `.bootstrap-scaffold/`.
   - **`native-cwd`** — run the resolved command with `{name}=.` directly in cwd. No merge step. Pre-flight: list the files the CLI is about to touch, surface them in conversation before exec.
   - **`git-clone`** — run the resolved command with `{name}=.bootstrap-scaffold`. On exit code 0, delete `.bootstrap-scaffold/.git/` before applying the conflict matrix and moving files up. Then delete `.bootstrap-scaffold/`.
3. Capture stdout, stderr, and the exit code into the in-memory verification record regardless of outcome.
4. **CLI failure is HARD-STOP.** If the exit code is non-zero, run the CLI failure handling path in `scaffold-merge.md` § CLI failure handling: leave `.bootstrap-scaffold/` in place, do not apply the conflict matrix, write a partial `verification.md` with `phase_3_status: failed`, set the clipboard to `/sdd-bootstrapper`, print the failure summary, and STOP. Do not advance to Step 3.
5. On exit code 0, print one summary line per the format in `scaffold-merge.md` § Surfacing the result. Stage the file-by-file move log into the in-memory verification record. Proceed to Step 3.

The populated-cwd guard from Step 0 (`refusal-protocol.md` § (d)) already ran before this step. The conflict matrix is the safety net: existing files become `.scaffold` siblings, `context/` is always preserved, `.gitignore` is append-merged.

When speaking to the user, translate strategy names to plain language ("scaffold into a temp directory then move files up", "scaffold directly into the current directory", "clone the starter repo without keeping its git history") rather than echoing the internal labels verbatim.

### Step 3 — Post-scaffold verification

Read `references/post-scaffold-verification.md` now. The slot dispatches to the audit command resolved at Step 1 (`audit_commands[<hints.language_family>]` from `bootstrapper-config.yaml`) and severity-tiers the findings.

Sequence:

1. If the resolved audit command is `null`, skip the audit and stage a structured "no built-in audit tool for <language_family>" note in the verification record. Print the skip line per the reference's Output format. Proceed to Step 4.
2. Otherwise, run the resolved command from cwd (or the appropriate dependency-install directory if the scaffold structured the project that way). Capture stdout, stderr, and exit code. The audit tool's exit code is informational only — bootstrapper does NOT halt on a non-zero audit exit.
3. Parse the output per the reference's per-ecosystem invocation block. Tier findings into CRITICAL / HIGH / MODERATE / LOW.
4. If the tool supports a direct-vs-transitive distinction, compute that breakdown.
5. Print one summary line in conversation per the reference's Output format. CRITICAL and HIGH counts surface inline; MODERATE and LOW are log-only.
6. Stage the full breakdown (raw output, parsed counts, per-finding details, direct/transitive split) into the in-memory verification record.

Tool unavailable, network failure, or parsing failure: WARN-AND-CONTINUE per the reference's Failure mode block. CRITICAL findings present: WARN-AND-CONTINUE — bootstrapper informs, the user decides.

### Step 4 — Write verification.md and exit

Read `references/verification-log-schema.md` now. This step writes the run's audit trail to disk and prints the closing summary.

Sequence:

1. Ensure `$CONTEXT_ROOT/changes/bootstrap-verification/` exists. Create the directory if absent (no `change.md` — the folder hosts the log only).
2. If `$CONTEXT_ROOT/changes/bootstrap-verification/verification.md` already exists, run the WARN-AND-CONFIRM guard from `references/refusal-protocol.md` § (e). On "Overwrite", proceed. On "Save as verification-v2.md", increment to the next available `verification-vN.md` slot. On "Abort", stop without writing.
3. Compose the file body per `references/verification-log-schema.md`: frontmatter (with `phase_3_status: ok` for normal runs, `failed` for the HARD-STOP partial-log case), then `## Hand-off`, `## Pre-scaffold verification`, `## Scaffold log`, `## Post-scaffold audit`, `## Hints recorded but not acted on`, `## Next steps`. The `Hints recorded but not acted on` section pulls every hint from the hand-off `handoff-consumer.md` flags as "surfaces but does not act on in v1".
4. Write the file. If the write fails (filesystem error, permission denied), fall back to printing the full body in chat per the schema's failure-mode block.
5. Copy the next-step command to the clipboard:

   ```bash
   echo -n "/sdd-roadmap" | pbcopy 2>/dev/null || echo -n "/sdd-roadmap" | clip.exe 2>/dev/null || echo -n "/sdd-roadmap" | xclip -selection clipboard 2>/dev/null || true
   ```

   ```powershell
   # PowerShell (Windows)
   Set-Clipboard "/sdd-roadmap"
   ```

6. Print the closing summary in conversation:

   ```
   ═══════════════════════════════════════════════════════════
     PROJECT BOOTSTRAPPED
   ═══════════════════════════════════════════════════════════

     Starter:      <starter_id> into <project-dir>
     Pre-scaffold: <one-line recency summary>
     Scaffold:     <one-line scaffold summary>
     Audit:        <one-line audit summary>

     ► Log:   $CONTEXT_ROOT/changes/bootstrap-verification/verification.md
     ► Next:  /sdd-roadmap  (✓ copied to clipboard)
   ═══════════════════════════════════════════════════════════
   ```

   **When `audience: plain`:** skip this block; give a plain summary (the project skeleton is set up, any security warnings a developer should look at, and where the log is) and a plain "want me to work out the build order next?" gate.

7. STOP. Do not chain into `/sdd-roadmap` automatically — the user runs it when ready.

For the HARD-STOP partial-log case (Step 2 CLI failure), Step 4 still runs but with the truncated body shape in the schema (`Audit not run` section, `phase_3_status: failed`). The clipboard is set to `/sdd-bootstrapper` for retry by Step 2's failure path, not by this step.

## Output

What the skill produces externally:

- **Scaffolded project files in cwd** — written by the starter's CLI, with `.scaffold` siblings where the conflict policy detected a clash. `context/` in cwd is preserved verbatim.
- **`$CONTEXT_ROOT/changes/bootstrap-verification/verification.md`** — the run's audit trail. Schema in `references/verification-log-schema.md`. One file per run; re-runs overwrite (with the WARN-AND-CONFIRM guard).
- **Conversation summaries at each step** — Step 0 confirm-or-correct echo, Step 1 recency summary, Step 2 scaffold summary (with `.scaffold`-sibling and `.gitignore`-handling notes), Step 3 audit summary, Step 4 closing summary with the next-steps pointer.
- **Clipboard pointer** — `/sdd-roadmap` on a successful run; `/sdd-tech-stack-selector` for the missing-handoff and registry-drift refusals; `/sdd-bootstrapper` for the Step 2 CLI-failure HARD-STOP retry.

What the skill does NOT produce in v1:

- **`AGENTS.md` / `CLAUDE.md`** — deferred to a future agent-context skill.
- **CI workflow files** (`.github/workflows/ci.yml`, etc.) — deferred to the same future skill.
- **`git init`** or any git history — bootstrapper assumes the user manages their own repo. The `git-clone` strategy explicitly deletes the cloned `.git/` before move-up so the upstream starter's history does not leak.
- **Auto-fix / auto-patch on audit findings** — bootstrapper informs; the user decides.

## References

- `references/handoff-consumer.md` — which hand-off frontmatter keys bootstrapper consumes vs surfaces vs ignores.
- `references/refusal-protocol.md` — refusal conditions, copy, and clipboard strings.
- `references/bootstrapper-config.yaml` — per-starter `cwd_strategy` overrides + `language_family → audit_command` map.
- `references/pre-scaffold-verification.md` — light recency check.
- `references/scaffold-merge.md` — `.bootstrap-scaffold/` mechanic, three cwd strategies, conflict matrix.
- `references/post-scaffold-verification.md` — per-language audit dispatch + severity tiering.
- `references/verification-log-schema.md` — shape of `$CONTEXT_ROOT/changes/bootstrap-verification/verification.md`.

## Critical guardrails

1. **Hand-off is a precondition, not a fallback.** No inline mini-handoff, no reading conversation history for substitute fields. The file on disk is the contract.

2. **Bootstrapper consumes the registry; it does not own it.** The canonical starter registry lives in `/sdd-tech-stack-selector`. Drift between bootstrapper-referenced `starter_id`s and the registry is a CI failure (`scripts/validate-structure.sh`).

3. **`context/` is always preserved.** The conflict policy is strict: anything under `context/` in the project directory (the context root, its `.sdd.yml` marker, and the gitignored `.sdd.local.yml`) is never overwritten by the scaffold. See `references/scaffold-merge.md` for the full conflict matrix (Phase 3).

4. **CLI failure is HARD-STOP.** Non-zero exit code at Step 2 halts the skill, leaves `.bootstrap-scaffold/` in place for inspection, and writes a partial verification log. All other phases use WARN-AND-CONTINUE — verification findings are educational, not gating.

5. **v1 does not generate `AGENTS.md` / `CLAUDE.md`.** That work moves to a future agent-context skill. v1 surfaces hint values like `bootstrapper_confidence: best-effort` and `quality_override: true` in the conversation summary but takes no compensating action.

6. **Skill-internal labels stay internal.** When speaking to the user, never reference Step numbers (`Step 0`, `Step 2`), strategy names verbatim (`subdir-then-move`, `native-cwd`, `git-clone`) without context, or internal field paths (`hints.deployment_target`). Translate to plain language: "the scaffold step", "your deployment target", "how the CLI scaffolds in your current directory", "by cloning a starter repo".