# Roadmap

This document tracks product and open-source readiness work for BrowserRouter.
It is intentionally practical: each item should make the app easier to trust,
use, debug, or distribute.

## Priorities

### P0: Open-Source Readiness And Core Daily Use

These are the highest-impact items before inviting broader usage. They either
reduce trust risk or make the app substantially better for everyday use.

#### Restore Default Browser

Status: Done.

Add a clear way to disable BrowserRouter and restore the previous `http` and
`https` default browser.

Why it matters:

- BrowserRouter asks for a high-trust system role.
- Users need an obvious exit path before they feel safe trying it.
- The app already captures the previous default browser when setting itself as
  default, but there is no user-facing restore action.

Acceptance criteria:

- [x] Settings includes a restore or disable action.
- [x] The action restores both `http` and `https` handlers when possible.
- [x] The UI explains what will happen before changing system defaults.
- [x] Failure states show the current handlers and a useful next step.
- [x] `scripts/uninstall.sh` attempts to restore the previous default browser
  before removing the app.

#### Privacy-Safe Logging

Status: Done.

Avoid writing full URLs to public logs by default.

Why it matters:

- BrowserRouter sees external links because it is the default URL handler.
- Full URLs can include tokens, private document paths, search terms, or account
  identifiers.
- Public logs are hard for users to reason about.

Acceptance criteria:

- [x] Normal logs avoid full URL strings.
- [x] Logs can include non-sensitive routing facts such as host, rule id, and
  target browser option id.
- [x] Full URL strings are not logged by default.
- [x] README privacy notes match the implementation.

#### Release Links And About Page

Status: Done.

Update project links and product copy before publishing.

Why it matters:

- The current About links should point to the final GitHub repository.
- The About description should describe the app, not the development history.

Acceptance criteria:

- [x] About page links point to the final repository and releases page.
- [x] README, app links, and release scripts use the same project name.
- [x] About copy is concise and product-focused.

#### Local Install And Uninstall Scripts

Status: Done.

Make source-based installation and removal clear for users who download or clone
the repository and run local scripts.

Why it matters:

- The current distribution path is source-based local install only; the project
  does not ship or support DMG distribution.
- BrowserRouter must live at a stable `/Applications` path before users set it
  as the default browser.
- Users need an obvious uninstall path before they trust a default browser
  helper.

Acceptance criteria:

- [x] `scripts/install.sh` builds the app, installs it to `/Applications`, handles
  replacement, and reports common failure cases clearly.
- [x] `scripts/uninstall.sh` removes the installed app and can optionally remove
  local configuration.
- [x] README documents source install, update, uninstall, and configuration
  removal behavior.

#### Rule Tester

Status: Done.

Add a Settings tool where users can paste a URL and see the matched rule and
target browser/profile.

Acceptance criteria:

- [x] The tester shows whether the chooser shortcut would override routing.
- [x] It shows the first matching rule, or that the default route will be used.
- [x] It shows when the target browser/profile is unavailable.

#### Rule Enable/Disable

Status: Done.

Allow temporary disabling of rules without deleting them.

Acceptance criteria:

- [x] Each rule has an enabled state.
- [x] Disabled rules are skipped by the matcher.
- [x] The rules table visually distinguishes disabled rules.
- [x] Config decoding preserves compatibility with older files.

#### Richer Chooser

Status: Done.

Improve the browser chooser for users with many browsers or profiles.

Acceptance criteria:

- [x] More than 12 options can be reached.
- [x] Keyboard navigation remains fast.
- [x] Search or filtering works for browser/profile names.
- [x] The default option remains visually clear.

#### Broader Browser Profile Support

Status: Done for Firefox MVP.

Detect and expose profile/profile-like targets for browsers that are not covered
by the current Chromium scanner.

Why it matters:

- BrowserRouter's value increases when it can route to the user's real browser
  identities, not just browser apps.
- The current scanner covers several Chromium browsers, but profile workflows
  also exist in Firefox-family browsers and other developer-focused browsers.
- Some browsers do not expose profiles the same way Chromium does, so each
  browser needs explicit launch and detection research.

MVP candidate:

- Firefox profiles from Firefox profile metadata.

Deferred candidates:

- Firefox Developer Edition, LibreWolf, Waterfox, and other Firefox-family
  browsers where profile launching is reliable.
- Arc spaces/profiles if there is a supported or stable external launch path.
- Other Chromium-family browsers not yet covered by the scanner.

Acceptance criteria:

- [x] Supported profile targets have stable ids and readable names.
- [x] Launch behavior opens the selected Firefox profile target, or the browser is
  left unsupported with documentation explaining why.
- [x] Missing or malformed profile metadata does not break app startup.
- [x] Browser-specific scanners are isolated enough that adding one browser does not
  make existing Chromium detection fragile.

MVP scope:

- [x] Firefox profiles from `profiles.ini`.

## P1: Daily Use Improvements

These features are useful and reasonable, but they are less urgent than the P0
trust, release, and daily-driver items.

#### Rule Ordering

Allow users to control routing rule priority.

Why it matters:

- Rules are evaluated in order and the first matching rule wins.
- Overlapping rules are common, such as `google.com` and `mail.google.com`.
- Without ordering, rule behavior can feel unpredictable.

Acceptance criteria:

- Rules can be moved up and down in Settings.
- The saved `routingRules` order matches the displayed order.
- The UI makes first-match behavior clear.
- Tests cover overlapping rules and priority.

