#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${1:-4173}"

if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1024 || PORT > 65535 )); then
  echo "Usage: $0 [port 1024-65535]" >&2
  exit 2
fi

cd "$ROOT"
npm run build
echo
echo "LIS preview:   http://localhost:$PORT/"
echo "Lampa runtime: http://localhost:$PORT/lampa/"
echo "Press Ctrl+C to stop."
exec python3 -m http.server "$PORT" --directory "$ROOT/dist"
