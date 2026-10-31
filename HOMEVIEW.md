# HomeView development copy

This branch preserves the HomeView work based on
[insidegui/vphone-cli's homeview branch](https://github.com/insidegui/vphone-cli/tree/homeview),
submitted upstream in [Lakr233/vphone-cli#786](https://github.com/Lakr233/vphone-cli/pull/786).
The starting commit for the local additions is
`e1ef98f` (HomeView distance sensing override).

The local additions include:

- BreadBoard Metal compiler access to remove shader retry stalls.
- IconServices access to restore dashboard app icons.
- Correct touch mapping when the host window is resized, with geometry tests.
- Control–Command–S for saving screenshots.
- Device-menu date/time override and reset, backed by a guest clock API that
  preserves a ticking manual clock across periodic host sync requests.
- Standalone Home Modular registration and wallpaper research tools.

Build the app using the existing instructions in `AGENTS.md` and `README.md`.
The HomeView-specific findings and validation are in
[`Research/Firmware/homeview_bringup.md`](Research/Firmware/homeview_bringup.md),
[`Research/Guest/host_clock_sync.md`](Research/Guest/host_clock_sync.md), and
[`Research/Tools/HomeView/README.md`](Research/Tools/HomeView/README.md).
The prior local checks passed 62 focused patch/entitlement tests, 14 geometry
tests, bundle admission/signature verification, and live clock override/reset
checks. These are recorded local results, not a claim that GitHub CI ran.

This is a source repository. The working VM, firmware, extracted wallpapers,
backups, and diagnostic logs stay in the local HomeView working folder. Git
history and upstream licensing are preserved. The repository is created as
a private standalone copy because GitHub does not support private forks of
public repositories. Its default branch is `homeview`.
