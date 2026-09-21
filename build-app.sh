#!/bin/zsh
set -euo pipefail

root_dir="${0:A:h}"
cd "$root_dir"
export CLANG_MODULE_CACHE_PATH="$root_dir/.cache/clang"
export SWIFT_MODULECACHE_PATH="$root_dir/.cache/swift"

swift build -c release --product DisplayGate
bin_dir="$(swift build -c release --show-bin-path)"
a="$bin_dir/DisplayGate"
b="$root_dir/.build/DisplayGate.app/Contents"
rm -rf "$root_dir/.build/DisplayGate.app"
mkdir -p "$b/MacOS" "$b/Resources"
cp "$a" "$b/MacOS/DisplayGate"
cp "$root_dir/Assets/DisplayGate.icns" "$b/Resources/DisplayGate.icns"
cp "$root_dir/Resources/Info.plist" "$b/Info.plist"
codesign --force --sign - "$root_dir/.build/DisplayGate.app"

echo "Built $root_dir/.build/DisplayGate.app"
if [[ "${1:-}" == "--run" ]]; then
    open "$root_dir/.build/DisplayGate.app"
fi
