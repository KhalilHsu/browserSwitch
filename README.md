# BrowserRouter

BrowserRouter is a native macOS utility that routes external `http` and `https`
links to the browser or Chromium profile you choose.

It is built for people who keep separate browsers or profiles for work,
personal browsing, testing, client accounts, OAuth flows, and app-launched links.

## Status

BrowserRouter is beta-quality software. The core link routing flow works, but
the project is still young and the release/distribution story is intentionally
simple.

Current assumptions:

- macOS 14 or newer.
- Local builds are ad-hoc signed.
- BrowserRouter must be installed in `/Applications` before you set it as the
  default browser.
- Configuration is local JSON in Application Support.

## Features

- Native Swift/AppKit menu bar app.
- First-run onboarding for setting BrowserRouter as the macOS default browser.
- Default browser/profile fallback when no rule matches.
- Keyboard-triggered chooser for picking a browser per link.
- Configurable chooser shortcut:
  - `Command + Shift`
  - `Option + Shift`
  - `Control + Shift`
  - `Command + Option`
  - always show chooser
- Routing rules for:
  - host suffix
  - host contains
  - path prefix
  - URL contains
- Chromium profile discovery for:
  - Google Chrome
  - Google Chrome Canary
  - Microsoft Edge
  - Brave
  - Vivaldi
- Firefox profile discovery from `profiles.ini`.
- Searchable chooser for any number of detected browsers or profiles.
- Browser inventory refresh for installed system URL handlers.
- Settings window with Basic, Appearance, Rules, Advanced, and About sections.
- Optional Dock icon and menu bar icon.
- Headless helper mode when both icons are hidden.
- Local-only configuration.

## How It Works

BrowserRouter registers itself as the macOS handler for `http` and `https`.
When another app opens a web link, macOS sends that URL to BrowserRouter.

BrowserRouter then chooses where to forward the link:

1. If the chooser shortcut is active, show the chooser.
2. Otherwise, use the first matching routing rule.
3. Otherwise, use the configured default browser/profile.
4. If the configured target is unavailable, fall back to another detected
   browser option.

Chromium profiles are opened with:

```text
--profile-directory=<profileDirectory>
```

Safari and non-Chromium browsers are opened through `NSWorkspace` without a
profile argument.

## Build

```bash
chmod +x scripts/build-app.sh
scripts/build-app.sh
```

The app bundle is created at:

```text
.build/BrowserRouter.app
```

## Install From Source

Install the app into `/Applications` before setting it as the default browser.
Launch Services can otherwise keep a reference to a temporary build path that
may be deleted later.

```bash
chmod +x scripts/install.sh
scripts/install.sh
```

The install script checks local build tools, rebuilds the app, replaces:

```text
/Applications/BrowserRouter.app
```

and relaunches BrowserRouter.

Useful install options:

```bash
scripts/install.sh --dry-run
scripts/install.sh --no-open
```

If `/Applications` is not writable from your account, run the script from an
admin account or with `sudo`.

## Update From Source

Pull the latest code and run the install script again:

```bash
git pull
scripts/install.sh
```

The script quits the running app, replaces `/Applications/BrowserRouter.app`,
registers the new app bundle with Launch Services, and relaunches it.

## Uninstall

By default, the uninstall script first tries to restore the browser that was
default before BrowserRouter setup. If that cannot be restored, it prints a
warning and you can choose a default browser in macOS System Settings.

```bash
chmod +x scripts/uninstall.sh
scripts/uninstall.sh
```

The uninstall script removes:

```text
/Applications/BrowserRouter.app
```

It keeps local configuration by default. To also delete BrowserRouter's local
configuration, run:

```bash
scripts/uninstall.sh --remove-config
```

Useful uninstall options:

```bash
scripts/uninstall.sh --dry-run
scripts/uninstall.sh --yes
scripts/uninstall.sh --skip-restore
```

## First Run

1. Run `scripts/install.sh`.
2. Open `/Applications/BrowserRouter.app`.
3. Follow onboarding to set BrowserRouter as the default browser.
4. Choose your default browser/profile.
5. Choose the shortcut that should show the chooser.

