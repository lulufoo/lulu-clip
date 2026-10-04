#!/bin/zsh
set -euo pipefail
WAIT="${0:A:h}/wait-png.sh"
ROOT=$(mktemp -d)
pid=""
trap '[[ -n ${pid:-} ]] && kill $pid 2>/dev/null || true; rm -rf "$ROOT"' EXIT

: > "$ROOT/old.png"
: > "$ROOT/listen.log"

"$WAIT" "$ROOT" 8 >"$ROOT/out.txt" 2>"$ROOT/err.txt" &
pid=$!

armed=0
for _ in {1..50}; do
  if [[ -f "$ROOT/arm" ]]; then
    armed=1
    break
  fi
  sleep 0.1
done
(( armed )) || {
  echo "FAIL: arm missing after snapshot"
  exit 1
}

sleep 0.4
if ! kill -0 $pid 2>/dev/null; then
  echo "FAIL: exited on old png"
  exit 1
fi

: > "$ROOT/new.png"
set +e
wait $pid
code=$?
set -e
pid=""
[[ $code -eq 0 ]] || {
  echo "FAIL: exit $code err=$(cat "$ROOT/err.txt")"
  exit 1
}
got=$(cat "$ROOT/out.txt")
[[ "$got" == "$ROOT/new.png" ]] || {
  echo "FAIL: got $got"
  exit 1
}

rm -f "$ROOT/arm" "$ROOT/new.png" "$ROOT/out.txt" "$ROOT/err.txt"
: > "$ROOT/listen.log"
"$WAIT" "$ROOT" 8 >"$ROOT/out.txt" 2>"$ROOT/err.txt" &
pid=$!
for _ in {1..50}; do
  [[ -f "$ROOT/arm" ]] && break
  sleep 0.1
done
print -r -- "capture failed cancelled" >>"$ROOT/listen.log"
set +e
wait $pid
code=$?
set -e
pid=""
[[ $code -eq 3 ]] || {
  echo "FAIL: cancel exit $code"
  exit 1
}

echo OK
