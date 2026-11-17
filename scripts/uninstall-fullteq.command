#!/bin/zsh
set -euo pipefail

print "This removes the current user's Fullteq VST3, AU, and Standalone app."
print -n "Continue? [y/N] "
read -r answer
if [[ "$answer" != [yY] ]]; then
  print "Cancelled."
  exit 0
fi

rm -rf "$HOME/Library/Audio/Plug-Ins/VST3/Fullteq.vst3"
rm -rf "$HOME/Library/Audio/Plug-Ins/Components/Fullteq.component"
rm -rf "$HOME/Applications/Fullteq.app"
print "Fullteq removed."
