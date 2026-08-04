#!/usr/bin/env bash
set -euo pipefail

version="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/ryanoasis/nerd-fonts/releases/latest)"
version="${version##*/}"
archive="$(mktemp --suffix=.zip)"
directory=/usr/share/fonts/jetbrains-mono-nerd-fonts
trap 'rm -f "$archive"' EXIT

curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/download/${version}/JetBrainsMono.zip" -o "$archive"
rm -rf "$directory"
mkdir -p "$directory"
unzip -q "$archive" '*.ttf' -d "$directory"
chmod 0644 "$directory"/*.ttf
fc-cache -f "$directory"
