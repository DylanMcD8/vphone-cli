# Host clock sync

## Local manual clock controls (2026-10-30)

The Device menu adds **Set Date & Time…**, **Set to Marketing Date & Time**,
and **Use Mac’s Date & Time**,
enabled only when the guest advertises `clock_override`. The date picker uses
the Mac's time zone, which is also the zone the existing guest sync supplies.
The selected time keeps advancing; this is not a frozen display clock.
The marketing preset uses a Gregorian calendar in the Mac's time zone to set
November 13, 2026 at 10:09:20 AM through the same manual override. In
America/New_York this resolves to `2026-11-13T15:09:20Z` (standard time).

`time.clock {time, manual: true}` validates a finite Unix timestamp after 2001
and no later than 2100, turns automatic time off through CoreTime and verifies
the setting, then calls `settimeofday` inside the root guest daemon and posts
`com.apple.system.clock_set`. The operation shares the existing clock lock so
a host sync cannot interleave with it. A failed set restores automatic time
if it had been on. The existing minute-by-minute host sync respects automatic
time being off. `{time: currentHostTime, automatic: true}` restores sync.
Manual requests without a time or with automatic time enabled are rejected.

The full bundle build and signature checks passed. On HomeView 27.2 (24V514),
live RPC checks rejected missing/conflicting/out-of-range manual requests,
set the clock two days forward and one day backward, and restored automatic
time. Manual time kept ticking within 2 seconds of its expected offset over
65 seconds, spanning a host-sync interval; an explicit ordinary host time
sync also left it unchanged. The Device menu items were enabled, and the user
successfully used the picker to select November 15. That interrupted the first
automated hold test, so it was rerun without UI interaction and passed. The
guest was left on automatic/current time. Persistence of the chosen manual
date across guest reboots was not tested.

An initial live update failed because a Foundation networking probe had
created a URL cache directory at /var/root/Library/Caches/vphoned, where
agent.apply_update expects to rename an executable. The running old agent
was healthy; the host suppressed its connected state while retrying updates.
Restoring the old host staging file allowed diagnosis through script.eval.
The cache directory (Cache.db and its WAL/SHM files) was moved intact to
vphoned-network-test-cache-20261030, and staging the new tvOS daemon then
updated successfully. No guest system-disk update was needed. The host binary
was authorized once through Launch HomeView.command. Test artifacts are in
work/clock-override-live-verification.json and work/clock-override-live-test.json
(the latter includes the user-interrupted test).

`vphone-vm` keeps a guest's wall clock on the Mac's. It sends the Mac's time
after every connect to vphoned, every minute, when the Mac wakes and when the
Mac's own clock is set; vphoned offers it to timed as an NTP result, and timed
sets the clock.

