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

# LIS-managed plugin preload: persist selected extensions before Lampa initializes.
# Kinopoisk Ratings requires the companion Kinopoisk authorization plugin.
python3 - "$LAMP_DIR/src/core/plugins.js" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text(encoding="utf-8")
s = s.replace("black_list.push('bylampa.github.io')", "// LIS: allow only the explicitly selected CUB-off plugin from this host")
old = "puts = puts.filter(p=>p.toLowerCase().indexOf(b) == -1)"
new = "puts = puts.filter(p=>p.toLowerCase().indexOf(b) == -1 || p === 'https://bylampa.github.io/cub_off.js')"
if old not in s:
    raise SystemExit("Could not locate Lampa plugin blacklist filter; refusing unsafe patch")
s = s.replace(old, new)
p.write_text(s, encoding="utf-8")
PY

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

# Apply LIS welcome screen styling and preload approved plugins.
mkdir -p "$OUTPUT/css"
python3 - "$OUTPUT/index.html" <<'PY'
from pathlib import Path
import sys
index = Path(sys.argv[1])
html = index.read_text(encoding="utf-8")
bootstrap = """<script>
(function(){
  var plugins = [
    'https://lampaplugins.github.io/store/logo.js',
    'https://bylampa.github.io/cub_off.js',
    'https://xiaomishka.github.io/lampa/ads.js',
    'https://and7ey.github.io/lampa/kinopoisk.js',
    'https://and7ey.github.io/lampa/kinopoisk_rating.js'
  ];
  try {
    var current = JSON.parse(localStorage.getItem('plugins') || '[]');
    if (!Array.isArray(current)) current = [];
    plugins.forEach(function(url) {
      if (!current.some(function(item) { return (typeof item === 'string' ? item : item.url) === url; })) {
        current.push({url:url, status:1, name:'LIS extension'});
      }
    });
    localStorage.setItem('plugins', JSON.stringify(current));
  } catch (e) { console.warn('LIS plugin preload failed', e); }
})();
</script>"""
if "LIS plugin preload failed" not in html:
    html = html.replace("</head>", bootstrap + "\n</head>")
index.write_text(html, encoding="utf-8")
PY
cp "$ROOT/branding/lis-theme.css" "$OUTPUT/css/lis-theme.css"
cp "$ROOT/branding/lis-fox.png" "$OUTPUT/css/lis-fox.png"
cp "$ROOT/branding/lis-fox.png" "$OUTPUT/lis-fox.png"
python3 - "$OUTPUT/index.html" <<'PY'
from pathlib import Path
import sys
index = Path(sys.argv[1])
html = index.read_text(encoding="utf-8")
link = '<link rel="stylesheet" href="css/lis-theme.css?v=37">' 
favicon = '<link rel="icon" type="image/png" href="lis-fox.png">'
if link not in html:
    html = html.replace("</head>", f"    {link}\n</head>")
if favicon not in html:
    html = html.replace("</head>", f"    {favicon}\n</head>")
index.write_text(html, encoding="utf-8")
PY

test -s "$OUTPUT/index.html"
test -s "$OUTPUT/app.min.js"
test -d "$OUTPUT/css"
test -d "$OUTPUT/vender"

echo "Original Lampa web bundle copied to $OUTPUT"
