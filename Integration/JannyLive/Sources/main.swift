import AppKit
import WebKit
import FadenCore

@MainActor final class Probe: NSObject, WKNavigationDelegate, WKDownloadDelegate, WKUIDelegate {
    var web: WKWebView!
    var window: NSWindow!
    var expectedID = ""
    var report: [String: Any] = ["complete": false]
    var destination: URL?
    var finished = false
    func run() async {
        do {
            let source = try String(contentsOfFile: "App/Services/JannyCatalogue.swift", encoding: .utf8)
            let prefix = source.components(separatedBy: "publicSearchKey = \"")
            guard prefix.count > 1, let key = prefix[1].split(separator: "\"").first else { throw failure("Missing public search configuration") }
            var request = URLRequest(url: URL(string: "https://search.jannyai.com/multi-search")!)
            request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer " + key, forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["queries": [["indexUid": "janny-characters", "q": "detective", "page": 1, "hitsPerPage": 1, "filter": ["isNsfw = false"]]]])
            let (data, response) = try await URLSession.shared.data(for: request)
            report["searchHTTP"] = (response as? HTTPURLResponse)?.statusCode
            guard let card = try JannyCatalogueCodec.decode(data).cards.first else { throw failure("No public SFW search result") }
            expectedID = String(card.id.dropFirst(6))
            guard let url = JannyWebsite.cardURL(id: expectedID, name: card.name) else { throw failure("Invalid card URL") }
            report["sourceURL"] = url.absoluteString
            let config = WKWebViewConfiguration()
            web = WKWebView(frame: NSRect(x: 0, y: 0, width: 900, height: 850), configuration: config)
            web.navigationDelegate = self; web.uiDelegate = self
            window = NSWindow(contentRect: web.frame, styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.contentView = web; window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            web.load(URLRequest(url: url))
            for _ in 0..<45 {
                if finished { return }
                try await Task.sleep(for: .seconds(1))
                guard let current = web.url, JannyWebsite.cardID(in: current) == expectedID else { continue }
                if let state = try? await web.evaluateJavaScript("""
                (() => ({title: document.title, verification: /just a moment|verify you are human|security verification/i.test(document.title + ' ' + (document.body?.innerText || '').slice(0,500)), controls: [...document.querySelectorAll('button,a,[role="menuitem"]')].filter(e => e.getClientRects().length).map(e => (e.innerText || e.getAttribute('aria-label') || '').trim()).filter(x => /download|export|definition|personality|scenario/i.test(x)).slice(0,12)}))()
                """) as? [String: Any] {
                    report["page"] = state
                    if state["verification"] as? Bool != true { _ = try? await web.evaluateJavaScript(JannyWebsite.exportScript) }
                }
            }
            finish(error: "No completed public export; any website verification was left untouched")
        } catch { finish(error: error.localizedDescription) }
    }
    func failure(_ message: String) -> NSError { NSError(domain: "JannyLiveProbe", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    func finish(error: String? = nil) {
        guard !finished else { return }; finished = true
        if let error { report["error"] = error }
        let data = (try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])) ?? Data()
        try? data.write(to: URL(fileURLWithPath: "janny-live-result.json"))
        print(String(decoding: data, as: UTF8.self))
        Darwin.exit(report["complete"] as? Bool == true ? 0 : 2)
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if navigationResponse.isForMainFrame, let http = navigationResponse.response as? HTTPURLResponse { report["pageHTTP"] = http.statusCode; report["websiteVerification"] = http.value(forHTTPHeaderField: "cf-mitigated") }
        decisionHandler(navigationResponse.canShowMIMEType ? .allow : .download)
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(navigationAction.shouldPerformDownload ? .download : .allow)
    }
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) { download.delegate = self }
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) { download.delegate = self }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? { if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }; return nil }
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        destination = file; completionHandler(file)
    }
    func downloadDidFinish(_ download: WKDownload) {
        do {
            guard let destination else { throw failure("No completed file") }
            defer { try? FileManager.default.removeItem(at: destination) }
            let data = try Data(contentsOf: destination); let card = try CardCodec.decode(data)
            let image = NSImage(data: data)
            report["definitionCharacters"] = card.description.count + card.personality.count
            report["greetingCharacters"] = card.firstMessage.count
            report["downloadBytes"] = data.count; report["originalImage"] = image != nil
            report["complete"] = card.hasDefinition && !card.firstMessage.isEmpty && image != nil
            finish()
        } catch { finish(error: error.localizedDescription) }
    }
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) { finish(error: error.localizedDescription) }
}
let application = NSApplication.shared
application.setActivationPolicy(.regular)
let probe = Probe()
Task { @MainActor in await probe.run() }
withExtendedLifetime(probe) { application.run() }
