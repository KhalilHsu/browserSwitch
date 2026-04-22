import AppKit
import BrowserRouterCore
import CoreServices
import Foundation

struct DefaultBrowserHandler {
    var bundleIdentifier: String
    var displayName: String
    var appName: String?
}

enum DefaultBrowserError: LocalizedError {
    case missingBundleIdentifier
    case registrationFailed(OSStatus)
    case setFailed(scheme: String, status: OSStatus)
    case verificationFailed(http: String?, https: String?)
    case restoreTargetUnavailable(bundleIdentifier: String)
    case restoreVerificationFailed(target: String, http: String?, https: String?)

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
        case .restoreTargetUnavailable(let bundleIdentifier):
            return "Could not find an installed app for \(bundleIdentifier)."
        case .restoreVerificationFailed(let target, let http, let https):
            return "Restore verification failed for \(target). Current handlers are http=\(http ?? "nil"), https=\(https ?? "nil")."
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

    @MainActor
    func restoreDefaultBrowser(to handler: SavedDefaultBrowser) async throws {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: handler.bundleIdentifier) else {
            throw DefaultBrowserError.restoreTargetUnavailable(bundleIdentifier: handler.bundleIdentifier)
        }

        for scheme in ["http", "https"] {
            do {
                try await NSWorkspace.shared.setDefaultApplication(at: appURL, toOpenURLsWithScheme: scheme)
            } catch {
                let current = currentHandler(for: scheme)
                guard current == handler.bundleIdentifier else {
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
        guard httpHandler == handler.bundleIdentifier, httpsHandler == handler.bundleIdentifier else {
            throw DefaultBrowserError.restoreVerificationFailed(
                target: handler.bundleIdentifier,
                http: httpHandler,
                https: httpsHandler
            )
        }
    }

    func statusSummary() -> String {
        let entries = statusEntries()
        return entries
            .map { "\($0.scheme) -> \($0.handler)" }
            .joined(separator: "\n")
    }

    func statusEntries() -> [(scheme: String, handler: String)] {
        ["http", "https"].map { scheme in
            (scheme: scheme, handler: currentHandlerDisplayName(for: scheme) ?? "unset")
        }
    }

    func isRoutingToSelf() -> Bool {
        currentHandler(for: "http") == bundleIdentifier && currentHandler(for: "https") == bundleIdentifier
    }

    func currentExternalDefaultHandler() -> DefaultBrowserHandler? {
        for scheme in ["http", "https"] {
            guard let handler = currentHandlerDetails(for: scheme), handler.bundleIdentifier != bundleIdentifier else {
                continue
            }

            return handler
        }

        return nil
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

    private func currentHandlerDetails(for scheme: String) -> DefaultBrowserHandler? {
        guard let url = URL(string: "\(scheme)://example.com") else {
            return nil
        }

        guard let appURL = NSWorkspace.shared.urlForApplication(toOpen: url) else {
            return nil
        }

        let bundle = Bundle(url: appURL)
        guard let bundleIdentifier = bundle?.bundleIdentifier else {
            return nil
        }

        let displayName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? bundleIdentifier
        let appName = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? displayName

        return DefaultBrowserHandler(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            appName: appName
        )
    }

    private func currentHandlerDisplayName(for scheme: String) -> String? {
        guard let url = URL(string: "\(scheme)://example.com") else {
            return nil
        }

        guard let appURL = NSWorkspace.shared.urlForApplication(toOpen: url) else {
            return nil
        }

        let bundle = Bundle(url: appURL)
        return bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? bundle?.bundleIdentifier
    }
}
