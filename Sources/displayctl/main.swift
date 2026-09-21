import Foundation
import AppKit
import CoreGraphics
import DisplayCore

let controller = DisplayController()
func usage() -> String { "Usage: displayctl list | inspect | disconnect <id|name> | reconnect <id|name> | toggle <id|name> | set-main <id|name> | toggle-all" }

func yesNo(_ value: Bool) -> String { value ? "yes" : "no" }
func rectText(_ rect: CGRect) -> String {
    String(format: "x=%.0f y=%.0f width=%.0f height=%.0f", rect.origin.x, rect.origin.y, rect.width, rect.height)
}
func uuidText(_ id: CGDirectDisplayID) -> String {
    guard let unmanaged = CGDisplayCreateUUIDFromDisplayID(id) else { return "unavailable" }
    let uuid = unmanaged.takeRetainedValue()
    return CFUUIDCreateString(nil, uuid) as String? ?? "unavailable"
}
func nsScreen(for id: CGDirectDisplayID) -> NSScreen? {
    NSScreen.screens.first {
        ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == id
    }
}
func printInspection() throws {
    for d in try controller.displays() {
        let bounds = CGDisplayBounds(d.id)
        let physical = CGDisplayScreenSize(d.id)
        let mirrorSource = CGDisplayMirrorsDisplay(d.id)
        let mode = CGDisplayCopyDisplayMode(d.id)
        let colorSpaceName = CGDisplayCopyColorSpace(d.id).name as String? ?? "unavailable"

        print("DISPLAY \(d.id)")
        print("  name: \(d.name)")
        print("  uuid: \(uuidText(d.id))")
        print("  type: \(d.builtIn ? "built-in" : "external")")
        print("  controllable: \(yesNo(d.controllable))")
        print("  online: \(yesNo(d.online))")
        print("  active: \(yesNo(d.active))")
        print("  enabled: \(yesNo(d.enabled))")
        print("  main: \(yesNo(d.main))")
        print("  asleep: \(yesNo(CGDisplayIsAsleep(d.id) != 0))")
        print("  inMirrorSet: \(yesNo(d.mirrored))")
        print("  mirrorSourceID: \(mirrorSource == kCGNullDirectDisplay ? "none" : String(mirrorSource))")
        print("  rotationDegrees: \(CGDisplayRotation(d.id))")
        print("  bounds: \(rectText(bounds))")
        print("  pixels: \(d.pixelWidth) × \(d.pixelHeight)")
        print(String(format: "  physicalSizeMM: %.1f × %.1f", physical.width, physical.height))
        print("  vendorID: \(d.vendor) (0x\(String(d.vendor, radix: 16, uppercase: true)))")
        print("  modelID: \(d.model) (0x\(String(d.model, radix: 16, uppercase: true)))")
        print("  serialNumber: \(CGDisplaySerialNumber(d.id))")
        print("  unitNumber: \(CGDisplayUnitNumber(d.id))")
        print("  colorSpace: \(colorSpaceName)")
        if let mode {
            let scale = mode.width > 0 ? Double(mode.pixelWidth) / Double(mode.width) : 0
            print("  currentMode.logical: \(mode.width) × \(mode.height)")
            print("  currentMode.pixels: \(mode.pixelWidth) × \(mode.pixelHeight)")
            print(String(format: "  currentMode.scale: %.2f×", scale))
            print(String(format: "  currentMode.refreshRate: %.3f Hz", mode.refreshRate))
            print("  currentMode.ioDisplayModeID: \(mode.ioDisplayModeID)")
            print("  currentMode.ioFlags: 0x\(String(mode.ioFlags, radix: 16, uppercase: true))")
            print("  currentMode.usableForDesktopGUI: \(yesNo(mode.isUsableForDesktopGUI()))")
        } else {
            print("  currentMode: unavailable")
        }
        let modeCount = (CGDisplayCopyAllDisplayModes(d.id, nil) as? [CGDisplayMode])?.count
        print("  availableModeCount: \(modeCount.map(String.init) ?? "unavailable")")

        if let screen = nsScreen(for: d.id) {
            print("  NSScreen.localizedName: \(screen.localizedName)")
            print("  NSScreen.frame: \(rectText(screen.frame))")
            print("  NSScreen.visibleFrame: \(rectText(screen.visibleFrame))")
            print(String(format: "  NSScreen.backingScaleFactor: %.2f", screen.backingScaleFactor))
            print("  NSScreen.maximumFramesPerSecond: \(screen.maximumFramesPerSecond)")
            print(String(format: "  NSScreen.EDR.current: %.3f", screen.maximumExtendedDynamicRangeColorComponentValue))
            print(String(format: "  NSScreen.EDR.potential: %.3f", screen.maximumPotentialExtendedDynamicRangeColorComponentValue))
            print(String(format: "  NSScreen.EDR.reference: %.3f", screen.maximumReferenceExtendedDynamicRangeColorComponentValue))
            print("  NSScreen.colorSpace: \(screen.colorSpace?.localizedName ?? "unavailable")")
            print("  NSScreen.safeAreaInsets: top=\(screen.safeAreaInsets.top) left=\(screen.safeAreaInsets.left) bottom=\(screen.safeAreaInsets.bottom) right=\(screen.safeAreaInsets.right)")
        } else {
            print("  NSScreen: unavailable")
        }
        print("")
    }
}

do {
    let args = Array(CommandLine.arguments.dropFirst())
    guard let command = args.first else { throw DisplayError.operationFailed(usage()) }
    switch command {
    case "list":
        guard args.count == 1 else { throw DisplayError.operationFailed(usage()) }
        print("ID\tNAME\tTYPE\tONLINE\tACTIVE\tENABLED")
        for d in try controller.displays() { print("\(d.id)\t\(d.name)\t\(d.builtIn ? "built-in" : "external")\t\(d.online ? "yes" : "no")\t\(d.active ? "yes" : "no")\t\(d.enabled ? "yes" : "no")") }
    case "inspect":
        guard args.count == 1 else { throw DisplayError.operationFailed(usage()) }
        try printInspection()
    case "disconnect", "reconnect", "toggle":
        guard args.count == 2 else { throw DisplayError.operationFailed(usage()) }
        let d = try controller.resolve(args[1])
        try controller.setEnabled(command == "reconnect" ? true : command == "disconnect" ? false : !d.enabled, for: d)
        print("OK: \(command) \(d.name) (\(d.id))")
    case "set-main":
        guard args.count == 2 else { throw DisplayError.operationFailed(usage()) }
        let d = try controller.resolve(args[1])
        try controller.setMainDisplay(d)
        print("OK: set-main \(d.name) (\(d.id))")
    case "toggle-all":
        guard args.count == 1 else { throw DisplayError.operationFailed(usage()) }
        try controller.toggleAllExternal()
        print("OK: toggle-all")
    case "help", "--help", "-h": print(usage())
    default: throw DisplayError.operationFailed(usage())
    }
} catch { fputs("Error: \(error)\n", stderr); exit(1) }
