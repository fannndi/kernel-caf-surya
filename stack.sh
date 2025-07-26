#!/bin/bash

# Set default vars
DEFCONFIG=surya_defconfig
ARCH=arm64
OUT_DIR=out

echo ">>> Generating base defconfig..."
make O=$OUT_DIR ARCH=$ARCH $DEFCONFIG

echo ">>> Disabling STACKPROTECTOR..."
scripts/config --file $OUT_DIR/.config --disable CONFIG_CC_STACKPROTECTOR
scripts/config --file $OUT_DIR/.config --enable CONFIG_CC_STACKPROTECTOR_NONE
scripts/config --file $OUT_DIR/.config --disable CONFIG_CC_STACKPROTECTOR_REGULAR
scripts/config --file $OUT_DIR/.config --disable CONFIG_CC_STACKPROTECTOR_STRONG

echo ">>> Running olddefconfig to apply changes..."
make O=$OUT_DIR ARCH=$ARCH olddefconfig

echo ">>> Copying new config to $DEFCONFIG..."
cp $OUT_DIR/.config arch/arm64/configs/$DEFCONFIG

echo ">>> Updating .gitignore if needed..."
GITIGNORE_FILE=".gitignore"

add_gitignore_entry() {
    local entry="$1"
    if ! grep -Fxq "$entry" "$GITIGNORE_FILE"; then
        echo "$entry" >> "$GITIGNORE_FILE"
        echo "    -> Added '$entry' to .gitignore"
    else
        echo "    -> '$entry' already in .gitignore"
    fi
}

touch "$GITIGNORE_FILE"
add_gitignore_entry "out/"
add_gitignore_entry "*.old"
add_gitignore_entry "*.orig"
add_gitignore_entry "*.rej"

echo ">>> Done! Config updated and .gitignore patched."