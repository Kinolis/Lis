#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAMP_DIR="$ROOT/vendor/lampa-source"
OUTPUT="$ROOT/dist/lampa"
LOG_FILE="${TMPDIR:-/tmp}/lis-lampa-gulp.log"

if [[ ! -f "$LAMP_DIR/gulpfile.js" ]]; then
  echo "Lampa submodule is missing. Clone with --recurse-submodules." >&2
  exit 1
fi

cd "$LAMP_DIR"
npm install --no-audit --no-fund

# The upstream default Gulp task starts BrowserSync and watches files.
# Wait for its initial Rollup bundle, then stop the watcher cleanly.
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
mkdir -p "$OUTPUT"
cp -a build/github/lampa/. "$OUTPUT/"

# Ensure the standalone Lampa entry point and its essential assets are present.
test -s "$OUTPUT/index.html"
test -s "$OUTPUT/app.min.js"
test -d "$OUTPUT/css"
test -d "$OUTPUT/vender"

echo "Lampa web bundle copied to $OUTPUT"
