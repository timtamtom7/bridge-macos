import Foundation

final class SettingsStore: ObservableObject {
    @Published var launchAtLogin: Bool = false
    @Published var syncContactsEnabled: Bool = true
    @Published var importDuplicates: Bool = false
    @Published var backupLocation: URL {
        didSet { UserDefaults.standard.set(backupLocation.path, forKey: "backupLocation") }
    }
    private let defaults = UserDefaults.standard

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let defaultPath = appSupport.appendingPathComponent("Bridge/Backups")
        if let saved = defaults.string(forKey: "backupLocation") {
            self.backupLocation = URL(fileURLWithPath: saved)
        } else {
            self.backupLocation = defaultPath
        }
    }

    func load() {
        launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        syncContactsEnabled = defaults.object(forKey: "syncContactsEnabled") as? Bool ?? true
        importDuplicates = defaults.bool(forKey: "importDuplicates")
    }

    func save() {
        defaults.set(launchAtLogin, forKey: "launchAtLogin")
        defaults.set(syncContactsEnabled, forKey: "syncContactsEnabled")
        defaults.set(importDuplicates, forKey: "importDuplicates")
    }
}
