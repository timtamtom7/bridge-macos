import Foundation

// MARK: - Bridge R13: Enterprise & IT Management

/// MDM, Fleet Management, Compliance, SSO
final class BridgeEnterpriseService: ObservableObject {
    static let shared = BridgeEnterpriseService()

    @Published var enrolledDevices: [BridgeDevice] = []
    @Published var fleetPolicies: [FleetPolicy] = []
    @Published var auditLog: [BridgeAuditEntry] = []
    @Published var ssoConfig: BridgeSSOConfig?

    struct BridgeDevice: Identifiable, Codable {
        let id: String; var name: String; var department: String?
        var firmwareVersion: String; var enrolledAt: Date; var lastSeen: Date
    }

    struct FleetPolicy: Identifiable, Codable {
        let id: UUID; var name: String; var allowlist: [String]; var blocklist: [String]
        var appliesTo: String // department or "all"
    }

    struct BridgeAuditEntry: Identifiable, Codable {
        let id: UUID; let deviceId: String; let action: String; let timestamp: Date
    }

    struct BridgeSSOConfig: Codable {
        var provider: BridgeSSOProvider; var enabled: Bool
        enum BridgeSSOProvider: String, Codable { case okta, azureAD, googleWorkspace }
    }

    private init() { loadState() }

    func enrollDevice(id: String, name: String) -> BridgeDevice {
        let device = BridgeDevice(id: id, name: name, department: nil, firmwareVersion: "1.0", enrolledAt: Date(), lastSeen: Date())
        enrolledDevices.append(device)
        logAudit(deviceId: id, action: "enrolled"); saveState(); return device
    }

    func logAudit(deviceId: String, action: String) {
        let entry = BridgeAuditEntry(id: UUID(), deviceId: deviceId, action: action, timestamp: Date())
        auditLog.insert(entry, at: 0); saveState()
    }

    func applyPolicy(_ policy: FleetPolicy) {
        fleetPolicies.append(policy); saveState()
    }

    private var stateURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Bridge/enterprise.json")
    }

    func saveState() {
        try? FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let state = BridgeEnterpriseState(enrolledDevices: enrolledDevices, fleetPolicies: fleetPolicies, auditLog: auditLog, ssoConfig: ssoConfig)
        try? JSONEncoder().encode(state).write(to: stateURL)
    }

    func loadState() {
        guard let data = try? Data(contentsOf: stateURL),
              let state = try? JSONDecoder().decode(BridgeEnterpriseState.self, from: data) else { return }
        enrolledDevices = state.enrolledDevices; fleetPolicies = state.fleetPolicies
        auditLog = state.auditLog; ssoConfig = state.ssoConfig
    }
}

struct BridgeEnterpriseState: Codable {
    var enrolledDevices: [BridgeEnterpriseService.BridgeDevice]
    var fleetPolicies: [BridgeEnterpriseService.FleetPolicy]
    var auditLog: [BridgeEnterpriseService.BridgeAuditEntry]
    var ssoConfig: BridgeEnterpriseService.BridgeSSOConfig?
}
