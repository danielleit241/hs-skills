#!/usr/bin/env bash
# Strip a chroma-key background from a Codex-generated image using the official
# upstream helper at $CODEX_HOME/skills/.system/imagegen/scripts/remove_chroma_key.py
# and validate that the result has an alpha channel.
#
# Usage:
#   codex-strip-chroma-key.sh <input.png> <output.png>
#
# Picks default flags documented in the upstream imagegen skill:
#   --auto-key border --soft-matte --transparent-threshold 12
#   --opaque-threshold 220 --despill

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <input.png> <output.png>" >&2
  exit 2
fi

IN="$1"
OUT="$2"
HELPER="${CODEX_HOME:-$HOME/.codex}/skills/.system/imagegen/scripts/remove_chroma_key.py"

[[ -f "$IN" ]] || { echo "input not found: $IN" >&2; exit 1; }
[[ -f "$HELPER" ]] || {
  echo "upstream helper missing: $HELPER" >&2
  echo "Install/update Codex CLI (>= 0.116) or set CODEX_HOME." >&2
  exit 1
}

mkdir -p "$(dirname "$OUT")"

echo "[codex] stripping chroma key: $IN -> $OUT"
python3 "$HELPER" \
  --input "$IN" \
  --out "$OUT" \
  --auto-key border \
  --soft-matte \
  --transparent-threshold 12 \
  --opaque-threshold 220 \
  --despill

if command -v identify >/dev/null; then
  channels=$(identify -format '%[channels]' "$OUT" 2>/dev/null || echo "?")
  case "$channels" in
    *a*) echo "[codex] OK: alpha channel present ($channels)" ;;
    *)   echo "[codex] WARNING: no alpha channel detected ($channels)" >&2; exit 1 ;;
  esac
else
  echo "[codex] note: ImageMagick 'identify' not found — skipping alpha validation"
fi
