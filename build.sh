#!/usr/bin/env bash

# By Fannndi & ChatGPT — Final Clang Android 15 Kernel Build Script (Surya)
set -euo pipefail

# ===================== DETEKSI ENVIRONMENT =====================
if [[ "${GITPOD_REPO_ROOT:-}" != "" ]]; then
    CI_ENV="gitpod"
elif [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    CI_ENV="github"
else
    CI_ENV="local"
fi

echo "==> Environment terdeteksi: $CI_ENV"

# ===================== KONFIGURASI =====================
CLANG_VER="a15"
CLANG_URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-r536225.tar.gz"
NDK_URL="https://dl.google.com/android/repository/android-ndk-r21e-linux-x86_64.zip"
GCC64_REPO="https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git"
GCC32_REPO="https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git"

KERNEL_NAME="${KERNEL_NAME:-MIUI-A10}"
DEFCONFIG="${DEFCONFIG:-surya_defconfig}"
BUILD_USER="${BUILD_USER:-fannndi}"
BUILD_HOST="${BUILD_HOST:-$CI_ENV}"

ARCH="arm64"
SUBARCH="arm64"
export ARCH SUBARCH

CACHE_DIR="$HOME/.cache/kernel_build"
CLANG_DIR="$CACHE_DIR/clang-${CLANG_VER}"
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
    local missing=false
    for tool in git wget tar unzip clang python3 zip; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo "❌ Tool '$tool' tidak ditemukan!"
            missing=true
        fi
    done
    if [[ "$missing" == "true" ]]; then
        echo "Silakan install tool yang belum ada terlebih dahulu."
        exit 1
    fi
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

    export PATH="$CLANG_DIR/bin:$CACHE_DIR/ndk/toolchains/llvm/prebuilt/linux-x86_64/bin:$CACHE_DIR/gcc64/bin:$CACHE_DIR/gcc32/bin:$PATH"
    export CROSS_COMPILE=aarch64-linux-android-
    export CROSS_COMPILE_ARM32=arm-linux-androideabi-
    export CLANG_TRIPLE=aarch64-linux-gnu-

    # Gunakan binutils dari NDK r21e
    BINUTILS="$CACHE_DIR/ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/"
    export AS=${BINUTILS}aarch64-linux-android-as
    export LD=${BINUTILS}aarch64-linux-android-ld
    export AR=${BINUTILS}aarch64-linux-android-ar
    export NM=${BINUTILS}aarch64-linux-android-nm
    export OBJCOPY=${BINUTILS}aarch64-linux-android-objcopy
    export OBJDUMP=${BINUTILS}aarch64-linux-android-objdump
    export STRIP=${BINUTILS}aarch64-linux-android-strip

    echo "==> Clang in use: $(which clang)"
    clang --version || true
}

clean_output() {
    echo "==> Cleaning old build files..."
    mkdir -p out

    # Backup .config jika ada
    if [[ -f out/.config ]]; then
        cp out/.config .config.backup
        echo "==> Backup .config ke .config.backup"
    fi

    # Bersihkan konfigurasi kernel
    make O=out mrproper || true

    # Hapus file output umum
    rm -f dtb.img dtbo.img
    rm -rf AnyKernel3 *.zip

    # Hapus file DTB/DTBO secara aman jika ada
    if [ -d out/arch/arm64/boot/dts ]; then
        find out/arch/arm64/boot/dts -type f \( -name "*.dtb" -o -name "*.dtbo" \) -delete
    fi

    # Restore .config jika ada backup
    if [[ -f .config.backup ]]; then
        cp .config.backup out/.config
        echo "==> Restore .config dari .config.backup"
    fi
}

make_defconfig() {
    echo "==> Running defconfig: $DEFCONFIG"
    make O=out "$DEFCONFIG"
}

compile_kernel() {
    echo "==> Compiling kernel..."
    make -j$(nproc) O=out \
        CC=clang \
        HOSTCC=clang HOSTCXX=clang++ \
        LD="$LD" AR="$AR" NM="$NM" \
        OBJCOPY="$OBJCOPY" OBJDUMP="$OBJDUMP" \
        STRIP="$STRIP" READELF=llvm-readelf OBJSIZE=llvm-size \
        LLVM=1 LLVM_IAS=1 \
        KBUILD_BUILD_USER="$BUILD_USER" \
        KBUILD_BUILD_HOST="$BUILD_HOST" \
        KCFLAGS="-gdwarf-4 -U_FORTIFY_SOURCE -D__NO_FORTIFY -fno-stack-protector" \
        CFLAGS_KERNEL="-Wno-unused-but-set-variable -Wno-unused-variable -Wno-uninitialized" \
        Image.gz-dtb

    [[ -f out/arch/arm64/boot/Image.gz-dtb ]] || {
        echo "❌ Build gagal: Image.gz-dtb tidak ditemukan"
        exit 1
    }
}

build_dtb_dtbo() {
    echo "==> Building DTB & DTBO..."
    find out/arch/arm64/boot/dts -type f -name '*.dtb' -exec cat {} + > out/dtb.img

    if [[ -x tools/makedtboimg.py ]]; then
        DTBO_FILES=$(find out/arch/arm64/boot/dts -type f -name '*.dtbo')
        if [[ -n "$DTBO_FILES" ]]; then
            python3 tools/makedtboimg.py create out/dtbo.img $DTBO_FILES
        else
            echo "⚠️  No DTBO files found, skipping dtbo.img"
        fi
    else
        echo "⚠️  tools/makedtboimg.py not found or not executable, skipping dtbo.img"
    fi
}

package_anykernel() {
    echo "==> Packaging AnyKernel3..."
    rm -rf AnyKernel3
    git clone --depth=1 https://github.com/rinnsakaguchi/AnyKernel3 -b FSociety
    cp out/arch/arm64/boot/Image.gz-dtb AnyKernel3/
    cp out/dtb.img AnyKernel3/
    [[ -f out/dtbo.img ]] && cp out/dtbo.img AnyKernel3/
    cd AnyKernel3 && zip -r9 "../${ZIPNAME}" . -x '*.git*' README.md *placeholder
    cd ..
    echo "✅ Package created: ${ZIPNAME}"
}

# ===================== MAIN =====================
require_tools
prepare_toolchains
clean_output
make_defconfig
compile_kernel
build_dtb_dtbo
package_anykernel

echo "✅ Build finished in $(( $(date +%s) - BUILD_START )) seconds."
