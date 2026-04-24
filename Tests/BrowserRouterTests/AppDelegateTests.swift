import AppKit
import CoreGraphics
import XCTest
@testable import BrowserRouter

@MainActor
final class AppDelegateTests: XCTestCase {

    func testShouldShowChooserResetsAfterResignActive() {
        let appDelegate = AppDelegate()
        
        // Start the key monitor manually as we are bypassing applicationDidFinishLaunching
        appDelegate.keyMonitor.start()
        
        // 1. Simulate the user pressing Command + Shift in a background app (e.g. WeChat)
        guard let flagsEvent = CGEvent(source: nil) else {
            XCTFail("Failed to create CGEvent")
            return
        }
        flagsEvent.type = .flagsChanged
        flagsEvent.flags = [.maskCommand, .maskShift]
        
        let info = Unmanaged.passUnretained(appDelegate.keyMonitor).toOpaque()
        let proxy = OpaquePointer(bitPattern: 1)!
        _ = KeyStateMonitor.tapCallback(proxy, .flagsChanged, flagsEvent, info)
        
        // Ensure that shouldShowChooser is true based on the pressed keys
        XCTAssertTrue(appDelegate.shouldShowChooser(), "Chooser should show when shortcut is pressed")
        
        // 2. Simulate the user dismissing the chooser. The chooser closes and the app goes to the background.
        NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: nil)
        
        // 3. User switches back to WeChat, no keys are pressed. We don't simulate a release because 
        // the app might miss it or the user might have released it while the app was tracking menu.
        // We just ensure that the cache has been cleared correctly so the chooser won't mistakenly show again.
        
        // Note: resetCache pulls the live hidSystemState. Since no keys are physically pressed by the test runner,
        // the cached flags will become empty (or standard system state without modifiers).
        
        XCTAssertFalse(appDelegate.shouldShowChooser(), "Chooser should NOT show after app goes to background, clearing the stale key state")
        
        appDelegate.keyMonitor.stop()
    }
}
