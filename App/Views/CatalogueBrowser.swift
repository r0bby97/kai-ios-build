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
    var body: some View {
        NavigationStack {
            CatalogueWebView(url: url, automaticCardID: automaticCardID, onDownload: { file, page in
                onDownload(file, page); dismiss()
            }, onError: { error = $0 })
                .navigationTitle("Originalkarte herunterladen").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
                .safeAreaInset(edge: .bottom) {
                    Text(automaticCardID == nil ? "Lade auf der Originalseite die öffentliche PNG- oder JSON-Karte herunter. Kai übernimmt den Download in deine Bibliothek." : "Kai öffnet den regulären Kartenexport automatisch. Falls die Website eine Bestätigung verlangt, führe sie hier aus. Der fertige Download wird direkt übernommen.")
                        .font(.caption).foregroundStyle(.secondary).padding(12).background(.bar)
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
    let onDownload: (URL, URL?) -> Void
    let onError: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(automaticCardID: automaticCardID, onDownload: onDownload, onError: onError) }
    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView(); view.navigationDelegate = context.coordinator; view.uiDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true
        view.load(URLRequest(url: url)); return view
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}

    @MainActor final class Coordinator: NSObject, WKNavigationDelegate, WKDownloadDelegate, WKUIDelegate {
        let onDownload: (URL, URL?) -> Void
        let onError: (String) -> Void
        var destinations: [ObjectIdentifier: URL] = [:]
        var pages: [ObjectIdentifier: URL] = [:]
        let automaticCardID: String?
        private var exportTask: Task<Void, Never>?
        private var downloaded = false
        init(automaticCardID: String?, onDownload: @escaping (URL, URL?) -> Void, onError: @escaping (String) -> Void) {
            self.automaticCardID = automaticCardID; self.onDownload = onDownload; self.onError = onError
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let id = automaticCardID, webView.url?.host == "jannyai.com", webView.url?.path.contains(id) == true, exportTask == nil else { return }
            exportTask = Task { [weak self, weak webView] in
                // Use only the website's ordinary public export controls. Verification
                // remains visible and is never clicked, solved or bypassed by Kai.
                let script = """
                (() => {
                  const controls = [...document.querySelectorAll('button,a,[role="menuitem"]')];
                  const candidate = controls.find(e => {
                    if (e.dataset.kaiClicked || e.disabled || !e.getClientRects().length || getComputedStyle(e).visibility === 'hidden') return false;
                    const label = (e.innerText || e.getAttribute('aria-label') || '').replace(/[()]/g, ' ').trim().replace(/\\s+/g, ' ');
                    return /^(?:(?:download|export|herunterladen)(?: (?:as|als|character|card|karte|png|json|sillytavern|format|file))*|png|json)$/i.test(label);
                  });
                  if (candidate) { candidate.dataset.kaiClicked = '1'; candidate.click(); return true; }
                  return false;
                })()
                """
                for _ in 0..<20 {
                    guard let self, let webView, !self.downloaded, !Task.isCancelled else { return }
                    _ = try? await webView.evaluateJavaScript(script)
                    try? await Task.sleep(for: .milliseconds(750))
                }
                self?.exportTask = nil
            }
        }
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
            return nil
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url, ["https", "about", "blob"].contains(url.scheme ?? "") else { decisionHandler(.cancel); return }
            decisionHandler(navigationAction.shouldPerformDownload ? .download : .allow)
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            let mime = navigationResponse.response.mimeType ?? ""
            let name = navigationResponse.response.suggestedFilename ?? ""
            let isFile = ["png", "json"].contains(URL(fileURLWithPath: name).pathExtension.lowercased())
            decisionHandler(!navigationResponse.canShowMIMEType || (isFile && ["image/png", "application/json", "application/octet-stream"].contains(mime)) ? .download : .allow)
        }
        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) { prepare(download, page: webView.url) }
        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) { prepare(download, page: webView.url) }
        private func prepare(_ download: WKDownload, page: URL?) {
            downloaded = true; exportTask?.cancel(); exportTask = nil
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
            onDownload(file, pages.removeValue(forKey: id))
        }
        func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            let id = ObjectIdentifier(download)
            if let file = destinations.removeValue(forKey: id) { try? FileManager.default.removeItem(at: file) }
            pages.removeValue(forKey: id); onError(error.localizedDescription)
        }
    }
}
