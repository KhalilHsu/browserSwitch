import Foundation
import Testing
@testable import BrowserRouterCore

@Test func routeResolverSkipsDisabledRulesAndUsesDefault() throws {
    let chrome = makeOption(id: "chrome", name: "Chrome")
    let safari = makeOption(id: "safari", name: "Safari")
    let configuration = RouterConfiguration(
        defaultOptionID: safari.id,
        chooserModifier: "command+shift",
        browserOptions: [chrome, safari],
        routingRules: [
            makeRule(id: "disabled", isEnabled: false, browserOptionID: chrome.id, hostSuffix: "example.com")
        ]
    )

    let resolution = RouteResolver.resolve(
        url: try makeURL("https://example.com"),
        configuration: configuration,
        availableOptionIDs: [chrome.id, safari.id]
    )

    #expect(resolution == .defaultRoute(option: safari))
}

@Test func routeResolverReportsFirstMatchingUnavailableRule() throws {
    let chrome = makeOption(id: "chrome", name: "Chrome")
    let safari = makeOption(id: "safari", name: "Safari")
    let rule = makeRule(id: "work", browserOptionID: chrome.id, hostSuffix: "example.com")
    let configuration = RouterConfiguration(
        defaultOptionID: safari.id,
        chooserModifier: "command+shift",
        browserOptions: [chrome, safari],
        routingRules: [rule]
    )

    let resolution = RouteResolver.resolve(
        url: try makeURL("https://example.com"),
        configuration: configuration,
        availableOptionIDs: [safari.id]
    )

    #expect(resolution == .unavailableRule(rule: rule, option: chrome))
}

@Test func routeResolverReportsMatchedRule() throws {
    let chrome = makeOption(id: "chrome", name: "Chrome")
    let rule = makeRule(id: "work", browserOptionID: chrome.id, hostSuffix: "example.com")
    let configuration = RouterConfiguration(
        defaultOptionID: chrome.id,
        chooserModifier: "command+shift",
        browserOptions: [chrome],
        routingRules: [rule]
    )

    let resolution = RouteResolver.resolve(
        url: try makeURL("https://example.com"),
        configuration: configuration,
        availableOptionIDs: [chrome.id]
    )

    #expect(resolution == .matchedRule(rule: rule, option: chrome))
}

@Test func routeResolverCanReportChooserOverride() throws {
    let chrome = makeOption(id: "chrome", name: "Chrome")
    let configuration = RouterConfiguration(
        defaultOptionID: chrome.id,
        chooserModifier: "always",
        browserOptions: [chrome],
        routingRules: []
    )

    let resolution = RouteResolver.resolve(
        url: try makeURL("https://example.com"),
        configuration: configuration,
        availableOptionIDs: [chrome.id],
        chooserOverride: true
    )

    #expect(resolution == .chooserOverride)
}

@Test func routeResolverFallsBackWhenConfiguredDefaultIsMissing() throws {
    let chrome = makeOption(id: "chrome", name: "Chrome")
    let safari = makeOption(id: "safari", name: "Safari")
    let configuration = RouterConfiguration(
        defaultOptionID: safari.id,
        chooserModifier: "command+shift",
        browserOptions: [chrome, safari],
        routingRules: []
    )

    let resolution = RouteResolver.resolve(
        url: try makeURL("https://example.com"),
        configuration: configuration,
        availableOptionIDs: [chrome.id]
    )

    #expect(resolution == .unavailableDefault(option: safari))
}

@Test func routeResolverReportsNoOptionsWhenNothingIsAvailable() throws {
    let configuration = RouterConfiguration(
        defaultOptionID: "missing-default",
        chooserModifier: "command+shift",
        browserOptions: [],
        routingRules: []
    )

    let resolution = RouteResolver.resolve(
        url: try makeURL("https://example.com"),
        configuration: configuration,
        availableOptionIDs: []
    )

    #expect(resolution == .noOptions)
}

@Test func routeResolverFallsBackWhenDefaultOptionIsMissingFromConfiguration() throws {
    let chrome = makeOption(id: "chrome", name: "Chrome")
    let safari = makeOption(id: "safari", name: "Safari")
    let configuration = RouterConfiguration(
        defaultOptionID: "missing-default",
        chooserModifier: "command+shift",
        browserOptions: [chrome, safari],
        routingRules: []
    )

    let resolution = RouteResolver.resolve(
        url: try makeURL("https://example.com"),
        configuration: configuration,
        availableOptionIDs: [chrome.id, safari.id]
    )

    #expect(resolution == .fallback(option: chrome))
}

private func makeOption(id: String, name: String) -> BrowserOption {
    BrowserOption(
        id: id,
        name: name,
        bundleIdentifier: "com.example.\(id)",
        appName: name,
        profileDirectory: nil,
        extraArguments: nil
    )
}

private func makeRule(
    id: String,
    isEnabled: Bool = true,
    browserOptionID: String,
    hostSuffix: String
) -> RoutingRule {
    RoutingRule(
        id: id,
        name: id,
        isEnabled: isEnabled,
        browserOptionID: browserOptionID,
        hostContains: nil,
        hostSuffix: hostSuffix,
        pathPrefix: nil,
        urlContains: nil
    )
}

private func makeURL(_ value: String) throws -> URL {
    guard let url = URL(string: value) else {
        throw URLError(.badURL)
    }

    return url
}
