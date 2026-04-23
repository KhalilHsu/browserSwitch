import CoreGraphics
import Testing
@testable import BrowserRouter

@Suite("KeyStateMonitor")
struct KeyStateMonitorTests {

    @Test func flagsChangedUpdatesCachedFlags() {
        let monitor = makeMonitor()
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else {
            Issue.record("Failed to create CGEvent")
            return
        }
        event.flags = [.maskCommand, .maskShift]

        invokeCallback(monitor: monitor, type: .flagsChanged, event: event)

        #expect(monitor.cachedFlags == [.maskCommand, .maskShift])
    }

    @Test func keyDownAddsToPressedKeyCodes() {
        let monitor = makeMonitor()
        let keyCode: CGKeyCode = 12
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
            Issue.record("Failed to create CGEvent")
            return
        }

        invokeCallback(monitor: monitor, type: .keyDown, event: event)

        #expect(monitor.pressedKeyCodes.contains(Int(keyCode)))
    }

    @Test func keyUpRemovesFromPressedKeyCodes() {
        let monitor = makeMonitor()
        let keyCode: CGKeyCode = 12
        guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            Issue.record("Failed to create CGEvent")
            return
        }

        invokeCallback(monitor: monitor, type: .keyDown, event: keyDownEvent)
        #expect(monitor.pressedKeyCodes.contains(Int(keyCode)))

        invokeCallback(monitor: monitor, type: .keyUp, event: keyUpEvent)
        #expect(!monitor.pressedKeyCodes.contains(Int(keyCode)))
    }

    @Test func tapDisabledReenablesTap() {
        let monitor = makeMonitor()
        guard let event = CGEvent(source: nil) else {
            Issue.record("Failed to create CGEvent")
            return
        }

        var context = CFMachPortContext()
        let dummyPort = CFMachPortCreate(kCFAllocatorDefault, { _, _, _, _ in }, &context, nil)
        monitor.eventTap = dummyPort

        var enableCallCount = 0
        var lastEnableValue = false
        monitor.tapEnableHandler = { _, enable in
            enableCallCount += 1
            lastEnableValue = enable
        }

        invokeCallback(monitor: monitor, type: .tapDisabledByTimeout, event: event)
        #expect(enableCallCount == 1)
        #expect(lastEnableValue)

        invokeCallback(monitor: monitor, type: .tapDisabledByUserInput, event: event)
        #expect(enableCallCount == 2)
        #expect(lastEnableValue)
    }
}

private func makeMonitor() -> KeyStateMonitor {
    KeyStateMonitor()
}

private func invokeCallback(monitor: KeyStateMonitor, type: CGEventType, event: CGEvent) {
    let info = Unmanaged.passUnretained(monitor).toOpaque()
    let proxy = OpaquePointer(bitPattern: 1)!
    _ = KeyStateMonitor.tapCallback(proxy, type, event, info)
}
