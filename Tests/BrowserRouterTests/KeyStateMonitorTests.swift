import CoreGraphics
import XCTest
@testable import BrowserRouter

final class KeyStateMonitorTests: XCTestCase {

    func testFlagsChangedUpdatesCachedFlags() {
        let monitor = makeMonitor()
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else {
            XCTFail("Failed to create CGEvent")
            return
        }
        event.flags = [.maskCommand, .maskShift]

        invokeCallback(monitor: monitor, type: .flagsChanged, event: event)

        XCTAssertEqual(monitor.cachedFlags, [.maskCommand, .maskShift])
    }

    func testKeyDownAddsToPressedKeyCodes() {
        let monitor = makeMonitor()
        let keyCode: CGKeyCode = 12
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
            XCTFail("Failed to create CGEvent")
            return
        }

        invokeCallback(monitor: monitor, type: .keyDown, event: event)

        XCTAssertTrue(monitor.pressedKeyCodes.contains(Int(keyCode)))
    }

    func testKeyUpRemovesFromPressedKeyCodes() {
        let monitor = makeMonitor()
        let keyCode: CGKeyCode = 12
        guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            XCTFail("Failed to create CGEvent")
            return
        }

        invokeCallback(monitor: monitor, type: .keyDown, event: keyDownEvent)
        XCTAssertTrue(monitor.pressedKeyCodes.contains(Int(keyCode)))

        invokeCallback(monitor: monitor, type: .keyUp, event: keyUpEvent)
        XCTAssertFalse(monitor.pressedKeyCodes.contains(Int(keyCode)))
    }

    func testTapDisabledReenablesTap() {
        let monitor = makeMonitor()
        guard let event = CGEvent(source: nil) else {
            XCTFail("Failed to create CGEvent")
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
        XCTAssertEqual(enableCallCount, 1)
        XCTAssertTrue(lastEnableValue)

        invokeCallback(monitor: monitor, type: .tapDisabledByUserInput, event: event)
        XCTAssertEqual(enableCallCount, 2)
        XCTAssertTrue(lastEnableValue)
    }

    private func makeMonitor() -> KeyStateMonitor {
        KeyStateMonitor()
    }

    private func invokeCallback(monitor: KeyStateMonitor, type: CGEventType, event: CGEvent) {
        let info = Unmanaged.passUnretained(monitor).toOpaque()
        let proxy = OpaquePointer(bitPattern: 1)!
        _ = KeyStateMonitor.tapCallback(proxy, type, event, info)
    }
}
