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

# Make the image releasable: modules_install leaves build/source symlinks to
# the builder's kernel tree, and the journal and free blocks still hold data
# from the build. Drop the links, then zero free space under a fresh journal
# (which also makes the image compress well).
MNT=$(mktemp -d)
tune2fs -O ^has_journal out/rootfs.img >/dev/null
mount -o loop out/rootfs.img "$MNT"
rm -f "$MNT"/usr/lib/modules/*/build "$MNT"/usr/lib/modules/*/source
dd if=/dev/zero of="$MNT/zero.fill" bs=4M status=none 2>/dev/null || true
rm -f "$MNT/zero.fill"
sync
umount "$MNT"
rmdir "$MNT"
tune2fs -O has_journal -J size=64 out/rootfs.img >/dev/null
e2fsck -fy out/rootfs.img >/dev/null || [ $? -le 1 ]

for f in metadata_csum metadata_csum_seed orphan_file; do
    if dumpe2fs -h out/rootfs.img 2>/dev/null | grep -q "features:.*\b$f\b"; then
        echo "ERROR: out/rootfs.img has $f, which 3.18 can't mount" >&2
        exit 1
    fi
done
[ -n "$SUDO_UID" ] && chown -R "$SUDO_UID:$SUDO_GID" out
echo "system.img OK for 3.18"
