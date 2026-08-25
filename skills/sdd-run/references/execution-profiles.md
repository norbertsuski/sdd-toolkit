# Execution profiles — resource-aware agent routing

Shared policy for `/sdd-project-run` and `/sdd-run`. It answers a separate question from execution strategy:

- **strategy** decides how work is decomposed (`single-agent`, sequential workers, or a DAG);
- **execution profile** decides which model tier, reasoning effort, context scope, and verification strength each dispatched agent receives.

The two decisions must not be conflated. A single-agent change can be `deep`; a multi-agent plan can give a documentation phase `light` and an auth phase `critical`.

## Decision record

Before dispatch, print and persist this block (project level: once per selected change; change level: once per worker/inline phase group and once for the reviewer):

```text
Execution profile: light | standard | deep | critical
Model tier: economical | standard | strong
Resolved model: <host-native model id> | inherited | default
Reasoning effort: low | medium | high
Context scope: small | scoped | broad
Verification: normal | independent | heightened
Why: <task signals that determined the profile>
```

`Resolved model` is an observation, not a requested fantasy. Use a concrete model id only when the host exposes an actual model override. If the host cannot select a model or reasoning effort for this dispatch, use `inherited` (same agent/session) or `default` (new agent with host defaults), state the limitation once, and still apply the context and verification parts of the profile. Never claim that a cheaper or stronger model was used when the runtime did not expose that control.

## Profiles

| Profile | Default model tier | Effort | Context | Verification | Typical work |
|---|---|---|---|---|---|
| **light** | economical | low | small | normal | docs/copy, mechanical rename, one exact existing pattern, local tests, usually <=2 files, no contract/schema/security impact |
| **standard** | standard | medium | scoped | independent | ordinary feature or fix inside one subsystem, several cooperating files, known architecture |
| **deep** | strong | high | broad | independent | cross-module work, new API/schema/migration, unfamiliar subsystem, research-heavy integration, difficult debugging, meaningful ambiguity |
| **critical** | strong | high | broad | heightened | auth, permissions, secrets, data safety, irreversible migration, security boundary, public compatibility, or another high-blast-radius decision |

Profiles are defaults, not an excuse to over-read. `Context scope` means the minimum sufficient evidence inside that band. A logically simple task that needs a wide repository survey may keep a lower model tier while using `broad` context; record the adjusted axis in the decision block.

### Context payloads (dispatch-side)

- **small** — plan Overview/Desired End State + target phase/group + its Progress rows; directly referenced interfaces/files; only the exact relevant frame/research excerpt; applicable lessons. No full conversation, full roadmap, or whole research document.
- **scoped** — the normal `worker-contract.md` payload: plan header guardrails, target phase, neighboring interfaces, relevant frame/research sections, lessons.
- **broad** — full plan plus all frame/research sections needed to resolve cross-cutting assumptions and a wider code/interface map; still exclude unrelated projects/conversation history.

These bands constrain **dispatched agent payloads**. The orchestrator may still read the full plan once to classify dependencies safely. Inline execution cannot erase context already inherited; record `context=<band>, carrier=inline (advisory)` rather than claiming token isolation. Prefer a profiled executor carrier below when a real model/context override is available and interaction rules allow it.

## Classification rule

Start at `light`, inspect deterministic signals, and take the strongest profile required by any applicable signal:

1. **Critical risk wins**: security/auth/permissions, destructive or irreversible data work, secrets, public compatibility guarantees, or a failure whose blast radius crosses trust boundaries -> `critical`.
2. **Deep complexity wins next**: architecture or schema changes, migrations, multiple subsystems, novel integration, plan uncertainty, research, cross-cutting behavior, or broad blast radius -> at least `deep`.
3. **Standard is the normal case**: a bounded feature/fix using known patterns inside one subsystem -> `standard`.
4. **Light must be evidenced**: isolated/mechanical, exact pattern, small write scope, no API/schema/security/architecture consequence -> `light`.

File count is only a signal. A one-line authorization change is not `light`; a ten-file generated snapshot refresh can be.

## Hierarchical routing

`/sdd-project-run` classifies the whole roadmap item before delegation. Its profile controls the change-factory agent when the host supports model-selectable child dispatch and supplies parent risk/context signals to `/sdd-run`.

`/sdd-run` then classifies each executable phase (or inseparable inline phase group) independently. The project profile is **not a blanket model floor**: a `critical` auth change may still give a docs-only phase `light`. It is a risk constraint:

- a phase touching the signal that made the change `critical` must be at least `deep`;
- the final verification profile is at least the project profile's verification strength;
- a child may escalate above the project estimate whenever the plan/code reveals stronger evidence;
- every downward choice must name why the parent risk does not apply to that phase.

When `/sdd-run` is invoked directly, there is no parent profile; derive from the plan/code. Resource carrier is orthogonal to decomposition: when host model override is available and materially differs, dispatch a single profiled executor even for `single-agent`/single-phase work (unattended, or attended only with interactive relay). Otherwise record inherited/inline advisory honestly. Model selection still applies to every worker and reviewer subagent.

## Reviewer routing

Implementation and review profiles are independent:

- `light` implementation -> `light` reviewer only for a trivial skip allowed by `/sdd-run`; otherwise at least `standard` independent review;
- `standard` implementation -> `standard` independent reviewer;
- `deep` implementation -> `deep` independent reviewer;
- any `critical` signal -> `critical`/heightened review, even if individual mechanical phases used cheaper agents.

The reviewer receives broader evidence than an implementation worker. Cost savings must never collapse producer and reviewer into the same authority for non-trivial work.

## Evidence-based escalation

Workers never change their own model. They return the normal STOP/WORKER REPORT with evidence; the parent owns routing.

On the one replacement already allowed by `/sdd-run`:

- `light -> standard` and `standard -> deep` when a gate failure, unexpected coupling, insufficient context, or uncertainty indicates under-classification;
- `deep -> critical` only when a critical-risk signal was discovered — not merely because the task is difficult;
- `critical` stays `critical`; there is no unbounded stronger-model loop;
- deterministic failures with complete evidence may keep the same profile when more reasoning would not help (record why).

Structural mismatches, missing preparation, and human decisions do not consume a stronger model as a retry. They STOP or route to the owning skill. Escalation never enlarges write scope, retry count, or permissions; those gates remain independent.

## Host capability resolution

At the start of a run, inspect the active host's callable agent/subagent interface once:

1. Does dispatch accept a model override? If yes, map `economical` / `standard` / `strong` to the cheapest suitable, default coding, and strongest reasoning-capable models actually available.
2. Does dispatch accept reasoning effort? If yes, pass `low` / `medium` / `high`; if not, record the host default.
3. Does it support isolated context? If not, multi-agent strategies already degrade to single-agent per `worker-contract.md`; profile decisions remain advisory for context/verification.

Do not hard-code vendor model names in this toolkit. Availability, pricing, and names drift; the stable contract is the tier + effort + evidence, while the resolved host-native id is logged per run.