#### Source App Routing

Allow routing rules to consider the app that initiated the link open request,
not only the destination URL.

Examples:

- Links opened from Slack, Feishu, or work email use a work Chrome profile.
- Links opened from Telegram, WeChat, or personal chat apps use Safari or a
  personal profile.

Why it matters:

- This matches a common real-world workflow for users who split work and
  personal browsing.
- It can be more ergonomic than maintaining large domain lists.

Implementation notes:

- Investigate whether Apple Events, Launch Services context, Accessibility API,
  or frontmost application heuristics can identify the source app reliably.
- Treat Accessibility permissions as a serious UX and privacy cost.
- If detection is heuristic, the UI should say so and the rule tester should
  expose the assumed source app context.

Acceptance criteria:

- Routing rules can optionally include a source application condition.
- The rule tester can simulate or display the source app condition.
- The feature degrades predictably when source app detection is unavailable.
- Privacy documentation explains any required permissions.

#### Import And Export Configuration

Let users back up, migrate, and share routing setups.

Acceptance criteria:

- Settings can export the current config to a JSON file.
- Settings can import a config file after validation.
- Import errors identify the invalid field or unsupported format.
- Imported configs preserve existing migration defaults.

#### Better Unavailable-Target Repair

Make it easier to fix rules that point to missing browsers or profiles.

Acceptance criteria:

- Settings clearly lists unavailable browser/profile targets.
- A rule with an unavailable target can be reassigned from the rule editor.
- Refresh and profile detection flows explain what changed.

#### Hide Browser Options

Allow users to hide detected browsers or profiles from default dropdowns and the
chooser without deleting them from the underlying inventory.

Why it matters:

- Some detected URL handlers are not useful browsers.
- Virtualized browsers or helper apps can clutter the chooser.
- Hiding is safer than deleting because inventory refresh can rediscover items.

Acceptance criteria:

- Browser/profile options can be hidden and unhidden in Settings.
- Hidden options do not appear in the chooser.
- Rules targeting hidden options are handled explicitly, either still allowed or
  marked as hidden.
- Hidden state survives browser inventory refresh.

## P2: Power User Features

These are useful once the core public experience is solid.

#### Manual Browser Options

Allow users to add and edit custom browser options.

Acceptance criteria:

- Users can add a bundle identifier, display name, optional app name, optional
  profile directory, and optional extra arguments.
- The UI validates that a target app exists when possible.
- Custom options survive inventory refresh.

#### Advanced Rule Types

Expand matching without making the common path complicated.

Potential additions:

- scheme-specific rules
- exact URL rules
- query parameter rules
- regular expression rules behind an advanced toggle
- rule groups or presets

#### Tracking Parameter Stripping

Optionally remove common tracking query parameters before forwarding a URL.

Why it matters:

- Tracking parameters can pollute browser history and copied URLs.
- This is useful, but it mutates the requested URL, so it should be opt-in and
  transparent.

Acceptance criteria:

- The feature is disabled by default.
- Users can enable a common tracking-parameter list.
- Users can inspect or customize the parameter list before relying on it.
- The rule tester shows the original URL and forwarded URL.
- The implementation avoids removing parameters that are likely to be required
  for login, payments, or app deep links.

#### Incognito Or Private Window Targets

Allow browser options or rules to open links in private/incognito mode when the
target browser supports it.

Why it matters:

- Some users want certain links, test flows, or one-off accounts isolated from
  normal history and cookies.

Acceptance criteria:

- Chromium targets can add `--incognito` through a clear UI option.
- Browser support differences are documented.
- Private mode variants are named clearly in the chooser.
- Normal and private variants can coexist for the same browser/profile.

#### Diagnostics Export

Provide a privacy-conscious debug bundle for issue reports.

Acceptance criteria:

- Export includes app version, macOS version, handler status, sanitized config,
  and recent sanitized routing events.
- Export excludes full URLs by default.
- Users can inspect the export before sharing.

#### Launch At Login

Add an optional launch-at-login setting.

Why it matters:

- BrowserRouter can launch on demand as the default URL handler, so this is not
  required for core routing.
- It is still useful for users who rely on the menu bar status item or want the
  app ready immediately after login.

Acceptance criteria:

- Settings exposes a launch-at-login toggle.
- The implementation uses the supported macOS service management API for the
  deployment target.
- The app handles registration failures with a clear message.

## Documentation And Community

These are open-source hygiene tasks that can happen alongside feature work.

- [ ] Add screenshots or a short demo GIF to README.
- [x] Add uninstall instructions.
- [ ] Add a changelog.
- [ ] Add issue templates for bugs and feature requests.
- [ ] Document release signing and notarization once public binaries are shipped.
- [ ] Consider Sparkle automatic updates after public signed releases exist.
- [ ] Consider English and Simplified Chinese localization after UI text stabilizes.
- [ ] Add more tests around config migration, browser inventory refresh, profile
  scanning, unavailable fallback, source app routing, tracking stripping, and
  rule priority.

## Done

- [x] Native Swift/AppKit app.
- [x] First-run onboarding.
- [x] Default browser/profile selection.
- [x] Chooser shortcut selection.
- [x] Basic routing rules.
- [x] Chromium profile detection.
- [x] Browser inventory refresh.
- [x] Local JSON configuration.
- [x] Basic GitHub Actions build workflow.
