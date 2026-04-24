import Foundation
import XCTest
@testable import BrowserRouterCore

final class RouteResolverTests: XCTestCase {
    func testRouteResolverSkipsDisabledRulesAndUsesDefault() throws {
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

        XCTAssertEqual(resolution, .defaultRoute(option: safari))
    }

    func testRouteResolverReportsFirstMatchingUnavailableRule() throws {
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

        XCTAssertEqual(resolution, .unavailableRule(rule: rule, option: chrome))
    }

    func testRouteResolverReportsMatchedRule() throws {
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

        XCTAssertEqual(resolution, .matchedRule(rule: rule, option: chrome))
    }

    func testRouteResolverCanReportChooserOverride() throws {
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

        XCTAssertEqual(resolution, .chooserOverride)
    }

    func testRouteResolverFallsBackWhenConfiguredDefaultIsMissing() throws {
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

        XCTAssertEqual(resolution, .unavailableDefault(option: safari))
    }

    func testRouteResolverReportsNoOptionsWhenNothingIsAvailable() throws {
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

        XCTAssertEqual(resolution, .noOptions)
    }

    func testRouteResolverFallsBackWhenDefaultOptionIsMissingFromConfiguration() throws {
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

        XCTAssertEqual(resolution, .fallback(option: chrome))
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
}
