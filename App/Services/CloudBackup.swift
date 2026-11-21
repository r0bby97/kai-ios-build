import CommonCrypto
import CryptoKit
import FadenCore
import Foundation
import Observation
import UIKit

struct CloudBackupPayload: Codable, Sendable {
    var archive: Archive
    var apiKeys: [UUID: String]
}

enum CloudBackupFormat {
    private static let header = Data("KaiBackup1".utf8)
    static let saltLength = 16
    static let maximumBytes = 64 * 1024 * 1024

    static func makeSalt() -> Data {
        SymmetricKey(size: .bits128).withUnsafeBytes { Data($0) }
    }

    static func deriveKey(password: String, salt: Data) throws -> Data {
        guard !password.isEmpty, password.utf8.count <= 1_024, salt.count == saltLength else {
            throw FadenError.invalidData("Ungültiges Sicherungspasswort.")
        }
        let passwordBytes = Data(password.precomposedStringWithCanonicalMapping.utf8)
        var bytes = Data(count: 32)
        let status = bytes.withUnsafeMutableBytes { output in
            passwordBytes.withUnsafeBytes { input in
                salt.withUnsafeBytes { saltBuffer in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2), input.bindMemory(to: Int8.self).baseAddress,
                        passwordBytes.count, saltBuffer.bindMemory(to: UInt8.self).baseAddress,
                        salt.count, CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 600_000,
                        output.bindMemory(to: UInt8.self).baseAddress, output.count
                    )
                }
            }
        }
        guard status == kCCSuccess else {
            throw FadenError.invalidData("Die Verschlüsselung konnte nicht vorbereitet werden.")
        }
        return bytes
    }

    static func seal(_ payload: CloudBackupPayload, key: Data, salt: Data) throws -> Data {
        guard key.count == 32, salt.count == saltLength else {
            throw FadenError.invalidData("Die Verschlüsselung muss neu eingerichtet werden.")
        }
        let plaintext = try JSONEncoder().encode(payload)
        let prefix = header + salt
        guard plaintext.count <= maximumBytes - prefix.count - 28 else {
            throw FadenError.invalidData("Die automatische Sicherung ist größer als 64 MB.")
        }
        let sealed = try AES.GCM.seal(plaintext, using: SymmetricKey(data: key), authenticating: prefix)
        guard let combined = sealed.combined else {
            throw FadenError.invalidData("Die Sicherung konnte nicht verschlüsselt werden.")
        }
        return prefix + combined
    }

    static func open(_ data: Data, password: String) throws -> CloudBackupPayload {
        let prefixLength = header.count + saltLength
        guard data.count >= prefixLength + 28, data.count <= maximumBytes,
              data.starts(with: header) else {
            throw FadenError.invalidData("Diese Datei ist keine unterstützte Kai-Sicherung.")
        }
        let prefix = Data(data.prefix(prefixLength))
        let key = try deriveKey(password: password, salt: Data(prefix.suffix(saltLength)))
        let plaintext: Data
        do {
            let box = try AES.GCM.SealedBox(combined: data.dropFirst(prefixLength))
            plaintext = try AES.GCM.open(box, using: SymmetricKey(data: key), authenticating: prefix)
        } catch {
            throw FadenError.invalidData("Das Passwort passt nicht oder die Sicherung ist beschädigt.")
        }
        let payload = try JSONDecoder().decode(CloudBackupPayload.self, from: plaintext)
        try payload.archive.validate()
        return payload
    }
}

struct CloudBackupFile: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let size: Int
    var filename: String { Self.filename(id) }

    static func filename(_ id: UUID) -> String {
        "Kai-\(id.uuidString).kaibackup"
    }

    static func id(for url: URL) -> UUID? {
        let name = url.deletingPathExtension().lastPathComponent
        guard url.pathExtension == "kaibackup", name.hasPrefix("Kai-") else { return nil }
        return UUID(uuidString: String(name.dropFirst(4)))
    }
}