Static analysis of `/usr/libexec/timed` (CoreTime-334.0.16.3) from an iOS
26.6.2 (23G90) `iPhone17,3` guest and of macOS 27's `timed` (CoreTime-340.0.14,
the same sources, read with Ghidra), 2026-10-12. Run on iOS 26.6.2 and iOS
27.0.1 (24A446) guests; see [Verification](#verification).

## What goes wrong without it

A guest was found 18 h 28 min behind the Mac, with the right time zone. Its
`/var/db/timed/com.apple.timed.plist` held a time filter (`TDTF`) with one
input, `FilesystemTimestamp`, taken 2 s after boot: UTC 2026-10-11 06:00:31 at
RTC 2026-10-12 00:28:56. The RTC value was right; the UTC value was the last
time the guest had run.

The guest's kernel takes the Mac's time from the virtual RTC at boot, so the
clock starts right. timed then replaces it:

1. `TMCache initWithPath:clock:` reads the plist. `readValidCache:clock:`
   accepts it only if the format version matches, the kernel's monotonic clock
   has not gone back, its offset is not zero, the platform has a PMU RTC
   (`kern.monotonicclock_usecs` exists) and the host UUID is the same.
2. On a guest the saved state does not pass on a new boot. Which check turns
   it down was not captured: timed logs it before vphoned is up to read the
   log. Restarted within one boot, timed loads the same file
   (`Boot UUID matches`, `TDTF,lastQualityTime,Src,NTP,…`).
3. When the state is turned down and it says the system time was once set
   (`TMSystemTimeSet`), timed takes the plist's modification time, empties the
   file, and, with `UseFilesystemTimestamp` (on by default where there is a
   PMU RTC), feeds it to the filter as `FilesystemTimestamp` with an
   uncertainty of 1.5e9 s (`Injecting filesystem timestamp`).
4. `testAndApplySystemTime` then moves the clock to the filter's time, more
   than `SettimeofdayThreshold` (0.05 s) away, with `settimeofday`.

So a guest whose clock timed has set once comes up, on every later boot,
behind by as long as it was off, and stays there until an NTP result arrives.
A guest that has never had one keeps the RTC's time: its plist has
`TMSystemTimeSet` false and the filter is not running.

NTP is `time.apple.com` over UDP 123, through the Mac's network. A proxy on
the Mac in fake-IP mode answers the name with an address of its own and may
not carry UDP 123: on the Mac where this was found, `sntp time.apple.com`
timed out against `198.18.147.230` while `sntp ntp.aliyun.com` answered, and
the guest resolved the same address. (Two hours later the guest's own fetches
to that address were answered, 0.3 to 0.55 s late.) A Mac that sleeps also stops a running
guest's clock for as long as it sleeps.

## What timed accepts

A client hands timed a time with CoreTime's `TMSetSourceTime(CFStringRef
source, CFAbsoluteTime time, CFTimeInterval uncertainty)`. It sends an XPC
message (`TMCommand` `TMSetSourceTime`, `TMSource`, `TMCurrentTime`,
`TMTimeError`, `TMMachTime`) and gets no reply.

timed's command check lets a command
through for a client with `com.apple.timed`, or for root, and for
`TMSetSourceTime` and `TMSetSourceTimeZone` also wants the source's name in
the client's `com.apple.timed.sources` array.
(`TMSetAuthenticatedSourceTime` wants it in `com.apple.private.timed.sources`.)
vphoned has `com.apple.timed` for the time zone, and now
`com.apple.timed.sources = [NTP]`.

`TMDaemonCore setSourceTime:` hands the time to the filter's
`update:withError:`:

- An uncertainty under 1e-6 s is refused.
- `MobileLockdown`, the source a paired computer sets through lockdownd, is
  used only while the filter is not running (`ignoreMobileLockdown`). On a
  guest the filter is running from the filesystem timestamp, so it is no use.
- A filter that is not running starts from the input.
- Otherwise the input is compared with the filter's prediction. Within 5
  standard deviations (3 for `TMLSSourceComputed`, 10 for
  `TimeSourceGnssValidPos`) of prediction and input together, it is averaged
  in. Outside, it is turned down (`RejectATime`).
- For `NTP`, `GPS`, `TimeSourceGnss`, `TimeSourceGnssValidPos` and
  `TMLSSourceComputedReliable`, a turned-down input counts. At the fifth in a
  row, or at once when the prediction is more than four times as uncertain as
  the input, the filter starts over from the input (`ResetSynthesizer`). Any
  other source can be turned down for ever.

That is why the source is `NTP`: after a Mac's sleep the guest is behind by
far more than the filter expects, and only a counted source gets it to start
over. It is also what the offered time is: the Mac's NTP-disciplined clock,
relayed.

`testAndApplySystemTime` applies the filter to the clock only while automatic
time is on (`TMAutomaticTimeOnlyEnabled` in timed's preferences,
`/var/db/timed/Library/Preferences/com.apple.timed.plist`). Settings' Set
Automatically shows off on a guest, because the time zone sync turns the
automatic time zone off, while automatic time stays on. Picking a date or time
there turns automatic time off too, and timed then leaves the clock alone.

## What vphone does

`time.clock` (capability `clock`; REST `GET/PUT /v1/clock`,
`VPhoneDaemon/Daemon/GuestAPI+Clock.swift`, `VPhoneDaemon/Native/vphoned_clock.m`):

- alone, returns `{time, automatic}`: the guest's clock in seconds since 1970
  and `TMIsAutomaticTimeEnabled`.
- `{time}` is the Mac's time. vphoned adds the time the request has waited
  since it was read. A guest within 1 s is left alone, and so is one with
  automatic time off. Otherwise vphoned calls
  `TMSetSourceTime("NTP", time, 0.1)` and reads the clock for 0.3 s, up to six
  times, until the clock is within 1 s. An offset over 1 s is more than the 5
  standard deviations a filter fed at 0.1 s allows (about 0.7 s), so an offer
  is never averaged in: the filter takes it whole, at once from a filesystem
  timestamp and after five offers otherwise. The answer adds `offset` (the
  Mac's time less the guest's, before) and `changed`. If the clock has not
  moved after six offers the request fails with timed's remaining offset.
- `{automatic}` turns automatic time on or off with
  `TMSetAutomaticTimeEnabled`; with `time` it is applied first.

`VPhoneClockSync` in `vphone-vm` sends the Mac's time when the guest reports
`clock`, then every 60 s, on `NSWorkspace.didWakeNotification` and on
`NSSystemClockDidChange`. It logs a move (`[clock] guest was 302.4 s behind,
set to the Mac's time`) every time and any other outcome once.

