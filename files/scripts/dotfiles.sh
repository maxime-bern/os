#!/usr/bin/env bash
set -euo pipefail

dotfiles_dir=/etc/skel/.dotfiles

git clone --depth=1 https://gitlab.com/maximebern/dotfiles.git "$dotfiles_dir"
git -C "$dotfiles_dir" remote set-url origin git@gitlab.com:maximebern/dotfiles.git
stow --no-folding --adopt --dir="$dotfiles_dir" --target=/etc/skel .
