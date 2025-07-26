#!/usr/bin/env bash

# By Fannndi & ChatGPT (Clang Android 15 - Final)
set -euo pipefail

# ===================== KONFIGURASI =====================
CLANG_VER="a15"
CLANG_URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-r536225.tar.gz"

KERNEL_NAME="${KERNEL_NAME:-MIUI-A10}"
DEFCONFIG="${DEFCONFIG:-surya_defconfig}"
BUILD_USER="fannndi"
BUILD_HOST="gitpod"

ARCH="arm64"
SUBARCH="arm64"
CACHE_DIR="$HOME/.cache/kernel_build"
CLANG_DIR="$CACHE_DIR/clang-${CLANG_VER}"

GCC64_REPO="https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git"
GCC32_REPO="https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git"
NDK_URL="https://dl.google.com/android/repository/android-ndk-r21e-linux-x86_64.zip"

BUILD_TIME=$(date '+%d%m%Y-%H%M')
ZIPNAME="${KERNEL_NAME}-Surya-${BUILD_TIME}.zip"
BUILD_START=$(date +%s)

# ===================== LOGGING =====================
LOGFILE="log.txt"
rm -f "$LOGFILE"
exec > >(tee -i "$LOGFILE") 2>&1
trap 'echo "[ERROR] Build failed. Check log.txt for full details."' ERR

# ===================== HELPER =====================
require_tools() {
    for tool in git wget tar unzip clang python3 zip; do
        command -v $tool >/dev/null 2>&1 || { echo "❌ Tool '$tool' tidak ditemukan!"; exit 1; }
    done
}

download_clang() {
    echo "==> Downloading Clang (Android 15)..."
    mkdir -p "$CLANG_DIR"
    local clang_tar="$CACHE_DIR/clang-${CLANG_VER}.tar.gz"
    if [[ ! -f "$clang_tar" ]]; then
        wget --show-progress -O "$clang_tar" "$CLANG_URL"
    fi
    rm -rf "$CLANG_DIR"/*
    tar -xf "$clang_tar" -C "$CLANG_DIR"
    echo "$CLANG_VER" > "$CLANG_DIR/clang.version"
}

prepare_clang() {
    local version_file="$CLANG_DIR/clang.version"
    if [[ -d "$CLANG_DIR" && -f "$version_file" ]] && [[ "$(cat "$version_file")" == "$CLANG_VER" ]]; then
        echo "==> Using cached Clang (Android 15)"
        return
    fi
    download_clang
}

prepare_toolchains() {
    echo "==> Preparing Toolchains (cache: $CACHE_DIR)"
    mkdir -p "$CACHE_DIR"
    prepare_clang

    # GCC 64-bit
    if [[ ! -d "$CACHE_DIR/gcc64" ]]; then
        echo "==> Cloning GCC64..."
        git clone --depth=1 -b lineage-17.1 "$GCC64_REPO" "$CACHE_DIR/gcc64"
    else
        echo "==> Using cached GCC64"
    fi

    # GCC 32-bit
    if [[ ! -d "$CACHE_DIR/gcc32" ]]; then
        echo "==> Cloning GCC32..."
        git clone --depth=1 -b lineage-17.1 "$GCC32_REPO" "$CACHE_DIR/gcc32"
    else
        echo "==> Using cached GCC32"
    fi

    # NDK
    if [[ ! -d "$CACHE_DIR/ndk" ]]; then
        echo "==> Downloading NDK..."
        wget -q "$NDK_URL" -O "$CACHE_DIR/ndk.zip"
        unzip -q "$CACHE_DIR/ndk.zip" -d "$CACHE_DIR"
        mv "$CACHE_DIR/android-ndk-r21e" "$CACHE_DIR/ndk"
        rm -f "$CACHE_DIR/ndk.zip"
    else
        echo "==> Using cached NDK"
    fi

    export PATH="$CLANG_DIR/bin:$CACHE_DIR/gcc64/bin:$CACHE_DIR/gcc32/bin:$CACHE_DIR/ndk/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH"
    clang --version || true
}

backup_config() {
    if [[ -f out/.config ]]; then
        cp out/.config .config.backup
        echo "==> Backup .config ke .config.backup"
    fi
}

restore_config() {
    if [[ ! -f out/.config && -f .config.backup ]]; then
        echo "==> Mengembalikan .config dari backup"
        mkdir -p out
        cp .config.backup out/.config
    fi
}

clean_output() {
    echo "==> Cleaning old build files..."
    backup_config
    make O=out clean || true
    rm -rf out/dtb.img out/dtbo.img out/arch/arm64/boot/Image.gz-dtb AnyKernel3 *.zip || true
    restore_config
}

make_defconfig() {
    echo "==> Running defconfig: $DEFCONFIG"
    make O=out ARCH=arm64 \
        CROSS_COMPILE=aarch64-linux-android- \
        CROSS_COMPILE_ARM32=arm-linux-androideabi- \
        CC=clang HOSTCC=clang HOSTCXX=clang++ \
        CLANG_TRIPLE=aarch64-linux-gnu- \
        LD=ld.lld LLVM=1 LLVM_IAS=1 \
        "$DEFCONFIG"
}

compile_kernel() {
    echo "==> Compiling kernel..."
    export CROSS_COMPILE=aarch64-linux-android-
    export CROSS_COMPILE_ARM32=arm-linux-androideabi-
    export CLANG_TRIPLE=aarch64-linux-gnu-
    export LD=ld.lld
    export MAKEFLAGS="-j$(nproc) -Oline"

    make O=out ARCH=arm64 CC=clang HOSTCC=clang HOSTCXX=clang++ \
        LLVM=1 LLVM_IAS=1 \
        KCFLAGS="-gdwarf-4 -U_FORTIFY_SOURCE -D__NO_FORTIFY -fno-stack-protector" \
        CFLAGS_KERNEL="-Wno-unused-but-set-variable -Wno-unused-variable -Wno-uninitialized" \
        Image.gz-dtb
}

build_dtb_dtbo() {
    echo "==> Building DTB & DTBO..."
    cat out/arch/arm64/boot/dts/**/*.dtb > out/dtb.img
    python3 tools/makedtboimg.py create out/dtbo.img out/arch/arm64/boot/dts/**/*.dtbo
}

package_anykernel() {
    echo "==> Packaging AnyKernel3..."
    rm -rf AnyKernel3
    git clone --depth=1 https://github.com/rinnsakaguchi/AnyKernel3 -b FSociety
    cp out/arch/arm64/boot/Image.gz-dtb AnyKernel3/
    cp out/dtb.img AnyKernel3/
    cp out/dtbo.img AnyKernel3/
    cd AnyKernel3 && zip -r9 "../${ZIPNAME}" . -x '*.git*' README.md *placeholder
    cd ..
    echo "Package created: ${ZIPNAME}"
}

# ===================== MAIN =====================
require_tools
prepare_toolchains
clean_output
make_defconfig
compile_kernel
build_dtb_dtbo
package_anykernel

echo "==> Build finished in $(( $(date +%s) - BUILD_START )) seconds."
