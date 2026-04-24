import XCTest
@testable import BrowserRouter
import BrowserRouterCore

final class BrowserInventoryTests: XCTestCase {
    func testRefreshConfigurationPreservesAutoRestorePreference() {
        // Arrange
        let initialConfig = RouterConfiguration(
            defaultOptionID: "safari",
            chooserModifier: ChooserModifier.commandShift.rawValue,
            showsDockIcon: false,
            showsStatusItem: true,
            hasCompletedOnboarding: true,
            autoRestoreDefaultBrowserOnQuit: false, // Ensure false is preserved
            previousDefaultBrowser: nil,
            browserOptions: [],
            routingRules: []
        )

        // Act
        let result = BrowserInventory.refreshConfiguration(initialConfig)

        // Assert
        XCTAssertFalse(result.configuration.autoRestoreDefaultBrowserOnQuit, "autoRestoreDefaultBrowserOnQuit should be preserved as false")

        // Arrange 2
        let initialConfigTrue = RouterConfiguration(
            defaultOptionID: "safari",
            chooserModifier: ChooserModifier.commandShift.rawValue,
            showsDockIcon: false,
            showsStatusItem: true,
            hasCompletedOnboarding: true,
            autoRestoreDefaultBrowserOnQuit: true, // Ensure true is preserved
            previousDefaultBrowser: nil,
            browserOptions: [],
            routingRules: []
        )

        // Act 2
        let resultTrue = BrowserInventory.refreshConfiguration(initialConfigTrue)

        // Assert 2
        XCTAssertTrue(resultTrue.configuration.autoRestoreDefaultBrowserOnQuit, "autoRestoreDefaultBrowserOnQuit should be preserved as true")
    }
}