After setup, click a link from another app. BrowserRouter will route it to the
default browser/profile unless a rule matches or the chooser shortcut is active.

## Settings

Open settings from the `Router` menu bar item, from the chooser menu, or by
opening the app again when BrowserRouter is running without visible icons.

Settings includes:

- **Basic**: default browser/profile and chooser shortcut.
- **Appearance**: Dock icon and menu bar icon visibility.
- **Rules**: add, update, enable, disable, remove, and test routing rules.
- **Advanced**: refresh browser inventory, detect Chromium profiles, and reveal
  the config file in Finder.
- **About**: version and project links.

Settings changes are saved automatically when you:

- change the default browser/profile
- change the chooser shortcut
- change Dock or menu bar visibility
- refresh browsers
- detect Chromium profiles
- add, update, or remove a rule
- enable or disable a rule
- finish editing an existing selected rule

Rule text fields are not saved on every keystroke. They save when you finish
editing a selected rule or explicitly commit the rule with `Add Rule`,
`Update Selected`, or `Remove Selected`.

## Configuration

BrowserRouter stores configuration at:

```text
~/Library/Application Support/BrowserRouter/config.json
```

The app can reveal this file from Settings > Advanced.

Example browser option:

```json
{
  "id": "chrome-default",
  "name": "Chrome - Default",
  "bundleIdentifier": "com.google.Chrome",
  "appName": "Google Chrome",
  "profileDirectory": "Default",
  "extraArguments": null
}
```

Example routing rule:

```json
{
  "id": "gmail-work",
  "name": "Gmail Work",
  "isEnabled": true,
  "browserOptionID": "chrome-default",
  "hostSuffix": "mail.google.com"
}
```

## Rule Matching

Enabled rules are checked in the order they appear in `routingRules`. The first
matching enabled rule wins when its browser/profile is available. If the matched
target is unavailable, BrowserRouter falls back to the default or another
available browser option. If no enabled rule matches, BrowserRouter uses the
configured default option.

Supported match fields:

- `hostSuffix` / **Domain Suffix**: matches an exact domain or subdomain, such
  as `baidu.com` and `www.baidu.com`.
- `hostContains` / **Domain Contains**: matches any domain containing the
  string, such as `baidu` in `www.baidu.com`.
- `pathPrefix` / **Path Starts With**: matches URL paths that start with the
  string, such as `/docs`. Path matching is case-sensitive and does not inspect
  the domain.
- `urlContains` / **Full URL Contains**: matches anywhere in the full URL after
  percent decoding.

When a rule has multiple match fields in JSON, all populated fields must match.
The current settings UI edits one match field per rule.

The configured chooser shortcut always wins over rules and default routing.

The Rules settings page includes a tester. Paste a URL to preview the matching
enabled rule, target browser/profile, unavailable-target state, default route,
and chooser override behavior.

## Development

Build the app:

```bash
scripts/build-app.sh
```

Run tests:

```bash
swift test
```

The project also has a GitHub Actions workflow that builds the app bundle on
pushes and pull requests.

## Distribution Notes

The current distribution path is source-based local install:

```bash
scripts/install.sh
```

Public binary releases still need some polish:

- Add notarized release builds if distributing outside source builds.
- Add a documented release process and changelog.
- Consider automatic update support after the first public release.
- Add screenshots or a short demo GIF to this README.

## Privacy

BrowserRouter runs locally and does not upload URLs.

Because BrowserRouter is the macOS default URL handler, it can see external
`http` and `https` URLs long enough to match rules and forward them to the
selected browser.

Default logs avoid full URL strings. Routing logs may include non-sensitive
facts such as scheme, host, whether a path exists, query item count, matched
rule id, and target browser/profile id.

Please avoid adding telemetry or persistent URL history unless it is explicit,
optional, and documented.

## Roadmap

See [ROADMAP.md](ROADMAP.md) for planned product improvements and open-source
readiness work.

## License

MIT
