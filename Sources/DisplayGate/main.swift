import Cocoa
import DisplayCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = DisplayController()
    private var item: NSStatusItem!
    private var screenParametersObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = item.button else { return }
        button.image = NSImage(systemSymbolName: "display.2", accessibilityDescription: "External displays")
        button.toolTip = "DisplayGate"
        button.target = self; button.action = #selector(statusClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp, .otherMouseUp])
        updateStatusIcon()
        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateStatusIcon()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let screenParametersObserver {
            NotificationCenter.default.removeObserver(screenParametersObserver)
        }
    }

    @objc private func statusClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.type == .otherMouseUp {
            toggleAll()
        } else {
            showDetailsMenu()
        }
    }

    private func showDetailsMenu() {
        item.menu = makeDetailsMenu()
        item.button?.performClick(nil)
        item.menu = nil
    }

    @objc private func toggleAll() {
        do {
            try controller.toggleAllExternal()
            updateStatusIcon()
        } catch {
            showError(error)
        }
    }

    private func updateStatusIcon() {
        let hasActiveExternal = (try? controller.externalDisplays().contains(where: \.active)) ?? false
        item.button?.image = NSImage(
            systemSymbolName: hasActiveExternal ? "display.2" : "display",
            accessibilityDescription: "External displays"
        )
    }

    private func makeDetailsMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(infoItem(label: "显示器", value: nil, emphasized: true))
        menu.addItem(.separator())
        do {
            let displays = try controller.controllableDisplays()
            let externalDisplays = displays.filter { !$0.builtIn }
            if displays.isEmpty {
                menu.addItem(infoItem(label: "没有可用的显示器", value: nil))
            }
            let hasActiveMirrorSet = displays.contains {
                $0.active && $0.mirrored
            }
            for d in displays {
                let state = d.enabled ? "已启用" : "已停用"
                let name = displayName(for: d)
                let displayItem = NSMenuItem(title: "\(name)  ·  \(state)", action: nil, keyEquivalent: "")
                displayItem.attributedTitle = NSAttributedString(
                    string: "\(name)  ·  \(state)",
                    attributes: [
                        .font: NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .semibold),
                        .foregroundColor: NSColor.labelColor
                    ]
                )
                displayItem.image = NSImage(
                    systemSymbolName: d.enabled ? "display" : "display.slash",
                    accessibilityDescription: state
                )
                displayItem.state = d.enabled ? .on : .off
                displayItem.submenu = displayMenu(for: d)
                menu.addItem(displayItem)

                let isMain = d.main
                let setMain = NSMenuItem(
                    title: isMain ? "当前主显示器" : "设为主显示器",
                    action: isMain ? nil : #selector(setMainDisplay(_:)),
                    keyEquivalent: ""
                )
                setMain.target = self
                setMain.representedObject = NSNumber(value: d.id)
                setMain.indentationLevel = 1
                setMain.state = isMain ? .on : .off
                setMain.isEnabled = !isMain && d.active && !hasActiveMirrorSet
                menu.addItem(setMain)
            }
            if !externalDisplays.isEmpty {
                menu.addItem(.separator())
                let allEnabled = externalDisplays.allSatisfy(\.enabled)
                let toggle = NSMenuItem(
                    title: allEnabled ? "停用全部外接显示器" : "启用全部外接显示器",
                    action: #selector(toggleAll),
                    keyEquivalent: ""
                )
                toggle.target = self
                menu.addItem(toggle)
            }
        } catch {
            menu.addItem(infoItem(label: "错误", value: error.localizedDescription, emphasized: true))
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 DisplayGate", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    private func displayMenu(for display: DisplayInfo) -> NSMenu {
        let screen = screen(for: display.id)
        let mode = CGDisplayCopyDisplayMode(display.id)
        let menu = NSMenu(title: displayName(for: display))
        if display.builtIn {
            let protected = NSMenuItem(title: "内建显示器不可停用", action: nil, keyEquivalent: "")
            protected.isEnabled = false
            menu.addItem(protected)
        } else {
            let toggle = NSMenuItem(
                title: display.enabled ? "停用此显示器" : "启用此显示器",
                action: #selector(toggleDisplay(_:)),
                keyEquivalent: ""
            )
            toggle.target = self
            toggle.representedObject = NSNumber(value: display.id)
            menu.addItem(toggle)
        }
        menu.addItem(.separator())
        menu.addItem(infoItem(label: "状态", value: display.enabled ? "已启用" : "已停用", emphasized: true))
        if let mode {
            let refreshRate = mode.refreshRate > 0
                ? mode.refreshRate
                : Double(screen?.maximumFramesPerSecond ?? 0)
            let refreshText = refreshRate > 0 ? String(format: " @ %.0f Hz", refreshRate) : ""
            let scale = mode.width > 0 ? Double(mode.pixelWidth) / Double(mode.width) : 1
            menu.addItem(infoItem(label: "显示模式", value: "\(mode.width) × \(mode.height)\(refreshText)"))
            menu.addItem(infoItem(
                label: "渲染分辨率",
                value: String(format: "%d × %d · %.0f× HiDPI", mode.pixelWidth, mode.pixelHeight, scale)
            ))
        }
        menu.addItem(infoItem(label: "位置", value: relativePosition(of: display.id)))
        if let screen {
            let potentialEDR = screen.maximumPotentialExtendedDynamicRangeColorComponentValue
            let edr = potentialEDR > 1
                ? String(format: "支持 · 最高 %.1f×", potentialEDR)
                : "标准动态范围"
            menu.addItem(infoItem(label: "HDR / EDR", value: edr))
            menu.addItem(infoItem(label: "色彩配置", value: screen.colorSpace?.localizedName ?? "不可用"))
        } else {
            menu.addItem(infoItem(label: "HDR / EDR", value: "显示器停用时不可用"))
        }
        menu.addItem(.separator())
        let technical = NSMenuItem(title: "技术信息", action: nil, keyEquivalent: "")
        technical.submenu = technicalMenu(for: display, mode: mode)
        menu.addItem(technical)
        return menu
    }

    private func technicalMenu(for display: DisplayInfo, mode: CGDisplayMode?) -> NSMenu {
        let menu = NSMenu(title: "技术信息")
        let bounds = CGDisplayBounds(display.id)
        let size = CGDisplayScreenSize(display.id)
        let diagonal = hypot(size.width, size.height) / 25.4
        let mirrorSource = CGDisplayMirrorsDisplay(display.id)

        menu.addItem(infoItem(label: "Display ID", value: String(display.id), emphasized: true))
        menu.addItem(infoItem(label: "UUID", value: uuidString(for: display.id)))
        menu.addItem(infoItem(
            label: "厂商 / 型号",
            value: "0x\(String(display.vendor, radix: 16, uppercase: true)) / 0x\(String(display.model, radix: 16, uppercase: true))"
        ))
        menu.addItem(infoItem(label: "序列号", value: String(CGDisplaySerialNumber(display.id))))
        menu.addItem(infoItem(label: "Unit Number", value: String(CGDisplayUnitNumber(display.id))))
        menu.addItem(infoItem(
            label: "物理尺寸",
            value: String(format: "%.1f × %.1f mm · %.1f 英寸", size.width, size.height, diagonal)
        ))
        menu.addItem(infoItem(
            label: "全局坐标",
            value: String(format: "x %.0f · y %.0f · %.0f × %.0f", bounds.minX, bounds.minY, bounds.width, bounds.height)
        ))
        menu.addItem(infoItem(label: "主显示器", value: CGDisplayIsMain(display.id) != 0 ? "是" : "否"))
        menu.addItem(infoItem(label: "旋转", value: String(format: "%.0f°", CGDisplayRotation(display.id))))
        menu.addItem(infoItem(label: "休眠", value: CGDisplayIsAsleep(display.id) != 0 ? "是" : "否"))
        menu.addItem(infoItem(label: "镜像组", value: CGDisplayIsInMirrorSet(display.id) != 0 ? "是" : "否"))
        menu.addItem(infoItem(
            label: "镜像源",
            value: mirrorSource == kCGNullDirectDisplay ? "无" : String(mirrorSource)
        ))
        let modeCount = (CGDisplayCopyAllDisplayModes(display.id, nil) as? [CGDisplayMode])?.count
        menu.addItem(infoItem(label: "可用模式", value: modeCount.map(String.init) ?? "不可用"))
        if let mode {
            menu.addItem(infoItem(label: "Mode ID", value: String(mode.ioDisplayModeID)))
            menu.addItem(infoItem(label: "IO Flags", value: "0x\(String(mode.ioFlags, radix: 16, uppercase: true))"))
        }
        return menu
    }

    private func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == displayID
        }
    }

    private func displayName(for display: DisplayInfo) -> String {
        if display.builtIn { return "内建显示器" }
        return screen(for: display.id)?.localizedName ?? display.name
    }

    private func uuidString(for displayID: CGDirectDisplayID) -> String {
        guard let unmanaged = CGDisplayCreateUUIDFromDisplayID(displayID) else { return "不可用" }
        let uuid = unmanaged.takeRetainedValue()
        return CFUUIDCreateString(nil, uuid) as String? ?? "不可用"
    }

    private func relativePosition(of displayID: CGDirectDisplayID) -> String {
        if CGDisplayIsMain(displayID) != 0 { return "主显示器" }
        guard CGDisplayIsOnline(displayID) != 0 else { return "显示器已停用" }
        let frame = CGDisplayBounds(displayID)
        let mainFrame = CGDisplayBounds(CGMainDisplayID())
        if frame.maxY <= mainFrame.minY { return "主显示器上方" }
        if frame.minY >= mainFrame.maxY { return "主显示器下方" }
        if frame.maxX <= mainFrame.minX { return "主显示器左侧" }
        if frame.minX >= mainFrame.maxX { return "主显示器右侧" }
        return "与主显示器部分重叠"
    }

    private func infoItem(label: String, value: String?, emphasized: Bool = false) -> NSMenuItem {
        let item = NSMenuItem()
        let textField = NSTextField(labelWithString: "")

        let text = value.map { "\(label)   \($0)" } ?? label
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
                .foregroundColor: NSColor.labelColor
            ]
        )
        let labelRange = NSRange(location: 0, length: (label as NSString).length)
        attributed.addAttribute(
            .font,
            value: NSFont.systemFont(
                ofSize: NSFont.systemFontSize,
                weight: emphasized ? .bold : .semibold
            ),
            range: labelRange
        )
        textField.attributedStringValue = attributed

        let textSize = textField.fittingSize
        let textWidth = ceil(textSize.width)
        let textHeight = max(18, ceil(textSize.height))
        textField.frame = NSRect(x: 14, y: 3, width: textWidth, height: textHeight)

        let container = NSView(
            frame: NSRect(x: 0, y: 0, width: textWidth + 28, height: textHeight + 6)
        )
        container.addSubview(textField)
        item.view = container
        return item
    }

    @objc private func toggleDisplay(_ sender: NSMenuItem) {
        guard let displayID = (sender.representedObject as? NSNumber)?.uint32Value else { return }
        do {
            guard let display = try controller.externalDisplays().first(where: { $0.id == displayID }) else {
                throw DisplayError.notFound(String(displayID))
            }
            try controller.setEnabled(!display.enabled, for: display)
            updateStatusIcon()
        } catch {
            showError(error)
        }
    }

    @objc private func setMainDisplay(_ sender: NSMenuItem) {
        guard let displayID = (sender.representedObject as? NSNumber)?.uint32Value else { return }
        do {
            guard let display = try controller.controllableDisplays().first(where: { $0.id == displayID }) else {
                throw DisplayError.notFound(String(displayID))
            }
            try controller.setMainDisplay(display)
            updateStatusIcon()
        } catch {
            showError(error)
        }
    }

    private func showError(_ error: Error) {
        NSSound.beep(); let alert = NSAlert(); alert.messageText = "Display change failed"; alert.informativeText = error.localizedDescription; alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate(); app.delegate = delegate
app.run()
