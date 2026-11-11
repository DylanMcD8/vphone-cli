# HomeView development copy

This branch preserves the HomeView work based on
[insidegui/vphone-cli's homeview branch](https://github.com/insidegui/vphone-cli/tree/homeview),
submitted upstream in [Lakr233/vphone-cli#786](https://github.com/Lakr233/vphone-cli/pull/786).
The starting commit for the local additions is
`e1ef98f` (HomeView distance sensing override).

Upstream 2.16.1 is integrated through `d1c36fa8` (November 10, 2026).
The merge preserves the custom panel, artwork, frame/input mapping, PNG capture,
manual clock, and guest helpers. Upstream's typed method dispatcher declares
the manual-clock parameter explicitly so it is not filtered out. The shared
viewport calculation now uses upstream's equivalent geometry helper.

The local additions include:

- BreadBoard Metal compiler access to remove shader retry stalls.
- IconServices access to restore dashboard app icons.
- Correct touch mapping when the host window is resized, with geometry tests.
- Control–Command–S for saving screenshots.
- Optional HomeView bezel around the live display, enabled by default and
  remembered through Device → Show Device Frame. Bezel clicks move the window;
  the alpha opening passes touches to the scaled guest view. Raw guest captures
  remain unframed; use a macOS window screenshot to include the bezel.
- Device → Show Frame Rate shows FPS in place of the guest IP address.
- Device-menu date/time override and reset, backed by a guest clock API that
  preserves a ticking manual clock across periodic host sync requests.
  “Set to Marketing Date & Time” (Control–Command–D) sets November 13, 2026 at 10:09:20 AM
  in the Mac’s time zone; “Use Mac’s Date & Time” restores automatic time.
- Standalone Home Modular registration and wallpaper research tools.
- A reversible AirPlay video presentation workaround; see
  [`Research/Guest/homeview_airplay.md`](Research/Guest/homeview_airplay.md).

Build the app using the existing instructions in `AGENTS.md` and `README.md`.
The HomeView-specific findings and validation are in
[`Research/Firmware/homeview_bringup.md`](Research/Firmware/homeview_bringup.md),
[`Research/Guest/host_clock_sync.md`](Research/Guest/host_clock_sync.md), and
[`Research/Tools/HomeView/README.md`](Research/Tools/HomeView/README.md).
The prior local checks passed 62 focused patch/entitlement tests, 14 geometry
tests, bundle admission/signature verification, and live clock override/reset
checks. These are recorded local results, not a claim that GitHub CI ran.

The 2.16.1 integration passed 29 controls checks, 60 frame/input/toolbar
checks, 16 core geometry tests, 48 selected firmware preset/HomeView sandbox
tests, 593 daemon logic checks, and the 198-method catalog plus its mutation
checks. Manual-clock and automatic-reset requests were also exercised through
the actual method dispatcher. Live validation of the rebuilt app requires
macOS to authorize its new executable signature.

This is a source repository. The working VM, firmware, extracted wallpapers,
backups, and diagnostic logs stay in the local HomeView working folder. Git
history and upstream licensing are preserved. This is a public forked
development copy with `homeview` as its default branch. Anyone can read or
clone it over HTTPS without a GitHub account or invitation. Firmware must be
obtained separately; see the setup prompt at the top of `README.md`.

The inherited GitHub Actions workflows are preserved as inactive
templates in `Research/Tools/HomeView/UpstreamWorkflows/`. They were archived
during the initial upload because its token lacked the `workflow` scope.
The website workflow added upstream is archived alongside them. Build workflows require the upstream's `xcode-27` runner. Restore them to
`.github/workflows/` after arranging workflow-capable authentication and a
compatible runner if automated builds are wanted.
