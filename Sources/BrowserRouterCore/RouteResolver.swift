import Foundation

public enum RouteResolution: Hashable {
    case chooserOverride
    case matchedRule(rule: RoutingRule, option: BrowserOption)
    case unavailableRule(rule: RoutingRule, option: BrowserOption?)
    case defaultRoute(option: BrowserOption)
    case unavailableDefault(option: BrowserOption?)
    case fallback(option: BrowserOption)
    case noOptions
}

public enum RouteResolver {
    public static func resolve(
        url: URL,
        configuration: RouterConfiguration,
        availableOptionIDs: Set<String>,
        chooserOverride: Bool = false,
        sourceApp: String? = nil
    ) -> RouteResolution {
        if chooserOverride {
            return .chooserOverride
        }

        for rule in configuration.routingRules where rule.isEnabled && RuleMatcher.matches(rule, url: url, sourceApp: sourceApp) {
            guard let option = configuration.browserOptions.first(where: { $0.id == rule.browserOptionID }) else {
                return .unavailableRule(rule: rule, option: nil)
            }

            guard availableOptionIDs.contains(option.id) else {
                return .unavailableRule(rule: rule, option: option)
            }

            return .matchedRule(rule: rule, option: option)
        }

        let fallbackOption = configuration.browserOptions.first { availableOptionIDs.contains($0.id) }
        guard let fallbackOption else {
            return .noOptions
        }

        guard let configuredDefault = configuration.browserOptions.first(where: { $0.id == configuration.defaultOptionID }) else {
            return .fallback(option: fallbackOption)
        }

        guard availableOptionIDs.contains(configuredDefault.id) else {
            return .unavailableDefault(option: configuredDefault)
        }

        return .defaultRoute(option: configuredDefault)
    }
}
