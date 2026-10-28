# Cutting Mat (Mac app)

Menu bar app (Swift, `LSUIElement`) that sets a cutting-mat wallpaper on every connected display, true to scale (1 grid square = 1 cm, `cm = ppi / 2.54` pixels).

## Conventions
- `mac/build.sh` builds `CuttingMat.app` and `CuttingMat.dmg` (app + `Applications` symlink, `hdiutil`, ad-hoc `codesign`), like PomoTL's `mac/build.sh`. Needs Xcode command line tools.
- The app draws with `js/devices.js`, `js/draw-mat.js`, `js/render.js` (copied into `Resources/engine`) plus `mac/Resources/bridge.js`, inside a hidden `WKWebView`. Classic scripts, no modules, no build step.
- Palettes live in `js/render.js` (`PALETTES`); the app reads the list from the web view.
- The same engine is used by a separate website project (not in this repo). Keep `js/` files compatible with it.
- Menu bar icon can be hidden (`hideIcon` default); re-opening the app shows a dialog to bring it back.
- CI (`.github/workflows/build.yml`) builds on every push to `main` and replaces the single `latest` release with the new `CuttingMat.dmg`. Check the Actions logs for Swift compile errors.
- Folders and code in English.
