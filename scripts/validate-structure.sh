#!/usr/bin/env bash
# Static structural validation for the sdd-skills plugin.
# Checks the mechanical invariants that keep the skill family consistent —
# frontmatter presence, skill counts in the docs, cross-reference resolution,
# and the orchestration-layer contracts. Run from the repo root:
#
#   bash scripts/validate-structure.sh
#
# Exits non-zero on any failure. Extend this file when adding a skill or a
# cross-skill contract; it is the repo's only automated check.

set -u
cd "$(dirname "$0")/.." || exit 1

fail=0
err() { echo "FAIL: $*"; fail=1; }
ok()  { echo "  ok: $*"; }

# --- 1. plugin.json parses and carries a semver version -----------------
if command -v python3 >/dev/null 2>&1; then
  version=$(python3 -c 'import json;print(json.load(open(".claude-plugin/plugin.json"))["version"])' 2>/dev/null)
  if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    ok "plugin.json valid, version $version"
  else
    err "plugin.json missing or malformed version (got: '$version')"
  fi
else
  grep -qE '"version": *"[0-9]+\.[0-9]+\.[0-9]+"' .claude-plugin/plugin.json \
    && ok "plugin.json version present (python3 unavailable, grep check)" \
    || err "plugin.json version missing/malformed"
fi

# --- 2. every skill folder has SKILL.md with matching name frontmatter --
count=0
for dir in skills/sdd-*/; do
  name=$(basename "$dir")
  count=$((count + 1))
  if [[ ! -f "$dir/SKILL.md" ]]; then
    err "$name has no SKILL.md"
    continue
  fi
  head -5 "$dir/SKILL.md" | grep -q "^name: $name$" \
    || err "$name/SKILL.md frontmatter name does not match folder"
  grep -q "^description:" "$dir/SKILL.md" \
    || err "$name/SKILL.md has no description frontmatter"
done
ok "$count skill folders, each with name-matching SKILL.md"

# --- 3. skill count consistent across the docs --------------------------
for spec in \
  "README.md:(${count} \`sdd-*\` skills)" \
  "skills/sdd-help/SKILL.md:Installed in this repo (${count})" \
  "skills/sdd-help/SKILL.md:All ${count} commands"
do
  file="${spec%%:*}"; needle="${spec#*:}"
  grep -qF "$needle" "$file" \
    && ok "$file mentions the count: '$needle'" \
    || err "$file does not carry the current skill count ('$needle' not found)"
done

# --- 4. every skill appears in sdd-help's installed list and README table
for dir in skills/sdd-*/; do
  name=$(basename "$dir")
  [[ "$name" == "sdd-help" ]] || grep -q "\`$name\`" skills/sdd-help/SKILL.md \
    || err "sdd-help does not mention $name"
  grep -q "| \`$name\`" README.md \
    || err "README skills table has no row for $name"
done
ok "all skills referenced in sdd-help and the README table"

# --- 5. orchestration-layer boundaries stay declared ---------------------
grep -q "Agent Factory for a Single Change" skills/sdd-run/SKILL.md \
  && ok "sdd-run still declares single-change scope" \
  || err "sdd-run no longer declares 'Agent Factory for a Single Change'"
grep -q "never writes.*roadmap statuses\|never writes\*\* roadmap statuses" skills/sdd-project-run/SKILL.md \
  && ok "sdd-project-run declares roadmap read-only boundary" \
  || err "sdd-project-run missing the roadmap read-only declaration"
grep -q "sole writer" skills/sdd-project-run/SKILL.md \
  && ok "sdd-project-run acknowledges /sdd-archive as sole done-writer" \
  || err "sdd-project-run missing the /sdd-archive sole-writer acknowledgment"

# --- 6. the run-result contract is wired on both ends --------------------
[[ -f skills/sdd-run/references/run-result-contract.md ]] \
  && ok "run-result-contract.md exists" \
  || err "skills/sdd-run/references/run-result-contract.md missing"
grep -q "run-result-contract.md" skills/sdd-run/SKILL.md \
  || err "sdd-run/SKILL.md does not reference run-result-contract.md"
grep -q "run-result-contract.md" skills/sdd-project-run/SKILL.md \
  || err "sdd-project-run/SKILL.md does not reference run-result-contract.md"
grep -q "FACTORY RESULT" skills/sdd-run/SKILL.md \
  || err "sdd-run/SKILL.md does not emit FACTORY RESULT"
ok "FACTORY RESULT contract wired in producer and consumer"

# --- 7. sdd-project-run references resolve -------------------------------
for ref in \
  skills/sdd-project-run/references/project-state.md \
  skills/sdd-project-run/references/project-log-format.md
do
  [[ -f "$ref" ]] || err "$ref missing"
done
ok "sdd-project-run reference files present"

# --- 8. relative cross-skill links in orchestration skills resolve ------
for skill in sdd-run sdd-project-run; do
  while IFS= read -r link; do
    target="skills/$skill/$link"
    # normalize ../ segments via cd
    resolved=$(cd "skills/$skill" 2>/dev/null && cd "$(dirname "$link")" 2>/dev/null && pwd)/$(basename "$link")
    [[ -f "$resolved" ]] || err "$skill/SKILL.md dangling relative link: $link"
  done < <(grep -oE '(\.\./|references/)[A-Za-z0-9/._-]+\.md' "skills/$skill/SKILL.md" | sort -u)
done
ok "relative .md links in sdd-run and sdd-project-run resolve"

echo
if [[ $fail -eq 0 ]]; then
  echo "validate-structure: ALL CHECKS PASSED"
else
  echo "validate-structure: FAILURES ABOVE"
fi
exit $fail
