#!/bin/bash
# Wrapper around halium-generic-adaptation-build-tools' build.sh.
#   ./build.sh            kernel + boot.img + device tarball
#   ./build.sh -k         kernel + boot.img only
set -xe

BUILD_DIR="$(pwd)/workdir"
TMPDOWN="$BUILD_DIR/downloads"

[ -d build ] || git clone https://gitlab.com/ubports/porting/community-ports/halium-generic-adaptation-build-tools build

# Build straight from the local kernel tree so edits there need no re-clone
mkdir -p "$TMPDOWN"
[ -e "$TMPDOWN/kernel-sanders" ] || ln -s "$HOME/ut-build/kernel-sanders" "$TMPDOWN/kernel-sanders"

# The 16M boot partition can't fit kernel + dt.img + the gzip Halium ramdisk,
# so recompress the ramdisk with xz (kernel has CONFIG_RD_XZ=y).
./build/build.sh -b "$BUILD_DIR" -c
RAMDISK="$TMPDOWN/halium-boot-ramdisk.img"
if gzip -t "$RAMDISK" 2>/dev/null; then
    gzip -dc "$RAMDISK" | xz --check=crc32 -9e > "$RAMDISK.xz"
    mv "$RAMDISK.xz" "$RAMDISK"
fi

# Git keeps only the exec bit; Android init skips group/world-writable .rc
# files, so normalise overlay permissions before packaging.
find overlay -type d -exec chmod 755 {} +
find overlay -type f -perm -u+x -exec chmod 755 {} +
find overlay -type f ! -perm -u+x -exec chmod 644 {} +

exec ./build/build.sh -b "$BUILD_DIR" "$@"
