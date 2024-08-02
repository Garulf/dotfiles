#!/bin/sh

git pull
stow home --adopt && echo "dotfiles are now active!"
