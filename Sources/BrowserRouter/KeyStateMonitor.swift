import AppKit
import CoreGraphics
import OSLog

private let keyMonitorLogger = Logger(subsystem: "local.browser-router", category: "key-monitor")

/// Maintains a real-time cache of global keyboard state.
///
/// Tries three strategies in order:
///   1. CGEventTap (listenOnly) — full coverage, needs Accessibility permission.
///   2. NSEvent global monitor  — covers modifier keys, may work without permission.
///   3. Polling fallback        — always works, timing-sensitive (original behaviour).
final class KeyStateMonitor {

    enum Mode: String { case eventTap, nsMonitor, polling }
    private(set) var mode: Mode = .polling

    // Cached state — main-thread only
    private(set) var cachedFlags: CGEventFlags = []
    private(set) var pressedKeyCodes: Set<Int> = []

    var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var nsMonitors: [Any] = []
    private var notificationObservers: [Any] = []

    // MARK: - Lifecycle

    func start() {
        resetCache()
        let center = NotificationCenter.default
        notificationObservers.append(center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.resetCache()
        })

        if tryInstallEventTap() {
            mode = .eventTap
            keyMonitorLogger.info("KeyStateMonitor: CGEventTap active (full coverage)")
        } else if tryInstallNSEventMonitor() {
            mode = .nsMonitor
            keyMonitorLogger.info("KeyStateMonitor: NSEvent monitor active (fallback)")
        } else {
            mode = .polling
            keyMonitorLogger.warning("KeyStateMonitor: polling fallback — grant Accessibility for better accuracy")
        }
    }

    func stop() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        eventTap = nil
        runLoopSource = nil
        nsMonitors.forEach { NSEvent.removeMonitor($0) }
        nsMonitors.removeAll()
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        notificationObservers.removeAll()
        mode = .polling
    }

    func resetCache() {
        cachedFlags = CGEventSource.flagsState(.hidSystemState)
        pressedKeyCodes.removeAll()
    }

    // MARK: - Queries

    /// Current modifier flags from cache, or live HID poll if no monitor is active.
    var effectiveFlags: CGEventFlags {
        mode == .polling ? CGEventSource.flagsState(.hidSystemState) : cachedFlags
    }

    /// Returns true if all bits in `required` are set among the modifier keys currently held.
    func modifiersMatch(_ required: CGEventFlags) -> Bool {
        let mask: CGEventFlags = [.maskControl, .maskAlternate, .maskShift, .maskCommand]
        return effectiveFlags.intersection(mask) == required.intersection(mask)
    }

    /// Returns true if the given virtual key code is currently held.
    func isKeyPressed(_ keyCode: Int) -> Bool {
        if mode == .eventTap {
            return pressedKeyCodes.contains(keyCode)
        }
        // NSMonitor may have partial keyDown data; also poll HID as backup.
        return pressedKeyCodes.contains(keyCode)
            || CGEventSource.keyState(.hidSystemState, key: CGKeyCode(keyCode))
    }

    // MARK: - CGEventTap

    private func tryInstallEventTap() -> Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        guard AXIsProcessTrustedWithOptions(opts) else { return false }

        let mask = CGEventMask(
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue)
        )

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: KeyStateMonitor.tapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = src
        return true
    }

    // Dependency injection for testing the C API
    var tapEnableHandler: (CFMachPort, Bool) -> Void = { tap, enable in
        CGEvent.tapEnable(tap: tap, enable: enable)
    }

    /// C-compatible callback; runs on the main run loop (added to CFRunLoopGetMain).
    static let tapCallback: CGEventTapCallBack = { _, type, event, info in
        guard let info else {
            // No user-info pointer — pass through without retaining (we don't own the event).
            return Unmanaged.passUnretained(event)
        }
        let m = Unmanaged<KeyStateMonitor>.fromOpaque(info).takeUnretainedValue()

        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // The system disabled our tap (e.g. it was too slow, or the user triggered a
            // secure input field). Re-enable it immediately so the cache stays fresh.
            // For listen-only taps the return value is ignored; nil is safest here since
            // these pseudo-events carry no real CGEvent payload we should propagate.
            if let tap = m.eventTap {
                m.tapEnableHandler(tap, true)
                keyMonitorLogger.info("KeyStateMonitor: tap re-enabled after disable (\(type.rawValue))")
            }
            return nil

        case .flagsChanged:
            m.cachedFlags = event.flags

        case .keyDown:
            m.pressedKeyCodes.insert(Int(event.getIntegerValueField(.keyboardEventKeycode)))

        case .keyUp:
            m.pressedKeyCodes.remove(Int(event.getIntegerValueField(.keyboardEventKeycode)))

        default:
            break
        }

        // Return the system's event unretained: we are a listen-only tap and do not own
        // this CGEvent. Returning passRetained would leak one object per key transition.
        return Unmanaged.passUnretained(event)
    }

    // MARK: - NSEvent global monitor

    private func tryInstallNSEventMonitor() -> Bool {
        // Global monitors (when app is in background)
        // flagsChanged typically doesn't require Input Monitoring permission.
        guard let gFm = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] e in
            self?.cachedFlags = e.modifierFlags.asCGEventFlags
        }) else { return false }
        nsMonitors.append(gFm)

        // keyDown/keyUp require Input Monitoring — add silently if available.
        if let gDm = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] e in
            self?.pressedKeyCodes.insert(Int(e.keyCode))
        }) { nsMonitors.append(gDm) }

        if let gUm = NSEvent.addGlobalMonitorForEvents(matching: .keyUp, handler: { [weak self] e in
            self?.pressedKeyCodes.remove(Int(e.keyCode))
        }) { nsMonitors.append(gUm) }

        // Local monitors (when app is in foreground, e.g. Chooser is visible)
        if let lFm = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] e in
            self?.cachedFlags = e.modifierFlags.asCGEventFlags
            return e
        }) { nsMonitors.append(lFm) }

        if let lDm = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] e in
            self?.pressedKeyCodes.insert(Int(e.keyCode))
            return e
        }) { nsMonitors.append(lDm) }

        if let lUm = NSEvent.addLocalMonitorForEvents(matching: .keyUp, handler: { [weak self] e in
            self?.pressedKeyCodes.remove(Int(e.keyCode))
            return e
        }) { nsMonitors.append(lUm) }

        return true
    }
}

private extension NSEvent.ModifierFlags {
    var asCGEventFlags: CGEventFlags {
        var f = CGEventFlags()
        if contains(.control) { f.insert(.maskControl) }
        if contains(.option)  { f.insert(.maskAlternate) }
        if contains(.shift)   { f.insert(.maskShift) }
        if contains(.command) { f.insert(.maskCommand) }
        return f
    }
}
