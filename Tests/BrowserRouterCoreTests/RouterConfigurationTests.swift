import Foundation
import XCTest
@testable import BrowserRouterCore

final class RouterConfigurationTests: XCTestCase {
    func testLegacyConfigurationDecodesNewPresentationDefaults() throws {
        let json = """
        {
          "defaultOptionID": "arc-default",
          "chooserModifier": "command+shift",
          "browserOptions": [],
          "routingRules": []
        }
        """

        let configuration = try JSONDecoder().decode(RouterConfiguration.self, from: Data(json.utf8))

        XCTAssertFalse(configuration.showsDockIcon)
        XCTAssertTrue(configuration.showsStatusItem)
        XCTAssertTrue(configuration.hasCompletedOnboarding)
        XCTAssertNil(configuration.previousDefaultBrowser)
    }

    func testLegacyRoutingRuleDecodesEnabledByDefault() throws {
        let json = """
        {
          "id": "legacy",
          "name": "Legacy",
          "browserOptionID": "chrome",
          "hostSuffix": "example.com"
        }
        """

        let rule = try JSONDecoder().decode(RoutingRule.self, from: Data(json.utf8))

        XCTAssertTrue(rule.isEnabled)
    }

    func testSampleConfigurationRequiresOnboarding() {
        let configuration = RouterConfiguration.sample()

        XCTAssertFalse(configuration.hasCompletedOnboarding)
    }

    func testBrowserSlugPreservesBundleIdentifierIDFormat() {
        XCTAssertEqual(BrowserSlug.make("com.google.Chrome"), "com-google-chrome")
        XCTAssertEqual(BrowserSlug.make("..."), "browser")
    }

    func testBrowserSlugPreservesChromiumProfileIDFormat() {
        XCTAssertEqual(BrowserSlug.makeProfileIDComponent("Default"), "default")
        XCTAssertEqual(BrowserSlug.makeProfileIDComponent("Profile 1"), "profile-1")
    }

    func testAdoptingDefaultBrowserReusesExistingDefaultOptionForBundle() {
        var configuration = RouterConfiguration.sample()

        configuration.adoptDefaultBrowser(
            bundleIdentifier: "com.google.Chrome",
            displayName: "Google Chrome",
            appName: "Google Chrome"
        )

        XCTAssertEqual(configuration.defaultOptionID, "chrome-default")
        XCTAssertEqual(configuration.browserOptions.filter { $0.bundleIdentifier == "com.google.Chrome" }.count, 2)
        XCTAssertEqual(configuration.previousDefaultBrowser?.bundleIdentifier, "com.google.Chrome")
        XCTAssertEqual(configuration.previousDefaultBrowser?.displayName, "Google Chrome")
    }

    func testAdoptingDefaultBrowserPrefersDefaultProfileOverGenericBundleOption() {
        var configuration = RouterConfiguration(
            defaultOptionID: "system-com-google-chrome",
            chooserModifier: "command+shift",
            browserOptions: [
                BrowserOption(
                    id: "system-com-google-chrome",
                    name: "Google Chrome",
                    bundleIdentifier: "com.google.Chrome",
                    appName: "Google Chrome",
                    profileDirectory: nil,
                    extraArguments: nil
                ),
                BrowserOption(
                    id: "chrome-default",
                    name: "Chrome - Khalil",
                    bundleIdentifier: "com.google.Chrome",
                    appName: "Google Chrome",
                    profileDirectory: "Default",
                    extraArguments: nil
                )
            ]
        )

        configuration.adoptDefaultBrowser(
            bundleIdentifier: "com.google.Chrome",
            displayName: "Google Chrome",
            appName: "Google Chrome"
        )

        XCTAssertEqual(configuration.defaultOptionID, "chrome-default")
    }

    func testAdoptingDefaultBrowserAddsUnknownBrowserOption() {
        var configuration = RouterConfiguration.sample()

        configuration.adoptDefaultBrowser(
            bundleIdentifier: "com.example.CustomBrowser",
            displayName: "Custom Browser",
            appName: "Custom Browser"
        )

        XCTAssertEqual(configuration.defaultOptionID, "previous-default-com-example-custombrowser")
        XCTAssertEqual(configuration.browserOptions.first?.id, "previous-default-com-example-custombrowser")
        XCTAssertEqual(configuration.browserOptions.first?.name, "Custom Browser")
        XCTAssertEqual(configuration.browserOptions.first?.bundleIdentifier, "com.example.CustomBrowser")
        XCTAssertEqual(configuration.previousDefaultBrowser?.bundleIdentifier, "com.example.CustomBrowser")
    }

    func testAdoptingDefaultBrowserEncodesPreviousDefaultBrowser() throws {
        var configuration = RouterConfiguration.sample()

        configuration.adoptDefaultBrowser(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            appName: "Safari"
        )

        let data = try JSONEncoder().encode(configuration)
        let decoded = try JSONDecoder().decode(RouterConfiguration.self, from: data)

        XCTAssertEqual(decoded.previousDefaultBrowser?.bundleIdentifier, "com.apple.Safari")
        XCTAssertEqual(decoded.previousDefaultBrowser?.displayName, "Safari")
    }
}
