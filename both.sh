#!/bin/bash
# auto_resolve_both_added.sh
# Script untuk resolve konflik "both added" dengan memilih versi kita (yours).

echo "==> Mencari file dengan konflik 'both added'..."
git status | grep "both added:" | awk '{print $3}' > conflict_files.txt

if [ ! -s conflict_files.txt ]; then
    echo "Tidak ada file dengan konflik 'both added'."
    rm -f conflict_files.txt
    exit 0
fi

echo "==> Menyelesaikan konflik dengan memilih versi kita (yours)..."
while read -r file; do
    echo "   - Resolving: $file"
    git checkout --ours "$file"
    git add "$file"
done < conflict_files.txt

rm -f conflict_files.txt
echo "==> Semua konflik 'both added' telah diselesaikan (versi kita)."
