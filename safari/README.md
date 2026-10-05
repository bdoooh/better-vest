# Better Vest for Safari

The same extension as [`../extension`](../extension), packaged for Safari on macOS (and optionally iPadOS / iOS).
`build.py` makes the Safari copy from the Chrome source, so there is still only one codebase to keep up to date.

## Requirements

- Safari 18 or later (macOS 15 Sequoia, or macOS 13 / 14 with Safari 18 installed). Safari 18 is the first
  version that runs a manifest content script in the page's `MAIN` world, which the suite needs.
- Xcode 15 or later, to build the app that carries the extension. A free Apple ID is enough to run it on your own Mac.
- Python 3 (comes with Xcode's command line tools).

## Build and install

```sh
python3 safari/build.py --xcode --bundle-id com.yourname.better-vest
open "safari/build/xcode/Better Vest/Better Vest.xcodeproj"
```

1. In Xcode, select the **Better Vest (macOS)** scheme, set your team under *Signing & Capabilities* for both
   the app and the extension targets, and press **Run**. The app opens once. You can close it.
2. Safari > Settings > Extensions: turn on **Better Vest**.
   If you haven't signed it with a paid developer account, first turn on Safari > Settings > Advanced >
   *Show features for web developers*, then Develop > *Allow Unsigned Extensions*. Safari turns this off
   again each time it quits.
3. Open https://next.vestmarkets.com. Safari asks before the extension can run on a site: click the
   Better Vest toolbar icon (or the prompt) and choose **Always Allow on This Website**.

Add `--ios` to also get an iPadOS / iOS target. The chart, the Execute card and the Calendar work there, but the
hotkeys need a hardware keyboard.

## Updating

There is no in-app updater in the Safari version (see below). To update, pull the new `extension/` source,
run `python3 safari/build.py` again, and press **Run** in Xcode. The Xcode project points at
`safari/build/extension`, so you don't need to make it again (only after adding `--ios`, or when you change
the bundle id).

## What's different from the Chrome version

| | Chrome | Safari |
|---|---|---|
| Self-updater | Asks `api.github.com` every 6 hours and rewrites its own folder with files downloaded from `raw.githubusercontent.com` | **Removed.** No GitHub requests at all. Safari runs the extension from inside a signed app it can't rewrite. Update by rebuilding. |
| Site access | Granted at install | Safari asks you for `next.vestmarkets.com` on first visit |
| Calendar / certificate tab reuse | Focuses an already-open Calendar tab | Safari has no `runtime.getContexts`, so it opens a new tab each time |
| Everything else | — | Same code, unchanged |

`build.py` makes these changes:

- It turns off the `UPDATER` switch in `sw.js`, the same switch the WICKED build uses. With it off, the
  service worker never contacts GitHub and never creates the update alarm. The popup and the dock also hide
  every update control.
- It leaves out `update.html`, `update/page.js`, `update/key.js`, `update/update.css`, `files.json`,
  `files.json.sig` and `INSTALL.txt`.
- It adds `browser_specific_settings.safari.strict_min_version: "18.0"` to the manifest.

Each patch checks that the code it changes is still there, so an upstream change that moves it makes
`build.py` fail instead of quietly shipping an unpatched file.

## Not yet tested in Safari

The build has only been checked by script, not run in Safari. Test these first:

- **Certificate PNG export.** It draws an SVG `<foreignObject>` onto a canvas. WebKit has a history of tainting
  the canvas when you do that, so *Save image* may fail.
- Vest's page CSP and the `MAIN`-world script on Safari's first page load. If the dock doesn't appear, reload
  the tab once after granting site access.
