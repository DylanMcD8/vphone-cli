#!/bin/zsh
# vphone-tier: build
set -euo pipefail

if (( $# != 3 )); then
    print -u2 'Usage: PackageHomeViewApp.sh VPhone.bundle /absolute/VM/config.plist /output/HomeView.app'
    exit 2
fi
source_bundle=${1:a}
config=${2:a}
app=${3:a}
[[ -f "$config" && -x "$source_bundle/Contents/MacOS/vphone-vm" ]] || {
    print -u2 'The built bundle and existing machine config must exist.'
    exit 1
}
[[ "$app" == *.app && ! -e "$app" ]] || {
    print -u2 'Choose a new .app destination; existing files are never replaced.'
    exit 1
}
/usr/bin/codesign --verify --deep --strict "$source_bundle"
/usr/bin/ditto "$source_bundle" "$app"
info="$app/Contents/Info.plist"
/usr/bin/plutil -replace CFBundlePackageType -string APPL "$info"
/usr/bin/plutil -replace CFBundleExecutable -string vphone-vm "$info"
/usr/bin/plutil -replace CFBundleIdentifier -string com.vphone.homeview.simulator "$info"
/usr/bin/plutil -replace CFBundleName -string HomeView "$info"
/usr/bin/plutil -replace CFBundleDisplayName -string HomeView "$info"
/usr/bin/plutil -replace VPhoneDefaultMachineConfig -string "$config" "$info"
# Signing an APPL seals its main executable together with Info.plist. Keep
# exactly the VM's existing entitlements; no extra permissions are added.
/usr/bin/codesign --force --sign - \
    --entitlements "${0:a:h:h}/Resources/VPhoneVirtualization.entitlements" "$app"
/usr/bin/codesign --verify --deep --strict "$app"
"${0:a:h}/ValidateBundle.sh" "$app" --homeview-app
print -r -- "Packaged $app for $config"
print 'Run its vphone-cli host preflight before launching; the app signature may need allowlisting.'
