import Foundation
import StoreKit
import os.log

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    private let logger = Logger(subsystem: "com.bridgeapp.bridge", category: "SubscriptionManager")
    
    @Published var isPro = false
    @Published var subscriptionStatus: SubscriptionStatus = .notSubscribed
    
    enum SubscriptionStatus {
        case notSubscribed
        case pro
        case expired(Date)
        case loading
    }
    
    enum Tier: String, CaseIterable {
        case free = "Free"
        case pro = "Pro"
        
        var price: String {
            switch self {
            case .free: return "Free"
            case .pro: return "$9.99/year"
            }
        }
        
        var features: [String] {
            switch self {
            case .free:
                return [
                    "Single device",
                    "Basic sync",
                    "5GB cloud storage"
                ]
            case .pro:
                return [
                    "Unlimited devices",
                    "All cloud destinations",
                    "Encrypted backups",
                    "Priority support"
                ]
            }
        }
    }
    
    private let proProductID = "com.bridgeapp.bridge.pro"
    
    private init() {
        Task {
            await checkSubscriptionStatus()
        }
    }
    
    // MARK: - StoreKit 2
    
    func checkSubscriptionStatus() async {
        subscriptionStatus = .loading
        
        do {
            let customerProducts = try await CustomerActivity.currentActivity.swift
            let transactions = try await Transaction.currentEntitlements
            
            for transaction in transactions {
                if transaction.productID == proProductID {
                    isPro = true
                    subscriptionStatus = .pro
                    return
                }
            }
            
            isPro = false
            subscriptionStatus = .notSubscribed
        } catch {
            logger.error("Failed to check subscription status: \(error.localizedDescription)")
            subscriptionStatus = .notSubscribed
        }
    }
    
    func purchasePro() async throws -> Bool {
        let products = try await Product.productsForIdentifiers([proProductID])
        
        guard let product = products.first else {
            throw SubscriptionError.productNotFound
        }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            isPro = true
            subscriptionStatus = .pro
            logger.info("Pro subscription purchased successfully")
            return true
            
        case .userCancelled:
            logger.info("User cancelled purchase")
            return false
            
        case .pending:
            logger.info("Purchase pending")
            return false
            
        @unknown default:
            return false
        }
    }
    
    func restorePurchases() async throws {
        try await AppStore.sync()
        await checkSubscriptionStatus()
        logger.info("Purchases restored")
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Tier Limits
    
    func checkFreeTierLimits() -> (devices: Int, cloudUsed: Int64) {
        // Return current usage for free tier warnings
        return (1, 5 * 1024 * 1024 * 1024) // 5GB
    }
    
    func showUpgradePrompt() {
        NotificationCenter.default.post(name: .showUpgradePrompt, object: nil)
    }
}

// MARK: - Errors

enum SubscriptionError: LocalizedError {
    case productNotFound
    case verificationFailed
    case purchaseFailed
    
    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Pro subscription not found"
        case .verificationFailed:
            return "Purchase verification failed"
        case .purchaseFailed:
            return "Purchase failed"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let showUpgradePrompt = Notification.Name("showUpgradePrompt")
}

// MARK: - Pro Upgrade View

struct ProUpgradeView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var isPurchasing = false
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Upgrade to Pro")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Tier.pro.features, id: \.self) { feature in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(feature)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("$9.99/year")
                .font(.title2)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Button("Subscribe") {
                    subscribe()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isPurchasing)
                
                Button("Restore Purchases") {
                    restore()
                }
                .buttonStyle(.bordered)
            }
            
            Button("Maybe Later") {
                dismiss()
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(32)
        .frame(width: 350)
    }
    
    private func subscribe() {
        isPurchasing = true
        
        Task {
            do {
                _ = try await subscriptionManager.purchasePro()
                dismiss()
            } catch {
                print("Purchase failed: \(error)")
            }
            isPurchasing = false
        }
    }
    
    private func restore() {
        Task {
            try? await subscriptionManager.restorePurchases()
        }
    }
}
