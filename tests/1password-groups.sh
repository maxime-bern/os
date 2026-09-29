#!/usr/bin/env bash
set -euo pipefail

repository=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
podman run --rm --network none --pull never --security-opt label=disable \
    --mount "type=bind,source=$repository,target=/repo,readonly" \
    -i registry.fedoraproject.org/fedora-toolbox:44 bash -s <<'EOF'
set -euo pipefail

mkdir -p /usr/lib/opt/1Password
for binary in /usr/lib/opt/1Password/1Password-BrowserSupport /usr/lib/opt/1Password/1password-mcp /usr/bin/op; do
    touch "$binary"
done

groupadd --gid 1000 onepassword
groupadd --gid 1001 onepassword-mcp
groupadd --gid 1002 onepassword-cli
bash /repo/files/scripts/1password-groups.sh
bash /repo/files/scripts/1password-groups.sh

root=$(mktemp -d)
mkdir -p "$root/etc"
printf 'root:x:0:\nuser:x:1000:\n' > "$root/etc/group"
systemd-sysusers --root="$root" /repo/files/system/usr/lib/sysusers.d/1password.conf
while read -r type group gid; do
    grep -qx "$group:x:$gid:" "$root/etc/group"
    test "$(getent group "$group" | cut -d: -f3)" = "$gid"
done < /repo/files/system/usr/lib/sysusers.d/1password.conf

groupmod --gid 1600 onepassword
groupadd --gid 1500 conflicting-group
if bash /repo/files/scripts/1password-groups.sh; then
    exit 1
fi
printf '1Password group checks passed\n'
EOF
