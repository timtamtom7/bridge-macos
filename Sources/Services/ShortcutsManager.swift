import AppIntents
import Foundation

// MARK: - App Shortcuts Provider

struct BridgeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetDeviceBatteryIntent(),
            phrases: [
                "Get \(.applicationName) battery status",
                "iOS battery from \(.applicationName)"
            ],
            shortTitle: "Device Battery",
            systemImageName: "battery.100"
        )

        AppShortcut(
            intent: GetDeviceStorageIntent(),
            phrases: [
                "Get \(.applicationName) storage status",
                "iOS storage from \(.applicationName)"
            ],
            shortTitle: "Device Storage",
            systemImageName: "internaldrive"
        )
    }
}

// MARK: - Get Device Battery Intent

struct GetDeviceBatteryIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Device Battery"
    static var description = IntentDescription("Returns the battery status of the primary iOS device")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let device = await BridgeState.shared.primaryDevice

        guard let primary = device else {
            return .result(dialog: "No iOS device connected. Connect a device to Bridge first.")
        }

        let charging = primary.isCharging ? "Charging" : "Not charging"
        let battery = "\(primary.formattedBattery)"

        return .result(dialog: "\(primary.name): Battery \(battery), \(charging)")
    }
}

// MARK: - Get Device Storage Intent

struct GetDeviceStorageIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Device Storage"
    static var description = IntentDescription("Returns the storage status of the primary iOS device")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let device = await BridgeState.shared.primaryDevice

        guard let primary = device else {
            return .result(dialog: "No iOS device connected. Connect a device to Bridge first.")
        }

        let used = primary.formattedStorageUsed
        let total = primary.formattedStorageTotal
        let pct = Int(primary.storageProgress * 100)

        return .result(dialog: "\(primary.name): Storage \(used) / \(total) (\(pct)% used)")
    }
}
