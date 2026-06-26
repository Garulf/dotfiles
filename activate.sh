#!/bin/sh
set -e
cd "$(dirname "$0")"

# Colors
GREEN='\033[0;32m'
NC='\033[0m'

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Warning: uncommitted changes detected — stashing before pull"
  git stash
  STASHED=1
fi

echo "${GREEN}Pulling latest changes...${NC}"
git pull

if [ "${STASHED:-0}" = "1" ]; then
  echo "${GREEN}Restoring stashed changes...${NC}"
  git stash pop
fi

echo "${GREEN}Restowing dotfiles...${NC}"
stow --restow --target="$HOME" home && echo "${GREEN}dotfiles are now active!${NC}"

if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    echo "${GREEN}Installing TPM...${NC}"
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi
