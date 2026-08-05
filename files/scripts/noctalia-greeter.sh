#!/usr/bin/env bash
set -euo pipefail

archive=$(mktemp --suffix=.tar.gz)
source=$(mktemp -d)
trap 'rm -rf "$archive" "$source"' EXIT

curl -fsSL https://github.com/noctalia-dev/noctalia-greeter/archive/refs/tags/v1.1.0.tar.gz -o "$archive"
tar -xzf "$archive" -C "$source" --strip-components=1
meson setup "$source/build" "$source" --prefix=/usr --buildtype=plain
meson compile -C "$source/build"
meson install -C "$source/build"
/usr/share/noctalia-greeter/setup_greetd_pam.sh
