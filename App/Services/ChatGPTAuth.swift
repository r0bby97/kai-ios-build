import Foundation
import CryptoKit
import Security
import Network
import Observation
import FadenCore

struct ChatGPTCredential: Codable {
    var clientID: String
    var subject: String
    var email: String
    var accessToken: String
    var refreshToken: String
    var idToken: String
    var scopes: [String]
    var expiresAt: Date
}

@MainActor @Observable final class ChatGPTAuth {
    var browserURL: URL?
    var signingIn = false
    private var listener: NWListener?
    private var continuation: CheckedContinuation<URL, Error>?
    private var timeout: Task<Void, Never>?
    private var refreshTasks: [UUID: Task<ChatGPTCredential, Error>] = [:]
    private let authorize = "https://auth.openai.com/api/accounts/authorize"
    private let tokenEndpoint = URL(string: "https://auth.openai.com/api/accounts/oauth/token")!
    private func credentialKey(_ id: UUID) -> String { "chatgpt.\(id.uuidString)" }
    func credential(_ id: UUID) -> ChatGPTCredential? {
        Keychain.read(credentialKey(id)).flatMap { try? JSONDecoder().decode(ChatGPTCredential.self, from: $0) }
    }
    private func save(_ value: ChatGPTCredential, id: UUID) throws {
        try Keychain.save(JSONEncoder().encode(value), key: credentialKey(id))
    }
    func connect(_ id: UUID) async throws {
        guard !signingIn else { return }
        signingIn = true
        defer { signingIn = false; closeListener() }
        let existing = credential(id)
        let savedID = Keychain.string("client.\(id)")
        let issuedID = existing?.clientID ?? (savedID.isEmpty ? nil : savedID)
        let state = try random(); let nonce = try random(); let verifier = try random(bytes: 48)
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URL
        var hostID = Keychain.string("agent-host")
        if hostID.isEmpty { hostID = "urn:uuid:" + UUID().uuidString.lowercased(); try Keychain.save(hostID, key: "agent-host") }
        let params = NWParameters.tcp
        params.requiredLocalEndpoint = .hostPort(host: .ipv4(IPv4Address.loopback), port: .any)
        let callbackListener = try NWListener(using: params)
        listener = callbackListener
        var redirect = ""
        let callback: URL = try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { (pending: CheckedContinuation<URL, Error>) in
                continuation = pending
                callbackListener.stateUpdateHandler = { [weak self] event in
                    Task { @MainActor in
                        guard let self else { return }
                        switch event {
                        case .ready:
                            guard let port = callbackListener.port else { self.fail(FadenError.network("Die lokale Anmeldung konnte nicht gestartet werden.")); return }
                            redirect = "http://127.0.0.1:\(port.rawValue)/auth/callback"
                            var url = URLComponents(string: self.authorize)!
                            var values: [String: String] = ["client_id": issuedID ?? "dynamic_agent_client",
                                "ext_agent_host_id": hostID, "response_type": "code", "redirect_uri": redirect,
                                "scope": "openid profile email offline_access resource.invoke chatgpt.tokens.use.direct",
                                "resource": "https://api.openai.com/v1", "state": state, "nonce": nonce,
                                "code_challenge_method": "S256", "code_challenge": challenge]
                            if issuedID == nil { values["agent_name_hint"] = "Kai" }
                            if let existing { values["id_token_hint"] = existing.idToken; values["login_hint"] = existing.email }
                            url.queryItems = values.map { URLQueryItem(name: $0.key, value: $0.value) }
                            self.browserURL = url.url
                        case .failed(let error): self.fail(error)
                        default: break
                        }
                    }
                }
                callbackListener.newConnectionHandler = { [weak self] connection in
                    connection.start(queue: .main)
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 16384) { data, _, _, _ in
                        guard let data, let line = String(data: data, encoding: .utf8)?.components(separatedBy: "\r\n").first,
                              line.hasPrefix("GET "), let path = line.split(separator: " ").dropFirst().first,
                              let url = URL(string: "http://127.0.0.1" + path), url.path == "/auth/callback",
                              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
                              parts.queryItems?.first(where: { $0.name == "state" })?.value == state else {
                            connection.cancel(); return
                        }
                        // No token, code, or user information is echoed in the browser response.
                        let html = "<html lang='de'><meta name='viewport' content='width=device-width'><body style='font:20px system-ui;padding:32px'>Du kannst zu Kai zurückkehren.</body></html>"
                        let reply = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n" + html
                        connection.send(content: Data(reply.utf8), completion: .contentProcessed { _ in connection.cancel() })
                        Task { @MainActor in
                            guard let self, let pending = self.continuation else { return }
                            self.continuation = nil; self.browserURL = nil; pending.resume(returning: url)
                        }
                    }
                }
                callbackListener.start(queue: .main)
                timeout = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(240))
                    if !Task.isCancelled { self?.fail(FadenError.network("Die Anmeldung ist abgelaufen. Bitte erneut starten.")) }
                }
            }
        }, onCancel: { Task { @MainActor in self.cancel() } })
        guard let parts = URLComponents(url: callback, resolvingAgainstBaseURL: false) else { throw FadenError.cancelled }
        let query = Dictionary(parts.queryItems?.map { ($0.name, $0.value ?? "") } ?? [], uniquingKeysWith: { first, _ in first })
        guard query["state"] == state else { throw FadenError.invalidData("Die Anmeldung konnte nicht verifiziert werden.") }
        if query["error"] != nil { throw FadenError.network("ChatGPT-Anmeldung oder Kontingentfreigabe wurde nicht abgeschlossen.") }
        guard let code = query["code"], let clientID = query["client_id"] ?? issuedID,
              clientID != "dynamic_agent_client", !clientID.isEmpty,
              issuedID == nil || clientID == issuedID else {
            throw FadenError.invalidData("ChatGPT hat keine passende Client-Registrierung zurückgegeben.")
        }
        // Preserve the issued registration even if exchange needs a fresh attempt.
        try Keychain.save(clientID, key: "client.\(id)")
        let token = try await exchange(["grant_type": "authorization_code", "client_id": clientID,
            "code": code, "code_verifier": verifier, "redirect_uri": redirect, "resource": "https://api.openai.com/v1"])
        guard let idToken = token["id_token"] as? String else { throw FadenError.invalidData("Die Identitätsbestätigung fehlt.") }
        let identity = try await verifyJWT(idToken, clientID: clientID, nonce: nonce)
        guard let subject = identity["sub"] as? String, existing == nil || existing?.subject == subject else {
            throw FadenError.invalidData("Die Anmeldung gehört zu einem anderen Konto.")
        }
        let value = try makeCredential(token, clientID: clientID, subject: subject, email: identity["email"] as? String ?? "ChatGPT-Konto", previous: existing)
        try save(value, id: id); try Keychain.save(clientID, key: "client.\(id)")
    }
    func cancel() { fail(FadenError.cancelled) }
    private func fail(_ error: Error) {
        let pending = continuation; continuation = nil; pending?.resume(throwing: error); closeListener()
    }
    private func closeListener() { timeout?.cancel(); timeout = nil; listener?.cancel(); listener = nil; browserURL = nil }
    func accessToken(_ id: UUID) async throws -> String {
        guard let saved = credential(id) else { throw FadenError.notConfigured }
        if saved.expiresAt.timeIntervalSinceNow > 90 { return saved.accessToken }
        if let task = refreshTasks[id] { return try await task.value.accessToken }
        let task = Task<ChatGPTCredential, Error> {
            let response = try await exchange(["grant_type": "refresh_token", "client_id": saved.clientID,
                "refresh_token": saved.refreshToken, "resource": "https://api.openai.com/v1"])
            let refreshed = try makeCredential(response, clientID: saved.clientID, subject: saved.subject, email: saved.email, previous: saved)
            try save(refreshed, id: id); return refreshed
        }
        refreshTasks[id] = task
        defer { refreshTasks[id] = nil }
        return try await task.value.accessToken
    }
    func disconnect(_ id: UUID) async -> Bool {
        var revoked = true
        if let saved = credential(id) {
            var request = URLRequest(url: URL(string: "https://auth.openai.com/api/accounts/oauth/revoke")!)
            request.httpMethod = "POST"; request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = form(["token": saved.refreshToken, "token_type_hint": "refresh_token", "client_id": saved.clientID])
            do { let (_, response) = try await HTTP.session.data(for: request); revoked = (response as? HTTPURLResponse)?.statusCode == 200 }
            catch { revoked = false }
        }
        Keychain.delete(credentialKey(id)); return revoked
    }
    private func exchange(_ values: [String: String]) async throws -> [String: Any] {
        var request = URLRequest(url: tokenEndpoint); request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = form(values)
        let (data, response) = try await HTTP.session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw FadenError.network("ChatGPT hat die Anmeldung nicht akzeptiert. Bitte erneut verbinden. Die Freigabe kann vom Konto oder der Verfügbarkeit abhängen.")
        }
        return try HTTP.object(data)
    }
    private func makeCredential(_ object: [String: Any], clientID: String, subject: String,
        email: String, previous: ChatGPTCredential?) throws -> ChatGPTCredential {
        let scopes = (object["scope"] as? String)?.split(separator: " ").map(String.init) ?? previous?.scopes ?? []
        guard scopes.contains("chatgpt.tokens.use.direct"), let access = object["access_token"] as? String,
              let refresh = object["refresh_token"] as? String ?? previous?.refreshToken else {
            throw FadenError.network("Die Anmeldung enthält keine Freigabe zur Nutzung deines ChatGPT-Kontingents.")
        }
        return ChatGPTCredential(clientID: clientID, subject: subject, email: email, accessToken: access,
            refreshToken: refresh, idToken: object["id_token"] as? String ?? previous?.idToken ?? "", scopes: scopes,
            expiresAt: Date().addingTimeInterval(object["expires_in"] as? Double ?? 3600))
    }
    private func verifyJWT(_ token: String, clientID: String, nonce: String) async throws -> [String: Any] {
        let parts = token.split(separator: ".").map(String.init)
        guard parts.count == 3, let headerData = Data(base64URL: parts[0]), let payload = Data(base64URL: parts[1]),
              let signature = Data(base64URL: parts[2]) else { throw FadenError.invalidData("Ungültige Identitätsbestätigung.") }
        let header = try HTTP.object(headerData); let claims = try HTTP.object(payload)
        guard header["alg"] as? String == "RS256", let kid = header["kid"] as? String else { throw FadenError.invalidData("Unbekannte Signatur.") }
        let (data, response) = try await HTTP.session.data(from: URL(string: "https://auth.openai.com/.well-known/jwks.json")!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw FadenError.network("Signaturschlüssel konnten nicht geladen werden.") }
        let keys = try HTTP.object(data)["keys"] as? [[String: Any]] ?? []
        guard let jwk = keys.first(where: { $0["kid"] as? String == kid && $0["kty"] as? String == "RSA" }),
              let modulus = jwk["n"] as? String, let exponent = jwk["e"] as? String,
              let n = Data(base64URL: modulus), let e = Data(base64URL: exponent) else { throw FadenError.invalidData("Der Signaturschlüssel fehlt.") }
        func der(_ tag: UInt8, _ content: Data) -> Data {
            let count = content.count
            let length: [UInt8] = count < 128 ? [UInt8(count)] : (count < 256 ? [0x81, UInt8(count)] : [0x82, UInt8(count >> 8), UInt8(count & 255)])
            return Data([tag] + length) + content
        }
        func integer(_ bytes: Data) -> Data { der(0x02, bytes.first.map { $0 & 0x80 != 0 } == true ? Data([0]) + bytes : bytes) }
        let keyData = der(0x30, integer(n) + integer(e))
        let attributes: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeRSA, kSecAttrKeyClass as String: kSecAttrKeyClassPublic]
        guard let key = SecKeyCreateWithData(keyData as CFData, attributes as CFDictionary, nil),
              SecKeyVerifySignature(key, .rsaSignatureMessagePKCS1v15SHA256, Data((parts[0] + "." + parts[1]).utf8) as CFData, signature as CFData, nil) else {
            throw FadenError.invalidData("Die Identitätssignatur ist ungültig.")
        }
        let audience = claims["aud"] as? [String] ?? (claims["aud"] as? String).map { [$0] } ?? []
        guard claims["iss"] as? String == "https://auth.openai.com", audience.contains(clientID),
              let expiry = claims["exp"] as? Double, expiry > Date().timeIntervalSince1970,
              claims["nonce"] as? String == nonce else { throw FadenError.invalidData("Die Identität konnte nicht verifiziert werden.") }
        return claims
    }
    private func random(bytes: Int = 32) throws -> String {
        var buffer = [UInt8](repeating: 0, count: bytes)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes, &buffer) == errSecSuccess else { throw FadenError.invalidData("Sichere Zufallswerte fehlen.") }
        return Data(buffer).base64URL
    }
    private func form(_ values: [String: String]) -> Data {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return Data(values.map { ($0.key.addingPercentEncoding(withAllowedCharacters: allowed) ?? "") + "=" + ($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "") }.joined(separator: "&").utf8)
    }
}
extension Data {
    var base64URL: String { base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") }
    init?(base64URL: String) {
        let raw = base64URL.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        self.init(base64Encoded: raw + String(repeating: "=", count: (4 - raw.count % 4) % 4))
    }
}
