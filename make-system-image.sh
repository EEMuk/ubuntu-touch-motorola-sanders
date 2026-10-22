#!/bin/bash
# Build out/system.img from ota/ (prepare-fake-ota.sh) with an ext4 feature
# set the 3.18 kernel can mount. Needs root (loop mount), e.g.:
#   sudo ./make-system-image.sh
set -e
HERE="$(dirname "$(realpath "$0")")"
cd "$HERE"
export PATH="/usr/local/sbin:/usr/sbin:/sbin:$PATH"
export MKE2FS_CONFIG="$HERE/mke2fs-3.18.conf"

./build/system-image-from-ota.sh ota/ubuntu_command out

for f in metadata_csum metadata_csum_seed orphan_file; do
    if dumpe2fs -h out/rootfs.img 2>/dev/null | grep -q "features:.*\b$f\b"; then
        echo "ERROR: out/rootfs.img has $f, which 3.18 can't mount" >&2
        exit 1
    fi
done
[ -n "$SUDO_UID" ] && chown -R "$SUDO_UID:$SUDO_GID" out
echo "system.img OK for 3.18"
