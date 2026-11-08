import Foundation
import Observation
import FadenCore

@MainActor @Observable final class DiagnosticLog {
    private(set) var entries: [InferenceDiagnostic] = []
    private let file: URL
    init() {
        file = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Kai-Diagnostics.json")
        if let data = try? Data(contentsOf: file), let saved = try? JSONDecoder().decode([InferenceDiagnostic].self, from: data) { entries = Array(saved.suffix(30)) }
    }
    func append(_ original: InferenceDiagnostic) {
        var value = original
        let info = Bundle.main.infoDictionary ?? [:]
        value.appVersion = "\(info["CFBundleShortVersionString"] as? String ?? "?") (Build \(info["CFBundleVersion"] as? String ?? "?"))"
        entries.append(value); entries = Array(entries.suffix(30))
        persist()
    }
    func clear() { entries = []; persist() }
    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    var text: String { entries.reversed().map(\.readable).joined(separator: "\n\n────────────────\n\n") }
}
