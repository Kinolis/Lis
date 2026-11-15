#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAMP_DIR="$ROOT/vendor/lampa-source"
OUTPUT="$ROOT/dist"
LOG_FILE="${TMPDIR:-/tmp}/lampa-gulp.log"

if [[ ! -f "$LAMP_DIR/gulpfile.js" || ! -f "$LAMP_DIR/package.json" ]]; then
  echo "Original Lampa submodule is missing. Clone with --recurse-submodules." >&2
  exit 1
fi

cd "$LAMP_DIR"
npm install --no-package-lock --no-audit --no-fund

# Run the upstream Gulp watcher only to generate the source bundle.
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
  echo "Timed out waiting for the original Lampa bundle." >&2
  exit 1
fi

cleanup
trap - EXIT

# Use the upstream packaging task without patching its source or output.
npx gulp pack_github

SOURCE="$LAMP_DIR/build/github/lampa"
test -s "$SOURCE/index.html"
test -s "$SOURCE/app.min.js"
test -d "$SOURCE/css"
test -d "$SOURCE/vender"

rm -rf "$OUTPUT"
mkdir -p "$OUTPUT"
cp -a "$SOURCE/." "$OUTPUT/"

test -s "$OUTPUT/index.html"
test -s "$OUTPUT/app.min.js"
echo "Built the unmodified upstream Lampa package into $OUTPUT"
