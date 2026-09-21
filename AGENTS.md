# Working on DisplayGate

Read `ARCHITECTURE.md` before changing display enumeration, state, safety checks, or SkyLight calls.

## Invariants

- Control external displays only. Keep built-in display operations rejected in `DisplayCore`.
- Keep at least one controllable display active when disabling displays.
- Enumerate disabled displays through `SLSGetDisplayList`; public CoreGraphics lists cannot reconnect them alone.
- Keep undocumented symbols and IOKit details inside `SkyLightBridge`.
- Keep shared behavior in `DisplayCore` so the menu bar app and `displayctl` use the same rules.
- Configure multi-display changes in one CoreGraphics transaction and cancel the transaction on failure.

## Product conventions

- Target Apple Silicon and macOS 13 or later.
- Keep the application menu-bar-only through `LSUIElement`.
- Keep user-facing menu text in Chinese and developer documentation in English.
- Use `display.2` for the status item and generated application icon unless the user requests a different design.
- Treat SkyLight compatibility as provisional and document behavior changes by macOS version.

## Repository hygiene

- Commit source files, documentation, icon assets, and reproducible asset tools.
- Keep `.build/`, `.cache/`, `work/`, and `outputs/` out of Git.
- Update `README.md` when commands, interactions, requirements, or known limitations change.
- Update `ARCHITECTURE.md` when a module interface, dependency direction, state meaning, or safety invariant changes.

## Verification

After code changes, run:

```bash
swift build -c release
./build-app.sh
```

Both package products must compile, the app bundle must contain `Resources/Info.plist` and `Assets/DisplayGate.icns`, and `git diff --check` must report no whitespace errors.

After icon changes, regenerate both `Assets/DisplayGateIcon.png` and `Assets/DisplayGate.icns`, then inspect the ICNS rendering at 512 and 64 pixels before completion.
