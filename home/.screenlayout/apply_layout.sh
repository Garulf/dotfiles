#!/bin/sh

HOSTNAME="$(hostname)"

# detect if directory named after hostname exists

echo "Looking for layout for $HOSTNAME"

if [ -d "$HOME/.screenlayout/$HOSTNAME" ]; then
  echo "Applying layout for $HOSTNAME"
  sh "$HOME/.screenlayout/$HOSTNAME/default.sh"
fi
