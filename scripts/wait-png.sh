#!/bin/zsh
set -euo pipefail
DIR="${1:-$HOME/.cache/lulu-clip}"
TIMEOUT="${2:-180}"
mkdir -p "$DIR"
LOG="$DIR/listen.log"
ARM="$DIR/arm"

# ⌘E stays dark until the old PNG list is frozen.
rm -f "$ARM"

typeset -A seen
for f in "$DIR"/*.png(N); do
  seen[$f]=1
done

log_offset=0
if [[ -f "$LOG" ]]; then
  log_offset=$(wc -c < "$LOG" | tr -d '[:space:]')
fi

touch "$ARM"

# Only *.png counts; LuluClip writes <name>.png.part then renames.
# After "edit begin" (user is annotating on screen) the timeout no longer applies.
editing=0
elapsed=0
while (( editing || elapsed < TIMEOUT )); do
  for f in "$DIR"/*.png(N); do
    if [[ -z ${seen[$f]+x} ]]; then
      echo "$f"
      exit 0
    fi
  done
  if [[ -f "$LOG" ]]; then
    size=$(wc -c < "$LOG" | tr -d '[:space:]')
    if (( size > log_offset )); then
      new=$(tail -c +$((log_offset + 1)) "$LOG")
      log_offset=$size
      if [[ "$new" == *"capture failed cancelled"* ]]; then
        rm -f "$ARM"
        echo "CANCELLED" >&2
        exit 3
      fi
      if [[ "$new" == *"edit begin"* ]]; then
        editing=1
      fi
    fi
  fi
  sleep 1
  (( ++elapsed ))
done
rm -f "$ARM"
echo "NO_NEW_FILE" >&2
exit 2
