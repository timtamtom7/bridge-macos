import Foundation

// MARK: - Bridge R12: Collaboration & Shared Connections

/// Household device sharing, team workflows, guest access, scenes
final class BridgeCollaborationService: ObservableObject {
    static let shared = BridgeCollaborationService()

    @Published var householdShares: [HouseholdShare] = []
    @Published var sharedWorkflows: [SharedWorkflow] = []
    @Published var guestAccesses: [BridgeGuestAccess] = []
    @Published var scenes: [CollaborativeScene] = []
    @Published var crossHouseholdLinks: [CrossHouseholdLink] = []

    private init() { loadState() }

    // MARK: - Household Device Sharing

    func shareDevice(deviceId: UUID, with memberId: UUID, accessLevel: DeviceAccessLevel) {
        let share = HouseholdShare(id: UUID(), deviceId: deviceId, sharedWith: memberId, accessLevel: accessLevel, createdAt: Date())
        householdShares.append(share); saveState()
    }

    // MARK: - Shared Workflows

    func shareWorkflow(_ workflowId: UUID, with member: TeamMember) {
        let shared = SharedWorkflow(id: UUID(), workflowId: workflowId, sharedWith: member, role: .viewer, version: 1)
        sharedWorkflows.append(shared); saveState()
    }

    // MARK: - Guest Access

    func inviteGuest(deviceId: UUID, email: String, duration: TimeInterval) -> BridgeGuestAccess {
        let guest = BridgeGuestAccess(id: UUID(), deviceId: deviceId, email: email, expiresAt: Date().addingTimeInterval(duration), createdAt: Date())
        guestAccesses.append(guest); saveState(); return guest
    }

    // MARK: - Scenes

    func createScene(name: String, deviceActions: [DeviceAction]) -> CollaborativeScene {
        let scene = CollaborativeScene(id: UUID(), name: name, deviceActions: deviceActions, collaborators: [], createdAt: Date())
        scenes.append(scene); saveState(); return scene
    }

    func inviteToScene(_ sceneId: UUID, member: String) {
        guard let idx = scenes.firstIndex(where: { $0.id == sceneId }) else { return }
        scenes[idx].collaborators.append(member); saveState()
    }

    // MARK: - Persistence

    private var stateURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Bridge/collaboration.json")
    }

    func saveState() {
        try? FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let state = BridgeCollabState(householdShares: householdShares, sharedWorkflows: sharedWorkflows, guestAccesses: guestAccesses, scenes: scenes, crossHouseholdLinks: crossHouseholdLinks)
        try? JSONEncoder().encode(state).write(to: stateURL)
    }

    func loadState() {
        guard let data = try? Data(contentsOf: stateURL),
              let state = try? JSONDecoder().decode(BridgeCollabState.self, from: data) else { return }
        householdShares = state.householdShares; sharedWorkflows = state.sharedWorkflows
        guestAccesses = state.guestAccesses; scenes = state.scenes
        crossHouseholdLinks = state.crossHouseholdLinks
    }
}

// MARK: - Models

struct HouseholdShare: Identifiable, Codable {
    let id: UUID; let deviceId: UUID; let sharedWith: UUID
    var accessLevel: DeviceAccessLevel; let createdAt: Date
}

enum DeviceAccessLevel: String, Codable { case control, viewOnly }

struct SharedWorkflow: Identifiable, Codable {
    let id: UUID; let workflowId: UUID; let sharedWith: TeamMember
    var role: WorkflowRole; var version: Int
}

struct TeamMember: Identifiable, Codable {
    let id: UUID; var name: String; var email: String; var role: BridgeRole
    enum BridgeRole: String, Codable { case admin, member, viewer }
}

enum WorkflowRole: String, Codable { case admin, member, viewer }

struct BridgeGuestAccess: Identifiable, Codable {
    let id: UUID; let deviceId: UUID; var email: String
    var expiresAt: Date?; let createdAt: Date
}

struct CollaborativeScene: Identifiable, Codable {
    let id: UUID; var name: String; var deviceActions: [DeviceAction]
    var collaborators: [String]; let createdAt: Date
}

struct DeviceAction: Codable {
    var deviceId: UUID; var action: String; var parameters: [String: String]
}

struct CrossHouseholdLink: Identifiable, Codable {
    let id: UUID; let household1: UUID; let household2: UUID
    var sharedDeviceIds: [UUID]; let createdAt: Date
}

struct BridgeCollabState: Codable {
    var householdShares: [HouseholdShare]; var sharedWorkflows: [SharedWorkflow]
    var guestAccesses: [BridgeGuestAccess]; var scenes: [CollaborativeScene]
    var crossHouseholdLinks: [CrossHouseholdLink]
}
