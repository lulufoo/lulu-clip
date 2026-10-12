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

# edit begin disables the timeout; .png.part is ignored
rm -f "$ROOT/arm" "$ROOT/out.txt" "$ROOT/err.txt"
: > "$ROOT/listen.log"
"$WAIT" "$ROOT" 2 >"$ROOT/out.txt" 2>"$ROOT/err.txt" &
pid=$!
for _ in {1..50}; do
  [[ -f "$ROOT/arm" ]] && break
  sleep 0.1
done
print -r -- "edit begin" >>"$ROOT/listen.log"
: > "$ROOT/edit.png.part"
sleep 4
if ! kill -0 $pid 2>/dev/null; then
  echo "FAIL: exited during edit err=$(cat "$ROOT/err.txt") out=$(cat "$ROOT/out.txt")"
  exit 1
fi
mv "$ROOT/edit.png.part" "$ROOT/edit.png"
set +e
wait $pid
code=$?
set -e
pid=""
[[ $code -eq 0 && "$(cat "$ROOT/out.txt")" == "$ROOT/edit.png" ]] || {
  echo "FAIL: edit exit $code out=$(cat "$ROOT/out.txt")"
  exit 1
}

# cancel during edit still exits 3
rm -f "$ROOT/arm" "$ROOT/out.txt" "$ROOT/err.txt"
: > "$ROOT/listen.log"
"$WAIT" "$ROOT" 2 >"$ROOT/out.txt" 2>"$ROOT/err.txt" &
pid=$!
for _ in {1..50}; do
  [[ -f "$ROOT/arm" ]] && break
  sleep 0.1
done
print -r -- "edit begin" >>"$ROOT/listen.log"
sleep 3
print -r -- "capture failed cancelled" >>"$ROOT/listen.log"
set +e
wait $pid
code=$?
set -e
pid=""
[[ $code -eq 3 ]] || {
  echo "FAIL: edit cancel exit $code"
  exit 1
}

# timeout still applies without edit begin
rm -f "$ROOT/arm" "$ROOT/out.txt" "$ROOT/err.txt"
: > "$ROOT/listen.log"
set +e
"$WAIT" "$ROOT" 1 >/dev/null 2>&1
code=$?
set -e
[[ $code -eq 2 ]] || {
  echo "FAIL: timeout exit $code"
  exit 1
}

echo OK
