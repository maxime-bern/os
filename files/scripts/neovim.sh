#!/usr/bin/env bash
set -euo pipefail

case "$(uname -m)" in
    x86_64) arch=x86_64 ;;
    aarch64) arch=arm64 ;;
    *)
        printf 'Unsupported architecture: %s\n' "$(uname -m)" >&2
        exit 1
        ;;
esac

version="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/neovim/neovim/releases/latest)"
version="${version##*/v}"
archive="$(mktemp)"
trap 'rm -f "$archive"' EXIT

curl -fsSL "https://github.com/neovim/neovim/releases/download/v${version}/nvim-linux-${arch}.tar.gz" -o "$archive"
rm -rf /usr/lib/neovim
mkdir -p /usr/lib/neovim
tar -xzf "$archive" -C /usr/lib/neovim --strip-components=1
ln -sf /usr/lib/neovim/bin/nvim /usr/bin/nvim

npm install --global --prefix /usr tree-sitter-cli
npm cache clean --force