#if DEBUG || KAI_TESTING
import Foundation

/// Only installed by an explicit UI-test launch flag; never part of Release.
final class InferenceUITestProtocol: URLProtocol {
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
        let valid = turns.first?["content"]?.contains("Keine Nutzerbeiträge vorgeben") == true && turns.last?["content"]?.contains("Prüfnachricht") == true
        let blocked = model == "blocked"
        let answer = model == "must-skip" ? "FEHLER: Kontoweites Limit wurde ignoriert." : valid ? "Prüfantwort: Mara stellt ihre Tasse ab und blickt zur Tür." : "FEHLER: Rollenregeln oder Nachricht fehlen."
        let payload = try! JSONSerialization.data(withJSONObject: ["choices": [["delta": ["content": answer]]]])
        let text = blocked ? "{\"error\":{\"code\":429}}" : "data: \(String(decoding: payload, as: UTF8.self))\n\ndata: {\"choices\":[{\"delta\":{},\"finish_reason\":\"stop\"}]}\n\ndata: [DONE]\n\n"
        let response = HTTPURLResponse(url: request.url!, statusCode: blocked ? 429 : 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "text/event-stream"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(text.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}
#endif
