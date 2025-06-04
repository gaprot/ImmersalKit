import Foundation
import Security

/// Token management for Immersal API access

public protocol TokenProvider {
  var token: String? { get }
  func setToken(_ token: String?)
  var debugDescription: String { get }
}

/// Token provider that reads from bundle Info.plist
public final class BundleTokenProvider: TokenProvider {
  private var _token: String?

  public var token: String? {
    _token ?? bundleToken
  }

  private var bundleToken: String? {
    guard let token = Bundle.main.object(forInfoDictionaryKey: "ImmersalToken") as? String else {
      return nil
    }
    return token.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  public init() {}

  public func setToken(_ token: String?) {
    _token = token
  }

  public var debugDescription: String {
    let hasRuntimeToken = _token != nil
    let hasBundleToken = bundleToken != nil
    let hasToken = token != nil

    return
      "BundleTokenProvider(runtime: \(hasRuntimeToken), bundle: \(hasBundleToken), available: \(hasToken))"
  }
}

/// Token provider with static value
public final class StaticTokenProvider: TokenProvider {
  private let _token: String?

  public var token: String? {
    _token
  }

  public init(token: String?) {
    _token = token
  }

  public func setToken(_ token: String?) {
  }

  public var debugDescription: String {
    let hasToken = _token != nil
    return "StaticTokenProvider(available: \(hasToken))"
  }
}

/// Secure token provider using Keychain
public final class SecureTokenProvider: TokenProvider {
  private static let service = "com.immersal.token"
  private static let account = "api-token"

  public var token: String? {
    return getTokenFromKeychain()
  }

  public init() {}

  public func setToken(_ token: String?) {
    if let token = token {
      saveTokenToKeychain(token)
    } else {
      deleteTokenFromKeychain()
    }
  }

  private func saveTokenToKeychain(_ token: String) {
    let tokenData = Data(token.utf8)

    deleteTokenFromKeychain()

    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.service,
      kSecAttrAccount as String: Self.account,
      kSecValueData as String: tokenData,
      kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    ]

    let status = SecItemAdd(query as CFDictionary, nil)
    if status != errSecSuccess {
      print("⚠️ SecureTokenProvider: Failed to save token to Keychain with status: \(status)")
    }
  }

  private func getTokenFromKeychain() -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.service,
      kSecAttrAccount as String: Self.account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)

    guard status == errSecSuccess,
      let tokenData = item as? Data,
      let token = String(data: tokenData, encoding: .utf8)
    else {
      return nil
    }

    return token
  }

  private func deleteTokenFromKeychain() {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.service,
      kSecAttrAccount as String: Self.account,
    ]

    SecItemDelete(query as CFDictionary)
  }

  public var debugDescription: String {
    let hasToken = getTokenFromKeychain() != nil
    return "SecureTokenProvider(keychain_available: \(hasToken))"
  }
}
