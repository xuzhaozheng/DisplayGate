# Architecture

DisplayGate has four modules with one-way dependencies:

```text
DisplayGate ─┐
             ├──> DisplayCore ──> SkyLightBridge
displayctl ──┘
```

## DisplayGate

The AppKit menu bar entry point. It builds menus from `DisplayInfo`, forwards user actions to `DisplayController`, presents errors, and refreshes its status icon when macOS reports a screen-parameter change.

## displayctl

The command line entry point. It uses the same controller interface as the app and adds text formatting for listing and diagnostics.

## DisplayCore

The shared display module. It owns enumeration, selector resolution, safety checks, state classification, and display configuration transactions.

`DisplayConnectionState` distinguishes three observable CoreGraphics states:

- `active`: participating in the current desktop.
- `onlineInactive`: online but not active.
- `disconnected`: absent from the public online and active lists but still returned by SkyLight.

There is no public macOS enabled-state query. The user-facing `enabled` value therefore means `active`.

Main-display and mirroring state are also captured in `DisplayInfo`, so both
front ends render the same CoreGraphics snapshot.

Batch operations configure every target inside one CoreGraphics transaction. If configuration fails before commit, the transaction is cancelled. Disabling is rejected unless a different controllable display remains active.

Main-display changes also belong to `DisplayCore`. Any active, controllable
display, including the built-in display, can be the target. The operation is
rejected while any active display is mirrored. The controller translates the
origins of all active displays in one public CoreGraphics transaction,
preserving their relative arrangement while moving the target to `(0, 0)`.
These changes use login-session scope and do not require SkyLight. Built-in
displays remain rejected by enable and disable operations.

The menu lists every controllable display. It uses the fixed Chinese label
`内建显示器` for the built-in display and the localized system name for external
displays. Bulk connection actions continue to target external displays only.

## SkyLightBridge

The only module that knows about undocumented SkyLight symbols and legacy IOKit display-name lookup. It resolves SkyLight functions at runtime with `dlopen` and `dlsym`, allowing callers to detect an unavailable private interface instead of requiring a direct link to the private framework.

## Dependency policy

- UI code does not call SkyLight directly.
- CLI code does not duplicate display-control rules.
- Private symbol declarations remain inside `SkyLightBridge`.
- Display safety rules remain inside `DisplayCore`, so every caller receives the same behavior.
