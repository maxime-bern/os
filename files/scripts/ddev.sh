#!/usr/bin/env bash
set -euo pipefail

case "$(uname -m)" in
    x86_64) arch=amd64 ;;
    aarch64) arch=arm64 ;;
    *)
        printf 'Unsupported architecture: %s\n' "$(uname -m)" >&2
        exit 1
        ;;
esac

version="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/ddev/ddev/releases/latest)"
version="${version##*/v}"
archive="$(mktemp)"
trap 'rm -f "$archive"' EXIT

curl -fsSL "https://github.com/ddev/ddev/releases/download/v${version}/ddev_linux-${arch}.v${version}.tar.gz" -o "$archive"
tar -xzf "$archive" -C /usr/bin ddev ddev-hostname mkcert
