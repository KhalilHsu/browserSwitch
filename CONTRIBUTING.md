# Contributing

Thanks for taking a look at BrowserRouter.

This project is still beta-quality software, so small focused pull requests are easiest to
review.

## Local Development

```bash
scripts/build-app.sh
```

The app bundle is written to:

```text
.build/BrowserRouter.app
```

Run tests with:

```bash
swift test
```

## Good First Areas

- Browser/profile detection for more browsers.
- Better rule editing UI.
- Rule reordering and rule enable/disable toggles.
- Safer default-browser restore flows.
- A richer chooser UI than the current alert.
- Tests around config migration, browser inventory refresh, and rule matching.
- Release packaging, notarization, screenshots, and documentation polish.

## Privacy

BrowserRouter sees external `http` and `https` URLs because macOS sends them to
the default URL handler. Please avoid adding telemetry or persistent URL logging
unless it is explicit, optional, and documented.
