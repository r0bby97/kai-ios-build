import SwiftUI
import UIKit

enum ChatScrollEdge: Equatable { case top, bottom }

/// Keeps an explicit edge jump anchored while a lazy transcript resolves row heights.
/// Corrections follow content-size changes, not guessed delays or estimated row sizes.
struct ChatScrollAnchor: UIViewRepresentable {
    let edge: ChatScrollEdge
    let requestID: Int

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> Probe {
        let view = Probe()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        view.moved = { [weak coordinator = context.coordinator, weak view] in
            if let view { coordinator?.connect(from: view) }
        }
        return view
    }
    func updateUIView(_ view: Probe, context: Context) {
        context.coordinator.request(edge: edge, id: requestID, from: view)
    }
    static func dismantleUIView(_ view: Probe, coordinator: Coordinator) { coordinator.disconnect() }

    final class Probe: UIView {
        var moved: (() -> Void)?
        override func didMoveToWindow() { super.didMoveToWindow(); moved?() }
        override func didMoveToSuperview() { super.didMoveToSuperview(); moved?() }
    }
    final class Coordinator: NSObject {
        private weak var scrollView: UIScrollView?
        private var sizeObservation: NSKeyValueObservation?
        private var boundsObservation: NSKeyValueObservation?
        private var lastRequest: Int?
        private var edge = ChatScrollEdge.bottom
        private var active = false
        private var queued = false

        func request(edge: ChatScrollEdge, id: Int, from view: UIView) {
            if lastRequest != id {
                lastRequest = id; self.edge = edge; active = true
            }
            // The representable can update before SwiftUI attaches its scroll view.
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let view else { return }
                self.connect(from: view); self.correctWhenReady()
            }
        }
        func connect(from view: UIView) {
            var ancestor = view.superview
            while let candidate = ancestor, !(candidate is UIScrollView) { ancestor = candidate.superview }
            guard let found = ancestor as? UIScrollView, found !== scrollView else { return }
            disconnect()
            scrollView = found
            found.panGestureRecognizer.addTarget(self, action: #selector(userPanned(_:)))
            sizeObservation = found.observe(\.contentSize, options: [.new]) { [weak self] _, _ in self?.correctWhenReady() }
            boundsObservation = found.observe(\.bounds, options: [.new]) { [weak self] _, _ in self?.correctWhenReady() }
            correctWhenReady()
        }
        func disconnect() {
            sizeObservation = nil; boundsObservation = nil
            scrollView?.panGestureRecognizer.removeTarget(self, action: #selector(userPanned(_:)))
            scrollView = nil
        }
        @objc private func userPanned(_ recognizer: UIPanGestureRecognizer) {
            if recognizer.state == .began || recognizer.state == .changed { active = false }
        }
        private func correctWhenReady() {
            guard active, !queued else { return }
            queued = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.queued = false
                guard self.active, let scroll = self.scrollView, scroll.window != nil,
                      !scroll.isDragging, !scroll.isTracking else { return }
                scroll.layoutIfNeeded()
                let inset = scroll.adjustedContentInset
                let top = -inset.top
                let bottom = max(top, scroll.contentSize.height - scroll.bounds.height + inset.bottom)
                let target = self.edge == .top ? top : bottom
                guard target.isFinite, abs(scroll.contentOffset.y - target) > 0.5 else { return }
                scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: target), animated: false)
            }
        }
    }
}
