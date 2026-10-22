#!/bin/bash
# Wrapper around halium-generic-adaptation-build-tools' build.sh.
#   ./build.sh            kernel + boot.img + device tarball
#   ./build.sh -k         kernel + boot.img only
set -xe

BUILD_DIR="$(pwd)/workdir"

[ -d build ] || git clone https://gitlab.com/ubports/porting/community-ports/halium-generic-adaptation-build-tools build

# Build straight from the local kernel tree so edits there need no re-clone
mkdir -p "$BUILD_DIR/downloads"
[ -e "$BUILD_DIR/downloads/kernel-sanders" ] || ln -s "$HOME/ut-build/kernel-sanders" "$BUILD_DIR/downloads/kernel-sanders"

exec ./build/build.sh -b "$BUILD_DIR" "$@"
