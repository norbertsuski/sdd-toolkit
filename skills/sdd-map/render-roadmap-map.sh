#!/usr/bin/env bash
# render-roadmap-map.sh — deterministic Mermaid renderer for a project's roadmap.
#
# Parses the "## At a glance" table of a roadmap.md and writes a sibling
# roadmap-map.md containing a Mermaid dependency graph (slices as nodes,
# Prerequisites as edges, coloured by status). Computes ready/blocked from the
# prerequisite graph. Read-only w.r.t. roadmap.md; writes only roadmap-map.md.
#
# Usage:   render-roadmap-map.sh <path/to/roadmap.md>
# Output:  writes <dir>/roadmap-map.md; prints its path then a one-line summary.
#
# Used by the /sdd-map skill (interactive) and by the roadmap-map auto-refresh
# hook (on edits to roadmap.md). It never opens an editor — that's the skill's job.

set -euo pipefail

roadmap="${1:-}"
if [ -z "$roadmap" ]; then
  echo "usage: render-roadmap-map.sh <path/to/roadmap.md>" >&2
  exit 2
fi
if [ ! -f "$roadmap" ]; then
  echo "render-roadmap-map: no such file: $roadmap" >&2
  exit 1
fi

dir="$(cd "$(dirname "$roadmap")" && pwd)"
slug="$(basename "$dir")"
out="$dir/roadmap-map.md"
today="$(date +%Y-%m-%d)"

awk -v slug="$slug" -v today="$today" '
  function trim(s){ gsub(/^[[:space:]]+|[[:space:]]+$/,"",s); return s }
  function sanitize(s){ gsub(/[^A-Za-z0-9]/,"",s); return s }

  # Section tracking: reset on every h2 (## ), but not h3 (### ).
  /^##[[:space:]]/ { section=tolower($0); next }

  # North star: capture the first ID token (e.g. S-01) in that section.
  section ~ /north star/ {
    if (ns=="" && match($0,/[A-Z]+-[0-9]+/)) ns=substr($0,RSTART,RLENGTH)
  }

  # "At a glance" table rows.
  section ~ /at a glance/ && /^[[:space:]]*\|/ {
    line=$0
    if (line ~ /^[[:space:]]*\|[[:space:]]*:?-+/) next   # separator row
    nf=split(line, f, "|")
    if (nf < 7) next
    id=trim(f[2])
    if (id=="" || id=="ID") next                          # header / blank
    cid=trim(f[3]); pre=trim(f[5]); st=tolower(trim(f[7]))
    n++; order[n]=id; ids[id]=1
    change[id]=cid; status[id]=st; prereq[id]=pre
  }

  END {
    if (n==0) { print "__EMPTY__"; exit }

    for (i=1;i<=n;i++){
      id=order[i]; st=status[id]
      if (st=="done"){ disp[id]="done"; done_ct++; continue }
      if (st=="blocked"){ disp[id]="blocked"; blk_ct++; continue }
      p=prereq[id]; blocked=0
      if (p!="" && p!="—" && p!="-"){
        gsub(/,/," ",p); m=split(p,pa,/[[:space:]]+/)
        for (j=1;j<=m;j++){ pp=trim(pa[j]); if (pp=="") continue; if (status[pp]!="done") blocked=1 }
      }
      if (blocked){ disp[id]="blocked"; blk_ct++ } else { disp[id]="ready"; rdy_ct++ }
    }

    print "# Roadmap map — " slug
    print ""
    print "> Generated " today " from `roadmap.md` — derived, do not hand-edit; regenerate with `/sdd-map`."
    print ""
    print "```mermaid"
    print "graph LR"
    print "  classDef done      fill:#e7f7ec,stroke:#1e9e57,color:#0b3d22;"
    print "  classDef ready     fill:#e9edff,stroke:#2b4eff,color:#101a52;"
    print "  classDef blocked   fill:#f4f4f6,stroke:#b9b9c4,color:#6c6c7a;"
    print "  classDef northstar stroke-width:3px;"
    print ""
    for (i=1;i<=n;i++){
      id=order[i]; nid=sanitize(id); label=id
      if (change[id]!="") label=label " · " change[id]
      star=(id==ns)?"★ ":""
      printf "  %s[\"%s%s\"]:::%s\n", nid, star, label, disp[id]
    }
    if (ns!="" && (ns in ids)) printf "  class %s northstar;\n", sanitize(ns)
    print ""
    for (i=1;i<=n;i++){
      id=order[i]; p=prereq[id]
      if (p=="" || p=="—" || p=="-") continue
      gsub(/,/," ",p); m=split(p,pa,/[[:space:]]+/)
      for (j=1;j<=m;j++){ pp=trim(pa[j]); if (pp=="" || !(pp in ids)) continue; printf "  %s --> %s\n", sanitize(pp), sanitize(id) }
    }
    print "```"
    print ""
    printf "%s · %d slices — %d done · %d ready · %d blocked", slug, n, done_ct+0, rdy_ct+0, blk_ct+0
    if (ns!="") printf " · ★ %s", ns
    print ""
  }
' "$roadmap" > "$out.tmp"

if grep -q "^__EMPTY__$" "$out.tmp"; then
  rm -f "$out.tmp"
  echo "render-roadmap-map: no '## At a glance' table found in $roadmap" >&2
  exit 3
fi

mv "$out.tmp" "$out"

# First line = path (machine-readable); second line = the summary (last line of file).
echo "$out"
tail -n 1 "$out"
