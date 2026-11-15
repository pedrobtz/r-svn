#!/bin/bash
# sweep.sh NAME -- sweep every allocation the reproducer repro/NAME.R makes
set -u
here=$(cd "$(dirname "$0")" && pwd)
name=$1
script="$here/repro/$name.R"
out="$RESULTS/$name"
mkdir -p "$out/runs" "$out/gdb"
mapfile -t RENV_ARR < "$RENV_FILE"
export RENV_ARR_STR
run() { env "${RENV_ARR[@]}" "$@"; }

run LD_PRELOAD="$FAILMALLOC" ALLOC_COUNT_FILE="$out/floor" BASELINE=1 R_ENABLE_JIT=0 RDS_FILE="$RDS_FILE" \
  "$RX" --vanilla --no-echo -f "$script" >/dev/null 2>&1 </dev/null
run LD_PRELOAD="$FAILMALLOC" ALLOC_COUNT_FILE="$out/total" R_ENABLE_JIT=0 RDS_FILE="$RDS_FILE" \
  "$RX" --vanilla --no-echo -f "$script" >"$out/expected" 2>"$out/expected.err" </dev/null
floor=$(cat "$out/floor"); total=$(cat "$out/total")
start=$((floor - 40)); [ $start -lt 1 ] && start=1
end=$total; cap=${CAP:-4000}; [ $end -gt $((start + cap)) ] && end=$((start + cap))
echo "== $name: floor $floor total $total sweep $start..$end; expected: $(cat "$out/expected")"

# export array for the child via a file (bash arrays don't export)
export RX FAILMALLOC RDS_FILE RENV_FILE
seq $start $end | xargs -P "$(nproc)" -I{} bash -c 'mapfile -t RENV_ARR < "$RENV_FILE"; source "'"$here"'/one.sh.inc" {} "'"$script"'" "'"$out"'" "'"$out"'/expected"' > "$out/results.unsorted"
sort -n "$out/results.unsorted" > "$out/results.txt"; rm "$out/results.unsorted"
echo "-- class counts:"; awk '{print $2}' "$out/results.txt" | sort | uniq -c
for c in CRASH WRONG OK_WARN; do
  echo "-- $c positions: $(awk -v c=$c '$2==c{printf "%s ", $1}' "$out/results.txt")"
done
echo "-- distinct error messages:"; awk '$2=="ERROR"' "$out/results.txt" | cut -d' ' -f4- | sed 's/[0-9]\+ bytes/N bytes/' | sort | uniq -c | sort -rn | head -20
echo "-- WRONG/OK_WARN details:"; awk '$2=="WRONG"||$2=="OK_WARN"' "$out/results.txt" | head -20
for n in $(awk '$2=="WRONG"{print $1}' "$out/results.txt" | head -5); do echo "--- wrong output at $n:"; sed -n '1,12p' "$out/runs/$n.txt"; done

# gdb backtraces: crashes, plus WRONG positions break on nothing (just record)
k=0
for n in $(awk '$2=="CRASH"{print $1}' "$out/results.txt"); do
  k=$((k+1)); [ $k -gt ${GDB_MAX:-30} ] && break
  for m in $n $((n-1)) $((n+1)) $((n-2)) $((n+2)); do
    run gdb -batch -nx -ex 'set startup-with-shell off' -ex 'set pagination off' \
      -ex "set environment LD_PRELOAD $FAILMALLOC" -ex "set environment ALLOC_FAIL_AT $m" \
      -ex 'set environment R_ENABLE_JIT 0' -ex "set environment RDS_FILE $RDS_FILE" \
      -ex 'handle SIGPIPE nostop noprint' -ex run -ex bt -ex 'info frame' \
      --args "$RX" --vanilla --no-echo -f "$script" > "$out/gdb/$n.txt" 2>&1 </dev/null
    if grep -q '^Program received signal' "$out/gdb/$n.txt"; then
      echo "(gdb alloc used: $m)" >> "$out/gdb/$n.txt"; break
    fi
  done
done
echo "-- distinct crash sites (top 4 frames):"
for f in "$out"/gdb/*.txt; do
  [ -e "$f" ] || continue
  sig=$(grep -m1 '^Program received signal' "$f" | cut -c1-60)
  fr=$(grep -E '^#[0-9]+ ' "$f" | grep -v -E ' (raise|abort|__assert|__pthread_kill|__GI_|pthread_kill)' | head -4 | sed -E 's/^#[0-9]+ +(0x[0-9a-f]+ in )?//; s/ \(.*\) (at|from) / @ /' | tr '\n' ';')
  echo "$sig | $fr | $(basename $f .txt)"
done | sort | awk -F' \\| ' '{key=$1" | "$2; c[key]++; ex[key]=ex[key]" "$3} END{for(k in c) print c[k]"x  "k"  [allocs:"ex[k]"]"}'
