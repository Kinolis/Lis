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

# Package the upstream Lampa client without modifying its source.
npx gulp pack_github

SOURCE="$LAMP_DIR/build/github/lampa"
test -s "$SOURCE/index.html"
test -s "$SOURCE/app.min.js"
test -d "$SOURCE/css"
test -d "$SOURCE/vender"

rm -rf "$OUTPUT"
mkdir -p "$OUTPUT"
cp -a "$SOURCE/." "$OUTPUT/"

# Add the LIS welcome-screen skin as a separate layer; keep upstream files intact.
mkdir -p "$OUTPUT/branding"
cp "$ROOT/branding/lis-language.css" "$OUTPUT/branding/lis-language.css"
cp "$ROOT/branding/lis-fox.svg" "$OUTPUT/branding/lis-fox.svg"

# Always rasterize the vector master into a clean, transparent, high-resolution PNG.
# This avoids shipping the old 128x128 PNG, which produced visible pixel/strip artifacts.
python3 -m pip install --quiet --user --disable-pip-version-check CairoSVG
python3 - "$ROOT/branding/lis-fox.svg" "$OUTPUT/branding/lis-fox.png" <<'PY'
from pathlib import Path
import sys
import cairosvg
import struct

source, target = map(Path, sys.argv[1:])
cairosvg.svg2png(url=str(source), write_to=str(target), output_width=512, output_height=512)
data = target.read_bytes()
if data[:8] != b"\\x89PNG\\r\\n\\x1a\\n":
    raise SystemExit("LIS icon generation did not produce a PNG")
width, height = struct.unpack(">II", data[16:24])
if (width, height) != (512, 512):
    raise SystemExit(f"Unexpected LIS PNG dimensions: {width}x{height}")
print(f"Generated clean LIS icon: {width}x{height}, {len(data)} bytes")
PY

python3 - "$OUTPUT/index.html" <<'PY'
from pathlib import Path
import sys
import re

index = Path(sys.argv[1])
html = index.read_text(encoding="utf-8")
html, title_count = re.subn(r"<title>.*?</title>", "<title>LIS</title>", html, count=1, flags=re.IGNORECASE | re.DOTALL)
if title_count == 0:
    if "</head>" not in html:
        raise SystemExit("Could not find </head> to add the LIS page title")
    html = html.replace("</head>", "<title>LIS</title>\\n</head>", 1)

branding = [
    ('./branding/lis-fox.png', '<link rel="icon" type="image/png" href="./branding/lis-fox.png">'),
    ('apple-touch-icon', '<link rel="apple-touch-icon" sizes="512x512" href="./branding/lis-fox.png">'),
    ('apple-mobile-web-app-title', '<meta name="apple-mobile-web-app-title" content="LIS">'),
    ('name="application-name"', '<meta name="application-name" content="LIS">'),
    ('name="description"', '<meta name="description" content="LIS — фильмы и сериалы в одном месте">'),
    ('./branding/lis-language.css', '<link rel="stylesheet" href="./branding/lis-language.css">'),
]
need = [tag for marker, tag in branding if marker not in html]
if need:
    if "</head>" not in html:
        raise SystemExit("Could not find </head> in packaged Lampa index.html")
    html = html.replace("</head>", "\\n".join(need) + "\\n</head>", 1)
index.write_text(html, encoding="utf-8")
PY

test -s "$OUTPUT/index.html"
test -s "$OUTPUT/app.min.js"
test -s "$OUTPUT/branding/lis-language.css"
test -s "$OUTPUT/branding/lis-fox.svg"
test -s "$OUTPUT/branding/lis-fox.png"
grep -q 'branding/lis-language.css' "$OUTPUT/index.html"
echo "Built original Lampa with the isolated LIS language-screen skin into $OUTPUT"
