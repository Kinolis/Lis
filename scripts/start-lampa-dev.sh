#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAMP_DIR="$ROOT/vendor/lampa-source"

if ! command -v git >/dev/null 2>&1; then
  echo "Ошибка: нужен git." >&2
  exit 1
fi
if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  echo "Ошибка: установите Node.js и npm (рекомендуется Node.js LTS)." >&2
  exit 1
fi

git -C "$ROOT" submodule update --init --recursive vendor/lampa-source

if [[ ! -f "$LAMP_DIR/package.json" ]]; then
  echo "Ошибка: исходники Lampa не найдены в $LAMP_DIR." >&2
  exit 1
fi

cd "$LAMP_DIR"
if [[ ! -d node_modules ]]; then
  echo "Устанавливаю зависимости оригинальной Lampa..."
  npm install
fi

echo "Запускаю оригинальную Lampa в режиме разработки (Gulp/BrowserSync)."
echo "Это локальный тестовый сервер; LIS и production-сайт не изменяются."
npm run start
