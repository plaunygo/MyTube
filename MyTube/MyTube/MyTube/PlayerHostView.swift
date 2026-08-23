import AppKit
import SwiftUI
import AVFoundation

final class PlayerHostView: NSView {
    let playerLayer = AVPlayerLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.addSublayer(playerLayer)
        playerLayer.videoGravity = .resizeAspect
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
    }
}

struct MPVContainerView: NSViewRepresentable {
    let player: MPVPlayer

    func makeNSView(context: Context) -> PlayerHostView {
        let v = PlayerHostView()
        v.playerLayer.player = player.player
        return v
    }

    func updateNSView(_ nsView: PlayerHostView, context: Context) {}
}
