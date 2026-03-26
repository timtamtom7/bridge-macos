import Foundation

/// R16: Subscription tiers for Bridge
public enum BridgeSubscriptionTier: String, Codable, CaseIterable {
    case free = "free"
    case pro = "pro"
    case household = "household"
    case enterprise = "enterprise"
    
    public var displayName: String {
        switch self { case .free: return "Free"; case .pro: return "Bridge Pro"; case .household: return "Bridge Household"; case .enterprise: return "Bridge Enterprise" }
    }
    public var monthlyPrice: Decimal? {
        switch self { case .free: return nil; case .pro: return 3.99; case .household: return 6.99; case .enterprise: return nil }
    }
    public var maxDevices: Int {
        switch self { case .free: return 2; case .pro: return 5; case .household: return 20; case .enterprise: return Int.max }
    }
    public var supportsAdvancedSync: Bool { self != .free }
    public var supportsWidgets: Bool { self != .free }
    public var supportsShortcuts: Bool { self != .free }
    public var supportsMDM: Bool { self == .enterprise }
    public var supportsSSO: Bool { self == .enterprise }
    public var trialDays: Int { self == .free ? 0 : 14 }
}

public struct BridgeSubscription: Codable {
    public let tier: BridgeSubscriptionTier
    public let status: String
    public let expiresAt: Date?
    public init(tier: BridgeSubscriptionTier, status: String = "active", expiresAt: Date? = nil) {
        self.tier = tier; self.status = status; self.expiresAt = expiresAt
    }
}
