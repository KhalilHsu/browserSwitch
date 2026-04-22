import Foundation
import Testing
@testable import BrowserRouterCore

@Test func legacyConfigurationDecodesNewPresentationDefaults() throws {
    let json = """
    {
      "defaultOptionID": "arc-default",
      "chooserModifier": "command+shift",
      "browserOptions": [],
      "routingRules": []
    }
    """

    let configuration = try JSONDecoder().decode(RouterConfiguration.self, from: Data(json.utf8))

    #expect(configuration.showsDockIcon == false)
    #expect(configuration.showsStatusItem == true)
    #expect(configuration.hasCompletedOnboarding == true)
    #expect(configuration.previousDefaultBrowser == nil)
}

@Test func legacyRoutingRuleDecodesEnabledByDefault() throws {
    let json = """
    {
      "id": "legacy",
      "name": "Legacy",
      "browserOptionID": "chrome",
      "hostSuffix": "example.com"
    }
    """

    let rule = try JSONDecoder().decode(RoutingRule.self, from: Data(json.utf8))

    #expect(rule.isEnabled)
}

@Test func sampleConfigurationRequiresOnboarding() {
    let configuration = RouterConfiguration.sample()

    #expect(configuration.hasCompletedOnboarding == false)
}

@Test func browserSlugPreservesBundleIdentifierIDFormat() {
    #expect(BrowserSlug.make("com.google.Chrome") == "com-google-chrome")
    #expect(BrowserSlug.make("...") == "browser")
}

@Test func browserSlugPreservesChromiumProfileIDFormat() {
    #expect(BrowserSlug.makeProfileIDComponent("Default") == "default")
    #expect(BrowserSlug.makeProfileIDComponent("Profile 1") == "profile-1")
}

@Test func adoptingDefaultBrowserReusesExistingDefaultOptionForBundle() {
    var configuration = RouterConfiguration.sample()

    configuration.adoptDefaultBrowser(
        bundleIdentifier: "com.google.Chrome",
        displayName: "Google Chrome",
        appName: "Google Chrome"
    )

    #expect(configuration.defaultOptionID == "chrome-default")
    #expect(configuration.browserOptions.filter { $0.bundleIdentifier == "com.google.Chrome" }.count == 2)
    #expect(configuration.previousDefaultBrowser?.bundleIdentifier == "com.google.Chrome")
    #expect(configuration.previousDefaultBrowser?.displayName == "Google Chrome")
}

@Test func adoptingDefaultBrowserPrefersDefaultProfileOverGenericBundleOption() {
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

    #expect(configuration.defaultOptionID == "chrome-default")
}

@Test func adoptingDefaultBrowserAddsUnknownBrowserOption() {
    var configuration = RouterConfiguration.sample()

    configuration.adoptDefaultBrowser(
        bundleIdentifier: "com.example.CustomBrowser",
        displayName: "Custom Browser",
        appName: "Custom Browser"
    )

    #expect(configuration.defaultOptionID == "previous-default-com-example-custombrowser")
    #expect(configuration.browserOptions.first?.id == "previous-default-com-example-custombrowser")
    #expect(configuration.browserOptions.first?.name == "Custom Browser")
    #expect(configuration.browserOptions.first?.bundleIdentifier == "com.example.CustomBrowser")
    #expect(configuration.previousDefaultBrowser?.bundleIdentifier == "com.example.CustomBrowser")
}

@Test func adoptingDefaultBrowserEncodesPreviousDefaultBrowser() throws {
    var configuration = RouterConfiguration.sample()

    configuration.adoptDefaultBrowser(
        bundleIdentifier: "com.apple.Safari",
        displayName: "Safari",
        appName: "Safari"
    )

    let data = try JSONEncoder().encode(configuration)
    let decoded = try JSONDecoder().decode(RouterConfiguration.self, from: data)

    #expect(decoded.previousDefaultBrowser?.bundleIdentifier == "com.apple.Safari")
    #expect(decoded.previousDefaultBrowser?.displayName == "Safari")
}
