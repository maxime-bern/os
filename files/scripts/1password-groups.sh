#!/usr/bin/env bash
set -euo pipefail

while read -r group gid binary; do
    groupmod --gid "$gid" "$group"
    chown "root:$group" "$binary"
    chmod 2755 "$binary"
    test "$(stat -c '%u:%g:%a' "$binary")" = "0:$gid:2755"
done <<'EOF'
onepassword 1500 /usr/lib/opt/1Password/1Password-BrowserSupport
onepassword-mcp 1501 /usr/lib/opt/1Password/1password-mcp
onepassword-cli 1502 /usr/bin/op
EOF
