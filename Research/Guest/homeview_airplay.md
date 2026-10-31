# HomeView AirPlay video presentation

Tested October 31, 2026 on HomeView 27.2 (24V514), HomeAccessory17,1,
with the cloudOS 26.4 (23E5207q) research kernel.

## Symptom and evidence

QuickTime on the host Mac discovers HomeView, completes the onscreen PIN
pairing, and reports that it is AirPlaying. HomeView remains on its clock.
The receiver's log confirms pair verification, APv2 video playback, registration
of a video session, and AVPlayer's playing state. It requests a fullscreen
Now Playing live activity but its presentation state remains `Background`.

The firmware enables both `TVAirPlay/PebbleAirPlayVideo` and
`TVAirPlay/PebbleAirPlayVideoInNowPlaying`. Disabling only the latter makes
the receiver use its separate video presentation path. After a guest reboot
and a new AirPlay connection, the host's H.264/AAC test video appeared in
HomeView, letterboxed on its square display. The user also confirmed playback
worked after an initial timed-out attempt. Audio output, DRM-protected content,
mirroring, and senders on other devices
require separate testing. The precise cause of the Now Playing handoff failure
has not been established.

NAT was left unchanged. Bonjour advertised the receiver on the Mac's virtual
interfaces, and the successful session identified its transport as `USB`.
Bridged networking is not required for this tested host-Mac route. This does
not establish LAN discovery from an iPhone, nor repair Music/Weather service
authentication.

## Apply the reversible workaround

Use the existing VM's guest-control connection. These are **guest paths**;
do not create the override in the host Mac's Library.

1. Read `/Library/Preferences/FeatureFlags/Domain/TVAirPlay.plist` with
   `files.plist`. Save an existing file outside the guest using `pull`, or
   record that it did not exist. Distinguish a missing file from other errors.
2. If absent, create `/Library/Preferences/FeatureFlags/Domain` with
   `files.mkdir` and push
   [`TVAirPlay.plist`](../Tools/HomeView/TVAirPlay.plist) to that guest path.
   Use mode `644`. Do not overwrite an existing override file with the template.
3. If present, preserve other keys and fields. Read its
   `PebbleAirPlayVideoInNowPlaying` dictionary, merge `Enabled: false` into it,
   then use `files.plist_set` to replace only that top-level key. Record its
   previous value for rollback. Leave `PebbleAirPlayVideo` enabled.
4. Reboot the guest using `system.reboot` with `{"force":true}` and verify
   reconnection. **Restarting TVAirPlay alone is insufficient**: feature flags
   are cached in shared memory across process restarts. A fresh native probe
   of `_os_feature_enabled_impl` confirmed `true` / `false` after this reboot.
5. In QuickTime, disconnect any old AirPlay session, select **HomeView** again
   from the video's AirPlay menu, and press Play. Enter the code shown on
   HomeView if prompted. Verify the guest's display, not just QuickTime's
   “playing on HomeView” message. Start with an ordinary unprotected video.

For a standalone installation, the same RPC methods and `push`/`pull` requests
work through its per-machine `vphone.sock`; see
[`guest-socket.md`](../../Skills/vphone-guest-control/references/guest-socket.md).
Launchpad installations can use `vphone-launchpad-cli guest rpc` and
`vphone-launchpad-cli guest push` instead. Use the machine's actual name and
socket path. No host administrator step, binary patch, or bundle rebuild was
needed for this preference override.

## Rollback

Restore the saved previous feature dictionary, or remove just the added key
if it was previously absent. If the entire file was created for this test and
contains no other overrides, remove that file. Preserve unrelated later edits.
Reboot the guest again to clear the shared feature-flag cache. Restoring the
original setting restores the native Now Playing presentation path.

## Music interface preview (October 31, 2026)

The host Mac’s Music app discovers this receiver and delivers track metadata
and artwork. A live screenshot verified the native HomeView Now Playing view
showing “mq9” by Automatic, album art, duration, and playback controls. This
initial session stopped shortly after starting. A later session showed
“FEVER DREAM” by Alex Warren at 0:59 with the Pause control, and subsequent
metadata displayed “I MISS YOU MORE” in the full-artwork view. This establishes
live visual updates, not reliable audio output or continuous playback.

Select HomeView in Music’s AirPlay menu and start a track. To bring the native
interface forward after metadata arrives, use the guest `apps.launch` RPC with
`{"bundle_id":"com.apple.pebblenowplaying"}`. This hidden service can report
`app did not become frontmost` even while its interface visibly opens; verify
with a screenshot. This is a research preview, not a reliable audio receiver.

The receiver logs confirm `updateMRNowPlayingInfo`, artwork updates, and the
Music source client. They also report `Starting the Synchronizer failed` with
`kTimeoutErr` (-6722). The guest’s VirtualAudio plugin is not initialized and
no local audio route is available. The virtio sound HAL driver is absent from
this HomeView installation. These are concrete audio-path problems; DRM was
not isolated as the cause. No audio driver, product-ID override, or new firmware
patch was installed for this visual test. Keep the working video override above.
