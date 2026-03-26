import Foundation
import StoreKit

@available(macOS 13.0, *)
public final class BridgeSubscriptionManager: ObservableObject {
    public static let shared = BridgeSubscriptionManager()
    @Published public private(set) var subscription: BridgeSubscription?
    @Published public private(set) var products: [Product] = []
    private init() {}
    public func loadProducts() async {
        do { products = try await Product.products(for: ["com.bridge.macos.pro.monthly","com.bridge.macos.pro.yearly","com.bridge.macos.household.monthly","com.bridge.macos.household.yearly"]) }
        catch { print("Failed to load products") }
    }
    public func canAccess(_ feature: BridgeFeature) -> Bool {
        guard let sub = subscription else { return false }
        switch feature {
        case .advancedSync: return sub.tier != .free
        case .widgets: return sub.tier != .free
        case .shortcuts: return sub.tier != .free
        case .mdm: return sub.tier == .enterprise
        case .sso: return sub.tier == .enterprise
        }
    }
    public func updateStatus() async {
        var found: BridgeSubscription = BridgeSubscription(tier: .free)
        for await result in Transaction.currentEntitlements {
            do {
                let t = try checkVerified(result)
                if t.productID.contains("household") { found = BridgeSubscription(tier: .household, status: t.revocationDate == nil ? "active" : "expired") }
                else if t.productID.contains("pro") { found = BridgeSubscription(tier: .pro, status: t.revocationDate == nil ? "active" : "expired") }
            } catch { continue }
        }
        await MainActor.run { self.subscription = found }
    }
    public func restore() async throws { try await AppStore.sync(); await updateStatus() }
    private func checkVerified<T>(_ r: VerificationResult<T>) throws -> T { switch r { case .unverified: throw NSError(domain: "Bridge", code: -1); case .verified(let s): return s } }
}
public enum BridgeFeature { case advancedSync, widgets, shortcuts, mdm, sso }
