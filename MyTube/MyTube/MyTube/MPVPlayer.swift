import AVFoundation
import AppKit

final class MPVPlayer {
    let player = AVPlayer()

    func attach(to view: PlayerHostView) {
        view.playerLayer.player = player
    }

    func play(url: URL) {
        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 30
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = false
        player.replaceCurrentItem(with: item)
        player.play()
    }

    func togglePause() {
        if player.timeControlStatus == .playing { player.pause() }
        else { player.play() }
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    func seek(_ s: Double) {
        let t = player.currentTime() + CMTime(seconds: s, preferredTimescale: 600)
        player.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func volume(_ d: Int) {
        player.volume = min(max(player.volume + Float(d) / 100, 0), 1)
    }
}
