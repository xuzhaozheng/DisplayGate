import Foundation
import CoreGraphics
import SkyLightBridge

public enum DisplayConnectionState: String, Sendable {
    case active
    case onlineInactive
    case disconnected
}

public struct DisplayInfo: Identifiable, Sendable {
    public let id: CGDirectDisplayID
    public let name: String
    public let builtIn: Bool
    public let online: Bool
    public let active: Bool
    public let main: Bool
    public let mirrored: Bool
    public let vendor: UInt32
    public let model: UInt32
    public let pixelWidth: Int
    public let pixelHeight: Int
    public var controllable: Bool {
        builtIn || vendor != 0 || model != 0 || pixelWidth > 1 || pixelHeight > 1
    }
    public var state: DisplayConnectionState {
        if active { return .active }
        if online { return .onlineInactive }
        return .disconnected
    }
    public var enabled: Bool { state == .active }
    public init(id: CGDirectDisplayID, name: String, builtIn: Bool, online: Bool, active: Bool,
                main: Bool, mirrored: Bool,
                vendor: UInt32, model: UInt32, pixelWidth: Int, pixelHeight: Int) {
        self.id = id; self.name = name; self.builtIn = builtIn; self.online = online
        self.active = active; self.main = main; self.mirrored = mirrored
        self.vendor = vendor; self.model = model
        self.pixelWidth = pixelWidth; self.pixelHeight = pixelHeight
    }
}

public enum DisplayError: Error, CustomStringConvertible, LocalizedError {
    case privateAPIUnavailable, builtInRejected, lastDisplay, notControllable
    case inactiveDisplay, mirroredDisplay
    case notFound(String), ambiguous(String), operationFailed(String)
    public var description: String {
        switch self {
        case .privateAPIUnavailable: return "SkyLight private API is unavailable."
        case .builtInRejected: return "The built-in display is not controlled by this tool."
        case .lastDisplay: return "Refusing to disable the last active display."
        case .notControllable: return "The selected SkyLight display is a placeholder and cannot be controlled."
        case .inactiveDisplay: return "Only an active display can become the main display."
        case .mirroredDisplay: return "The main display cannot be changed while display mirroring is active. Disable mirroring first."
        case .notFound(let s): return "No display matched '\(s)'."
        case .ambiguous(let s): return "More than one display matched '\(s)'; use the numeric ID."
        case .operationFailed(let s): return s
        }
    }
    public var errorDescription: String? { description }
}

