import Foundation
import Security

enum Keychain {
    static let service = "dev.r0bby97.faden.credentials"
    static func read(_ key: String) -> Data? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: key,
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var value: CFTypeRef?
        return SecItemCopyMatching(query as CFDictionary, &value) == errSecSuccess ? value as? Data : nil
    }
    static func string(_ key: String) -> String { read(key).flatMap { String(data: $0, encoding: .utf8) } ?? "" }
    static func save(_ data: Data, key: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: key]
        let attributes: [String: Any] = [kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let update = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if update == errSecItemNotFound {
            let status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
            guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
        } else if update != errSecSuccess { throw NSError(domain: NSOSStatusErrorDomain, code: Int(update)) }
    }
    static func save(_ value: String, key: String) throws { try save(Data(value.utf8), key: key) }
    static func delete(_ key: String) {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: key] as CFDictionary)
    }
}

final class NoRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
enum HTTP {
    static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        #if DEBUG || KAI_TESTING
        if ProcessInfo.processInfo.arguments.contains("-KaiUIInferenceTest") { config.protocolClasses = [InferenceUITestProtocol.self] }
        #endif
        config.timeoutIntervalForRequest = 60; config.timeoutIntervalForResource = 240
        config.httpCookieStorage = nil; config.urlCache = nil
        return URLSession(configuration: config, delegate: NoRedirects(), delegateQueue: nil)
    }()
    static func object(_ data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FadenError.invalidData("Unerwartete Serverantwort.")
        }
        return object
    }
    static func requireHTTPS(_ text: String) throws -> URL {
        guard let url = URL(string: text), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else {
            throw FadenError.invalidData("Bitte eine HTTPS-Basisadresse ohne Zugangsdaten oder Parameter angeben.")
        }
        return url
    }
}

import FadenCore
