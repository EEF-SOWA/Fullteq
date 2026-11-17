#!/bin/zsh
set -euo pipefail

root="${0:A:h}"

for bundle in Fullteq.vst3 Fullteq.component Fullteq.app; do
  if [[ ! -e "$root/$bundle" ]]; then
    print -u2 "Missing $bundle in the release folder."
    exit 1
  fi
done

print "Fullteq installs for the current user only."
print "Existing Fullteq plug-ins and app will be replaced."
print -n "Continue? [y/N] "
read -r answer
if [[ "$answer" != [yY] ]]; then
  print "Cancelled."
  exit 0
fi

vst_dir="$HOME/Library/Audio/Plug-Ins/VST3"
au_dir="$HOME/Library/Audio/Plug-Ins/Components"
app_dir="$HOME/Applications"
mkdir -p "$vst_dir" "$au_dir" "$app_dir"

rm -rf "$vst_dir/Fullteq.vst3" "$au_dir/Fullteq.component" "$app_dir/Fullteq.app"
ditto "$root/Fullteq.vst3" "$vst_dir/Fullteq.vst3"
ditto "$root/Fullteq.component" "$au_dir/Fullteq.component"
ditto "$root/Fullteq.app" "$app_dir/Fullteq.app"

print "Installed Fullteq 0.9.0 beta."
print "This build is unsigned. See INSTALL.txt if macOS blocks it."