enum CloudBackupFolder {
    static func access<Value>(bookmark: Data, _ work: (URL) throws -> Value) throws -> Value {
        var stale = false
        let folder = try URL(resolvingBookmarkData: bookmark, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
        guard !stale, folder.startAccessingSecurityScopedResource() else {
            throw FadenError.invalidData("Wähle den Sicherungsordner erneut, damit Kai darauf zugreifen kann.")
        }
        defer { folder.stopAccessingSecurityScopedResource() }
        return try work(folder)
    }

    static func files(in bookmark: Data) throws -> [CloudBackupFile] {
        try access(bookmark: bookmark) { folder in
            var coordinationError: NSError?
            var result: Result<[CloudBackupFile], Error>?
            NSFileCoordinator().coordinate(readingItemAt: folder, options: [], error: &coordinationError) { url in
                result = Result {
                    let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey]
                    let entries = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles])
                    return entries.compactMap { file in
                        guard let id = CloudBackupFile.id(for: file), let meta = try? file.resourceValues(forKeys: keys),
                              meta.isRegularFile == true, meta.isSymbolicLink != true else { return nil }
                        return CloudBackupFile(id: id, date: meta.contentModificationDate ?? .distantPast, size: meta.fileSize ?? 0)
                    }.sorted { $0.date > $1.date }
                }
            }
            if let coordinationError { throw coordinationError }
            return try required(result)
        }
    }

    static func write(_ data: Data, id: UUID, in bookmark: Data) throws {
        try access(bookmark: bookmark) { folder in
            let file = folder.appendingPathComponent(CloudBackupFile.filename(id), isDirectory: false)
            var coordinationError: NSError?
            var result: Result<Void, Error>?
            NSFileCoordinator().coordinate(writingItemAt: file, options: .forReplacing, error: &coordinationError) { url in
                result = Result { try data.write(to: url, options: .atomic) }
            }
            if let coordinationError { throw coordinationError }
            try required(result)
        }
    }

    static func read(_ file: CloudBackupFile, in bookmark: Data) throws -> Data {
        try access(bookmark: bookmark) { folder in
            let target = folder.appendingPathComponent(file.filename, isDirectory: false)
            var coordinationError: NSError?
            var result: Result<Data, Error>?
            NSFileCoordinator().coordinate(readingItemAt: target, options: [], error: &coordinationError) { url in
                result = Result {
                    let meta = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
                    guard meta.isRegularFile == true, meta.isSymbolicLink != true,
                          let size = meta.fileSize, size <= CloudBackupFormat.maximumBytes else {
                        throw FadenError.invalidData("Die Datei kann nicht als Kai-Sicherung geöffnet werden.")
                    }
                    return try Data(contentsOf: url, options: .mappedIfSafe)
                }
            }
            if let coordinationError { throw coordinationError }
            return try required(result)
        }
    }

    private static func required<Value>(_ result: Result<Value, Error>?) throws -> Value {
        guard let result else { throw FadenError.invalidData("Der Sicherungsordner ist gerade nicht verfügbar.") }
        return try result.get()
    }
}

@MainActor @Observable final class CloudBackup {
    private struct Location: Codable {
        let bookmark: Data
        let name: String
        var id = UUID()
        var salt: Data?
        var includeKeys = false
        var lastSavedAt: Date?
        var size: Int?
        var keyName: String { "cloud-backup.\(id.uuidString)" }
    }

    private let settingsURL: URL
    private var location: Location?
    private var scheduled: Task<Void, Never>?
    private var changed = false
    private(set) var busy = false
    private(set) var files: [CloudBackupFile] = []
    var failure: String?
    var folderName: String? { location?.name }
    var enabled: Bool { location?.salt != nil }
    var includesAPIKeys: Bool { location?.includeKeys ?? false }
    var lastSavedAt: Date? { location?.lastSavedAt }
    var size: Int? { location?.size }

    init(directory: URL) {
        settingsURL = directory.appendingPathComponent("cloud-backup.json")
        if let data = try? Data(contentsOf: settingsURL) {
            location = try? JSONDecoder().decode(Location.self, from: data)
        }
    }

