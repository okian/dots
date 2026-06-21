#!/bin/sh
# essentials bootstrap — installs chezmoi and applies this repo.
#
# Usage (from a fresh machine):
#   sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply github.com/okian/essentials
#
# Or, if you've cloned the repo locally:
#   ./bootstrap.sh
set -eu

REPO="${ESSENTIALS_REPO:-github.com/okian/essentials}"

# Ensure curl exists (Linux minimal images sometimes lack it).
if ! command -v curl >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -y && sudo apt-get install -y curl ca-certificates
  fi
fi

if command -v chezmoi >/dev/null 2>&1; then
  exec chezmoi init --apply "$REPO"
else
  # Installs chezmoi to ~/.local/bin and runs init --apply in one shot.
  exec sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply "$REPO"
fi
