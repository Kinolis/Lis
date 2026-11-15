#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAMP_DIR="$ROOT/vendor/lampa-source"
OUTPUT="$ROOT/dist"
LOG_FILE="${TMPDIR:-/tmp}/lis-lampa-gulp.log"

if [[ ! -f "$LAMP_DIR/gulpfile.js" ]]; then
  echo "Lampa submodule is missing. Clone with --recurse-submodules." >&2
  exit 1
fi

cd "$LAMP_DIR"
npm install --no-audit --no-fund

# Build the upstream bundle without leaving its watch server running.
npx gulp >"$LOG_FILE" 2>&1 &
gulp_pid=$!
cleanup() {
  kill "$gulp_pid" 2>/dev/null || true
  wait "$gulp_pid" 2>/dev/null || true
}
trap cleanup EXIT

built=0
for attempt in $(seq 1 90); do
  if [[ -s dest/app.js ]]; then
    first_size=$(wc -c < dest/app.js)
    sleep 2
    second_size=$(wc -c < dest/app.js)
    if [[ "$first_size" -gt 0 && "$first_size" -eq "$second_size" ]]; then
      built=1
      break
    fi
  fi
  sleep 1
done

if [[ "$built" -ne 1 ]]; then
  cat "$LOG_FILE" >&2
  echo "Timed out waiting for the upstream Lampa bundle." >&2
  exit 1
fi

cleanup
trap - EXIT
npx gulp pack_github

test -s build/github/lampa/index.html
test -s build/github/lampa/app.min.js

# Publish only the original Lampa web package at the site root.
rm -rf "$OUTPUT"
mkdir -p "$OUTPUT"
cp -a build/github/lampa/. "$OUTPUT/"

# Apply LIS welcome screen styling.
mkdir -p "$OUTPUT/css"
cp "$ROOT/branding/lis-theme.css" "$OUTPUT/css/lis-theme.css"
cp "$ROOT/branding/lis-fox.svg" "$OUTPUT/css/lis-fox.svg"
cp "$ROOT/branding/lis-fox.svg" "$OUTPUT/favicon.svg"
python3 - "$OUTPUT/index.html" <<'PY'
from pathlib import Path
import sys
index = Path(sys.argv[1])
html = index.read_text(encoding="utf-8")
link = '<link rel="stylesheet" href="css/lis-theme.css?v=8">'\nfavicon = '<link rel="icon" type="image/svg+xml" href="favicon.svg">'
if link not in html:
    html = html.replace("</head>", f"    {link}\\n</head>")
if favicon not in html:
    html = html.replace("</head>", f"    {favicon}\\n</head>")
index.write_text(html, encoding="utf-8")
PY

test -s "$OUTPUT/index.html"
test -s "$OUTPUT/app.min.js"
test -d "$OUTPUT/css"
test -d "$OUTPUT/vender"

echo "Original Lampa web bundle copied to $OUTPUT"
