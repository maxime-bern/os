#!/usr/bin/env bash
set -euo pipefail

case "$(uname -m)" in
    x86_64) arch=x86_64 ;;
    aarch64) arch=aarch64 ;;
    *)
        printf 'Unsupported architecture: %s\n' "$(uname -m)" >&2
        exit 1
        ;;
esac

version="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/stablyai/orca/releases/latest)"
version="${version##*/v}"
package="$(mktemp --suffix=.rpm)"
trap 'rm -f "$package"' EXIT

curl -fsSL "https://github.com/stablyai/orca/releases/download/v${version}/orca-ide-${version}.${arch}.rpm" -o "$package"
dnf5 install --assumeyes "$package"

python3 -m pip install --break-system-packages --no-cache-dir --prefix /usr "headroom-ai[proxy]"

npm install --global --prefix /usr --ignore-scripts @colbymchenry/codegraph @earendil-works/pi-coding-agent
npm cache clean --force
