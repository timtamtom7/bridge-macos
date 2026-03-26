import Foundation
import CryptoKit

public final class BridgePrivacyService {
    public static let shared = BridgePrivacyService()
    private let keychainService = "com.bridge.macos.privacy"
    private init() {}
    public func getOrCreateKey() throws -> SymmetricKey {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService, kSecAttrAccount as String: "bridge-key", kSecReturnData as String: true]
        var result: AnyObject?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data { return SymmetricKey(data: data) }
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        let storeQuery: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService, kSecAttrAccount as String: "bridge-key", kSecValueData as String: keyData, kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        SecItemDelete(storeQuery as CFDictionary); SecItemAdd(storeQuery as CFDictionary, nil)
        return key
    }
    public func encrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateKey()
        let box = try AES.GCM.seal(data, using: key)
        guard let combined = box.combined else { throw NSError(domain: "BridgePrivacy", code: -1) }
        return combined
    }
    public func wipeAllData() { if let bundleId = Bundle.main.bundleIdentifier { UserDefaults.standard.removePersistentDomain(forName: bundleId) } }
    public static var privacyManifest: [String: Any] { ["NSPrivacyTracking": false, "NSPrivacyTrackingDomains": [], "NSPrivacyCollectedDataTypes": [], "NSPrivacyAccessedDataTypes": [["NSPrivacyAccessedDataType": "NSPrivacyAccessedDataTypeUserDefaults", "NSPrivacyAccessedDataTypeReasons": ["CA92.1"]]]] }
}
