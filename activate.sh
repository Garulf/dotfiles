#!/bin/sh
set -e
cd "$(dirname "$0")"

# Colors
GREEN='\033[0;32m'
NC='\033[0m'

echo "${GREEN}Pulling latest changes...${NC}"
git pull

echo "${GREEN}Restowing dotfiles...${NC}"
stow --restow home && echo "${GREEN}dotfiles are now active!${NC}"

if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    echo "${GREEN}Installing TPM...${NC}"
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi
