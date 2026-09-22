#!/bin/zsh
set -euo pipefail

# Build the release app, then replace the installed copy in /Applications
# and relaunch it.

root_dir="${0:A:h}"
cd "$root_dir"
app_name="DisplayGate"
src="$root_dir/.build/DisplayGate.app"
dst="/Applications/DisplayGate.app"

# 1. Build (release) the .app bundle.
./build-app.sh

# 2. Kill the running app; escalate to SIGKILL if it does not quit.
pkill -x "$app_name" 2>/dev/null || true
for _ in {1..20}; do
    pgrep -x "$app_name" >/dev/null || break
    sleep 0.25
done
if pgrep -x "$app_name" >/dev/null; then
    pkill -9 -x "$app_name" || true
    sleep 0.5
fi

# 3. Install over the previous copy.
rm -rf "$dst"
cp -R "$src" "$dst"

# 4. Launch the installed app.
open "$dst"
echo "Installed and launched $dst"
