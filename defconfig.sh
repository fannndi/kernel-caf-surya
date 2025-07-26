#!/bin/bash
set -euo pipefail

# Konfigurasi path
OUT_DIR="out"
DEFCONFIG="arch/arm64/configs/surya_defconfig"
CONFIG_FILE="$OUT_DIR/.config"
BACKUP="${DEFCONFIG}.bak.$(date +%s)"

# Warna
RED="\033[0;31m"
GRN="\033[0;32m"
YEL="\033[1;33m"
NC="\033[0m"

# Validasi
[[ ! -f "$DEFCONFIG" ]] && {
  echo -e "${RED}❌ Defconfig tidak ditemukan: $DEFCONFIG${NC}"
  exit 1
}

echo -e "${YEL}🧹 Menghapus folder $OUT_DIR/...${NC}"
rm -rf "$OUT_DIR"

echo -e "${YEL}📦 Membuat ulang .config dari $DEFCONFIG...${NC}"
make -s O="$OUT_DIR" ARCH=arm64 surya_defconfig

echo -e "${YEL}🔄 Menjalankan make olddefconfig...${NC}"
make -s O="$OUT_DIR" ARCH=arm64 olddefconfig

# Bersihkan semua backup lama
echo -e "${YEL}🗑️ Menghapus backup lama...${NC}"
rm -f "${DEFCONFIG}".bak.*

# Backup sebelum menimpa
echo -e "${YEL}🛡️ Backup defconfig lama ke: $BACKUP${NC}"
cp "$DEFCONFIG" "$BACKUP"

# Timpa defconfig dengan versi terbaru
cp "$CONFIG_FILE" "$DEFCONFIG"
echo -e "${GRN}✅ Defconfig diperbarui di: $DEFCONFIG${NC}"

# Tambahkan ke .gitignore jika belum ada
if [[ ! -f .gitignore ]] || ! grep -qxF "$OUT_DIR/" .gitignore; then
  echo "$OUT_DIR/" >> .gitignore
  echo -e "${GRN}📌 Menambahkan $OUT_DIR/ ke .gitignore${NC}"
fi

# Bersihkan out setelah selesai
rm -rf "$OUT_DIR"
echo -e "${YEL}🧽 Folder $OUT_DIR dibersihkan.${NC}"

echo -e "${GRN}🎉 Selesai! Defconfig berhasil diregenerasi dan dibackup.${NC}"