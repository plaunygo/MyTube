import AppKit
import SwiftUI

final class PreviewWindowController: NSObject, NSWindowDelegate {
    static let shared = PreviewWindowController()
    private var window: NSWindow?
    var onClose: (() -> Void)?

    func show(player: MPVPlayer, title: String) {
        if window == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 640, height: 360),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered, defer: false
            )
            win.isReleasedWhenClosed = false
            win.backgroundColor = .black
            win.contentView = NSHostingView(rootView: MPVContainerView(player: player))
            win.center()
            win.delegate = self
            window = win
        }
        window?.title = title
        window?.orderFrontRegardless()
    }

    func close() {
        window?.orderOut(nil)
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}