    func selectFolder(_ folder: URL) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        failure = nil
        do {
            guard folder.startAccessingSecurityScopedResource() else {
                throw FadenError.invalidData("Kai hat keinen Zugriff auf diesen Ordner.")
            }
            let bookmark: Data
            do {
                defer { folder.stopAccessingSecurityScopedResource() }
                bookmark = try folder.bookmarkData(options: [.minimalBookmark], includingResourceValuesForKeys: nil, relativeTo: nil)
            }
            let available = try await Task.detached(priority: .utility) { try CloudBackupFolder.files(in: bookmark) }.value
            let previous = location
            try persist(Location(bookmark: bookmark, name: folder.lastPathComponent))
            scheduled?.cancel()
            scheduled = nil
            changed = false
            if let previous { Keychain.delete(previous.keyName) }
            files = available
        } catch { failure = error.localizedDescription }
    }

    func enable(password: String, includeKeys: Bool) async -> Bool {
        guard !busy, var location else { return false }
        busy = true
        defer { busy = false }
        failure = nil
        do {
            guard password.count >= 12 else {
                throw FadenError.invalidData("Wähle ein Wiederherstellungspasswort mit mindestens 12 Zeichen.")
            }
            let salt = CloudBackupFormat.makeSalt()
            let key = try await Task.detached(priority: .userInitiated) {
                try CloudBackupFormat.deriveKey(password: password, salt: salt)
            }.value
            let previous = location
            location.id = UUID()
            location.salt = salt
            location.includeKeys = includeKeys
            location.lastSavedAt = nil
            location.size = nil
            try Keychain.save(key, key: location.keyName)
            do { try persist(location) }
            catch { Keychain.delete(location.keyName); throw error }
            Keychain.delete(previous.keyName)
            return true
        } catch {
            failure = error.localizedDescription
            return false
        }
    }

    func pause() {
        guard !busy, var location else { return }
        failure = nil
        do {
            location.salt = nil
            location.includeKeys = false
            try persist(location)
            Keychain.delete(location.keyName)
            scheduled?.cancel()
            scheduled = nil
            changed = false
        } catch { failure = error.localizedDescription }
    }

    func setIncludesAPIKeys(_ include: Bool) -> Bool {
        guard !busy, var location, location.salt != nil else { return false }
        do {
            location.includeKeys = include
            try persist(location)
            return true
        } catch {
            failure = error.localizedDescription
            return false
        }
    }

    func refreshFiles() async {
        guard let bookmark = location?.bookmark, !busy else { return }
        busy = true
        defer { busy = false }
        failure = nil
        do { files = try await Task.detached(priority: .utility) { try CloudBackupFolder.files(in: bookmark) }.value }
        catch { failure = error.localizedDescription }
    }

    func read(_ file: CloudBackupFile, password: String) async throws -> CloudBackupPayload {
        guard let bookmark = location?.bookmark, !busy else {
            throw FadenError.invalidData("Warte, bis der aktuelle Vorgang abgeschlossen ist.")
        }
        busy = true
        defer { busy = false }
        return try await Task.detached(priority: .userInitiated) {
            let data = try CloudBackupFolder.read(file, in: bookmark)
            return try CloudBackupFormat.open(data, password: password)
        }.value
    }

    func request(immediately: Bool = false, snapshot: @escaping @MainActor () -> CloudBackupPayload?) {
        guard enabled else { return }
        changed = true
        if immediately {
            scheduled?.cancel()
            scheduled = nil
        }
        schedule(delay: immediately ? .zero : .seconds(20), snapshot: snapshot)
    }

    private func schedule(delay: Duration, snapshot: @escaping @MainActor () -> CloudBackupPayload?) {
        guard scheduled == nil else { return }
        scheduled = Task { [weak self] in
            do { try await Task.sleep(for: delay) }
            catch { return }
            guard let self else { return }
            self.scheduled = nil
            await self.write(snapshot: snapshot)
        }
    }

    private func write(snapshot: @escaping @MainActor () -> CloudBackupPayload?) async {
        guard changed, let location, let salt = location.salt else { return }
        guard !busy else {
            schedule(delay: .seconds(5), snapshot: snapshot)
            return
        }
        guard let payload = snapshot() else { return }
        guard let key = Keychain.read(location.keyName) else {
            failure = "Der lokale Verschlüsselungsschlüssel fehlt. Richte die automatische Sicherung erneut ein."
            return
        }
        busy = true
        changed = false
        failure = nil
        let background = BackupBackgroundTime()
        defer { busy = false; background.end() }
        do {
            let size = try await Task.detached(priority: .utility) {
                let data = try CloudBackupFormat.seal(payload, key: key, salt: salt)
                try CloudBackupFolder.write(data, id: location.id, in: location.bookmark)
                return data.count
            }.value
            var saved = location
            saved.lastSavedAt = Date()
            saved.size = size
            try persist(saved)
            files.removeAll { $0.id == saved.id }
            files.insert(.init(id: saved.id, date: saved.lastSavedAt ?? Date(), size: size), at: 0)
            if changed { schedule(delay: .seconds(20), snapshot: snapshot) }
        } catch {
            changed = true
            failure = "Der Sicherungsordner konnte nicht beschrieben werden. " + error.localizedDescription
        }
    }

    private func persist(_ value: Location) throws {
        let data = try JSONEncoder().encode(value)
        try data.write(to: settingsURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        location = value
    }
}

@MainActor private final class BackupBackgroundTime {
    private var identifier: UIBackgroundTaskIdentifier = .invalid
    init() {
        identifier = UIApplication.shared.beginBackgroundTask(withName: "Kai Cloud Backup") { [weak self] in
            Task { @MainActor in self?.end() }
        }
    }
    func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
