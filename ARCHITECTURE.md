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

Batch operations configure every target inside one CoreGraphics transaction. If configuration fails before commit, the transaction is cancelled. Disabling is rejected unless a different controllable display remains active.

## SkyLightBridge

The only module that knows about undocumented SkyLight symbols and legacy IOKit display-name lookup. It resolves SkyLight functions at runtime with `dlopen` and `dlsym`, allowing callers to detect an unavailable private interface instead of requiring a direct link to the private framework.

## Dependency policy

- UI code does not call SkyLight directly.
- CLI code does not duplicate display-control rules.
- Private symbol declarations remain inside `SkyLightBridge`.
- Display safety rules remain inside `DisplayCore`, so every caller receives the same behavior.
