# Contributing

Thanks for taking a look at BrowserRouter.

This project is still an MVP, so small focused pull requests are easiest to
review.

## Local Build

```bash
scripts/build-app.sh
```

The app bundle is written to:

```text
.build/BrowserRouter.app
```

## Good First Areas

- Browser/profile detection for more browsers.
- Better rule editing UI.
- Safer default-browser restore flows.
- A richer chooser UI than the current alert.
- Tests around rule matching and config migration.

## Privacy

BrowserRouter sees external `http` and `https` URLs because macOS sends them to
the default URL handler. Please avoid adding telemetry or persistent URL logging
unless it is explicit, optional, and documented.