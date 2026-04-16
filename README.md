# BrowserRouter

BrowserRouter is a native macOS MVP for routing external `http` and `https`
links to a chosen browser/profile.

It is designed for people who use multiple browsers or multiple Chromium
profiles and want external links, OAuth flows, and app-launched URLs to land in
the right place.

## Status

This is an experimental MVP. It works by becoming the macOS default handler for
`http` and `https`, then forwarding links to the browser/profile you choose.

## Features

- Native Swift/AppKit menu bar app.
- Default browser/profile selection.
- Configurable chooser trigger.
- Simplified domain routing rules.
- Chromium profile discovery for Chrome, Chrome Canary, Edge, Brave, and
  Vivaldi.
- Local-only config stored in Application Support.

## Build

```bash
chmod +x scripts/build-app.sh
scripts/build-app.sh
```

The app bundle is created at:

```text
.build/BrowserRouter.app
```

For a real trial, move the app to a stable location such as `/Applications`
before setting it as the default browser. Otherwise Launch Services may keep a
reference to a temporary build path that you later delete.

## Install For Testing

```bash
chmod +x scripts/install.sh
scripts/install.sh
```

Then use the `Router` menu bar item to set BrowserRouter as the `http` and
`https` default handler.

From now on, updates are the same one-liner:

```bash
scripts/install.sh
```

It rebuilds the app, replaces `/Applications/BrowserRouter.app`, and relaunches
BrowserRouter.

## Try It

1. Open `.build/BrowserRouter.app`.
2. Move it to `/Applications` if you want to keep testing it across rebuilds.
3. Use the menu bar item named `Router`.
4. Choose `Set as HTTP/HTTPS Default`.
5. Click a link from another app.
6. Hold `Command + Shift` while opening a link to show the browser chooser.

If `Command + Shift` is not held, BrowserRouter forwards the URL to the
configured default option.

## Configuration

On first launch, BrowserRouter creates:

```text
~/Library/Application Support/BrowserRouter/config.json
```

Edit `defaultOptionID` and `browserOptions` to match your installed browsers and
Chromium profile directories.

You can also use `Router` -> `Settings...` from the menu bar app. The settings
window includes:

- A default browser/profile dropdown.
- A chooser modifier dropdown.
- A simplified routing rules table.
- A `Detect Chromium Profiles` button that merges profiles discovered from
  Chrome, Chrome Canary, Edge, Brave, and Vivaldi.

The menu bar also includes:

- `Set as HTTP/HTTPS Default`
- `Show Default Handler Status`

Settings changes are saved automatically when you:

- change the default browser/profile
- change the chooser modifier
- refresh browsers
- detect Chromium profiles
- add, update, or remove a rule
- finish editing an existing selected rule

Rule text fields are not saved on every keystroke. They save only when you
finish editing a selected rule or explicitly commit the rule with `Add Rule`,
`Update Selected`, or `Remove Selected`.

Chromium-style profiles use:

```text
--profile-directory=<profileDirectory>
```

Safari and other browsers are opened through `NSWorkspace` without a profile
argument in this MVP.

## Rules

Rules live in `routingRules` and are checked before the default browser fallback.
The configured chooser modifier still wins and always shows the chooser.

Example:

```json
{
  "id": "gmail-work",
  "name": "Gmail Work",
  "browserOptionID": "chrome-default",
  "hostSuffix": "mail.google.com"
}
```

Supported match fields:

- `hostSuffix`: matches an exact host or subdomain, such as `chatgpt.com`.
- `hostContains`: matches any host containing the string.
- `pathPrefix`: matches URL paths that start with the string.
- `urlContains`: matches anywhere in the full URL.

## Privacy

BrowserRouter runs locally and does not upload URLs. Because it is the macOS
default URL handler, it can see external `http` and `https` URLs long enough to
match rules and forward them to the selected browser.

The MVP stores configuration at:

```text
~/Library/Application Support/BrowserRouter/config.json
```

## License

MIT
