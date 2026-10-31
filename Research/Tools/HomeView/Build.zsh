#!/bin/zsh
set -euo pipefail

source_dir=${0:a:h}
repo_dir=${source_dir:h:h:h}
output_dir="$repo_dir/.build/HomeViewResearchTools"
mkdir -p "$output_dir"

xcrun --sdk appletvos clang -arch arm64e -mtvos-version-min=27.0 \
  -fobjc-arc -framework Foundation "$source_dir/HomeModularControl.m" \
  -o "$output_dir/home-modular-control"
codesign --force --sign - --entitlements "$source_dir/HomeModularControl.entitlements" \
  "$output_dir/home-modular-control"

xcrun --sdk appletvos clang -arch arm64e -mtvos-version-min=27.0 \
  -fobjc-arc -framework Foundation -framework CoreLocation \
  "$source_dir/HomeViewLocationControl.m" -o "$output_dir/homeview-location-control"
codesign --force --sign - --entitlements "$source_dir/HomeViewLocationControl.entitlements" \
  "$output_dir/homeview-location-control"

xcrun --sdk macosx clang -fobjc-arc -framework Foundation \
  -framework CoreGraphics -framework ImageIO "$source_dir/ExtractAssets.m" \
  -o "$output_dir/extract-homeview-assets"
xcrun --sdk macosx swiftc "$source_dir/RenderBackgroundColors.swift" \
  -o "$output_dir/render-homeview-colors"
print -r -- "Research tools built in $output_dir"
