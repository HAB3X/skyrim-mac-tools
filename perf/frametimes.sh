#!/bin/bash
# Frame-time summary of a DXMT log (SkyrimSE_d3d11.log from the jdrly fork with DXMT_STATS=1): one line with the
# frames, mean fps, frames over 33 and 50 ms, the median and worst 99th-percentile frame of the two-second intervals,
# the worst frame, the HITCH frames (frames over DXMT_HITCH_MS) by length, and how they split between DXMT and the rest (game, mod, Wine).
#   frametimes.sh <log> [first line]    only the lines from <first line> on (a benchmark's measured part)
set -u
log=${1:?usage: frametimes.sh <log> [first line]}; from=${2:-1}
[ -f "$log" ] || { echo "FAIL no log $log"; exit 1; }
/usr/bin/tail -n "+$from" "$log" | /usr/bin/awk '
  function field(s, k,   m) { return match(s, k "[0-9.]+") ? substr(s, RSTART + length(k), RLENGTH - length(k)) + 0 : -1 }
  / PACE app=/ {
    n += field($0, " n="); s33 += field($0, "slow33="); s50 += field($0, "slow50=")
    p99[++iv] = field($0, "p99:"); mx = field($0, "max:"); if (mx > worst) worst = mx
    if (p99[iv] > 33.4) bad++
  }
  / BG throttled=/ { bg++ }
  /in front on macOS/ { front++ }
  / STATS fps=/ { fps += field($0, "fps="); nf++ }
  / HITCH frame=/ {
    ms = field($0, " ms="); h++
    if (ms <= 34) b20++; else if (ms <= 50) b34++; else if (ms <= 100) b50++; else b100++
    # time inside DXMT calls this frame, presentwait (waiting for a drawable) apart
    split($0, parts, "dxmt\\(ms/calls\\): "); in_dxmt = 0; wait = 0
    c = split(parts[2], calls, " ")
    for (i = 1; i <= c; i++) { split(calls[i], kv, "[=/]"); if (kv[1] == "presentwait") wait += kv[2]; else in_dxmt += kv[2] }
    if (wait > ms / 2) hw++; else if (in_dxmt > ms / 2) hd++; else ho++
  }
  END {
    if (!iv) { print "FAIL no PACE lines (DXMT_STATS=1 off, or the game never presented)"; exit 1 }
    for (i = 2; i <= iv; i++) { v = p99[i]; for (j = i - 1; j > 0 && p99[j] > v; j--) p99[j + 1] = p99[j]; p99[j + 1] = v }   # macOS awk has no asort
    printf "frames=%d fps=%.1f over33=%d over50=%d (%.2f%%/%.2f%%) p99_median=%.1fms p99_over33=%d/%d intervals worst=%.0fms hitches=%d [20-34:%d 34-50:%d 50-100:%d >100:%d] (dxmt %d, drawable wait %d, outside dxmt %d) throttled_intervals=%d front_override=%d\n",
      n, nf ? fps / nf : 0, s33, s50, 100 * s33 / n, 100 * s50 / n, p99[int((iv + 1) / 2)], bad, iv, worst, h, b20, b34, b50, b100, hd, hw, ho, bg, front
  }'
