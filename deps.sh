#!/usr/bin/env bash

# Kernel Build Dependencies Installer (All-in-One)
# Supports: Gitpod (22.04), GitHub Actions (24.04), VPS, WSL
set -euo pipefail

# ==================== WARNA TERMINAL ====================
GREEN='\033[1;32m'
RED='\033[1;31m'
BLUE='\033[1;34m'
NC='\033[0m'

# ==================== DETEKSI LINGKUNGAN ====================
echo -e "${BLUE}🔍 Mendeteksi lingkungan & OS...${NC}"

IS_GITPOD=false
IS_GITHUB=false

if [[ "${GITPOD_REPO_ROOT:-}" != "" || -d "/workspace" ]]; then
  IS_GITPOD=true
elif [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  IS_GITHUB=true
fi

ARCH=$(uname -m)
DISTRO=$(grep -oP '(?<=^NAME=).+' /etc/os-release | tr -d '"')
UBUNTU_VERSION=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"')

echo -e "${BLUE}🖥️  Arsitektur : ${GREEN}${ARCH}${NC}"
echo -e "${BLUE}🧩 Distro     : ${GREEN}${DISTRO}${NC} (Ubuntu ${UBUNTU_VERSION})"

if $IS_GITPOD; then
  echo -e "${BLUE}🌐 Mode       : ${GREEN}Gitpod (Ubuntu 22.04)${NC}"
elif $IS_GITHUB; then
  echo -e "${BLUE}🌐 Mode       : ${GREEN}GitHub Actions (Ubuntu 24.04)${NC}"
else
  echo -e "${BLUE}🌐 Mode       : ${GREEN}Manual/Local${NC}"
fi

# ==================== CEK SUDO & APT ====================
if ! command -v sudo &>/dev/null; then
  echo -e "${RED}❌ 'sudo' tidak tersedia. Jalankan sebagai root atau install sudo.${NC}"
  exit 1
fi

if ! command -v apt-get &>/dev/null; then
  echo -e "${RED}❌ Sistem ini tidak menggunakan APT. Script ini hanya mendukung Debian/Ubuntu.${NC}"
  exit 1
fi

# ==================== UPDATE & UPGRADE APT ====================
echo -e "${BLUE}🔄 Memperbarui database APT...${NC}"
sudo DEBIAN_FRONTEND=noninteractive apt-get update -y

echo -e "${BLUE}⬆️  Meng-upgrade paket yang tersedia...${NC}"
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# ==================== DAFTAR PAKET DASAR ====================
COMMON_PKGS=(
  build-essential make bc bison flex libssl-dev libelf-dev
  libncurses5-dev libncursesw5-dev libzstd-dev lz4 zstd xz-utils
  liblz4-tool pigz cpio lzop python3 python3-pip python-is-python3
  python3-mako python3-virtualenv clang llvm device-tree-compiler
  libfdt-dev libudev-dev abootimg android-sdk-libsparse-utils
  curl wget git zip unzip rsync nano jq ccache kmod ninja-build
  patchutils binutils cmake gettext protobuf-compiler libxml2-utils
  lsb-release libstdc++-10-dev openssl
)

# ==================== TAMBAHAN OPSIONAL BERDASARKAN OS ====================
EXTRA_PKGS=()
if [[ "$UBUNTU_VERSION" == "22.04" ]]; then
  EXTRA_PKGS+=(gcc-9 g++-9 gcc-aarch64-linux-gnu)
elif [[ "$UBUNTU_VERSION" == "24.04" ]]; then
  EXTRA_PKGS+=(gcc g++) # gcc-9 deprecated
else
  EXTRA_PKGS+=(gcc g++)
fi

# ==================== INSTALASI ====================
echo -e "${BLUE}📦 Menginstal dependencies kernel build...${NC}"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  "${COMMON_PKGS[@]}" "${EXTRA_PKGS[@]}"

# ==================== VERIFIKASI TOOLS ====================
echo -e "${BLUE}🔍 Verifikasi tools penting...${NC}"
REQUIRED_TOOLS=( bc make curl git zip python3 clang lz4 zstd dtc cpio jq rsync unzip gcc )

MISSING=0
for tool in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "$tool" &>/dev/null; then
    echo -e "${RED}❌ Tool '${tool}' tidak ditemukan setelah instalasi.${NC}"
    MISSING=1
  fi
done

if [[ "$MISSING" -eq 1 ]]; then
  echo -e "${RED}❌ Beberapa tools tidak ditemukan. Pastikan instalasi berhasil.${NC}"
  exit 1
fi

# ==================== CLEANUP ====================
echo -e "${BLUE}🧹 Membersihkan cache APT...${NC}"
sudo apt-get autoremove -y
sudo apt-get clean

# ==================== DONE ====================
echo -e "${GREEN}✅ Semua dependencies berhasil diinstal dan diverifikasi!${NC}"
