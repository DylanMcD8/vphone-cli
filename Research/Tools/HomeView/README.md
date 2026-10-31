# HomeView research tools

These are the source helpers used with the HomeView 27.2 (24V514) research
guest. They are separate from the shipped VPhone bundle. Build them on the
Mac with Xcode 27:

```sh
zsh Research/Tools/HomeView/Build.zsh
```

The outputs go to `.build/HomeViewResearchTools`, which is ignored by Git.

## Native HomeView app and icon

The core build remains `VPhone.bundle` for existing CLI and Launchpad workflows.
For a standard Dock icon with the system-rendered Icon Composer appearances,
package a separate `HomeView.app` after building the bundle:

```sh
zsh VPhoneExecutable/VPhoneVirtualization/Build/PackageHomeViewApp.sh \
  .build/XcodeBundle/Build/Products/Debug/VPhone.bundle \
  "$HOME/HomeView-OS/data/machines/HomeView/config.plist" \
  "$HOME/HomeView-OS/HomeView.app"
```

Use your actual machine config path and a new output destination. The script
copies the application code and resources, not the VM disk. It records the local
config path in the app's Info.plist, so double-clicking opens that existing VM.
Explicit CLI arguments override the default. Do not redistribute this locally
configured app as a portable VM or commit its machine path to Git.

Run the app's `Contents/MacOS/vphone-cli host preflight`. If it reports an AMFI
block, the owner must run the exact administrator allowlist command it prints.
The application signature includes its Info.plist, so signing the `.app`
requires fresh authorization even if the preceding core bundle was allowed.
Stop an existing instance of the same VM before opening the app. Its CLI tools
remain in `Contents/MacOS`, so existing launch scripts can point there too.

The native app leaves `NSApplication.applicationIconImage` and the Dock tile
untouched: macOS renders `Assets.car` directly, without the nameplate or a
flattened image override. The original Icon Composer document is retained in
`VPhoneExecutable/VPhoneVirtualization/Resources/HomeView Simulator.icon`.

## Location Services

`homeview-location-control` uses the native `CLLocationManager` Settings API
with locationd’s authorization entitlement. It runs only inside the patched
tvOS guest; it does not change this Mac’s location settings or automatically
grant individual apps location permission.

Push the built helper to `/var/tmp/homeview-location-control` with mode `755`.
Record the original state before explicitly enabling the guest’s switch:

```js
print(proc.run('/var/tmp/homeview-location-control', ['status']));
print(proc.run('/var/tmp/homeview-location-control', ['enable']));
```

Check exit status and `enabled: true`. Then use the emulator’s location panel,
or call `location.set` with `{"latitude":37.3349,"longitude":-122.009,"altitude":30}`
for a simulated Cupertino location. `location.current` must return those
coordinates with `simulated: true`; a successful setter alone is insufficient.
This was verified on HomeView 27.2 (24V514). Location permission does not repair
Weather’s service authentication or supply a physical GPS receiver.

To undo, call `location.clear`; if the switch was originally off, run the helper
with `disable`. Location simulation may need to be reapplied after a guest
restart. The helper’s `status` action is read-only, and `enable` is idempotent.

## Personal Content for a local demo profile

`homeview-personal-content` reads or changes the native UserProfiles Personal
Content setting for an explicitly supplied profile UUID. It neither creates
profiles nor authenticates an Apple Account. Push the helper into the guest
with mode `755`, then use its `status`, `enable`, or `disable` action:

```js
print(proc.run('/var/tmp/homeview-personal-content', ['status', '<local demo profile UUID>']));
print(proc.run('/var/tmp/homeview-personal-content', ['enable', '<local demo profile UUID>']));
```

Record the original value before enabling it. The helper uses
`UPUpdateProfileRequest` and explicitly requests the Personal Content setting
when reading it back. The lightweight `allProfilesWithError:` inventory omits
settings, so its null values do not establish that the setting is off.
Successful enable/disable operations verify the stored Boolean. Recognition
and paired-device/network requirements remain separate; enabling this does
not provide reminder, calendar, or message data.

## Restoring Home Modular gallery samples

The saved Home Modular presets contain Apple's gallery tile data. An actual
HomeKit home can replace those tiles after the face loads, even when
`HFEnablePressDemoModeKey` and `demoModeTypeV2` are off. A screenshot taken during
that loading interval is insufficient verification.

For the locally created demo-home experiment, preserve the face store and
export/backup the owned demo home first. Removing only that identified local
demo home through `HMHomeManager` restored the original sample tiles without
rewriting face configurations. Verify that the home inventory is empty and
that the sample tiles remain after loading. Do not remove other homes or clear
HomeKit databases as a general setup step. The lamp/camera experiment is not
enabled by this repository's standard installation.

## AirPlay video

[`TVAirPlay.plist`](TVAirPlay.plist) is a guest preference override for the
case where pairing succeeds but video leaves HomeView on its clock. Follow
the [AirPlay findings and reversible installation steps](../../Guest/homeview_airplay.md);
merge existing overrides and reboot the guest. This template is not installed
by `Build.zsh` or the firmware preset automatically.

## Installing Home Modular without the gallery

The Home app already contains `com.apple.Home.HomeFace`. The stalled face
gallery can be bypassed by asking `PRSService` to create and select its saved
configuration. This does not patch the face binary or enable global retail
demo mode.

Copy `home-modular-control` into the guest at `/var/tmp/home-modular-control`,
make it executable, and run it through vphoned's `script.eval` interface:

```js
print(proc.run('/var/tmp/home-modular-control', ['list']));
```

Before adding a face, record the current selection and back up the
`PRBPosterExtensionDataStore` directory in PosterBoard's data container.
The container UUID is specific to each VM; do not reuse another VM's path.

Create either the normal face or Apple's populated nine-tile sample:

```js
print(proc.run('/var/tmp/home-modular-control', ['create', 'default-color-1']));
print(proc.run('/var/tmp/home-modular-control', ['create', 'HomeControlFace-featured8']));
```

Each successful create returns a new configuration UUID. Repeating it creates
another face. Use the returned UUID to select it:

```js
print(proc.run('/var/tmp/home-modular-control', ['select', '<returned UUID>']));
```

Check the JSON `error` field as well as the process result: this diagnostic
helper's asynchronous callbacks report service errors in JSON. The `active`
and `list` actions are read-only. Selecting the previously recorded UUID
restores the former face without deleting anything.

The helper uses the guest mobile UID 501 and narrowly scoped PosterBoard
service entitlements. It is intended for this already-patched research guest,
not stock Apple hardware or execution on the Mac.

### Additional built-in faces

`AdditionalFaces.json` records 14 additional descriptors present in the tested
firmware: Home Camera, Photos Clock, Photos Memories, four- and six-tile Home
Modular samples, hourly/daily Weather, and Calendar, analog/digital/dimensional
clock, Flow, Snoopy, and widget presets. Use the explicit provider action:

```js
print(proc.run('/var/tmp/home-modular-control', [
  'create-provider', 'com.apple.Home.CameraFace', 'HomeCameraFace'
]));
```

Check the existing provider/descriptor pairs before creating entries to avoid
duplicates. Creation can automatically select the new face: record and restore
the previous selection after a batch. Do not overwrite existing configuration
directories. The local batch added 14 entries to the existing 10, and all 76
original configuration files remained byte-identical. The prior selection was
restored afterward. Camera/Photos faces need corresponding content; adding
presets does not repair Weather authentication or download Snoopy animations.

Verified on the local VM: the eight original faces remained, the normal face
rendered six empty tiles without Home setup, and `HomeControlFace-featured8`
rendered nine populated tiles. The user confirmed the sample display worked.
Its accessory names, states, and temperature are demonstration content, not
connected HomeKit accessories. The normal Home/account setup remains needed
for actual accessories. Other installed Home Modular sample descriptors
include four- and six-tile arrangements; Home Camera has a demo-mode path,
but activating its sample was not verified.

## Extracting original background images

`ExtractAssets.m` decodes image renditions through the Mac's CoreUI framework,
selects appearance and scale, and checks dimensions against `assetutil`
metadata. It does not synthesize or upscale images. For an asset catalog
copied from a guest:

```sh
xcrun --sdk macosx assetutil --info /path/to/Assets.car > /path/to/inventory.json
.build/HomeViewResearchTools/extract-homeview-assets \
  /path/to/Assets.car /path/to/inventory.json /path/to/output
```

It targets universal image renditions used by the examined wallpapers. Some
unrelated device-specific UI icons cannot be resolved by this helper and are
reported as missing or mismatched.

`RenderBackgroundColors.swift` takes a local extraction folder containing
`color-backgrounds.json`. Each array entry supplies the assetutil keys
`Color components`, `Colorspace`, and an `output` path. It renders 1088-square
solid-color PNGs and builds a contact sheet from `Images/Home-Modular/*.png`.
Those solid renders are distinct from original bitmap wallpapers.

The local extraction produced 40 distinct 1088-square Home Modular images
(20 light/dark design pairs), plus shared/fallback resources. Flow uses
shaders; Snoopy animation atlases were not downloaded. Firmware, extracted
Apple catalogs/images, VM disks, guest databases, and screenshots remain
outside this source repository.

## Cosmetic Wi-Fi status indicator

`homeview-wifi-indicator` is an opt-in helper for HomeView 27.2 (24V514).
It publishes simulated Wi-Fi activity and three signal bars through Apple's
SystemStatus Wi-Fi domain. HomeView then omits its disconnected status-bar
symbol. This changes the displayed connection state, not the virtual Ethernet
interface, radio hardware, connectivity checks, or account authentication.

Build with `Build.zsh`, push `.build/HomeViewResearchTools/homeview-wifi-indicator`
to `/var/tmp/homeview-wifi-indicator` with mode `755`, and run inside the guest:

```js
print(proc.run('/var/tmp/homeview-wifi-indicator', ['enable']));
```

Check process exit status zero, `verified: true`, and `wifiActive: true`.
The helper reads back its published status in the native domain. Settings and Music were checked visually with the override.
To show a disconnected indicator again:

```js
print(proc.run('/var/tmp/homeview-wifi-indicator', ['disable']));
```

This publishes inactive Wi-Fi with zero bars; it is not a restore of every
previous network-status field. A guest reboot restores automatic reporting.
The override is volatile and may be replaced by a later system-status update.
Reapply after restarting the guest or if the warning returns. No launch daemon,
firmware patch, or automatic startup change is installed. `/var/tmp` is cleared
at boot, so push the helper again before using it in a new session.
