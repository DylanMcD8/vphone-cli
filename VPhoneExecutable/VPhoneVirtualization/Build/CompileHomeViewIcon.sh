#!/bin/zsh
# vphone-tier: build
set -euo pipefail

source_dir=${0:a:h:h}/Resources
bundle=${1:?Pass the VPhone.bundle path}
resources="$bundle/Contents/Resources"
icon_name='HomeView Simulator'
partial=$(mktemp -t homeview-icon)
trap '/bin/rm -f "$partial"' EXIT
/bin/mkdir -p "$resources"
/usr/bin/xcrun actool "$source_dir/$icon_name.icon" \
    --compile "$resources" --platform macosx --minimum-deployment-target 15.0 \
    --app-icon "$icon_name" --output-partial-info-plist "$partial"
for key in CFBundleIconFile CFBundleIconName; do
    value=$(/usr/bin/plutil -extract "$key" raw -o - "$partial")
    /usr/bin/plutil -replace "$key" -string "$value" "$bundle/Contents/Info.plist"
done
