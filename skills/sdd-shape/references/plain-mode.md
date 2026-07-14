# Plain-Mode Contract (canonical reference)

Single source of truth for how `/sdd-*` skills behave when `audience: plain`. Skills defer to this
doc; they do not restate its rules. When `audience: technical` (the default), skills behave exactly
as their own body describes and this doc does not apply.

`audience` marks **who is operating the skill**, not what is being built:

- `technical` — a developer. Default. Full behavior: YAML, schemas, FR-NNN, shell, git, stack
  questions all shown. No change from today.
- `plain` — a non-technical operator (product owner / project manager). The skill facilitates and
  reports in plain language, silently handles technical-only decisions, and logs every such decision
  for a technical reviewer. The operator's journey ends at an open merge request that a technical
  person reviews and merges.

## Audience resolution

`audience` is a per-operator preference, never a shared/committed one. Resolve it the same way in
every audience-aware skill:

1. **Read** `audience:` from `$CONTEXT_ROOT/.sdd.local.yml`. If present, use it — done.
2. **Absent** → ask the operator the plain question (below), then write the answer as
   `audience: <plain|technical>` into `$CONTEXT_ROOT/.sdd.local.yml`, creating the file if it
   doesn't exist. Before writing it, ensure `$CONTEXT_ROOT/.gitignore` exists and contains a line
   `.sdd.local.yml` (so this per-operator file is never committed) — create or append to the
   `.gitignore` first if needed.
3. **Default** `technical` if the question goes unanswered.

Every audience-aware skill resolves audience this same way — read `$CONTEXT_ROOT/.sdd.local.yml`,
else ask+write. It's a cheap local read, so there is no inheritance through frontmatter and no
re-stamping into artifacts: each skill just checks the local file itself every time.

The plain question to ask when `$CONTEXT_ROOT/.sdd.local.yml` has no `audience:`:

> Are you a developer, or a non-technical person (like a product owner or project manager)?
> I'll keep everything in plain language if you're not a developer.

Map "developer" → `technical`; anything else → `plain`.

## Translation rules

In plain mode, the operator sees plain sentences and plain choices. The following are **never shown**
to the operator (they still happen underneath, and still land in the artifacts on disk):

- YAML / frontmatter, field names (`context_type`, `product_type`, `timeline_budget`, etc.).
- FR-NNN / US-NN numbering, NFR terminology, the "one-sentence business rule" framing, the
  empty-CRUD label, "Socratic round".
- The PRD/roadmap schema, section-name contracts, self-review/lint internals.
- Shell commands, `pbcopy`/PowerShell blocks, file paths, `context/<app>/…` layout talk.
- Greenfield/brownfield terms, "vertical slice", "fan-out", "north star", "Change ID",
  "dependency graph", "foundation".
- Git/branch/commit mechanics.

Replace jargon with plain intent. Examples (regenerate per context, keep the meaning):

| Instead of (technical) | Say (plain) |
| --- | --- |
| "Let's capture the FRs and NFRs." | "Let's list what people need to be able to do, and the qualities it must have." |
| "State the one-sentence business rule." | "In one sentence, what's the smart thing this does for the user that a plain spreadsheet couldn't?" |
| "This is the north-star vertical slice." | "This is the first piece worth building — the one that proves the idea works." |
| "I'll write shape-notes.md, then run /sdd-prd." | "I'll save your answers, then turn them into a product write-up you can share." |
| "Which starter/stack should we use?" | (not asked — see Auto-decision policy) |

Keep the family's existing rule: mirror the operator's language (Polish operator → Polish
throughout). Plain mode adds "no jargon"; it does not change language mirroring.

## Auto-decision policy

In plain mode, the skill resolves technical-only decisions itself and does NOT ask the operator.
Each row: the safe default, and whether it must be logged (see audit trail).

| Decision | Owner skill | Plain-mode default | Log? |
| --- | --- | --- | --- |
| Workspace / app resolution | shape, plan | Auto-detect from cwd; if ambiguous, ask in product terms ("which part of the product is this for?") and map the answer to the workspace | yes |
| Greenfield vs brownfield | shape, prd | Auto-detect silently from project markers; never surface the term | no |
| Stack / starter (greenfield) | tech-stack-selector | Pick the recommended agent-friendly starter | yes |
| Stack assessment (brownfield) | stack-assess, health-check | Run to a plain summary, or skip when stack is already fixed | yes (anything risky) |
| Test strategy / TDD-vs-e2e-vs-goal | plan, implement | Auto-pick per phase shape | yes |
| Which implement variant | implement router | Default to gated `/sdd-implement`; offer "just build it all" (`/sdd-goal-implement`) | no |
| Commit / branch / MR mechanics | implement, mr | Fully automated; never shown as git commands | no |

The skill never invents PRODUCT content (business rules, success criteria, requirements). That rule
from the family core is unchanged in plain mode — genuine product gaps still surface as plain
questions, and unresolved ones still land in the artifact's Open Questions. Auto-decisions cover
TECHNICAL choices only.

## Auto-decision audit trail

Every technical decision the skill made silently in plain mode (rows marked "Log? yes" above) is
appended to an `## Auto-decisions (for review)` block on the artifact the skill produces
(`shape-notes.md`, `plan-brief.md`, and the MR description). Format — one bullet per decision:

```markdown
## Auto-decisions (for review)

- **<what was decided>** — <the choice made>. Why: <one-line rationale>. A developer should confirm
  this at review.
```

This block is additive: it does NOT replace or alter any schema-required section, and it is ignored
by downstream parsers (which grep for the contract section names). Its sole audience is the human
technical reviewer at the MR. This upholds the family principle "gaps surface, they don't hide" —
auto-handling is logged, never silent invention.

## Handoff style

Plain mode KEEPS every human handoff (nothing auto-chains) but replaces the jargon status block with
a plain summary and a plain continue-gate:

```
Here's what I did: <2-4 plain sentences>.
Here's what happens next: <one plain sentence naming the next step in product terms>.
Want me to keep going?
```

Do NOT print the schema status block, the clipboard command, or the next slash command to a plain
operator. Copy the next command to the clipboard silently (as today), but describe the next step in
words, not as `/sdd-…`.

## Artifacts are unchanged

The files written to disk are identical in both modes and fully schema-conformant. Plain mode
changes only (a) the conversation, (b) the printed summaries, and (c) the additive
`## Auto-decisions (for review)` block. A technical reviewer opening a PM-produced `prd.md` gets the
real, complete PRD. This is the property that makes the whole approach safe.
