#!/bin/zsh
set -euo pipefail

repo="${0:A:h:h}"
version="0.9.0"
build_dir="${BUILD_DIR:-$repo/build}"
dist_dir="$repo/dist"
stage="$dist_dir/Fullteq-$version-macOS-universal"
zip_path="$dist_dir/Fullteq-$version-macOS-universal.zip"

cd "$repo"

cmake -B "$build_dir" -DCMAKE_BUILD_TYPE=Release -DFULLTEQ_INSTALL_PLUGINS=OFF
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

vst3="$build_dir/Fullteq_artefacts/Release/VST3/Fullteq.vst3"
au="$build_dir/Fullteq_artefacts/Release/AU/Fullteq.component"
standalone="$build_dir/Fullteq_artefacts/Release/Standalone/Fullteq.app"

for bundle in "$vst3" "$au" "$standalone"; do
  codesign --force --deep --sign - "$bundle"
  codesign --verify --deep --strict "$bundle"
done

for arch in arm64 x86_64; do
  lipo -archs "$vst3/Contents/MacOS/Fullteq" | grep -q "$arch"
done

rm -rf "$stage" "$zip_path"
mkdir -p "$stage"
ditto "$vst3" "$stage/Fullteq.vst3"
ditto "$au" "$stage/Fullteq.component"
ditto "$standalone" "$stage/Fullteq.app"

mkdir -p "$stage/docs" "$stage/Source/Fonts"
cp README.md MANUAL.md CHANGELOG.md LICENSE THIRD_PARTY_NOTICES.md "$stage/"
cp docs/fullteq-ui.png "$stage/docs/"
cp Source/Fonts/OFL.txt "$stage/Source/Fonts/"
cp docs/INSTALL.txt "$stage/INSTALL.txt"
cp scripts/install-fullteq.command "$stage/Install Fullteq.command"
cp scripts/uninstall-fullteq.command "$stage/Uninstall Fullteq.command"
chmod +x "$stage/Install Fullteq.command" "$stage/Uninstall Fullteq.command"

ditto -c -k --norsrc --noextattr --noqtn --keepParent "$stage" "$zip_path"
cd "$dist_dir"
shasum -a 256 "$(basename "$zip_path")" > SHA256SUMS.txt
cd "$repo"

print "Created $zip_path"
print "Created $dist_dir/SHA256SUMS.txt"
