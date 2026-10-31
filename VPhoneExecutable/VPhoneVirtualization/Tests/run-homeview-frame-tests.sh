#!/bin/zsh
set -euo pipefail

tests=${0:a:h}
repo=${tests:h:h:h}
out="$repo/.build/homeview-frame-tests"
mkdir -p "$out"
xcrun --sdk macosx swiftc -swift-version 6 -strict-concurrency=complete -parse-as-library \
    "$tests:h/UI/VirtualMachine/VPhoneHomeViewFrame.swift" \
    "$repo/VPhoneKit/VPhoneCoreKit/VirtualMachine/VPhoneDisplayGeometry.swift" \
    "$tests/HomeViewFrameTests.swift" -o "$out/HomeViewFrameTests"
"$out/HomeViewFrameTests" "$tests:h/Resources/HomeView Device Frame.png"
