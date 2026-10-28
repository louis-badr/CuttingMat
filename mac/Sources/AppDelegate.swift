import Cocoa
import WebKit

/// Menu bar app. Draws the wallpaper with the same JavaScript as the website, inside a
/// hidden web view, and sets it on every connected display whenever the displays change.
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, WKNavigationDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var webView: WKWebView!
    private var engineReady = false
    private var palettes: [(id: String, name: String)] = []
    private var pending: DispatchWorkItem?
    private var busy = false
    private var again = false
    private var againReroll = false
    private var statusText = "Starting…"
    private let defaults = UserDefaults.standard

    private final class RefreshState {
        var palettes: [String: String] = [:]
        var used = Set<String>()
        var summary: [String] = []
    }

    private var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("CuttingMat/wallpapers", isDirectory: true)
    }

    // MARK: launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLocationHelper.promptToMoveIfNeeded()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            if let img = NSImage(systemSymbolName: "square.grid.3x3", accessibilityDescription: "Cutting Mat") {
                button.image = img
            } else {
                button.title = "▦"
            }
        }
        menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        statusItem.isVisible = !defaults.bool(forKey: "hideIcon")

        // Start at login, automatically, once the app sits in Applications.
        if AppLocationHelper.isInApplications && !defaults.bool(forKey: "didSetUpLaunchAtLogin") {
            defaults.set(true, forKey: "didSetUpLaunchAtLogin")
            LaunchAtLoginHelper.setEnabled(true)
        }

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.scheduleRefresh()
        }

        // Hidden web view that runs the drawing code.
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 200, height: 200), configuration: WKWebViewConfiguration())
        webView.navigationDelegate = self
        if let dir = Bundle.main.resourceURL?.appendingPathComponent("engine") {
            webView.loadFileURL(dir.appendingPathComponent("engine.html"), allowingReadAccessTo: dir)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("cmwPalettes()") { [weak self] result, _ in
            guard let self = self else { return }
            if let s = result as? String, let data = s.data(using: .utf8),
               let list = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] {
                self.palettes = list.compactMap { item in
                    guard let id = item["id"], let name = item["name"] else { return nil }
                    return (id: id, name: name)
                }
            }
            self.engineReady = true
            self.refresh(reroll: false)
        }
    }

    // MARK: displays

    private func scheduleRefresh() {
        pending?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.refresh(reroll: false) }
        pending = item
        // let macOS finish reconfiguring the displays first
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: item)
    }

    private func info(for screen: NSScreen) -> [String: Any] {
        let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
        let mm = CGDisplayScreenSize(id)
        let scale = screen.backingScaleFactor
        var pw = Int(screen.frame.width * scale)
        var ph = Int(screen.frame.height * scale)
        if let mode = CGDisplayCopyDisplayMode(id) {
            pw = mode.pixelWidth
            ph = mode.pixelHeight
        }
        // height hidden at the top by the menu bar (and the notch), in pixels
        let menu = (screen.frame.maxY - screen.visibleFrame.maxY) * scale
        return [
            "id": Int(id),
            "name": screen.localizedName,
            "pixelWidth": pw,
            "pixelHeight": ph,
            "widthMM": Double(mm.width),
            "heightMM": Double(mm.height),
            "scale": Double(scale),
            "menuBarPx": Double(menu),
        ]
    }

    private func refresh(reroll: Bool) {
        guard engineReady, !palettes.isEmpty else { return }
        if busy {
            again = true
            againReroll = againReroll || reroll
            return
        }
        busy = true
        statusText = "Updating…"

        let screens = NSScreen.screens
        let infos = screens.map { info(for: $0) }
        let signature = infos.map { "\($0["id"] ?? 0):\($0["name"] ?? ""):\($0["pixelWidth"] ?? 0):\($0["pixelHeight"] ?? 0)" }
            .joined(separator: "|")
        let previous = defaults.dictionary(forKey: "displayPalettes") as? [String: String] ?? [:]
        // A display keeps its random palette until the set of displays changes.
        let keep = (!reroll && defaults.string(forKey: "displaySignature") == signature) ? previous : [:]
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        process(0, screens, infos, RefreshState(), keep, previous, signature)
    }

    private func process(_ i: Int, _ screens: [NSScreen], _ infos: [[String: Any]], _ st: RefreshState,
                         _ keep: [String: String], _ previous: [String: String], _ signature: String) {
        if i >= screens.count {
            finish(st, signature)
            return
        }
        let info = infos[i]
        let name = info["name"] as? String ?? "Display"
        let ids = palettes.map { $0.id }
        let mode = defaults.string(forKey: "paletteMode") ?? "random"
        let pid: String
        if ids.contains(mode) {
            pid = mode
        } else if let k = keep[name], ids.contains(k) {
            pid = k
        } else {
            let pool = ids.filter { $0 != previous[name] }
            pid = pool.randomElement() ?? ids[0]
        }
        st.palettes[name] = pid

        guard let jsonData = try? JSONSerialization.data(withJSONObject: info),
              let json = String(data: jsonData, encoding: .utf8) else {
            process(i + 1, screens, infos, st, keep, previous, signature)
            return
        }
        webView.evaluateJavaScript("cmwRender(\(json), '\(pid)')") { [weak self] result, error in
            guard let self = self else { return }
            if let error = error {
                NSLog("Cutting Mat: render failed for \(name): \(error)")
            } else if let s = result as? String, let data = s.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let b64 = obj["png"] as? String, let png = Data(base64Encoded: b64) {
                let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
                let safe = name.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: "_")
                let w = obj["width"] as? Int ?? 0, h = obj["height"] as? Int ?? 0
                let ppi = obj["ppi"] as? Double ?? 0
                let menuBar = obj["menubar"] as? Int ?? 0
                let file = "\(safe)-\(w)x\(h)-\(pid)-\(Int(ppi * 10))-\(menuBar)-v\(version).png"
                let url = self.folder.appendingPathComponent(file)
                st.used.insert(file)
                do {
                    if !FileManager.default.fileExists(atPath: url.path) { try png.write(to: url) }
                    let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
                        .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,   // fill
                        .allowClipping: true,
                    ]
                    try NSWorkspace.shared.setDesktopImageURL(url, for: screens[i], options: options)
                    st.summary.append("\(name): \(obj["cols"] as? Int ?? 0) × \(obj["rows"] as? Int ?? 0) cm")
                } catch {
                    NSLog("Cutting Mat: could not set wallpaper on \(name): \(error)")
                }
            }
            self.process(i + 1, screens, infos, st, keep, previous, signature)
        }
    }

    private func finish(_ st: RefreshState, _ signature: String) {
        defaults.set(st.palettes, forKey: "displayPalettes")
        defaults.set(signature, forKey: "displaySignature")
        // keep the folder small: only the images in use
        if let files = try? FileManager.default.contentsOfDirectory(atPath: folder.path) {
            for f in files where !st.used.contains(f) {
                try? FileManager.default.removeItem(at: folder.appendingPathComponent(f))
            }
        }
        statusText = st.summary.isEmpty ? "No wallpaper set" : st.summary.joined(separator: "\n")
        busy = false
        if again {
            let r = againReroll
            again = false
            againReroll = false
            refresh(reroll: r)
        }
    }

    // MARK: menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        for line in statusText.components(separatedBy: "\n") {
            let item = NSMenuItem(title: line, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
        menu.addItem(.separator())

        let reroll = NSMenuItem(title: "New random palette", action: #selector(newRandom), keyEquivalent: "r")
        reroll.target = self
        menu.addItem(reroll)

        let paletteItem = NSMenuItem(title: "Palette", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        let mode = defaults.string(forKey: "paletteMode") ?? "random"
        let random = NSMenuItem(title: "Random", action: #selector(pickPalette(_:)), keyEquivalent: "")
        random.target = self
        random.representedObject = "random"
        random.state = mode == "random" ? .on : .off
        sub.addItem(random)
        sub.addItem(.separator())
        for p in palettes {
            let item = NSMenuItem(title: p.name, action: #selector(pickPalette(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = p.id
            item.state = mode == p.id ? .on : .off
            sub.addItem(item)
        }
        paletteItem.submenu = sub
        menu.addItem(paletteItem)

        let open = NSMenuItem(title: "Show Wallpapers in Finder", action: #selector(showFolder), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        menu.addItem(.separator())

        let hide = NSMenuItem(title: "Hide Menu Bar Icon…", action: #selector(hideIcon), keyEquivalent: "")
        hide.target = self
        menu.addItem(hide)

        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = LaunchAtLoginHelper.isEnabled ? .on : .off
        menu.addItem(login)

        let quit = NSMenuItem(title: "Quit Cutting Mat", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func newRandom() {
        defaults.set("random", forKey: "paletteMode")
        refresh(reroll: true)
    }

    @objc private func pickPalette(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        defaults.set(id, forKey: "paletteMode")
        refresh(reroll: id == "random")
    }

    @objc private func showFolder() {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(folder)
    }

    @objc private func hideIcon() {
        let alert = NSAlert()
        alert.messageText = "Hide the menu bar icon?"
        alert.informativeText = "Cutting Mat keeps running in the background. To bring the icon back, open Cutting Mat again from Applications or Spotlight."
        alert.addButton(withTitle: "Hide Icon")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            defaults.set(true, forKey: "hideIcon")
            statusItem.isVisible = false
        }
    }

    /// Opening the app again while it runs with a hidden icon brings the icon back (or quits it).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard defaults.bool(forKey: "hideIcon") else { return true }
        let alert = NSAlert()
        alert.messageText = "Cutting Mat is running with its icon hidden"
        alert.informativeText = "It keeps your wallpapers up to date in the background."
        alert.addButton(withTitle: "Show Menu Bar Icon")
        alert.addButton(withTitle: "Quit Cutting Mat")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            defaults.set(false, forKey: "hideIcon")
            statusItem.isVisible = true
        case .alertSecondButtonReturn:
            NSApplication.shared.terminate(nil)
        default:
            break
        }
        return true
    }

    @objc private func toggleLogin() {
        LaunchAtLoginHelper.setEnabled(!LaunchAtLoginHelper.isEnabled)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
