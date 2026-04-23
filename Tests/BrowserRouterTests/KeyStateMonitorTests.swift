import XCTest
import CoreGraphics
@testable import BrowserRouter

final class KeyStateMonitorTests: XCTestCase {

    var monitor: KeyStateMonitor!

    override func setUp() {
        super.setUp()
        monitor = KeyStateMonitor()
        // We only test the callback logic, not the actual system hook installation,
        // so we don't call monitor.start() directly.
    }

    override func tearDown() {
        monitor = nil
        super.tearDown()
    }

    // Helper to invoke the callback just like the system would
    private func invokeCallback(type: CGEventType, event: CGEvent) {
        let info = Unmanaged.passUnretained(monitor).toOpaque()
        let proxy = OpaquePointer(bitPattern: 1)!
        _ = KeyStateMonitor.tapCallback(proxy, type, event, info)
    }

    func testFlagsChangedUpdatesCachedFlags() {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else {
            XCTFail("Failed to create CGEvent")
            return
        }
        event.flags = [.maskCommand, .maskShift]

        invokeCallback(type: .flagsChanged, event: event)

        XCTAssertEqual(monitor.cachedFlags, [.maskCommand, .maskShift])
    }

    func testKeyDownAddsToPressedKeyCodes() {
        let keyCode: CGKeyCode = 12 // 'Q'
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
            XCTFail("Failed to create CGEvent")
            return
        }

        invokeCallback(type: .keyDown, event: event)

        XCTAssertTrue(monitor.pressedKeyCodes.contains(Int(keyCode)))
    }

    func testKeyUpRemovesFromPressedKeyCodes() {
        let keyCode: CGKeyCode = 12 // 'Q'
        guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            XCTFail("Failed to create CGEvent")
            return
        }

        invokeCallback(type: .keyDown, event: keyDownEvent)
        XCTAssertTrue(monitor.pressedKeyCodes.contains(Int(keyCode)))

        invokeCallback(type: .keyUp, event: keyUpEvent)
        XCTAssertFalse(monitor.pressedKeyCodes.contains(Int(keyCode)))
    }

    func testTapDisabledDoesNotCrashAndAttemptsEnable() {
        guard let event = CGEvent(source: nil) else { return }

        // Create a dummy CFMachPort to simulate an active tap
        var context = CFMachPortContext()
        let dummyPort = CFMachPortCreate(kCFAllocatorDefault, { _, _, _, _ in }, &context, nil)
        monitor.eventTap = dummyPort

        var enableCallCount = 0
        var lastEnableValue = false

        // Inject our mock handler
        monitor.tapEnableHandler = { port, enable in
            enableCallCount += 1
            lastEnableValue = enable
        }

        // Send a tapDisabledByTimeout event
        invokeCallback(type: .tapDisabledByTimeout, event: event)
        XCTAssertEqual(enableCallCount, 1)
        XCTAssertTrue(lastEnableValue)

        // Send a tapDisabledByUserInput event
        invokeCallback(type: .tapDisabledByUserInput, event: event)
        XCTAssertEqual(enableCallCount, 2)
        XCTAssertTrue(lastEnableValue)
    }
}
