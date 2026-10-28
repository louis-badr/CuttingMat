import Cocoa
import ServiceManagement

enum LaunchAtLoginHelper {
    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return UserDefaults.standard.bool(forKey: "LaunchAtStartup")
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
                } else {
                    if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
                }
                return true
            } catch {
                NSLog("Cutting Mat: could not update launch at login: \(error)")
                return false
            }
        }
        UserDefaults.standard.set(enabled, forKey: "LaunchAtStartup")
        return true
    }
}

enum AppLocationHelper {
    static var isInApplications: Bool {
        let path = Bundle.main.bundlePath
        let userApps = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        return path.hasPrefix("/Applications") || path.hasPrefix(userApps)
    }

    /// When opened straight from the disk image or Downloads, offer to copy the app to /Applications.
    static func promptToMoveIfNeeded() {
        let path = Bundle.main.bundlePath
        if path.contains("/mac/dist/") || isInApplications { return }
        guard path.hasPrefix("/Volumes/") || path.contains("/Downloads/") else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let alert = NSAlert()
            alert.messageText = "Move Cutting Mat to Applications?"
            alert.informativeText = "The app needs to live in your Applications folder to start automatically when you log in."
            alert.addButton(withTitle: "Move to Applications")
            alert.addButton(withTitle: "Not Now")
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn { moveToApplications() }
        }
    }

    private static func moveToApplications() {
        let fm = FileManager.default
        let source = Bundle.main.bundleURL
        let dest = URL(fileURLWithPath: "/Applications").appendingPathComponent(source.lastPathComponent)
        do {
            if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
            try fm.copyItem(at: source, to: dest)
            NSWorkspace.shared.openApplication(at: dest, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                DispatchQueue.main.async {
                    if error == nil { NSApplication.shared.terminate(nil) }
                }
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not move Cutting Mat"
            alert.informativeText = "\(error.localizedDescription)\nYou can drag it into the Applications folder yourself."
            alert.runModal()
        }
    }
}
