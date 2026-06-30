#!/bin/sh
set -e
cd "$(dirname "$0")"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
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
  if ! git stash pop; then
    echo "${RED}Conflict while restoring stash. Resolve these files then run 'git stash drop':${NC}"
    git diff --name-only --diff-filter=U
    exit 1
  fi
fi

echo "${GREEN}Restowing dotfiles...${NC}"
stow --restow --target="$HOME" home && echo "${GREEN}dotfiles are now active!${NC}"

if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    echo "${GREEN}Installing TPM...${NC}"
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi
