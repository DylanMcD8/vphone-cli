# HomeView research tools

These are the source helpers used with the HomeView 27.2 (24V514) research
guest. They are separate from the shipped VPhone bundle. Build them on the
Mac with Xcode 27:

```sh
zsh Research/Tools/HomeView/Build.zsh
```

The outputs go to `.build/HomeViewResearchTools`, which is ignored by Git.

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
