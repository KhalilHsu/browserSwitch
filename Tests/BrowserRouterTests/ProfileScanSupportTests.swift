import XCTest
@testable import BrowserRouter
import BrowserRouterCore

final class ProfileScanSupportTests: XCTestCase {
    private func option(_ id: String, name: String, directory: String?, hidden: Bool = false) -> BrowserOption {
        BrowserOption(
            id: id,
            name: name,
            bundleIdentifier: "com.google.Chrome",
            appName: "Google Chrome",
            profileDirectory: directory,
            extraArguments: nil,
            isHidden: hidden
        )
    }

    func testMergeKeepsSettingsHiddenStateAndOrder() {
        var configuration = RouterConfiguration(
            defaultOptionID: "chrome-default",
            chooserModifier: ChooserModifier.custom.rawValue,
            showsDockIcon: false,
            showsStatusItem: true,
            hasCompletedOnboarding: true,
            autoRestoreDefaultBrowserOnQuit: false,
            previousDefaultBrowser: nil,
            browserOptions: [
                option("safari", name: "Safari", directory: nil),
                option("chrome-profile-1", name: "Chrome - Ivette", directory: "Profile 1", hidden: true)
            ],
            routingRules: []
        )
        configuration.customChooserFlags = 42
        configuration.customChooserKeyCode = 7

        let merged = ProfileScanSupport.merge([
            option("chrome-profile-1", name: "Chrome - Ivette", directory: "Profile 1"),
            option("chrome-profile-2", name: "Chrome - Abraham", directory: "Profile 2")
        ], into: configuration)

        XCTAssertEqual(merged.browserOptions.map(\.id), ["safari", "chrome-profile-1", "chrome-profile-2"])
        XCTAssertTrue(merged.browserOptions[1].isHidden)
        XCTAssertFalse(merged.autoRestoreDefaultBrowserOnQuit)
        XCTAssertEqual(merged.customChooserFlags, 42)
        XCTAssertEqual(merged.customChooserKeyCode, 7)
    }

    func testPermissionErrorsAreRecognized() {
        let tccDenied = NSError(
            domain: NSCocoaErrorDomain,
            code: NSFileReadNoPermissionError,
            userInfo: [NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: Int(EPERM))]
        )
        let missing = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError)

        XCTAssertTrue(ProfileScanSupport.isPermissionError(tccDenied))
        XCTAssertTrue(ProfileScanSupport.isPermissionError(NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES))))
        XCTAssertFalse(ProfileScanSupport.isPermissionError(missing))
    }

    func testReadReportsMissingFile() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        guard case .missing = ProfileScanSupport.read(url, parse: { $0 }) else {
            return XCTFail("A missing file should not be reported as a permission problem")
        }
    }

    func testToolingBundlesAreSkipped() {
        XCTAssertTrue(BrowserInventory.isToolingBundle(URL(fileURLWithPath:
            "/Users/me/project/node_modules/.remotion/chrome-for-testing/Google Chrome for Testing.app")))
        XCTAssertTrue(BrowserInventory.isToolingBundle(URL(fileURLWithPath:
            "/Users/me/.cache/ms-playwright/chromium-1/Chromium.app")))
        XCTAssertFalse(BrowserInventory.isToolingBundle(URL(fileURLWithPath: "/Applications/Google Chrome.app")))
    }
}
