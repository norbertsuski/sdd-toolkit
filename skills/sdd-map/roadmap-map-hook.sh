#!/usr/bin/env bash
# roadmap-map-hook.sh — Claude Code PostToolUse hook.
#
# After an Edit/Write, if the edited file is a roadmap.md AND a sibling
# roadmap-map.md already exists, regenerate the map via render-roadmap-map.sh.
# Otherwise it's a silent no-op. This keeps an already-generated map in sync
# without re-invoking /sdd-map; the "only if it exists" guard makes it opt-in.
#
# Wire it up in .claude/settings.json:
#   { "hooks": { "PostToolUse": [ { "matcher": "Edit|Write",
#       "hooks": [ { "type": "command",
#         "command": ".claude/skills/sdd-map/roadmap-map-hook.sh" } ] } ] } }
#
# The hook JSON arrives on stdin; we only need tool_input.file_path.

set -euo pipefail

payload="$(cat)"

# Extract the edited file path — prefer node (robust JSON), fall back to grep.
fp="$(printf '%s' "$payload" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);process.stdout.write((j.tool_input&&j.tool_input.file_path)||"")}catch(e){}})' 2>/dev/null || true)"
if [ -z "$fp" ]; then
  fp="$(printf '%s' "$payload" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//; s/"$//')"
fi

[ -n "$fp" ] || exit 0

# Only react to roadmap.md (not roadmap-map.md, not other files).
case "$fp" in
  */roadmap.md) ;;
  roadmap.md) ;;
  *) exit 0 ;;
esac

dir="$(dirname "$fp")"
# Opt-in guard: only maintain a map that already exists.
[ -f "$dir/roadmap-map.md" ] || exit 0

# Regenerate quietly. Writing via the script (shell) does not re-trigger this
# hook, which only fires on Claude's own Edit/Write tools — so no loop.
here="$(cd "$(dirname "$0")" && pwd)"
bash "$here/render-roadmap-map.sh" "$fp" >/dev/null 2>&1 || true
exit 0
