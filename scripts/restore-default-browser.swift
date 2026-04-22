#!/usr/bin/env swift

import AppKit
import CoreServices
import Darwin
import Foundation

struct BrowserOption: Decodable {
    var id: String
    var name: String
    var bundleIdentifier: String
    var appName: String?
}

struct SavedDefaultBrowser: Decodable {
    var bundleIdentifier: String
    var displayName: String
    var appName: String?
}

struct RouterConfiguration: Decodable {
    var defaultOptionID: String
    var previousDefaultBrowser: SavedDefaultBrowser?
    var browserOptions: [BrowserOption]
}

struct RestoreTarget {
    var bundleIdentifier: String
    var displayName: String
}

let arguments = Set(CommandLine.arguments.dropFirst())
let quiet = arguments.contains("--quiet")
let dryRun = arguments.contains("--dry-run")

if arguments.contains("--help") || arguments.contains("-h") {
    print("""
    Usage: scripts/restore-default-browser.swift [--dry-run] [--quiet]

    Restore http and https default handlers from BrowserRouter config.
    """)
    exit(0)
}

func log(_ message: String) {
    guard !quiet else {
        return
    }
    print(message)
}

func fail(_ message: String, code: Int32) -> Never {
    fputs("Error: \(message)\n", stderr)
    exit(code)
}

let environment = ProcessInfo.processInfo.environment
let homePath = environment["BROWSERROUTER_HOME"].flatMap { $0.isEmpty ? nil : $0 } ?? NSHomeDirectory()
let configURL = URL(fileURLWithPath: homePath)
    .appendingPathComponent("Library/Application Support/BrowserRouter/config.json")

guard FileManager.default.fileExists(atPath: configURL.path) else {
    fail("BrowserRouter config was not found at \(configURL.path).", code: 2)
}

let configuration: RouterConfiguration
do {
    let data = try Data(contentsOf: configURL)
    configuration = try JSONDecoder().decode(RouterConfiguration.self, from: data)
} catch {
    fail("Could not read BrowserRouter config: \(error)", code: 3)
}

let target: RestoreTarget?
if let previousDefaultBrowser = configuration.previousDefaultBrowser {
    target = RestoreTarget(
        bundleIdentifier: previousDefaultBrowser.bundleIdentifier,
        displayName: previousDefaultBrowser.displayName
    )
} else if let defaultOption = configuration.browserOptions.first(where: { $0.id == configuration.defaultOptionID }) {
    target = RestoreTarget(
        bundleIdentifier: defaultOption.bundleIdentifier,
        displayName: defaultOption.appName ?? defaultOption.name
    )
} else {
    target = nil
}

guard let target else {
    fail("BrowserRouter config does not contain a previous default browser.", code: 4)
}

guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: target.bundleIdentifier) != nil else {
    fail("Could not find an installed app for \(target.bundleIdentifier).", code: 5)
}

if dryRun {
    log("Would restore http and https handlers to \(target.displayName) (\(target.bundleIdentifier)).")
    exit(0)
}

for scheme in ["http", "https"] {
    let status = LSSetDefaultHandlerForURLScheme(scheme as CFString, target.bundleIdentifier as CFString)
    guard status == noErr else {
        fail("Could not restore \(scheme) handler to \(target.bundleIdentifier). Launch Services status: \(status)", code: 6)
    }
}

Thread.sleep(forTimeInterval: 0.2)

for scheme in ["http", "https"] {
    guard let url = URL(string: "\(scheme)://example.com"),
          let appURL = NSWorkspace.shared.urlForApplication(toOpen: url),
          Bundle(url: appURL)?.bundleIdentifier == target.bundleIdentifier else {
        fail("Restore verification failed for \(scheme).", code: 7)
    }
}

log("Restored http and https handlers to \(target.displayName) (\(target.bundleIdentifier)).")
