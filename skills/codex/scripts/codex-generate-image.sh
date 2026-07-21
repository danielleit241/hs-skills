#!/usr/bin/env bash
# Generate image(s) via Codex (GPT-5.4 Image 2) and move them from
# ~/.codex/generated_images/<session>/ into the target output directory.
#
# Usage:
#   codex-generate-image.sh "<prompt>" [out-dir]
#
# Defaults out-dir to ./assets.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 \"<prompt>\" [out-dir]" >&2
  exit 2
fi

PROMPT="$1"
OUT_DIR="${2:-./assets}"
CODEX_IMG_DIR="${CODEX_HOME:-$HOME/.codex}/generated_images"

mkdir -p "$OUT_DIR"

# Snapshot existing sessions + CWD pngs so we can detect anything new
before=$(ls -1 "$CODEX_IMG_DIR" 2>/dev/null | sort || true)
before_cwd=$(find "$PWD" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) 2>/dev/null | sort)

# Auto-prepend the $imagegen skill invocation if the user didn't already use it.
# This routes Codex to the bundled official imagegen skill for consistent behavior.
case "$PROMPT" in
  *'$imagegen'*) ;;
  *) PROMPT="Use \$imagegen skill. $PROMPT" ;;
esac

echo "[codex] generating image(s) -> $OUT_DIR"
codex exec --full-auto --skip-git-repo-check -C "$PWD" "$PROMPT" </dev/null

after=$(ls -1 "$CODEX_IMG_DIR" 2>/dev/null | sort || true)
new_sessions=$(comm -13 <(echo "$before") <(echo "$after") || true)

# Catch any images Codex may have written directly to CWD via workspace-write
after_cwd=$(find "$PWD" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) 2>/dev/null | sort)
new_cwd=$(comm -13 <(echo "$before_cwd") <(echo "$after_cwd") || true)

if [[ -z "$new_sessions" && -z "$new_cwd" ]]; then
  echo "[codex] WARNING: no new images detected (neither in $CODEX_IMG_DIR nor CWD)" >&2
  echo "[codex] Codex may have refused or errored. Check output above." >&2
  exit 1
fi

moved=0
# Move CWD-written images first
while IFS= read -r f; do
  [[ -z "$f" || ! -f "$f" ]] && continue
  base=$(basename "$f")
  target="$OUT_DIR/$base"
  [[ -e "$target" && "$f" != "$target" ]] && target="$OUT_DIR/cwd-${base}"
  if [[ "$f" != "$target" ]]; then
    mv "$f" "$target"
    echo "[codex] moved (from CWD): $target"
    moved=$((moved + 1))
  fi
done <<< "$new_cwd"
while IFS= read -r session; do
  [[ -z "$session" ]] && continue
  src_dir="$CODEX_IMG_DIR/$session"
  [[ ! -d "$src_dir" ]] && continue
  for f in "$src_dir"/*; do
    [[ -e "$f" ]] || continue
    base=$(basename "$f")
    target="$OUT_DIR/$base"
    # avoid clobber
    if [[ -e "$target" ]]; then
      target="$OUT_DIR/${session}-${base}"
    fi
    mv "$f" "$target"
    echo "[codex] moved: $target"
    moved=$((moved + 1))
  done
  rmdir "$src_dir" 2>/dev/null || true
done <<< "$new_sessions"

if [[ $moved -eq 0 ]]; then
  echo "[codex] WARNING: new session(s) created but contained no files" >&2
  exit 1
fi

echo "[codex] done. $moved file(s) in $OUT_DIR"
