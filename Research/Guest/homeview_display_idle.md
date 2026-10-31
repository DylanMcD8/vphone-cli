# Keeping HomeView's display awake

The app now exposes this configuration under **Device → HomeView Controls… →
Keep Display Awake**, including saved-value restoration and a restart reminder.
The command-line procedure below remains available for manual use.

HomeView's BreadBoard shell has its own backlight controls. The iOS
SpringBoard Auto-Lock override is not the configuration used here.

On HomeView 27.2 (24V514), BreadBoardFoundation reads these mobile-user
preferences from `com.apple.BreadBoard`:

| Key | Keep-awake value | Purpose |
| --- | --- | --- |
| `BBDisplayOffLocalizedSetting` | `PSAlwaysActiveDisplayTurnOffNever` (string) | Native Never choice for automatic display-off |
| `BBActiveBacklightHysteresisInterval` | `2147483647` (number) | Extends the automatic active-to-inactive timer to about 68 years |

Read and save each key's previous existence, type, and value with the guest
`settings.get` RPC before changing it. Apply through `settings.set`, for example:

```json
{"method":"settings.set","params":{"domain":"com.apple.BreadBoard","key":"BBDisplayOffLocalizedSetting","value":"PSAlwaysActiveDisplayTurnOffNever","type":"string"}}
{"method":"settings.set","params":{"domain":"com.apple.BreadBoard","key":"BBActiveBacklightHysteresisInterval","value":2147483647,"type":"float"}}
```

Restart HomeView to begin with this configuration, avoiding a transition
scheduled before the preference change. This does not send periodic input,
change the recognition session, or prevent an app from returning to a face.
The active timer is extended, not represented by an infinite-duration value.

To restore, set each original value and type, or use `settings.delete` for a
key that was originally absent. Do not replace unrelated BreadBoard settings.

## Validation on 2026-10-31

Inspection of BreadBoardFoundation's exported preference getters and their
implementation established the domain, keys, and Never string. Both keys
were originally absent. A native guest probe called the framework's actual
`ActiveTimeout.value` and `InactiveTimeout.value` getters: the original values
were 300 and 900 seconds. After the change, ActiveTimeout read back as
2147483647 seconds, and the stored display-off selection read Never.
The separate `ForceActive` override remains false; it was not needed for
this configuration. These are preference/native-getter checks, not a claim
that every brightness or presence-driven transition has been tested.

The local workspace provides `Keep HomeView Display Awake.command` and
`Restore HomeView Automatic Dimming.command`, with the original key values
saved separately. Those workstation shortcuts are not bundled in the app.
