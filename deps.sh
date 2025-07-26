#!/usr/bin/env bash

# 📦 Kernel Build Dependencies Installer (v3.3-full)
# All-in-One: Gitpod, VPS, WSL, Android Builder
# By Fannndi & ChatGPT

set -euo pipefail

# ==================== WARNA TERMINAL ====================
GREEN='\033[1;32m'
RED='\033[1;31m'
BLUE='\033[1;34m'
NC='\033[0m'

# ==================== DETEKSI SISTEM ====================
echo -e "${BLUE}🔍 Mendeteksi sistem...${NC}"
ARCH=$(uname -m)
DISTRO=$(lsb_release -ds 2>/dev/null || grep -oP '(?<=^NAME=).+' /etc/os-release | tr -d '"' || echo "Unknown")
echo -e "${BLUE}🖥️  Arsitektur : ${GREEN}${ARCH}${NC}"
echo -e "${BLUE}🧩 Distro     : ${GREEN}${DISTRO}${NC}"

# ==================== CEK SUDO & APT ====================
if ! command -v sudo &>/dev/null; then
  echo -e "${RED}❌ 'sudo' tidak tersedia. Jalankan sebagai root atau install sudo.${NC}"
  exit 1
fi

if ! command -v apt-get &>/dev/null; then
  echo -e "${RED}❌ Sistem ini tidak menggunakan APT. Script ini hanya mendukung Debian/Ubuntu.${NC}"
  exit 1
fi

# ==================== APT UPDATE ====================
echo -e "${BLUE}🔄 Memperbarui database APT...${NC}"
sudo apt-get update -y

# ==================== INSTALASI DEPENDENCIES ====================
echo -e "${BLUE}📦 Menginstal dependencies kernel build...${NC}"
sudo apt-get install -y --no-install-recommends \
  build-essential \
  make \
  bc \
  bison \
  flex \
  libssl-dev \
  libelf-dev \
  libncurses5-dev \
  libncursesw5-dev \
  libzstd-dev \
  lz4 \
  zstd \
  xz-utils \
  liblz4-tool \
  pigz \
  cpio \
  lzop \
  python3 \
  python3-pip \
  python-is-python3 \
  python2 \
  python3-mako \
  python3-virtualenv \
  clang \
  llvm \
  gcc-9 \
  g++-9 \
  gcc-aarch64-linux-gnu \
  device-tree-compiler \
  libfdt-dev \
  libudev-dev \
  abootimg \
  android-sdk-libsparse-utils \
  curl \
  wget \
  git \
  zip \
  unzip \
  rsync \
  nano \
  jq \
  ccache \
  kmod \
  ninja-build \
  patchutils \
  binutils \
  cmake \
  gettext \
  protobuf-compiler \
  libxml2-utils \
  lsb-release \
  openssl

# ==================== VERIFIKASI TOOLS ====================
echo -e "${BLUE}🔍 Verifikasi tools penting...${NC}"
REQUIRED_TOOLS=(
  bc
  make
  curl
  git
  zip
  python3
  clang
  lz4
  zstd
  dtc
  cpio
)

for tool in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "$tool" &>/dev/null; then
    echo -e "${RED}❌ Tool '${tool}' tidak ditemukan setelah instalasi.${NC}"
    exit 1
  fi
done

# ==================== CLEANUP ====================
echo -e "${BLUE}🧹 Membersihkan cache APT...${NC}"
sudo apt-get autoremove -y
sudo apt-get clean

# ==================== DONE ====================
echo -e "${GREEN}✅ Semua dependencies berhasil diinstal dan diverifikasi!${NC}"