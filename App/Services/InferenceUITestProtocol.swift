#if DEBUG || KAI_TESTING
import Foundation

/// Only installed by an explicit UI-test launch flag; never part of Release.
final class InferenceUITestProtocol: URLProtocol {
    private let stateLock = NSLock()
    private var stopped = false
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "kai-ui-test.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var data = request.httpBody
        if data == nil, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096); var body = Data()
            while stream.hasBytesAvailable { let n = stream.read(&buffer, maxLength: buffer.count); if n <= 0 { break }; body.append(contentsOf: buffer.prefix(n)) }
            data = body
        }
        let object = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any] ?? [:]
        let model = object["model"] as? String ?? ""
        let turns = object["messages"] as? [[String: String]] ?? []
        let secondTurn = turns.last?["content"]?.contains("Zweite Prüfnachricht") == true
        let switching = ProcessInfo.processInfo.arguments.contains("-KaiUIModelSwitchTest")
        let noPrivateThought = !turns.contains { $0["content"]?.contains("PRIVAT_NICHT_SENDEN") == true }
        let history = turns.contains { $0["role"] == "user" && $0["content"]?.contains("Guten Abend.") == true } &&
            turns.contains { $0["role"] == "assistant" && $0["content"]?.contains("Prüfantwort: Mara stellt ihre Tasse ab") == true }
        let visibleTurns = turns.filter { $0["role"] != "system" }
        let alternating = visibleTurns.first?["role"] == "user" && zip(visibleTurns, visibleTurns.dropFirst()).allSatisfy { $0["role"] != $1["role"] }
        let valid = turns.first?["content"]?.contains("Keine Nutzerbeiträge vorgeben") == true && turns.last?["content"]?.contains("Prüfnachricht") == true && noPrivateThought && (!secondTurn || history && alternating)
        let blocked = model == "blocked" || (switching && secondTurn && model == "working")
        var answer = model == "must-skip" ? "FEHLER: Kontoweites Limit wurde ignoriert." : valid ? (secondTurn ? "Prüfantwort zweiter Zug: Der neue Anbieter hat den ersten Dialog erhalten." : "Prüfantwort: Mara stellt ihre Tasse ab und blickt zur Tür.") : "FEHLER: Rollenregeln, privater Schutz oder Verlauf fehlen."
        let longReply = ProcessInfo.processInfo.arguments.contains("-KaiUILongReplyTest")
        if longReply && valid { answer += "\n" + String(repeating: "Sie betrachtet die ruhige Straße. ", count: 45) + "SCROLL_ENDE_42" }
        let payload = try! JSONSerialization.data(withJSONObject: ["choices": [["delta": ["content": answer]]]])
        let text = blocked ? "{\"error\":{\"code\":429}}" : "data: \(String(decoding: payload, as: UTF8.self))\n\ndata: {\"choices\":[{\"delta\":{},\"finish_reason\":\"stop\"}]}\n\ndata: [DONE]\n\n"
        let response = HTTPURLResponse(url: request.url!, statusCode: blocked ? 429 : 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "text/event-stream"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if longReply && !blocked {
            let characters = Array(answer)
            var frames: [Data] = stride(from: 0, to: characters.count, by: 70).map { start in
                let delta = String(characters[start..<min(start + 70, characters.count)])
                let payload = try! JSONSerialization.data(withJSONObject: ["choices": [["delta": ["content": delta]]]])
                return Data("data: \(String(decoding: payload, as: UTF8.self))\n\n".utf8)
            }
            frames.append(Data("data: {\"choices\":[{\"delta\":{},\"finish_reason\":\"stop\"}]}\n\ndata: [DONE]\n\n".utf8))
            emit(frames, index: 0)
            return
        }
        client?.urlProtocol(self, didLoad: Data(text.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    private func emit(_ frames: [Data], index: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.035) { [self] in
            stateLock.lock(); let cancelled = stopped; stateLock.unlock()
            guard !cancelled else { return }
            guard index < frames.count else { client?.urlProtocolDidFinishLoading(self); return }
            client?.urlProtocol(self, didLoad: frames[index])
            emit(frames, index: index + 1)
        }
    }
    override func stopLoading() { stateLock.lock(); stopped = true; stateLock.unlock() }
}
#endif
