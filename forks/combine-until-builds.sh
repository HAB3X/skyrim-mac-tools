#!/bin/bash
# Rebuild the "combined" branch from mac-build with every client-side fork commit (forks-scan/st-order.txt, oldest
# first) except those in forks-scan/skip.txt, then build the player's programs. On a compile error, the original fork
# commit that wrote the failing line (from the "cherry picked from commit" trailer of the applied copy) goes on the skip
# list and the round repeats; commits that depended on a skipped one stop applying by themselves.
# Outputs: forks-scan/combined-picks.tsv (last round: applied / conflict per commit), forks-scan/skip.txt (with reasons
# in skip-reasons.tsv), forks-scan/combined-build.log.
set -u
TREE="$HOME/Documents/Skyrim-RE-References/build-combined"
SCAN="$HOME/Documents/Skyrim-RE-References/forks-scan"
ORDER="$SCAN/st-order.txt"; SKIP="$SCAN/skip.txt"; REASONS="$SCAN/skip-reasons.tsv"
MAX=${MAX:-60}
cd "$TREE" || exit 1
. "$HOME/Developer/xwin/env.sh"
touch "$SKIP" "$REASONS"

rebuild_branch() {
  git cherry-pick --abort >/dev/null 2>&1; git revert --abort >/dev/null 2>&1
  git reset -q --hard mac-build || return 1
  git submodule update --init --recursive -q --force >/dev/null 2>&1
  git clean -qfd -e build -e .xmake -e vsxmake2022 >/dev/null 2>&1
  : > "$SCAN/combined-picks.tsv"
  local c
  while read -r c; do
    /usr/bin/grep -qx "$c" "$SKIP" && continue
    if git cherry-pick -x --allow-empty --allow-empty-message "$c" >/dev/null 2>&1; then
      printf "applied\t%s\n" "$c" >> "$SCAN/combined-picks.tsv"
    else
      git cherry-pick --abort >/dev/null 2>&1
      printf "conflict\t%s\n" "$c" >> "$SCAN/combined-picks.tsv"
    fi
  done < "$ORDER"
}

origin_of() {   # origin_of <file> <line>: original fork commit that wrote this line (empty for mac-build's own lines)
  local c
  c=$(git blame -L "$2,$2" --porcelain -- "$1" 2>/dev/null | head -1 | cut -d' ' -f1)
  [ -n "$c" ] || return
  git merge-base --is-ancestor "$c" mac-build 2>/dev/null && return
  git log -1 --format=%B "$c" | sed -nE 's/^\(cherry picked from commit ([0-9a-f]{40})\)$/\1/p' | tail -1
}

for round in $(seq "$MAX"); do
  rebuild_branch || { echo "STOP: could not reset to mac-build"; exit 1; }
  applied=$(/usr/bin/grep -c '^applied' "$SCAN/combined-picks.tsv")
  if { xmake build -y SkyrimImmersiveLauncher && xmake build -y TPProcess && xmake build -y ImmersiveElf; } \
       > "$SCAN/combined-build.log" 2>&1; then
    echo "BUILD OK in round $round: $applied fork commits applied, $(wc -l < "$SKIP" | tr -d ' ') skipped for build errors"
    exit 0
  fi
  locs=$(/usr/bin/grep -aoE "((Code|Libraries)/[^ (]+)\(([0-9]+),[0-9]+\): (fatal error|error|note)" "$SCAN/combined-build.log" \
         | sed -E 's/\(([0-9]+),[0-9]+\): (fatal error|error|note)/ \1 \2/; s/ fatal error$/ error/' | head -20)
  culprit=""; where=""
  while read -r f l kind; do
    [ -f "$f" ] || continue
    c=$(origin_of "$f" "$l"); [ -n "$c" ] && { culprit=$c; where="$f:$l ($kind)"; break; }
  done <<< "$locs"
  if [ -z "$culprit" ]; then
    echo "STOP in round $round ($applied applied): errors not attributable to one fork commit:"
    /usr/bin/grep -aE "error" "$SCAN/combined-build.log" | head -6; exit 2
  fi
  echo "$culprit" >> "$SKIP"
  printf "%s\t%s\t%s\n" "$round" "$where" "$(git log -1 --format='%h %an | %s' "$culprit" | cut -c1-110)" >> "$REASONS"
  echo "round $round: $applied applied; skip $(git log -1 --format='%h %s' "$culprit" | cut -c1-90)  [$where]"
done
echo "STOP: $MAX rounds"; exit 4
