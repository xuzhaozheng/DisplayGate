#!/bin/zsh
set -euo pipefail

# Regenerates Assets/DisplayGateIcon.png and Assets/DisplayGate.icns from the
# SF Symbol source. The ICNS is built through a full PNG iconset so every size
# uses modern PNG entries (no legacy is32/il32 + mask formats).
root_dir="${0:A:h:h}"
cd "$root_dir"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
iconset="$tmp_dir/DisplayGate.iconset"
mkdir "$iconset"

swift Tools/make_displaygate_icon.swift Assets/DisplayGateIcon.png

sizes=("16:icon_16x16" "32:icon_16x16@2x" "32:icon_32x32" "64:icon_32x32@2x" \
    "128:icon_128x128" "256:icon_128x128@2x" "256:icon_256x256" "512:icon_256x256@2x" \
    "512:icon_512x512" "1024:icon_512x512@2x")
for spec in "${sizes[@]}"; do
    px="${spec%%:*}"
    name="${spec##*:}"
    sips -z "$px" "$px" Assets/DisplayGateIcon.png \
        --out "$iconset/${name}.png" >/dev/null
done

iconutil -c icns "$iconset" -o Assets/DisplayGate.icns
echo "Regenerated Assets/DisplayGateIcon.png and Assets/DisplayGate.icns"