public final class DisplayController {
    public init() {}
    private func ids(from getter: (UInt32, UnsafeMutablePointer<CGDirectDisplayID>?, UnsafeMutablePointer<UInt32>) -> CGError) -> Set<CGDirectDisplayID> {
        var count: UInt32 = 0; _ = getter(0, nil, &count); guard count > 0 else { return [] }
        var values = [CGDirectDisplayID](repeating: 0, count: Int(count)); _ = getter(count, &values, &count)
        return Set(values.prefix(Int(count)))
    }
    private func allIDs() throws -> [CGDirectDisplayID] {
        if sl_is_available() {
            var count: UInt32 = 0; guard sl_get_display_list(0, nil, &count) else { throw DisplayError.privateAPIUnavailable }
            var values = [CGDirectDisplayID](repeating: 0, count: Int(count)); guard sl_get_display_list(count, &values, &count) else { throw DisplayError.operationFailed("SLSGetDisplayList failed.") }
            return Array(values.prefix(Int(count)))
        }
        return Array(ids(from: CGGetOnlineDisplayList).union(ids(from: CGGetActiveDisplayList)))
    }
    private func name(for id: CGDirectDisplayID) -> String {
        var buffer = [CChar](repeating: 0, count: 256)
        return sl_copy_display_name(id, &buffer, buffer.count) ? String(cString: buffer) : "Display \(id)"
    }
    public func displays() throws -> [DisplayInfo] {
        let online = ids(from: CGGetOnlineDisplayList), active = ids(from: CGGetActiveDisplayList)
        return try allIDs().sorted().map { id in
            DisplayInfo(id: id, name: name(for: id), builtIn: CGDisplayIsBuiltin(id) != 0,
                        online: online.contains(id), active: active.contains(id),
                        main: CGDisplayIsMain(id) != 0, mirrored: CGDisplayIsInMirrorSet(id) != 0,
                        vendor: CGDisplayVendorNumber(id), model: CGDisplayModelNumber(id),
                        pixelWidth: CGDisplayPixelsWide(id), pixelHeight: CGDisplayPixelsHigh(id))
        }
    }
    public func externalDisplays() throws -> [DisplayInfo] {
        try displays().filter { !$0.builtIn && $0.controllable }
    }
    public func controllableDisplays() throws -> [DisplayInfo] {
        try displays().filter(\.controllable)
    }
    public func resolve(_ selector: String) throws -> DisplayInfo {
        let list = try displays(); if let id = UInt32(selector), let exact = list.first(where: { $0.id == id }) { return exact }
        let matches = list.filter { $0.name.localizedCaseInsensitiveContains(selector) }
        guard matches.count == 1, let result = matches.first else { if matches.isEmpty { throw DisplayError.notFound(selector) }; throw DisplayError.ambiguous(selector) }
        return result
    }
    public func setEnabled(_ enabled: Bool, for display: DisplayInfo) throws {
        if display.builtIn { throw DisplayError.builtInRejected }; if display.enabled == enabled { return }
        if !display.controllable { throw DisplayError.notControllable }
        try apply(enabled, to: [display])
    }
    public func setMainDisplay(_ display: DisplayInfo) throws {
        let currentDisplays = try displays()
        guard let current = currentDisplays.first(where: { $0.id == display.id }) else {
            throw DisplayError.notFound(String(display.id))
        }
        if !current.controllable { throw DisplayError.notControllable }
        if !current.active { throw DisplayError.inactiveDisplay }
        if current.main { return }

        let activeDisplays = currentDisplays.filter(\.active)
        if activeDisplays.contains(where: \.mirrored) {
            throw DisplayError.mirroredDisplay
        }

        let targetOrigin = CGDisplayBounds(current.id).origin
        var config: CGDisplayConfigRef?
        let begin = CGBeginDisplayConfiguration(&config)
        guard begin == .success, let config else {
            throw DisplayError.operationFailed("CGBeginDisplayConfiguration failed (\(begin.rawValue)).")
        }

        for activeDisplay in activeDisplays {
            let origin = CGDisplayBounds(activeDisplay.id).origin
            guard let x = Int32(exactly: origin.x - targetOrigin.x),
                  let y = Int32(exactly: origin.y - targetOrigin.y) else {
                CGCancelDisplayConfiguration(config)
                throw DisplayError.operationFailed("Display origin is outside the supported coordinate range.")
            }
            let result = CGConfigureDisplayOrigin(config, activeDisplay.id, x, y)
            guard result == .success else {
                CGCancelDisplayConfiguration(config)
                throw DisplayError.operationFailed("CGConfigureDisplayOrigin failed for \(activeDisplay.name) (\(result.rawValue)).")
            }
        }

        let commit = CGCompleteDisplayConfiguration(config, .forSession)
        guard commit == .success else {
            CGCancelDisplayConfiguration(config)
            throw DisplayError.operationFailed("CGCompleteDisplayConfiguration failed (\(commit.rawValue)).")
        }
    }
    private func apply(_ enabled: Bool, to targets: [DisplayInfo]) throws {
        guard !targets.isEmpty else { return }
        if !enabled {
            let targetIDs = Set(targets.map(\.id))
            let hasOtherActive = try displays().contains {
                $0.active && $0.controllable && !targetIDs.contains($0.id)
            }
            if !hasOtherActive { throw DisplayError.lastDisplay }
        }
        guard sl_is_available() else { throw DisplayError.privateAPIUnavailable }
        var config: CGDisplayConfigRef?; let begin = CGBeginDisplayConfiguration(&config)
        guard begin == .success, let config else { throw DisplayError.operationFailed("CGBeginDisplayConfiguration failed (\(begin.rawValue)).") }
        for display in targets {
            let result = sl_configure_display_enabled(config, display.id, enabled)
            guard result == .success else {
                CGCancelDisplayConfiguration(config)
                throw DisplayError.operationFailed("SLSConfigureDisplayEnabled failed for \(display.name) (\(result.rawValue)).")
            }
        }
        let commit = CGCompleteDisplayConfiguration(config, .forSession)
        guard commit == .success else { CGCancelDisplayConfiguration(config); throw DisplayError.operationFailed("CGCompleteDisplayConfiguration failed (\(commit.rawValue)).") }
    }
    public func setAllExternalEnabled(_ enabled: Bool) throws {
        let targets = try externalDisplays().filter { $0.enabled != enabled }
        try apply(enabled, to: targets)
    }
    public func toggleAllExternal() throws {
        let list = try externalDisplays(); guard !list.isEmpty else { return }
        try setAllExternalEnabled(!list.allSatisfy(\.enabled))
    }
}
