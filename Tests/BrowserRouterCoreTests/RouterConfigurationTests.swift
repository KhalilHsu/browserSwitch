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
}