An NTP result of the guest's own is still used. It is averaged in when it is
within the filter's 5 standard deviations of the Mac's time, which the Mac's
clock normally is.

## Limits

- The clock is wrong from boot until vphoned connects, about ten seconds.
  Turning `UseFilesystemTimestamp` off in timed's preferences would leave the
  RTC's time in place over that stretch; it was not tried.
- A Mac whose own clock is more than a second off real time, with a guest
  whose NTP works, has timed and the host each start the filter over in turn:
  every turned-down input makes timed fetch NTP at once (`RequestFastTime`),
  and five of its results in a row undo the offer. A result that arrives
  between offers and agrees with the filter also clears the count, and the
  request then fails with `timed kept its own time`. Turning automatic time
  off in the guest ends it.
- The Mac's time is known in the guest to the request's time on the control
  connection, 10 to 20 ms as measured.

## Verification

New `iPhone17,3` guests on iOS 26.6.2 (23G90) and iOS 27.0.1 (24A446), cloudOS
26.4, 2026-10-12. Offsets are the guest's `time.clock` less the Mac's clock
at the middle of the round trip.

| Case | iOS 26.6.2 | iOS 27.0.1 |
| --- | --- | --- |
| `time` 0.5 s ahead of the Mac | left alone | left alone |
| `time` 1.5 s ahead | moved, +1.498 s | moved, +1.495 s |
| `time` 1 h ahead | moved, +3599.997 s | moved, +3599.997 s |
| `time` 1 day behind | moved, −86400.002 s | moved, −86400.005 s |
| `{automatic: false}`, then `time` 1 h ahead | left alone | left alone |
| `{automatic: true, time}` 120 s ahead | moved on the second try, +119.996 s | moved, +119.996 s |
| The host's next send after that | back within 60 s, +0.004 s | back within 60 s, +0.002 s |
| `time` of 12, and of a string | refused | not run |
| Booted after some minutes off, once timed had set the clock | `guest was 302.4 s behind, set to the Mac's time` at connect, then steady | `guest was 405.8 s behind, set to the Mac's time`, then −0.027 s over 70 s |
| The same boot with Unlock at Startup | unlocked, on the Mac's time | not run |

On an earlier build, which offered the time with an uncertainty of 0.5 s, the
iOS 26.6.2 guest also kept a date picked in its Settings (8 days ahead,
automatic time off) over 70 s of host sends, and came back to −0.005 s at
once when Set Automatically was turned on there. On that build a time 1.5 s
ahead was averaged in and the guest ended 0.75 s ahead, which is why the
uncertainty is 0.1 s.

The first try of `{automatic: true, time}` on iOS 26.6.2 failed with
`timed kept its own time, -120.003 s from the Mac's`. The guest's own NTP was
answering through the Mac's proxy at that moment (`cmd,fetchTime … delay
0.32 … ip 198.18.147.230`, results of ±0.32 s), so the offered time, wrong on
purpose, ran into the second limit above. The same results are what moved
that guest's clock by 0.06 s shortly after each sync: the Mac was about half
a second ahead of real time.

Not run: a Mac that sleeps and wakes, and a change of the Mac's own clock.
Both send through the same path as the minute's timer.
