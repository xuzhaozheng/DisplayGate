# DisplayGate

DisplayGate is a small macOS menu bar app for managing external-display connections and choosing the main display. It also includes a command line tool named `displayctl`.

The project uses undocumented SkyLight functions because macOS does not provide a public API for this operation. It is intended for personal use, experimentation, and development workflows.

## Features

- List the built-in display and connected or software-disabled external displays.
- Disconnect, reconnect, or toggle one external display.
- Toggle all controllable external displays from the menu bar.
- Make any active display, including the built-in display, the main display.
- Show display mode, position, color, HDR/EDR, hardware identifiers, and other diagnostics.
- Refuse to enable or disable the built-in display.
- Refuse operations that would disable the last active display.

## Requirements

- Apple Silicon Mac
- macOS 13 Ventura or later
- Xcode Command Line Tools or Xcode with Swift 5.9 or later

The project has been used on macOS 26. Private API compatibility can change in any macOS update.

## Build the menu bar app

```bash
./build-app.sh
open .build/DisplayGate.app
```

To build and open it in one step:

```bash
./build-app.sh --run
```

The generated application stays under `.build/` and is not part of the source repository.

## Menu bar controls

- Left click: open display details and per-display controls.
- Right click: toggle all external displays.
- Middle click: toggle all external displays.

Each display, including the built-in display, has an indented action in the
display list for making that active display the main display. The action is
unavailable for disabled or already-main displays, and while display mirroring
is active. The built-in display can become the main display but cannot be
disabled through DisplayGate. It is labeled `内建显示器` in the menu to keep
the menu compact and consistent with the Chinese interface.

The status item and application icon use the `display.2` SF Symbol. The application icon under `Assets/` can be regenerated with `./Tools/make_displaygate_icns.sh`, which rebuilds both the 1024px source PNG and the ICNS (full-bleed tile, modern PNG entries for every size).

## Build and use the CLI

```bash
swift build -c release --product displayctl
.build/release/displayctl list
```

Commands:

```text
displayctl list
displayctl inspect
displayctl disconnect <id|name>
displayctl reconnect <id|name>
displayctl toggle <id|name>
displayctl set-main <id|name>
displayctl toggle-all
```

Name matching is case-insensitive and must produce a unique match. A numeric display ID can be used when names are ambiguous. `set-main` accepts the built-in display; connection commands continue to reject it.

## How it works

DisplayGate starts a normal CoreGraphics display configuration transaction and calls two runtime-resolved SkyLight functions:

| Function | Purpose |
| --- | --- |
| `SLSConfigureDisplayEnabled` | Enable or disable a display in a configuration transaction |
| `SLSGetDisplayList` | Enumerate displays, including displays disabled in software |

`CGGetOnlineDisplayList` and `CGGetActiveDisplayList` no longer include a display after it is disabled. `SLSGetDisplayList` is therefore required to find it again for reconnection.

Making an active display the main display uses the public
`CGConfigureDisplayOrigin` API. DisplayGate translates every active display in
one transaction so that the selected display has origin `(0, 0)` while the
relative arrangement is preserved. The change has login-session scope.

The private symbols are loaded with `dlopen` and `dlsym`. If they are unavailable, read-only display listing falls back to public CoreGraphics lists and state-changing operations fail with an error.

## Known limitations

- SkyLight is private and undocumented. Its symbols, calling conventions, or behavior may change without notice.
- The application is not intended for Mac App Store distribution.
- Intel Macs are not supported.
- Display state can be restored by macOS after logout, restart, sleep, or hardware changes.
- Window placement does not always behave exactly like a physical cable disconnect.
- The displayed `enabled` value currently follows the CoreGraphics active state because there is no public enabled-state query.
- Display names for disabled displays depend on legacy IOKit behavior and may fall back to `Display <id>`.

If a display cannot be reconnected through the app, reconnect its cable, power-cycle it, or log out and back in.

## Privacy

DisplayGate has no network functionality, analytics, telemetry, accounts, or background data collection. It reads display information from macOS and does not persist it.

## Project structure

```text
Sources/DisplayGate/       Menu bar application
Sources/displayctl/        Command line interface
Sources/DisplayCore/       Shared display model and control logic
Sources/SkyLightBridge/    Runtime-resolved SkyLight and IOKit bridge
Assets/                    Application icon source and ICNS file
Resources/                 Application bundle metadata
Tools/                     Reproducible asset generation tools
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for module responsibilities, display-state semantics, and safety invariants.

## Prior art

The implementation was informed by public work documenting the same private display interfaces:

- [displaytoggle](https://github.com/calvincchan/displaytoggle)
- [screen_tune](https://github.com/antonorlov/screen_tune)
- [Lunar: Turn off MacBook display in clamshell mode](https://alinpanaitiu.com/blog/turn-off-macbook-display-clamshell/)

These projects are references and are not runtime dependencies.

## Versioning

Application version metadata is maintained in `Resources/Info.plist`:

- `CFBundleShortVersionString` is the user-facing release version.
- `CFBundleVersion` is the internal build number.

The version is visible in Finder's Get Info panel and other macOS bundle metadata views. DisplayGate does not currently show it in the menu bar UI, and `displayctl` does not currently provide a `--version` command. Git release tags should use the same release version with a `v` prefix, for example `v1.0`.

## License

DisplayGate is available under the [MIT License](LICENSE).
