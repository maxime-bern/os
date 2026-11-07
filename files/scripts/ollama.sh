#!/usr/bin/env bash
set -euo pipefail

version=v0.40.0
sha256=c94aa4156b3d13e64ebc2efe5ea53f015384c882be776e6695cfb37fb180d5ad

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL --retry 3 -o "$tmp/ollama.tar.zst" "https://github.com/ollama/ollama/releases/download/$version/ollama-linux-amd64.tar.zst"
printf '%s  %s\n' "$sha256" "$tmp/ollama.tar.zst" | sha256sum -c -
tar --zstd -xf "$tmp/ollama.tar.zst" -C /usr
test -x /usr/bin/ollama
