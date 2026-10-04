#!/bin/zsh
set -euo pipefail
DIR="${1:-$HOME/.cache/lulu-clip}"
TIMEOUT="${2:-180}"
mkdir -p "$DIR"

typeset -A seen
for f in "$DIR"/*.png(N); do
  seen[$f]=1
done

for _ in $(seq 1 "$TIMEOUT"); do
  for f in "$DIR"/*.png(N); do
    if [[ -z ${seen[$f]+x} ]]; then
      echo "$f"
      exit 0
    fi
  done
  sleep 1
done
rm -f "$DIR/arm"
echo "NO_NEW_FILE" >&2
exit 2
