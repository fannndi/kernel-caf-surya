#!/bin/bash
set -euo pipefail

echo "🔍 Mencari konflik di file penting (Makefile, *.c, *.h, *.mk)..."
conflict_files=$(grep -rE '^(<<<<<<<|=======|>>>>>>>)' \
    --include='Makefile' \
    --include='*.c' \
    --include='*.h' \
    --include='*.mk' \
    . || true)

if [[ -z "$conflict_files" ]]; then
  echo "✅ Tidak ada konflik di file penting."
  exit 0
fi

echo "⚠️ Ditemukan konflik di file:"
echo "$conflict_files"
echo

# Fix konflik (ambil ours)
for file in $conflict_files; do
  echo "🛠️ Memperbaiki konflik di: $file (mengambil versi ours)"
  if git ls-files --error-unmatch "$file" &>/dev/null; then
    git checkout --ours "$file" || true
  fi

  # Jika masih ada marker, hapus manual
  sed -i '/^<<<<<<< /,/^>>>>>>> /d' "$file"
done

# Stage dan commit
echo "📌 Menambahkan file ke staging..."
git add $conflict_files
echo "✅ File ditambahkan."

echo "💾 Membuat commit..."
git commit -m "Auto fix merge conflicts (ours)"
echo "🎉 Konflik berhasil diperbaiki dan sudah di-commit."
