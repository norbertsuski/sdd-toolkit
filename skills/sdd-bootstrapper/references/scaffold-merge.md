# Scaffold-and-merge (Step 2)

The phase where bootstrapper actually runs the starter's CLI. Three `cwd_strategy` branches share one strict conflict policy. CLI exit code != 0 is the only HARD-STOP in the skill; everything else is WARN-AND-CONTINUE.

## Inputs (resolved at Step 0 / Step 1)

- The chosen card's `cmd_template` (carries `{name}`, `{module}` and/or `{pm}` placeholders).
- `project_name` from the hand-off frontmatter (kebab-case, starts with a letter).
- `package_manager` from the hand-off frontmatter, falling back to the card's `toolchain.package_manager` if omitted.
- `cwd_strategy` from `bootstrapper-config.yaml` for this `starter_id`, defaulting to `subdir-then-move` if the id is not listed.

## Substitution rules

Three placeholders, substituted before exec. Substitution is the same for every strategy — the strategy decides *where* the command runs, never *what* the placeholders become:

- `{name}` — replaced by `project_name` verbatim (e.g., `recipe-fridge`). This is the project/package/crate/app name the CLI sees, so CLIs that derive identifiers from it (npm package name, Rails app module, Cargo crate, Go module path, .NET namespace, Maven artifactId) get the real name.
- `{module}` — replaced by `project_name` with every `-` turned into `_` (e.g., `recipe_fridge`). Used where the ecosystem forbids hyphens in identifiers: Python modules (`django`) and Dart packages (`flutter`).
- `{pm}` — replaced by the resolved package manager (hand-off value, or card's `toolchain.package_manager` fallback). If `cmd_template` contains no `{pm}` placeholder, the package manager field is unused (e.g., `cargo new {name} --bin --edition 2024`).

No other placeholders exist; `scripts/validate-structure.sh` rejects any other `{...}` token in a registry `cmd_template`.

Template contract per strategy (also enforced by the validator where mechanically checkable):

- **`subdir-then-move` / `git-clone`** — the template must create exactly one directory, `./{name}/`, relative to where it runs. Bootstrapper runs it inside the staging directory `.bootstrap-scaffold/`, so the project lands at `.bootstrap-scaffold/<project_name>/` (the *scaffold root*), and that is what gets moved up. A template that writes into its own working directory instead (e.g., an un-rooted `tar -xzf -`) leaves the scaffold root empty — that is a registry bug.
- **`native-cwd`** — the template writes into its working directory itself (a literal `.` or the CLI's in-place default). `{name}` / `{module}` may still appear as *name* arguments, never as the target directory.

The scaffolded project lives in cwd; the cwd's directory name is the project's directory name — `project_name` names the project, it does not create a `<project_name>/` directory in cwd. `project_name` is also staged into the verification log as metadata.

## Strategy: subdir-then-move (default)

The default for any `starter_id` not listed in `bootstrapper-config.yaml`. Used by `next`, `astro`, `vite-react`, `t3`, `expo`, and most v2-onward starters.

Sequence:

1. Substitute `{name}`, `{module}`, `{pm}` into `cmd_template` per the rules above.
2. Create the staging directory `.bootstrap-scaffold/` in cwd and run the resolved command with `.bootstrap-scaffold/` as its working directory (`mkdir .bootstrap-scaffold && cd .bootstrap-scaffold && <resolved command>`, as one shell invocation). Capture stdout, stderr, and exit code.
3. If exit code != 0, run the CLI failure handling below. Stop here on failure.
4. Confirm the scaffold root `.bootstrap-scaffold/<project_name>/` exists. If it does not, treat the run as a CLI failure (the template broke its contract) and take the same HARD-STOP path.
5. Apply the conflict matrix below to move files from the scaffold root up into cwd.
6. Delete `.bootstrap-scaffold/` (it should be empty apart from the emptied scaffold root; if anything else is left, log the leftover paths into the verification log and remove the directory anyway — the move-up step is best-effort, not transactional).

## Strategy: native-cwd

Used by starters whose CLI was designed to scaffold into the current directory (e.g., `django-admin startproject {module} .`, `uv init --name {name}`). Listed explicitly in `bootstrapper-config.yaml` per starter. cwd always holds `context/`, so only CLIs that tolerate a non-empty directory (and refuse, rather than overwrite, on a real conflict) qualify.

Sequence:

1. Run the populated-cwd pre-flight: list the files the CLI is about to create or touch (best-effort — for most CLIs this is "files matching the starter's known layout"). If pre-flight cannot enumerate, surface the limitation in conversation but proceed.
2. Substitute `{name}`, `{module}`, `{pm}` into `cmd_template` per the rules above.
3. Run the resolved command in cwd. Capture stdout, stderr, and exit code.
4. If exit code != 0, run the CLI failure handling below. Stop here on failure.
5. There is no merge step — the CLI wrote into cwd directly. The conflict policy still applies in spirit: if the CLI overwrote a file the user had pre-populated (rare; most cwd-aware CLIs refuse on conflict and exit non-zero, which trips the HARD-STOP), surface the overwrite in the post-run summary.

`native-cwd` exists because some CLIs refuse to operate inside a parent directory or perform their own conflict handling that is friendlier than `.scaffold` siblings. When in doubt, `subdir-then-move` is the safer default.

## Strategy: git-clone

Used by starters whose `cmd_template` starts with `git clone` (e.g., `sdd-astro-starter`).

Sequence:

1. Substitute `{name}`, `{module}`, `{pm}` into `cmd_template` per the rules above.
2. Create `.bootstrap-scaffold/` and run the resolved command inside it, exactly as for `subdir-then-move`. The clone lands at the scaffold root `.bootstrap-scaffold/<project_name>/`. Capture stdout, stderr, and exit code.
3. If exit code != 0, or the scaffold root is missing, run the CLI failure handling below. Stop here on failure.
4. **Delete `.bootstrap-scaffold/<project_name>/.git/`** before the move-up. The cloned `.git/` carries the upstream starter's history, which is rarely what the user wants; the user typically initialises their own repo afterwards. (The conflict matrix drops a scaffold `.git/` anyway; deleting it first keeps the move log clean.)
5. Apply the conflict matrix below to move files up into cwd.
6. Delete `.bootstrap-scaffold/`.

## Conflict matrix

Applied during the move-up step for `subdir-then-move` and `git-clone`. Compares each path under the scaffold root `.bootstrap-scaffold/<project_name>/` against the same relative path under cwd.

| Path pattern in scaffold                                                       | Path exists in cwd? | Resolution                                                                          |
| ------------------------------------------------------------------------------ | ------------------- | ----------------------------------------------------------------------------------- |
| `context/**` (any path under `context/`)                                       | yes or no           | scaffold copy is dropped; cwd `context/` is the source of truth and never overwritten |
| `.git/**` (any path under a root-level `.git/`)                                | yes or no           | scaffold copy is dropped; cwd's own repository (or its absence) is authoritative      |
| `.gitignore`                                                                   | yes                 | append-merged: cwd lines kept in order, then scaffold lines de-duped against the cwd set, appended at the end with a `# from <starter_id>` separator comment |
| `.gitignore`                                                                   | no                  | move silently                                                                       |
| `package.json`, `README.md`, `CLAUDE.md`, `AGENTS.md`, root-level `*.md`       | yes                 | existing wins; scaffold copy lands as `<filename>.scaffold` sibling                  |
| `package.json`, `README.md`, `CLAUDE.md`, `AGENTS.md`, root-level `*.md`       | no                  | move silently                                                                       |
| anything else                                                                  | yes                 | existing wins; scaffold copy lands as `<filename>.scaffold` sibling                  |
| anything else                                                                  | no                  | move silently                                                                       |

Notes on the matrix:

- `context/` is special-cased because it is the bootstrap chain's metadata surface — `tech-stack.md`, `change.md`, plans, frames. Overwriting any of it would destroy the chain trail. Drop is the right policy: cwd `context/` is canonical.
- `.git/` is dropped because many CLIs `git init` their output (`rails new`, `cargo new`, `nuxi init --gitInit`, `create-astro --git`, `create-turbo`, ...). Moving those files up would graft `.scaffold` siblings into the user's repository metadata, or silently hand the user a repository they did not create. Bootstrapper never initialises git (see below).
- `.gitignore` is the only file that gets append-merged because git's ignore semantics are additive (more patterns = stricter), so combining is safe and useful. De-dupe is line-by-line, exact match.
- `<filename>.scaffold` siblings give the user a no-data-loss diff target. The user can `diff README.md README.md.scaffold` to see what the starter shipped vs what they had.
- The matrix never deletes user files. It either moves a scaffold file into place, drops it (for `context/**`), or sidelines it as a `.scaffold` sibling.

## Default strategy

Any `starter_id` not listed in `bootstrapper-config.yaml`'s `starters:` map defaults to `subdir-then-move`. This is the safe default — the CLI scaffolds into a temp dir, then the conflict matrix governs the move-up, and cwd state (including `context/`) is preserved.

The template contract is what makes a strategy work, so a strategy change is never config-only: moving a starter between `native-cwd` and a staged strategy also means rewriting its `cmd_template` (a staged template must create `./{name}/`; a native-cwd template must write into `.`). Worked example: `fastapi` is `native-cwd` with `uv init --name {name} && uv add fastapi uvicorn` (initialises the project in place). Under `subdir-then-move` the same intent would need `uv init {name} && cd {name} && uv add fastapi uvicorn`.

Future starters get explicit overrides in v2 by adding entries to `bootstrapper-config.yaml`. The validator at `scripts/validate-structure.sh` ensures every `starter_id` listed there exists in the tech-stack-selector registry.

## CLI failure handling

When the scaffold CLI exits non-zero, bootstrapper HARD-STOPs:

1. Capture stdout, stderr, and the exit code into the in-memory verification record.
2. Leave `.bootstrap-scaffold/` in place for the user to inspect (do NOT delete it on failure — the user may want to read partial output, log files, or rerun manually).
3. Do NOT apply the conflict matrix. cwd stays exactly as it was at Step 1.
4. Write a partial `verification.md` per `verification-log-schema.md`, with `phase_3_status: failed`, the captured CLI output, and the resolved invocation that failed.
5. Set the clipboard for retry:

   ```bash
   echo -n "/sdd-bootstrapper" | pbcopy 2>/dev/null || echo -n "/sdd-bootstrapper" | clip.exe 2>/dev/null || echo -n "/sdd-bootstrapper" | xclip -selection clipboard 2>/dev/null || true
   ```

6. Print verbatim (substitute `<exit_code>` and `<short_stderr>`):

   ```
   Scaffold CLI exited with status <exit_code>. The scaffold directory `.bootstrap-scaffold/` is left in place for inspection. Last stderr line:

       <short_stderr>

   A partial verification log was written to `$CONTEXT_ROOT/changes/bootstrap-verification/verification.md` with `phase_3_status: failed` and the captured CLI output. Re-invoke `/sdd-bootstrapper` (clipboard set) once the failure cause is addressed.
   ```

7. Stop. Do not advance to Step 3 or Step 4 (Step 4 already ran in step 4 above for the partial log; the normal Step 3 audit is skipped because there is nothing to audit).

CLI failure is the only HARD-STOP in the skill. Pre-scaffold staleness, post-scaffold CRITICAL findings, missing audit tools — all WARN-AND-CONTINUE. The principle: bootstrapper halts only when there is genuinely no project to verify.

## Substitution edge cases

- **`{pm}` omitted from hand-off**: fall back to the card's `toolchain.package_manager`. Every card whose `cmd_template` contains `{pm}` carries one (`go`, with `toolchain: {}`, has no `{pm}` in its template).
- **`cmd_template` with no `{pm}` placeholder**: ignore the package_manager field for this run (e.g., `cargo new {name} --bin --edition 2024` does not need a JS package manager). Stage the resolved value in the verification log anyway for audit-trail completeness.
- **`{name}` appears more than once in `cmd_template`**: substitute every occurrence. The sdd-astro-starter template (`git clone <url> {name} && cd {name} && {pm} install`) is the canonical example; `spring` uses it twice as artifactId and archive `baseDir`.
- **Name rejected by the ecosystem**: `project_name` is kebab-case starting with a letter, so `{name}` is a valid npm/Cargo/Go/Maven/.NET name and `{module}` a valid Python/Dart identifier. Bootstrapper does not re-validate or repair the name. A residual collision (e.g., `{module}` = `test` or `django`, which `django-admin` refuses as it shadows an importable module; a Dart reserved word for `flutter`) surfaces as a non-zero CLI exit and takes the HARD-STOP path.
- **`cmd_template` carries a chained `&&`**: run the whole template as one shell invocation. Bootstrapper does not split on `&&` — it lets the shell handle the chain. Failure of any segment surfaces as a non-zero overall exit code, which the HARD-STOP path handles correctly.

## Surfacing the result

After a successful scaffold, print one summary line in conversation. Format:

```
Scaffolded via <strategy>. <N> files moved. <M> conflicts surfaced as `.scaffold` siblings: <comma list>. `.gitignore` <append-merged | moved silently | absent>.
```

For `native-cwd`:

```
Scaffolded via native-cwd directly into the current directory. <N> files written. <M> pre-existing files preserved.
```

Stage the full file-by-file move log (or write log, for `native-cwd`) into the in-memory verification record for Step 4 to write to disk.

## Resolved invocations per starter

Every registry starter, resolved for `project_name: recipe-fridge` (`{module}` = `recipe_fridge`) with the card's default `{pm}`. "Runs in" is the command's working directory; for staged strategies the scaffold root is `.bootstrap-scaffold/recipe-fridge/`. Keep this table in sync with the registry when a `cmd_template` or `cwd_strategy` changes.

| starter_id | cwd_strategy | Runs in | Resolved invocation |
| --- | --- | --- | --- |
| `sdd-astro-starter` | git-clone | `.bootstrap-scaffold/` | `git clone https://github.com/przeprogramowani/sdd-astro-starter recipe-fridge && cd recipe-fridge && npm install` |
| `next` | subdir-then-move | `.bootstrap-scaffold/` | `npx create-next-app@latest recipe-fridge --ts --tailwind --eslint --app --src-dir --import-alias "@/*" --use-npm` |
| `astro` | subdir-then-move | `.bootstrap-scaffold/` | `npm create astro@latest -- recipe-fridge --template basics --install --git --yes` |
| `vite-react` | subdir-then-move | `.bootstrap-scaffold/` | `npm create vite@latest recipe-fridge -- --template react-ts` |
| `vite-vue` | subdir-then-move | `.bootstrap-scaffold/` | `npm create vite@latest recipe-fridge -- --template vue-ts` |
| `sveltekit` | subdir-then-move | `.bootstrap-scaffold/` | `npx sv create recipe-fridge --template minimal --types ts --no-add-ons --install npm` |
| `nuxt` | subdir-then-move | `.bootstrap-scaffold/` | `npx nuxi init recipe-fridge --packageManager npm --install --gitInit` |
| `react-router` | subdir-then-move | `.bootstrap-scaffold/` | `npx create-react-router@latest recipe-fridge --yes --package-manager npm` |
| `t3` | subdir-then-move | `.bootstrap-scaffold/` | `npx create-t3-app@latest recipe-fridge --CI --tailwind --trpc --drizzle --appRouter --biome --dbProvider sqlite` |
| `expo` | subdir-then-move | `.bootstrap-scaffold/` | `npx create-expo-app recipe-fridge --yes --template default` |
| `angular` | subdir-then-move | `.bootstrap-scaffold/` | `npx @angular/cli new recipe-fridge --defaults --routing --style scss --skip-tests --ssr false` |
| `nestjs` | subdir-then-move | `.bootstrap-scaffold/` | `npx @nestjs/cli new recipe-fridge -p npm --strict --skip-git` |
| `hono` | subdir-then-move | `.bootstrap-scaffold/` | `npm create hono@latest recipe-fridge -- --template nodejs --pm npm --install` |
| `fastify` | subdir-then-move | `.bootstrap-scaffold/` | `npx fastify-cli generate recipe-fridge --lang=ts --esm` |
| `express` | subdir-then-move | `.bootstrap-scaffold/` | `npx express-generator recipe-fridge --git` |
| `django` | native-cwd | cwd | `django-admin startproject recipe_fridge .` |
| `fastapi` | native-cwd | cwd | `uv init --name recipe-fridge && uv add fastapi uvicorn` |
| `rails` | subdir-then-move | `.bootstrap-scaffold/` | `rails new recipe-fridge --database postgresql --skip-bundle --skip-test` |
| `rails-api` | subdir-then-move | `.bootstrap-scaffold/` | `rails new recipe-fridge --api --database postgresql --skip-bundle --skip-test` |
| `spring` | subdir-then-move | `.bootstrap-scaffold/` | `curl -s https://start.spring.io/starter.tgz -d dependencies=web,devtools -d type=maven-project -d javaVersion=21 -d groupId=com.example -d artifactId=recipe-fridge -d baseDir=recipe-fridge \| tar -xzf -` |
| `laravel` | subdir-then-move | `.bootstrap-scaffold/` | `composer create-project laravel/laravel recipe-fridge --no-interaction --prefer-dist` |
| `go` | subdir-then-move | `.bootstrap-scaffold/` | `mkdir recipe-fridge && cd recipe-fridge && go mod init github.com/user/recipe-fridge` |
| `rust` | subdir-then-move | `.bootstrap-scaffold/` | `cargo new recipe-fridge --bin --edition 2024` |
| `axum` | subdir-then-move | `.bootstrap-scaffold/` | `cargo new recipe-fridge --bin --edition 2024 && cd recipe-fridge && cargo add axum tokio --features tokio/full` |
| `turborepo` | subdir-then-move | `.bootstrap-scaffold/` | `npx create-turbo@latest recipe-fridge --package-manager npm --skip-install` |
| `nx` | subdir-then-move | `.bootstrap-scaffold/` | `npx create-nx-workspace recipe-fridge --preset react-monorepo --interactive=false --packageManager npm --nxCloud skip` |
| `tauri` | subdir-then-move | `.bootstrap-scaffold/` | `npm create tauri-app@latest recipe-fridge -- --template react-ts --manager npm --yes` |
| `flutter` | subdir-then-move | `.bootstrap-scaffold/` | `flutter create -e --project-name recipe_fridge --org com.example --platforms android,ios,web recipe-fridge` |
| `dotnet` | subdir-then-move | `.bootstrap-scaffold/` | `dotnet new webapi -n recipe-fridge --no-restore` |

Starter-specific notes:

- `django` — `startproject` takes a Python module name, not a directory; `{module}` plus the explicit `.` target scaffolds `manage.py` and `recipe_fridge/` straight into cwd.
- `fastapi` — `uv init` with no path initialises cwd in place; `--name` keeps the project name from falling back to cwd's directory name. It refuses if a `pyproject.toml` already exists.
- `hono` — staged rather than native-cwd: `create-hono` prompts when its target directory is non-empty, and cwd always contains `context/`.
- `spring` — Spring Initializr's `baseDir` roots the archive at `recipe-fridge/`, so `tar` extracts into the scaffold root instead of the staging directory.
- `go` / `rust` / `axum` — `{name}` gives a real Go module path and a valid Cargo crate name (Cargo accepts hyphens; the binary is `recipe-fridge`).
- `flutter` — the directory stays kebab-case, while `--project-name {module}` supplies the Dart package name (`pubspec.yaml` `name:`), which must be `lowercase_with_underscores`.

## What this step does NOT do

- Does not install dependencies beyond what `cmd_template` itself runs. Most templates chain an install (`npm create next-app && cd next-app && npm install`); bootstrapper inherits that behaviour but does not add its own install step.
- Does not initialise git. The user runs `git init` themselves (or did so before invoking bootstrapper). For `git-clone` strategy, the cloned `.git/` is deleted before move-up exactly so the user is not surprised by inherited history; for every staged strategy, a `.git/` the CLI created is dropped by the conflict matrix.
- Does not run any audit. That is Step 3 (`post-scaffold-verification.md`).
- Does not generate `AGENTS.md` / `CLAUDE.md`. That is a future agent-context skill's job.
- Does not write the verification log. That is Step 4. This step only stages findings into the in-memory record.
