#!/bin/zsh
set -euo pipefail

repo="${0:A:h:h}"
build_dir="${BUILD_DIR:-$repo/build}"

cd "$repo"
mkdir -p "$repo/dist"

cmake -B "$build_dir" -DCMAKE_BUILD_TYPE=Release -DFULLTEQ_INSTALL_PLUGINS=ON
cmake --build "$build_dir" --target FullteqTests Fullteq_VST3 Fullteq_AU Fullteq_Standalone --parallel 4

"$build_dir/FullteqTests_artefacts/Release/FullteqTests"

pluginval_bin="${PLUGINVAL:-}"
if [[ -z "$pluginval_bin" ]] && command -v pluginval >/dev/null 2>&1; then
  pluginval_bin="$(command -v pluginval)"
fi
if [[ -z "$pluginval_bin" && -x /Applications/pluginval.app/Contents/MacOS/pluginval ]]; then
  pluginval_bin=/Applications/pluginval.app/Contents/MacOS/pluginval
fi
if [[ -z "$pluginval_bin" ]]; then
  print -u2 "pluginval is required. Install it with: brew install --cask pluginval"
  exit 1
fi
"$pluginval_bin" --strictness-level 10 --validate "$build_dir/Fullteq_artefacts/Release/VST3/Fullteq.vst3"
auval -v aufx Fteq EEFL

"$build_dir/FullteqTests_artefacts/Release/FullteqTests" --snapshot "$repo/dist/fullteq-ui.png" 1

vst3="$build_dir/Fullteq_artefacts/Release/VST3/Fullteq.vst3"
for arch in arm64 x86_64; do
  lipo -archs "$vst3/Contents/MacOS/Fullteq" | grep -q "$arch"
done
codesign --force --deep --sign - "$vst3"
codesign --verify --deep --strict "$vst3"

print "All local macOS release gates passed."
