import SwiftUI
import WebKit
import FadenCore

/// Uses the site's normal browser flow; no session-token extraction or hidden-definition recovery.
struct CatalogueBrowser: View {
    @Environment(\.dismiss) private var dismiss
    let url: URL
    var automaticCardID: String? = nil
    let onDownload: (URL, URL?) -> Void
    @State private var error: String?
    @State private var status = "Originalseite wird geöffnet …"
    @State private var retryID = UUID()
    var body: some View {
        NavigationStack {
            CatalogueWebView(url: url, automaticCardID: automaticCardID, retryID: retryID, onStatus: { status = $0 }, onDownload: { file, page in
                onDownload(file, page); try? FileManager.default.removeItem(at: file); dismiss()
            }, onError: { error = $0 })
                .navigationTitle("Originalkarte herunterladen").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
                .safeAreaInset(edge: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                    Text(status).font(.subheadline.weight(.medium))
                    Button("Originalseite erneut laden", systemImage: "arrow.clockwise") { status = "Originalseite wird erneut geöffnet …"; retryID = UUID() }
                    Text(automaticCardID == nil ? "Lade auf der Originalseite die öffentliche PNG- oder JSON-Karte herunter. Kai übernimmt den Download in deine Bibliothek." : "Kai öffnet den regulären Kartenexport automatisch. Falls die Website eine Bestätigung verlangt, führe sie hier aus. Der fertige Download wird direkt übernommen.")
                        .font(.caption).foregroundStyle(.secondary)
                    }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.bar)
                }
                .alert("Download nicht möglich", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                    Button("Verstanden", role: .cancel) { error = nil }
                } message: { Text(error ?? "") }
        }
    }
}

struct CatalogueWebView: UIViewRepresentable {
    let url: URL
    let automaticCardID: String?
    var retryID = UUID()
    var onStatus: (String) -> Void = { _ in }
    let onDownload: (URL, URL?) -> Void
    let onError: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(automaticCardID: automaticCardID, onDownload: onDownload, onError: onError, onStatus: onStatus) }
    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView(); view.navigationDelegate = context.coordinator; view.uiDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true
        context.coordinator.retryID = retryID
        view.load(URLRequest(url: url)); return view
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard context.coordinator.retryID != retryID else { return }
        context.coordinator.retryID = retryID
        context.coordinator.restart()
        uiView.load(URLRequest(url: url))
    }

    @MainActor final class Coordinator: NSObject, WKNavigationDelegate, WKDownloadDelegate, WKUIDelegate {
        let onDownload: (URL, URL?) -> Void
        let onError: (String) -> Void
        let onStatus: (String) -> Void
        var retryID: UUID?
        var destinations: [ObjectIdentifier: URL] = [:]
        var pages: [ObjectIdentifier: URL] = [:]
        let automaticCardID: String?
        private var exportTask: Task<Void, Never>?
        private var downloaded = false
        private var pendingSourcePage: URL?
        init(automaticCardID: String?, onDownload: @escaping (URL, URL?) -> Void, onError: @escaping (String) -> Void, onStatus: @escaping (String) -> Void = { _ in }) {
            self.onStatus = onStatus
            self.automaticCardID = automaticCardID; self.onDownload = onDownload; self.onError = onError
        }
        func restart() {
            exportTask?.cancel(); exportTask = nil; downloaded = false; pendingSourcePage = nil
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            guard (error as NSError).code != NSURLErrorCancelled else { return }
            onStatus("Die Originalseite konnte nicht geladen werden."); onError(error.localizedDescription)
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let id = automaticCardID, webView.url.flatMap({ JannyWebsite.cardID(in: $0) }) == id.lowercased(), exportTask == nil else { return }
            exportTask = Task { [weak self, weak webView] in
                // Use only the website's ordinary public export controls. Verification
                // remains visible and is never clicked, solved or bypassed by Kai.
                let script = JannyWebsite.exportScript
                for _ in 0..<20 {
                    guard let self, let webView, !self.downloaded, !Task.isCancelled else { return }
                    if (try? await webView.evaluateJavaScript(script)) as? Bool == true { self.onStatus("Originalkarte wird von JannyAI heruntergeladen …") }
                    try? await Task.sleep(for: .milliseconds(750))
                }
                guard !Task.isCancelled else { return }
                self?.exportTask = nil
                if self?.downloaded == false { self?.onStatus("Noch kein Kartendownload. Falls JannyAI eine Browser-Prüfung zeigt, bestätige sie hier; Kai übernimmt danach die Datei.") }
            }
        }
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
            return nil
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let source = navigationAction.sourceFrame.request.url, JannyWebsite.cardID(in: source) != nil { pendingSourcePage = source }
            guard let url = navigationAction.request.url, ["https", "about", "blob"].contains(url.scheme ?? "") else { decisionHandler(.cancel); return }
            decisionHandler(navigationAction.shouldPerformDownload ? .download : .allow)
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if let http = navigationResponse.response as? HTTPURLResponse, http.statusCode == 403 {
                onStatus("JannyAI verlangt eine Browser-Prüfung. Bestätige sie auf der Originalseite; danach setzt Kai den Import fort.")
            }
            let mime = navigationResponse.response.mimeType ?? ""
            let name = navigationResponse.response.suggestedFilename ?? ""
            let isFile = ["png", "json"].contains(URL(fileURLWithPath: name).pathExtension.lowercased())
            decisionHandler(!navigationResponse.canShowMIMEType || (isFile && ["image/png", "application/json", "application/octet-stream"].contains(mime)) ? .download : .allow)
        }
        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) { prepare(download, page: navigationAction.sourceFrame.request.url ?? pendingSourcePage ?? webView.url) }
        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) { prepare(download, page: pendingSourcePage ?? webView.url) }
        private func prepare(_ download: WKDownload, page: URL?) {
            downloaded = true; exportTask?.cancel(); exportTask = nil
            onStatus("Originalkarte wird übernommen …")
            download.delegate = self
            if let page { pages[ObjectIdentifier(download)] = page }
        }
        func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
            let ext = URL(fileURLWithPath: suggestedFilename).pathExtension.lowercased()
            guard ["png", "json"].contains(ext), response.expectedContentLength <= Int64(CardCodec.maximumBytes) else {
                completionHandler(nil); onError("Bitte eine PNG- oder JSON-Charakterkarte herunterladen (maximal 24 MB)."); return
            }
            let target = FileManager.default.temporaryDirectory.appendingPathComponent("Kai-Karte-\(UUID().uuidString).\(ext)")
            destinations[ObjectIdentifier(download)] = target; completionHandler(target)
        }
        func downloadDidFinish(_ download: WKDownload) {
            let id = ObjectIdentifier(download)
            guard let file = destinations.removeValue(forKey: id) else { return }
            onStatus("Download abgeschlossen. Die echte Charakterkarte wird importiert.")
            onDownload(file, pages.removeValue(forKey: id))
        }
        func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            let id = ObjectIdentifier(download)
            if let file = destinations.removeValue(forKey: id) { try? FileManager.default.removeItem(at: file) }
            pages.removeValue(forKey: id); downloaded = false
            onStatus("Der Kartendownload wurde unterbrochen. Du kannst die Originalseite erneut laden.")
            onError(error.localizedDescription)
        }
    }
}
