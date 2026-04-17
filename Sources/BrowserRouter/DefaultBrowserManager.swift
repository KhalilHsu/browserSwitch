import AppKit
import CoreServices
import Foundation

enum DefaultBrowserError: LocalizedError {
    case missingBundleIdentifier
    case registrationFailed(OSStatus)
    case setFailed(scheme: String, status: OSStatus)
    case verificationFailed(http: String?, https: String?)

    var errorDescription: String? {
        switch self {
        case .missingBundleIdentifier:
            return "BrowserRouter is missing a bundle identifier."
        case .registrationFailed(let status):
            return "Launch Services registration failed with status \(status)."
        case .setFailed(let scheme, let status):
            return "Setting the default handler for \(scheme) failed with status \(status)."
        case .verificationFailed(let http, let https):
            return "Verification failed. Current handlers are http=\(http ?? "nil"), https=\(https ?? "nil")."
        }
    }
}

final class DefaultBrowserManager {
    private let bundleURL: URL
    private let bundleIdentifier: String

    init(bundle: Bundle = .main) throws {
        guard let bundleIdentifier = bundle.bundleIdentifier else {
            throw DefaultBrowserError.missingBundleIdentifier
        }

        self.bundleIdentifier = bundleIdentifier
        self.bundleURL = bundle.bundleURL
    }

    @MainActor
    func setAsDefaultBrowser() async throws {
        let registerStatus = LSRegisterURL(bundleURL as CFURL, true)
        guard registerStatus == noErr else {
            throw DefaultBrowserError.registrationFailed(registerStatus)
        }

        for scheme in ["http", "https"] {
            do {
                try await NSWorkspace.shared.setDefaultApplication(at: bundleURL, toOpenURLsWithScheme: scheme)
            } catch {
                // Treat the actual Launch Services state as the source of truth.
                let current = currentHandler(for: scheme)
                guard current == bundleIdentifier else {
                    let nsError = error as NSError
                    let status = nsError.userInfo[NSUnderlyingErrorKey]
                        .flatMap { ($0 as? NSError)?.code }
                        ?? nsError.code
                    throw DefaultBrowserError.setFailed(scheme: scheme, status: OSStatus(status))
                }
            }
        }

        let httpHandler = currentHandler(for: "http")
        let httpsHandler = currentHandler(for: "https")
        guard httpHandler == bundleIdentifier, httpsHandler == bundleIdentifier else {
            throw DefaultBrowserError.verificationFailed(http: httpHandler, https: httpsHandler)
        }
    }

    func statusSummary() -> String {
        let http = currentHandler(for: "http") ?? "unset"
        let https = currentHandler(for: "https") ?? "unset"
        return "http -> \(http)\nhttps -> \(https)"
    }

    func isInstalledInApplications() -> Bool {
        bundleURL.path.hasPrefix("/Applications/")
    }

    private func currentHandler(for scheme: String) -> String? {
        guard let url = URL(string: "\(scheme)://example.com") else {
            return nil
        }

        guard let appURL = NSWorkspace.shared.urlForApplication(toOpen: url) else {
            return nil
        }

        return Bundle(url: appURL)?.bundleIdentifier
    }
}