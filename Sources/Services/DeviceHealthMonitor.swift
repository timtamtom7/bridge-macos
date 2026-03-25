import Foundation
import UserNotifications

/// Device health monitoring for Bridge
/// Monitors battery level, storage, and sends alerts when thresholds are exceeded
final class DeviceHealthMonitor {
    static let shared = DeviceHealthMonitor()

    private var timer: Timer?
    private var lastBatteryAlert: Date?
    private var lastStorageAlert: Date?
    private let cooldownInterval: TimeInterval = 3600 // 1 hour between alerts

    // Thresholds
    var lowBatteryThreshold: Double {
        get { UserDefaults.standard.double(forKey: "bridge_lowBatteryThreshold").nonZeroOr(0.20) }
        set { UserDefaults.standard.set(newValue, forKey: "bridge_lowBatteryThreshold") }
    }

    var lowStorageThresholdGB: Double {
        get { UserDefaults.standard.double(forKey: "bridge_lowStorageThreshold").nonZeroOr(5.0) }
        set { UserDefaults.standard.set(newValue, forKey: "bridge_lowStorageThreshold") }
    }

    private init() {}

    // MARK: - Monitor

    func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.checkDevices()
        }
        checkDevices()  // Check immediately
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func checkDevices() {
        Task { @MainActor in
            for device in BridgeState.shared.devices {
                checkBattery(device)
                checkStorage(device)
            }
        }
    }

    private func checkBattery(_ device: Device) {
        guard device.batteryLevel > 0 else { return }  // Skip if no battery

        if device.batteryLevel < lowBatteryThreshold && canSendBatteryAlert() {
            sendBatteryAlert(device: device)
            lastBatteryAlert = Date()
        }
    }

    private func checkStorage(_ device: Device) {
        let storageGB = Double(device.storageTotal - device.storageUsed) / 1_073_741_824.0

        if storageGB < lowStorageThresholdGB && canSendStorageAlert() {
            sendStorageAlert(device: device, availableGB: storageGB)
            lastStorageAlert = Date()
        }
    }

    // MARK: - Cooldown

    private func canSendBatteryAlert() -> Bool {
        guard let last = lastBatteryAlert else { return true }
        return Date().timeIntervalSince(last) > cooldownInterval
    }

    private func canSendStorageAlert() -> Bool {
        guard let last = lastStorageAlert else { return true }
        return Date().timeIntervalSince(last) > cooldownInterval
    }

    // MARK: - Notifications

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification auth error: \(error)")
            }
        }
    }

    private func sendBatteryAlert(device: Device) {
        let content = UNMutableNotificationContent()
        content.title = "Bridge: Low Battery"
        content.body = "\(device.name) battery is at \(device.formattedBattery). Please charge your device."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "low-battery-\(device.udid)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func sendStorageAlert(device: Device, availableGB: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Bridge: Low Storage"
        content.body = "\(device.name) has only \(String(format: "%.1f", availableGB))GB free. Consider freeing up space."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "low-storage-\(device.udid)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}

private extension Double {
    func nonZeroOr(_ defaultValue: Double) -> Double {
        self == 0 ? defaultValue : self
    }
}
