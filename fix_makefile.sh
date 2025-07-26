#!/bin/bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

if [[ ! -f Makefile ]]; then
  echo "❌ Makefile tidak ditemukan di $(pwd)"
  exit 1
fi

echo "🔍 Before:"
head -n 3 Makefile | cat -A || true

# Remove BOM
sed -i '1s/^\xEF\xBB\xBF//' Makefile
# Convert CRLF to LF
sed -i 's/\r$//' Makefile

echo "✅ After:"
head -n 3 Makefile | cat -A || true
