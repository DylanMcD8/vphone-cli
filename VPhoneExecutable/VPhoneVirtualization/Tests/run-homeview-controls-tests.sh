#!/bin/zsh
set -euo pipefail
tests=${0:a:h}
repo=${tests:h:h:h}
out="$repo/.build/homeview-controls-tests"
mkdir -p "$out"
xcrun --sdk macosx swiftc -swift-version 6 -strict-concurrency=complete -parse-as-library \
    "$tests:h/UI/UserInterface/Panels/HomeView/VPhoneHomeViewControlsModel.swift" \
    "$tests/HomeViewControlsTests.swift" -o "$out/HomeViewControlsTests"
"$out/HomeViewControlsTests"
