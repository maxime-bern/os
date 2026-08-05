#!/usr/bin/env bash
set -euo pipefail

config=/etc/niri/config.kdl
include='include "noctalia.kdl"'

install -Dm0644 /usr/share/doc/niri/default-config.kdl "$config"
sed -i '/^[[:space:]]*spawn-at-startup "waybar"[[:space:]]*$/d' "$config"
printf '\n%s\n' "$include" >> "$config"
