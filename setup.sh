#!/usr/bin/env bash

set -euo pipefail

FZF_VERSION="0.67.0"
FD_VERSION="10.3.0"
RG_VERSION="15.1.0"
NVIM_VERSION="nightly"

TMPDIR=$(mktemp -d)
mkdir -p "$HOME/.config"
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.local/opt"

for url in "thibautvas/dotfiles/archive/refs/heads/main.tar.gz" \
           "junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-linux_amd64.tar.gz" \
           "sharkdp/fd/releases/download/v${FD_VERSION}/fd-v${FD_VERSION}-x86_64-unknown-linux-gnu.tar.gz" \
           "burntsushi/ripgrep/releases/download/${RG_VERSION}/ripgrep-${RG_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
           "neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-x86_64.tar.gz"
do
  curl -fsSL "https://github.com/$url" | tar -xz -C "$TMPDIR"
done

for dir in bash git nvim; do
  cp -r "$TMPDIR/dotfiles-main/$dir" "$HOME/.config"
done

ln -sf "$HOME/.config/bash/bashrc" "$HOME/.bashrc"

for bin in fzf fd rg; do
  find "$TMPDIR" -type f -name "$bin" -executable -exec cp {} "$HOME/.local/bin" \;
done

cp -r "$TMPDIR/nvim-linux-x86_64" "$HOME/.local/opt"
ln -s "$HOME/.local/opt/nvim-linux-x86_64/bin/nvim" "$HOME/.local/bin"
