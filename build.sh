#!/bin/bash
# Wrapper around halium-generic-adaptation-build-tools' build.sh.
#   ./build.sh            kernel + boot.img + device tarball
#   ./build.sh -k         kernel + boot.img only
set -xe

BUILD_DIR="$(pwd)/workdir"
TMPDOWN="$BUILD_DIR/downloads"

[ -d build ] || git clone https://gitlab.com/ubports/porting/community-ports/halium-generic-adaptation-build-tools build

# Don't record the builder's user and host name in the kernel version, or
# the build directory in __FILE__ strings (WARN/BUG messages) and debug info
export KBUILD_BUILD_USER=ubports KBUILD_BUILD_HOST=sanders
export KCFLAGS="-fmacro-prefix-map=$TMPDOWN/= -fdebug-prefix-map=$TMPDOWN/="

# Optional: build from a local kernel checkout (KERNEL_DIR) instead of
# cloning deviceinfo_kernel_source, so local edits need no push/re-clone
mkdir -p "$TMPDOWN"
KERNEL_NAME=$(sed -n 's/^deviceinfo_kernel_source="\(.*\)"/\1/p' deviceinfo)
KERNEL_NAME=$(basename "${KERNEL_NAME%.git}")
if [ -n "$KERNEL_DIR" ] && [ ! -e "$TMPDOWN/$KERNEL_NAME" ]; then
    ln -s "$KERNEL_DIR" "$TMPDOWN/$KERNEL_NAME"
fi

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

./build/build.sh -b "$BUILD_DIR" "$@"

# modules_install adds build/source links to the kernel tree on the build
# machine; they are useless on the device and leak the builder's paths
for t in out/device_*.tar.xz; do
    [ -f "$t" ] || continue
    xz -dc "$t" | tar --delete --wildcards -f - \
        'system/usr/lib/modules/*/build' 'system/usr/lib/modules/*/source' \
        | xz -T0 -9 > "$t.tmp"
    mv "$t.tmp" "$t"
done
