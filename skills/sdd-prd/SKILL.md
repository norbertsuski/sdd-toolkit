---
name: sdd-prd
description: >
  Generate prd.md from shape-notes.md (or raw notes) against the locked PRD
  schema, written into the project subfolder $CONTEXT_ROOT/foundation/<project-slug>/
  (legacy: context/<app>/foundation/<project-slug>/) alongside the shape-notes
  it was generated from. Auto-routes to greenfield (10 sections) or brownfield
  (11 sections) template based on context_type in shape-notes.md or cwd
  auto-detection. Use when the user has shaping notes ready and wants a
  schema-conformant PRD written to disk. Trigger phrases: "write the PRD",
  "generate PRD", "create the PRD from notes", "stwórz PRD", "turn notes into a
  PRD", "PRD from shape-notes". Use AFTER /sdd-shape, not in place of it.
---

# PRD: Generate prd.md from shape-notes

This skill is the second link in the bootstrap chain. For greenfield: `/sdd-shape → /sdd-prd → sdd-tech-stack-selector → bootstrapper`. For brownfield: `/sdd-shape → /sdd-prd → sdd-stack-assess → sdd-health-check`. Its single job: take a shaped notes file and emit a `prd.md` — written into the same project subfolder the input lives in (`$CONTEXT_ROOT/foundation/<project-slug>/prd.md`, legacy: `context/<app>/foundation/<project-slug>/prd.md`; see the schema's "Output paths" section) — that conforms to the locked PRD schema, routing every gap to `## Open Questions` rather than inventing content.

This skill operates under the `CONTEXT_ROOT` handed to it (or the resolved input path it is given) — it does not run its own root discovery. `app:` may be absent for flat roots; do not require it. For legacy roots, `<app>` is the resolved workspace directory's name (e.g. `assets`); it is inherited from the input path's first segment after `context/`, never re-asked.

The skill auto-routes to the correct template based on `context_type` in the input:

- **greenfield** → 10-section PRD template (product built from scratch)
- **brownfield** → 11-section PRD template (delta-change to an existing system)

The skill is a **document generator**, not a discovery facilitator. It NEVER invents domain decisions, business-logic rules, success criteria, or user stories. Anything missing in the input goes verbatim into `## Open Questions` so a human can resolve it.

This skill resolves its own `audience` per `../sdd-shape/references/plain-mode.md` (`## Audience
resolution`: read `$CONTEXT_ROOT/.sdd.local.yml`, else ask+write there; default `technical`) — it
does NOT read or copy an `audience` field from `shape-notes.md`, because that field does not exist
in committed frontmatter. When the resolved audience is `plain`, this skill follows the plain-mode
contract for everything it SAYS to the operator — the thin-input warning and the hand-off are given
in plain language, with no schema, section-name, or slash-command jargon. The generated `prd.md` is
byte-for-byte identical regardless of audience; only the operator-facing messages change, and
`audience` itself never appears in `prd.md` frontmatter.

The locked schema this skill conforms to lives at `../sdd-shape/references/prd-schema.md` (relative to this SKILL.md). Read it before generating any artifact and re-check the produced file against it before writing to disk.

## When to use, when to skip

**Use when**: the user has run `/sdd-shape` (and a `$CONTEXT_ROOT/foundation/<project-slug>/shape-notes.md`, legacy: `context/<app>/foundation/<project-slug>/shape-notes.md`, exists with a checkpoint block), OR the user has a raw notes file they want turned into a PRD draft, OR the user explicitly asks to (re-)generate a project's `prd.md`.

**Skip when**: the user is still ideating and has no notes — point at `/sdd-shape` first. Skip also when the user wants to _edit_ an existing PRD by hand — this skill writes whole files; surgical edits are out of scope.

## Relationship to other skills

- `/sdd-shape` — produces `shape-notes.md`, the canonical input. Always preferred upstream of this skill.
- `sdd-tech-stack-selector` — downstream consumer of `prd.md` for **greenfield**. Reads the product-level frontmatter as priors and runs its own residual interview for team composition, language preferences, deployment, and CI/CD shape.
- `sdd-stack-assess` — downstream consumer of `prd.md` for **brownfield**. Evaluates the existing stack against agent-friendly quality gates.
- `/sdd-frame`, `/sdd-plan` — unrelated; PRD is a foundation artifact, not a per-change plan.

## Initial Response

When this skill is invoked:

1. **If a path argument was provided** (e.g. `/sdd-prd @notes/raw.md` or `/sdd-prd context/assets/foundation/brickworks-personalisations/shape-notes.md` (legacy) or `/sdd-prd $CONTEXT_ROOT/foundation/brickworks-personalisations/shape-notes.md`), capture it as the input path. Proceed to Step 1.
2. **If no argument was provided**, proceed to Step 1 — it discovers shaped inputs across project subfolders under the handed-in `CONTEXT_ROOT` (and legacy cross-root `context/*/foundation/*/` locations, if any) (and handles the none / multiple / missing cases). Do not prompt yet.

## Process

### Step 1: Locate input

Resolve the input path:

- If an argument was passed, use it verbatim (strip a leading `@` if present).
- Otherwise, discover shaped inputs under the resolved `CONTEXT_ROOT` (and the legacy cross-root/top-level locations, if any):

  ```bash
  ls "$CONTEXT_ROOT"/foundation/*/shape-notes.md 2>/dev/null
  # legacy cross-root search (pre-CONTEXT_ROOT / workspace-first):
  ls context/*/foundation/*/shape-notes.md 2>/dev/null   # legacy
  ls context/foundation/*/shape-notes.md 2>/dev/null     # legacy flat layout
  test -f context/foundation/shape-notes.md && echo "legacy: context/foundation/shape-notes.md"
  ```

  - **Exactly one** `shape-notes.md` → use it.
  - **Multiple** → ask the user which project to generate the PRD for. List candidates disambiguated by **app + project** (for legacy roots, the first path segment after `context/` is the app; the last folder is the project slug — e.g. `assets / brickworks-personalisations`); use the chosen file.
  - **None** → treat as "file not found" (the missing-input branch below).

This skill operates under the `CONTEXT_ROOT` handed to it (or the resolved input path it is given) — it does not run its own root discovery; `app:` may be absent for flat roots. **App resolution for legacy roots (inherited, not re-asked).** This skill RECEIVES its input. Infer `<app>` from the resolved input path's first segment after `context/` (`context/<app>/foundation/…`) and carry it through — never re-ask. (Legacy flat-layout inputs at `context/foundation/…` have no `<app>` segment; treat the repo as having no workspace layout and keep paths flat.)

Record **`OUTPUT_DIR`** = the directory that contains the resolved input (e.g. `$CONTEXT_ROOT/foundation/<project-slug>`, legacy: `context/<app>/foundation/<project-slug>`). The generated PRD is written there, as a **sibling of the shape-notes** — never at a fixed top-level path. (For pasted raw notes with no file on disk, resolve `OUTPUT_DIR` from the handed-in `CONTEXT_ROOT` per the next bullet; for legacy roots, resolve `<app>` like an entry skill.)

For pasted raw notes with no file on disk, derive `OUTPUT_DIR` from the `CONTEXT_ROOT` this skill was handed. For legacy (app-partitioned) roots with no `CONTEXT_ROOT` yet resolved, fall back to resolving `<app>` the way an entry skill does:

```bash
# 1. cwd auto-detect: are we inside a workspace dir? (substitute the resolved <workspace-parent>)
pwd | grep -oE '<workspace-parent>/[^/]+' | head -1
# 2. else list the workspaces and ask which one this project belongs to:
ls -1 <workspace-parent>/
```

Resolve the workspace the way `/sdd-shape` does — probe `packages/apps/*`, `apps/*`, or the `workspaces` / `pnpm-workspace.yaml` globs to find `<workspace-parent>`. Use the auto-detected app when cwd is inside a workspace dir; otherwise present the `ls -1 <workspace-parent>/` list and ask. Then derive the project slug per the schema's "Output paths" rule and set `OUTPUT_DIR = context/<app>/foundation/<project-slug>/` (legacy), creating it if absent. **Default:** with a `CONTEXT_ROOT` already resolved (flat or otherwise), set `OUTPUT_DIR = $CONTEXT_ROOT/foundation/<project-slug>/`, omitting `app:` from frontmatter when the root is flat.

Test the resolved path:

```bash
test -f "<resolved-path>"
```

If the file exists, read it FULLY (no `limit`/`offset`) and proceed to Step 1.5.

If the file does not exist, ask:

Ask the user: "No input file found at `<resolved-path>`. How would you like to proceed?" with options:

- "Run /sdd-shape first (Recommended)" (description: "Stop here. Run /sdd-shape to produce shape-notes.md, then re-invoke /sdd-prd.")
- "Paste raw notes" (description: "I'll wait for you to paste any notes you have. The thin-input check will warn about missing signals.")
- "Cancel" (description: "Exit without changes.")

On "Run /sdd-shape first": print "Stopping. Run `/sdd-shape` to produce shape-notes.md, then re-invoke `/sdd-prd`." and STOP.

On "Paste raw notes": prompt "Paste your notes below. End with an empty line." and capture the user's text as the in-memory input. Proceed to Step 1.5 with that content.

On "Cancel": STOP without changes.

### Step 1.5: Determine context type

Determine whether to generate a greenfield or brownfield PRD:

1. **If the input has `context_type:` in frontmatter** — use that value directly. No confirmation needed.
2. **If no `context_type:` in frontmatter** (raw notes, pasted input) — auto-detect from cwd:

   Use the same multi-signal detection as `/sdd-shape` (Step 0.7): check for git history (Tier 1), lockfiles (Tier 2), manifest files (Tier 3), and bonus signals (source dirs, framework configs). Any Tier 1 or Tier 2 hit → propose brownfield. Tier 3 only → propose brownfield with ambiguity flag. No signals → propose greenfield.

   Confirm with the user:

   Ask the user: "No context_type found in the input. Based on cwd markers, this looks like [greenfield|brownfield]. Correct?" with options:

   - "[Detected mode] — correct (Recommended)" (description: "Generate a [greenfield|brownfield] PRD.")
   - "[Other mode] — override" (description: "Generate a [other] PRD instead.")

Store the resolved `context_type` for use in Steps 2 and 3. Proceed to Step 2.

### Step 2: Assess input

Score the input on a 0–4 shaped-vs-thin heuristic. Each signal contributes 1 point:

**Greenfield signals:**

1. **Frontmatter `checkpoint:` block present** — strongest signal that this came from `/sdd-shape`. Look for the literal `checkpoint:` key inside a YAML frontmatter fence at the top of the file.
2. **At least one FR-NNN-format requirement** — grep for `^- FR-\d{3}: ` (bulleted line, three-digit zero-padded index, colon-space).
3. **At least one Given/When/Then block** — grep for `\*\*Given\*\*` AND `\*\*When\*\*` AND `\*\*Then\*\*` anywhere in the body.
4. **Explicit business-logic capture** — a `## Business Logic` section exists AND its first non-blank line is a single declarative sentence (heuristic: ≤ 200 chars, ends in `.`, not equal to `# TODO: domain rule — see Open Questions` and not blank/placeholder).

**Brownfield signals** (replace signal 1 when `context_type: brownfield`):

1. **Frontmatter `checkpoint:` block present AND `context_type: brownfield`** — strongest signal that this came from `/sdd-shape` in brownfield mode. Also check for `## Current System` section in the body.
   2–4. Same as greenfield.

Compute the total. Document the heuristic explicitly in the conversation so a future maintainer can tune it:

```
Input assessment (heuristic, 4 signals, 1 point each):
  [✓|✗] Frontmatter checkpoint block       — <found|missing>
  [✓|✗] FR-NNN format requirements         — <found N FRs|missing>
  [✓|✗] Given/When/Then user stories       — <found|missing>
  [✓|✗] Explicit one-sentence business rule — <found|missing>

  Score: <N>/4
```

**Score ≥ 2**: input is shaped enough; proceed to Step 3 silently.

**Score < 2**: trigger the thin-input warning. Name each missing signal explicitly (do NOT print a generic "your notes are thin" — name what's missing and why it matters):

```
This input scored <N>/4 on the shape heuristic. Missing signals:

  - <signal name>: <one-line consequence for the generated PRD>
  - ...

A PRD generated from thin input will have many `# TODO` placeholders and a long
`## Open Questions` section. That's a valid intermediate state, but if you have
time to run /sdd-shape first, the resulting PRD will be substantially stronger.
```

**When `audience: plain`:** do not show the `<N>/4` score, the signal names, or "shape heuristic".
Give the plain equivalent from the contract: e.g. "Your notes are a bit thin — I can still make a
first draft, but it'll have some open questions a developer or you will need to fill in later.
Want me to go ahead, or would you rather answer a few more questions first?" The options map to the
same three branches (run /sdd-shape first / proceed anyway / cancel), phrased plainly.

Then ask:

Ask the user: "How would you like to proceed?" with options:

- "Run /sdd-shape first (Recommended)" (description: "Stop here. Use /sdd-shape to fill in the missing signals, then re-invoke /sdd-prd.")
- "Proceed anyway" (description: "Generate the PRD from what's there. Missing pieces land in ## Open Questions verbatim.")
- "Cancel" (description: "Exit without changes.")

On "Run /sdd-shape first": print the redirect message and STOP. On "Proceed anyway": continue to Step 3 with `score < 2` recorded so later steps know to expect TODOs. On "Cancel": STOP.

### Step 3: Generate PRD

Read the schema reference FULLY one more time (`../sdd-shape/references/prd-schema.md`) to confirm the field list and section names have not drifted.

Build the PRD content **in memory first** (not on disk yet):

#### 3a. Frontmatter

Populate every required frontmatter field per the schema:

- `project` — extract from input frontmatter `project:` if present; otherwise from a Title heading (`# <Project>`); otherwise `# TODO: project — see Open Questions`.
- `app` — _(workspace repos only)_ copy verbatim from the input shape-notes frontmatter `app:` when present; otherwise (raw-notes path) set it from the `<app>` resolved in Step 1. This is a real schema field and a location key — place it immediately after `project`. Do NOT route it to Open Questions: it is resolved (from the input path or cwd), not a product prior to be discovered. Omit the field entirely in repos with no workspace layout that use the flat layout. (`app` is the deliberate exception to the "stack-shaped fields stay out of PRD frontmatter" rule below — it is a path/location key, not a technology choice.)
- `version` — `1` for the first PRD this skill writes. The collision step (Step 4) bumps this if the user picks a versioned save.
- `status` — `draft`. Never promote to `reviewed`/`locked`; that's a downstream decision.
- `created` — today's date in `YYYY-MM-DD` (use `date +%Y-%m-%d` in a shell).
- `context_type` — `greenfield` or `brownfield` (from Step 1.5).
- `product_type` — pull from input if available; otherwise `# TODO: product_type — see Open Questions` (and add an Open Question entry).
- `target_scale`, `timeline_budget` — same rule. If the input has the field, copy it verbatim; if not, emit `# TODO: <field> — see Open Questions` and add a matching Open Question. For brownfield, `timeline_budget` uses `delivery_weeks` instead of `mvp_weeks`.

**Do NOT populate** `team_profile`, `tech_preferences`, or `deployment_constraint` into PRD frontmatter, even when the input notes carry them. Those fields are gathered by the downstream tech-stack-selection (greenfield) or stack-assessment (brownfield) step, not by PRD. If the input has them, summarize them into the Step 5 hand-off message under "forward to tech-stack/stack-assess" so the user knows the content is being routed, not silently dropped — but DO NOT emit them in PRD frontmatter.

**Do NOT populate `audience`** either — it is not a PRD schema field. Even if a raw pasted notes file happens to carry an `audience:` line, do not copy it through; PRD frontmatter never carries this key. The skill resolves its own audience per `../sdd-shape/references/plain-mode.md` for its own conversation only (see above).

Field key names are load-bearing per the schema. Field values are not.

#### 3b. Required sections (in schema order)

The section list depends on `context_type`:

**Greenfield (10 sections):**

Emit exactly these 10 `##`-level headings, in this exact order (the schema's section-name contract is what downstream parsers split on):

1. `## Vision & Problem Statement`
2. `## User & Persona`
3. `## Success Criteria` (with `### Primary` / `### Secondary` / `### Guardrails`)
4. `## User Stories`
5. `## Functional Requirements`
6. `## Non-Functional Requirements`
7. `## Business Logic`
8. `## Access Control`
9. `## Non-Goals`
10. `## Open Questions`

**Brownfield (11 sections):**

Emit exactly these 11 `##`-level headings, in this exact order:

1. `## Current System Overview` — what exists now: key architecture, tech stack, user base. This section has no greenfield equivalent; it establishes the baseline that all subsequent sections describe changes against.
2. `## Problem Statement & Motivation` — what's wrong/missing, why now. Delta-framed: focuses on the gap between current state and desired state.
3. `## User & Persona` — who is affected (existing users + new if any). For brownfield, emphasize existing users whose experience changes.
4. `## Success Criteria` (with `### Primary` / `### Secondary` / `### Guardrails`) — how we know the change worked. Guardrails should explicitly include existing behavior that must not regress.
5. `## User Stories` — what changes for the user. Delta-framed: Given/When/Then describes the new behavior, with explicit notes on what was different before.
6. `## Scope of Change` — what's being modified/added/removed. Explicit delta: categorize each item as `new`, `modified`, or `removed`. This replaces the implicit "everything is new" assumption of the greenfield `## Functional Requirements`.
7. `## Constraints & Compatibility` — backward compatibility, data migration, existing integrations, preserved behavior. The brownfield-specific section that makes preservation explicit.
8. `## Business Logic Changes` — domain rule additions/modifications (not full domain model). If the change is infrastructure-only (no domain logic change), state that explicitly.
9. `## Access Control Changes` — permission changes if any. If no changes, state: "No access control changes."
10. `## Non-Goals` — what we're NOT changing. Critical for brownfield: explicitly names existing system aspects that are out of scope.
11. `## Open Questions`

**Do NOT emit** `## Data Model`, `## Data Model Changes`, `## Implementation Decisions`, `## Testing Strategy`, or `## Deployment & CI/CD` sections in either mode — those concerns are not part of the PRD schema. Entities and their lifecycles emerge from FRs and User Stories and are pinned during stack selection / implementation planning, not in PRD. If the input notes carry data-model or implementation content, summarize it into the Step 5 hand-off message under "forward to technical-roadmap" so the user knows it's being routed, not silently dropped — but DO NOT emit those sections in the PRD.

#### Section content rules (both modes)

For each section:

- **If the input has matching content** — transcribe it faithfully into the section. Preserve user wording. Convert formatting only when the schema demands a specific shape (e.g., FR-NNN format, Given/When/Then for user stories, three-subsection Success Criteria). Do not rephrase, summarize, or "improve" the user's words.
- **If the input has partial content** — transcribe what's there, then close with `# TODO: <what's missing> — see Open Questions` inside the section, and add a matching numbered entry under `## Open Questions`.
- **If the input has no matching content** — emit just the heading plus `# TODO: <section name> — see Open Questions`, and add a matching numbered entry under `## Open Questions`.

If shape-notes.md carried Socrates blockquotes under FRs, preserve them verbatim — they're load-bearing for downstream review.

If shape-notes.md carried a `## Quality cross-check` block (from Step 7 of `/sdd-shape`), mirror each gap into `## Open Questions` as a numbered entry naming the missing element and its consequence.

**Brownfield-specific content rules:**

- FRs with `Change: preserved` become explicit preservation items in `## Scope of Change`, not `## Non-Goals`.
- `## Current System Overview` maps from shape-notes' `## Current System` section.
- `## Constraints & Compatibility` maps from shape-notes' `## Constraints & Preserved Behavior` section.
- Delta-framing convention: sections describe what changes, not the full system. "The auth model adds Google OAuth alongside existing email login" — not "The system supports email login and Google OAuth."

**Hard rule — never invent**: if the input does not contain a one-sentence business rule, the `## Business Logic` / `## Business Logic Changes` section MUST read `# TODO: domain rule — see Open Questions` and Open Questions MUST carry "What is the one-sentence business rule? — TBD by user. Block: yes (PRD is hollow until resolved)." Do not write a placeholder rule. Do not "extrapolate" a rule from entity nouns appearing in FRs or User Stories. The whole point of this skill is to surface gaps, not paper over them.

Same rule applies to: success criteria, user stories, FR priorities, NFR targets, access control, non-goals. If it's not in the input, it goes to Open Questions.

#### 3c. Pre-write self-review

Before any disk write, run a self-review pass against the schema's required-sections list AND a content-level lint for technical leak:

**Structural checks:**

1. Parse the in-memory PRD content. Extract every `## ` heading.
2. Compare to the canonical section list for the active `context_type` (10 for greenfield, 11 for brownfield). Verify ALL sections are present, in order, exact spelling. The PRD must NOT contain `## Data Model` or `## Data Model Changes` — those sections were retired.
3. Verify the frontmatter declares all required keys per the schema (`project`, `version`, `status`, `created`, `context_type`, `product_type`, `target_scale`, `timeline_budget`). In workspace repos `app:` must also be present (it is the artifact's location key); in repos with no workspace layout it must be absent. `audience` MUST NOT appear in frontmatter — it is not a schema field (see `prd-schema.md`).
4. Verify `## Success Criteria` contains `### Primary`, `### Secondary`, `### Guardrails` subsections (or, if missing, that they're flagged as TODO with corresponding Open Questions entries).

**Content-level lint for technical leak:**

5. Scan all `##`-level section bodies (excluding brownfield `## Current System Overview`, where naming the existing stack is allowed) for tokens that indicate implementation detail has leaked into the PRD. Treat each hit as a leak unless it is part of a verbatim user quotation explicitly being routed to Open Questions:

   - **Vendor / hosted-service names**: `OpenRouter`, `Stripe`, `Auth0`, `Supabase`, `Firebase`, `Vercel`, `Cloudflare`, `AWS`, `GCP`, `Azure`, `OpenAI`, `Anthropic`, etc. (any proper-noun product/service).
   - **Schema / ORM notation**: `(FK)`, `nullable`, `_hash`, `_at` column suffixes presented as field lists, `password_hash`, `cascade`, `soft-delete`, `hard-delete`, `migration`, `backfill`.
   - **Runtime location**: `client-side`, `server-side`, `on the edge`, `in the cache`, `in the worker`.
   - **Enforcement mechanism**: `per IP`, `per user-agent`, `token bucket`, `rate-limit per <axis>`.
   - **UI affordance** (when used to state an NFR, not a user story): `spinner`, `progress bar`, `streaming response`, `modal`, `toast`.
   - **Transport / protocol**: `WebSocket`, `gRPC`, `GraphQL`, `REST endpoint`, `webhook`, `SSE`.
   - **Implementation verbs in domain rules**: "the LLM does X", "the SRS library decides Y", "the database stores Z" (naming the component performing the rule, rather than stating the rule).

   For each hit, emit a structured warning. Do NOT silently rewrite — abort the write so the user can see what leaked.

If any structural OR lint check fails, **abort the write** and report:

```
PRD generation self-review FAILED:

  Structural:
    - Missing section: <name>
    - Out-of-order section: <name> (expected position N, found position M)
    - Missing frontmatter key: <key>
    - Retired section present: <name>

  Technical leak (content lint):
    - <section name>: "<offending phrase>" — <category, e.g. vendor name / schema notation / runtime location>
    - ...

The PRD was NOT written. For structural failures: the schema and the generator
have drifted — re-read ../sdd-shape/references/prd-schema.md and reconcile.
For leak failures: the input notes carry implementation detail that PRD does
not own. Either (a) rewrite the offending phrasings as outside-observable
properties / scope decisions and re-run, or (b) move the leaked content into
shape-notes' `## Forward: ...` blocks so a downstream skill consumes it.
```

Then STOP. Do not proceed to Step 4.

If all checks pass, proceed to Step 4 with the validated content in hand.

### Step 4: Collision check

Resolve all paths inside the input's project subfolder (`OUTPUT_DIR`, from Step 1):

```bash
test -f "<OUTPUT_DIR>/prd.md"
```

If the file does not exist, write to `<OUTPUT_DIR>/prd.md` and proceed to Step 5.

If the file exists, ask:

Ask the user: "`<OUTPUT_DIR>/prd.md` already exists. How would you like to proceed?" with options:

- "Save as prd-vN.md (Recommended)" (description: "Preserve history. The new PRD lands at the next available prd-vN.md slot in the same project subfolder. The unversioned prd.md is unchanged.")
- "Overwrite prd.md" (description: "Replace the existing prd.md. The prior version is lost (unless you've committed it).")
- "Abort" (description: "Exit without writes. No collision resolution.")

On "Save as prd-vN.md": pick `N` by scanning `<OUTPUT_DIR>/` for files matching `prd-v*.md`. Treat the unversioned `prd.md` as v1. The next slot is `N = (max existing N or 1) + 1`. Write the validated content to `<OUTPUT_DIR>/prd-v<N>.md` and bump the in-content `version:` frontmatter field to `<N>`. Proceed to Step 5.

On "Overwrite prd.md": write the validated content to `<OUTPUT_DIR>/prd.md`. Keep `version: 1` (overwriting is a replacement, not a new version). Proceed to Step 5.

On "Abort": STOP without writes.

### Step 5: Hand off

After the write lands, summarize what was produced:

**When `audience: plain`:** skip the `PRD GENERATED` status block, the `echo … | pbcopy` line, and
the literal next-command text. Copy the next command to the clipboard silently as usual, then give
the plain hand-off from the contract: what the write-up now contains (in plain terms), how many
things still need deciding (count the Open Questions without naming the section), and one plain
sentence on what's next ("next I can work out the order to build things in"). End with a plain
"want me to keep going?".

```
═══════════════════════════════════════════════════════════
  PRD GENERATED
═══════════════════════════════════════════════════════════

  Project:          [project from frontmatter]
  Context type:     [greenfield | brownfield]
  Path:             [<OUTPUT_DIR>/prd.md | <OUTPUT_DIR>/prd-vN.md]
  Schema sections:  [10 / 10 (greenfield) | 11 / 11 (brownfield)] present
  Frontmatter:      <K populated, M as TODO>  (all schema keys)
  Open Questions:   <count> entries

  Sections fully populated from input:
    - <list of section names with non-trivial content>

  Sections marked TODO (see Open Questions):
    - <list of section names with TODO placeholders>

═══════════════════════════════════════════════════════════
```

Then copy the next-step command to clipboard and announce:

**Greenfield:**

```bash
echo -n "/sdd-tech-stack-selector" | pbcopy 2>/dev/null || echo -n "/sdd-tech-stack-selector" | clip.exe 2>/dev/null || echo -n "/sdd-tech-stack-selector" | xclip -selection clipboard 2>/dev/null || true
```

```powershell
# PowerShell (Windows)
Set-Clipboard "/sdd-tech-stack-selector"
```

```
► Next:   /sdd-tech-stack-selector  (✓ copied to clipboard)

          It picks up team composition, language preferences,
          technology avoid-list, deployment target, and CI/CD
          pipeline shape. None of those are in this PRD by design —
          the PRD describes the product, the next step describes
          how to build it.
```

**Brownfield:**

```bash
echo -n "/sdd-stack-assess" | pbcopy 2>/dev/null || echo -n "/sdd-stack-assess" | clip.exe 2>/dev/null || echo -n "/sdd-stack-assess" | xclip -selection clipboard 2>/dev/null || true
```

```powershell
# PowerShell (Windows)
Set-Clipboard "/sdd-stack-assess"
```

```
► Next:   /sdd-stack-assess  (✓ copied to clipboard)

          It evaluates your existing stack against agent-friendly
          quality gates and produces a compensation plan. After that,
          /sdd-health-check audits dependency health, test suite,
          and CI/CD coverage. None of those are in this PRD by
          design — the PRD describes WHAT changes, the next steps
          assess WHETHER your existing system is ready.
```

If the input notes carried forward-looking concerns (tech-stack preferences, implementation notes, deploy hints), list them briefly so the user knows they're being routed to the next step, not dropped:

```
  Forward to next step (not in PRD):
    • [one-line summary per detected item]
```

Skip the block entirely if the input didn't carry any of those.

STOP. Do not chain into another skill automatically.

## Critical guardrails

1. **Generator, not author.** This skill writes whole files from inputs the user has already approved. It does not invent business logic, success criteria, user stories, or FR priorities. Missing content goes to `## Open Questions` verbatim. The PRD's `## Business Logic` section is the single most-policed area: if there is no one-sentence rule in the input, the section reads `# TODO: domain rule — see Open Questions`. No exceptions.

2. **Schema is the contract.** `../sdd-shape/references/prd-schema.md` defines frontmatter keys, section names, and section order. Re-read it at every invocation. Re-validate the in-memory PRD against it in Step 3c before writing. Drift between this skill and the schema is the failure mode this skill exists to prevent.

3. **Stack openness is binding — and broader than just stack names.** The forbidden vocabulary in a generated PRD covers seven categories, not just frameworks:

   - **Frameworks, databases, hosting platforms, specific libraries** — the original rule.
   - **Vendor / hosted-service names** — OpenRouter, Stripe, Auth0, Supabase, Firebase, Vercel, Cloudflare, AWS/GCP/Azure, OpenAI, Anthropic, and any other proper-noun product or service.
   - **Schema / ORM notation** — field-level lists, `(FK)`, `nullable`, `_hash` columns, `password_hash`, `cascade-delete`, `soft-delete`, `hard-delete`, `migration`, `backfill`. (Entities surface naturally in FRs and User Stories; column-level schema is a downstream concern.)
   - **Runtime location** — `client-side`, `server-side`, `on the edge`, `in the cache`, `in the worker`. The PRD describes what must be true at the product's outer boundary, not where in the stack it's enforced.
   - **Enforcement mechanism** — `per IP`, `per user-agent`, `token bucket`, `rate-limit per <axis>`. The NFR is the property; the mechanism is a downstream design choice.
   - **UI affordance in NFRs** — `spinner`, `progress bar`, `streaming response`, `modal`, `toast`. NFRs name the user-observable quality (e.g. "continuous feedback during long operations"); the affordance is downstream.
   - **Transport / protocol** — `WebSocket`, `gRPC`, `GraphQL`, `REST endpoint`, `webhook`, `SSE`. The PRD describes information flow as the user experiences it, not the wire format.

   PRD frontmatter is product-level only (`product_type`, `target_scale`, `timeline_budget` + metadata, plus `app` as a location key in workspace repos); language family, frameworks, deployment, team profile, and any technology avoid-list belong to the downstream step (tech-stack-selector for greenfield, stack-assess for brownfield), NOT PRD. If the input contains forbidden vocabulary, leave it in shape-notes' `## Forward: ...` blocks for the downstream step to consume — do NOT translate it into PRD frontmatter or sections. Exception: brownfield `## Current System Overview` may name the existing stack and vendors since it describes the current state, not a stack choice. Step 3c's content lint enforces this guardrail mechanically.

4. **Collisions favor history.** The collision prompt recommends versioned save (`prd-vN.md`) over overwrite. Lost prior versions are an unrecoverable failure mode; a duplicate file in the project subfolder is not.

5. **Self-review aborts on drift.** If the in-memory PRD is missing a section, has a misordered section, or lacks a frontmatter key, the write is ABORTED — not patched up silently. The error names the specific drift so a maintainer can reconcile schema and skill.

6. **Universal language only.** No cohort / certification references in any user-facing output or any artifact written to disk. The skill is a generic PRD generator.

7. **Never chain automatically.** The hand-off is an announcement, not an invocation. The user picks when (and whether) to run the next step (sdd-tech-stack-selector for greenfield, sdd-stack-assess for brownfield). Auto-chaining would skip the human's review of the generated PRD.

## Notes

- This is a **document generator** skill. Output is `$CONTEXT_ROOT/foundation/<project-slug>/prd.md` (or `prd-vN.md` in the same subfolder), period. (Legacy app-partitioned roots: `context/<app>/foundation/<project-slug>/prd.md`.)
- The schema reference (`../sdd-shape/references/prd-schema.md`) is the single source of truth. Any field name, section name, or frontmatter key referenced in this body MUST exist in the schema doc — if it doesn't, fix the schema doc first.
- The thin-input heuristic (Step 2) is intentionally conservative. False positives (warning on shaped input) are recoverable via the "Proceed anyway" override; false negatives (silently generating from thin input) produce hollow PRDs that mislead the user. Tune the heuristic toward warning more, not less.
- The `# TODO: <field-name> — see Open Questions` pattern is load-bearing. Downstream tooling (review skills, sdd-tech-stack-selector / sdd-stack-assess) can grep for `^# TODO: ` to count unresolved gaps and decide whether the PRD is review-ready.
