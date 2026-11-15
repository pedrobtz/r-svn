# sourced by sweep.sh: $1=N $2=SCRIPT $3=OUTDIR $4=EXPECTED
n=$1; script=$2; out=$3; expected=$4
d=$(mktemp -d)
env "${RENV_ARR[@]}" LD_PRELOAD="$FAILMALLOC" ALLOC_FAIL_AT=$n R_ENABLE_JIT=0 RDS_FILE="$RDS_FILE" \
  timeout 60 "$RX" --vanilla --no-echo -f "$script" >"$d/out" 2>"$d/err" </dev/null
rc=$?
if [ $rc -ge 124 ] || grep -q 'caught segfault\|irrecoverable\|Assertion' "$d/out" "$d/err"; then
  cls=CRASH
elif [ $rc -eq 0 ] && cmp -s "$d/out" "$expected"; then
  if [ -s "$d/err" ]; then cls=OK_WARN; else cls=OK; fi
elif [ $rc -eq 0 ]; then
  cls=WRONG
else
  cls=ERROR
fi
msg=$(cat "$d/err" "$d/out" | grep -m1 -E 'Error|Warning|warning|address|Assertion|could not|memory' | tr -d '\n' | cut -c1-200)
echo "$n $cls rc=$rc $msg"
if [ "$cls" != OK ]; then
  { echo "### alloc $n class $cls rc $rc"; echo "--- stdout"; cat "$d/out"; echo "--- stderr"; cat "$d/err"; } > "$out/runs/$n.txt"
fi
rm -rf "$d"
