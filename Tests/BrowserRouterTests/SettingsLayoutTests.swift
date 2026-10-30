import XCTest
@testable import BrowserRouter
import BrowserRouterCore

@MainActor
final class SettingsLayoutTests: XCTestCase {
    func testLongRuleTesterResultDoesNotWidenSettingsWindow() throws {
        let configuration = RouterConfiguration(
            defaultOptionID: "safari",
            chooserModifier: ChooserModifier.commandShift.rawValue,
            showsDockIcon: false,
            showsStatusItem: true,
            hasCompletedOnboarding: true,
            autoRestoreDefaultBrowserOnQuit: false,
            previousDefaultBrowser: nil,
            browserOptions: [],
            routingRules: []
        )
        let controller = SettingsWindowController(
            configuration: configuration,
            onSave: { _ in },
            onRestoreDefaultBrowser: {},
            onLanguageChange: {}
        )
        let window = try XCTUnwrap(controller.window)
        controller.settingsTabViewController.selectedTabViewItemIndex = 1
        window.layoutIfNeeded()
        let initialWidth = window.frame.width

        controller.ruleTesterURLField.stringValue = "baidu.com/a/very/long/path/that/keeps/going?with=query&and=more&even=longer"
        controller.updateRuleTesterResult()
        window.layoutIfNeeded()

        XCTAssertLessThanOrEqual(controller.ruleTesterResultLabel.intrinsicContentSize.width, SettingsStyle.contentWidth + 1)
        XCTAssertEqual(window.frame.width, initialWidth, accuracy: 0.5)
    }
}
