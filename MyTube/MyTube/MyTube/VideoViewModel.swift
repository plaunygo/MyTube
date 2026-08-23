import Foundation
import SwiftUI
import AppKit
import Combine

extension Notification.Name {
    static let focusSearch = Notification.Name("focusSearch")
}

final class VideoViewModel: ObservableObject {
    enum Mode { case browse, watch }

    @Published var mode: Mode = .browse
    @Published var videos: [ResolvedVideo] = []
    @Published var loading = false
    @Published var current: ResolvedVideo?
    @Published var visibleComments: [VideoComment] = []
    @Published var totalComments = 0
    @Published var hasMoreComments = false
    @Published var commentsLoading = false
    @Published var profile: ChannelProfile?
    @Published var isPreviewOpen = false
    @Published var downloadProgress: Double? = nil
    @Published var playbackError: String? = nil

    var hoveredVideo: ResolvedVideo?
    var hoveredUser: ChannelRef?

    let mainPlayer = MPVPlayer()
    let previewPlayer = MPVPlayer()
    let downloader = DownloadManager()

    private var allComments: [VideoComment] = []
    private var commentsToken: String?
    private let resolver = StreamResolver()
    private let keyboard = KeyboardController()
    private var profileHeld = false

    init() {
        keyboard.onSearch = {
            NotificationCenter.default.post(name: .focusSearch, object: nil)
        }
        keyboard.onSpaceDown  = { [weak self] in DispatchQueue.main.async { self?.spaceDown() } }
        keyboard.onSpaceUp    = { [weak self] in DispatchQueue.main.async { self?.spaceUp() } }
        keyboard.onSeekLeft   = { [weak self] in DispatchQueue.main.async { self?.active.seek(-5) } }
        keyboard.onSeekRight  = { [weak self] in DispatchQueue.main.async { self?.active.seek(5) } }
        keyboard.onVolumeUp   = { [weak self] in DispatchQueue.main.async { self?.active.volume(5) } }
        keyboard.onVolumeDown = { [weak self] in DispatchQueue.main.async { self?.active.volume(-5) } }
        keyboard.onEscape     = { [weak self] in DispatchQueue.main.async { self?.escape() } }
        keyboard.start()

        downloader.onProgress = { [weak self] p in
            DispatchQueue.main.async { self?.downloadProgress = p }
        }

        PreviewWindowController.shared.onClose = { [weak self] in
            DispatchQueue.main.async { self?.closePreview() }
        }

        Task { @MainActor [weak self] in await self?.loadInitial() }
    }

    var active: MPVPlayer { isPreviewOpen ? previewPlayer : mainPlayer }

    // MARK: - Навигация и данные

    func loadInitial() async {
        loading = true
        videos = (try? await resolver.search(query: "technology", limit: 30)) ?? []
        loading = false
    }

    func search(query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        if q.hasPrefix("http"), let url = URL(string: q),
           q.contains("youtu.be") || q.contains("youtube.com") {
            open(ResolvedVideo(id: q, url: url, title: "Загрузка…",
                               channel: "", channelID: nil, thumbnail: nil, duration: 0))
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.loading = true
            self.videos = (try? await self.resolver.search(query: q, limit: 30)) ?? []
            self.loading = false
        }
    }

    func open(_ video: ResolvedVideo) {
        closePreview()
        mode = .watch
        current = video
        playbackError = nil
        visibleComments = []
        allComments = []
        totalComments = 0
        hasMoreComments = false
        commentsToken = nil

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let info = try await self.resolver.resolve(url: video.url)
                self.playbackError = nil
                self.mainPlayer.play(url: info.videoURL)
            } catch {
                self.playbackError = "Не удалось запустить видео. \(error)"
            }
        }
        Task { @MainActor [weak self] in
            guard let self, let meta = try? await self.resolver.metadata(url: video.url) else { return }
            if self.current?.url == video.url { self.current = meta }
        }
        Task { @MainActor [weak self] in
            guard let self, let id = StreamResolver.videoID(from: video.url) else { return }
            self.commentsLoading = true
            if let page = try? await self.resolver.comments(videoID: id) {
                self.allComments = page.comments
                self.commentsToken = page.nextToken
                self.totalComments = page.comments.count
                self.hasMoreComments = page.nextToken != nil
                self.visibleComments = Array(page.comments.prefix(10))
            }
            self.commentsLoading = false
        }
    }

    func loadMoreComments() {
        if visibleComments.count < allComments.count {
            visibleComments = Array(allComments.prefix(min(visibleComments.count + 10, allComments.count)))
            return
        }
        guard let token = commentsToken, !commentsLoading else { return }
        commentsLoading = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let page = try? await self.resolver.moreComments(token: token) {
                self.allComments += page.comments
                self.commentsToken = page.nextToken
                self.totalComments = self.allComments.count
                self.hasMoreComments = page.nextToken != nil
                self.visibleComments = Array(self.allComments.prefix(
                    min(self.visibleComments.count + 10, self.allComments.count)))
            }
            self.commentsLoading = false
        }
    }

    func backToBrowse() {
        mainPlayer.stop()
        current = nil
        playbackError = nil
        visibleComments = []
        allComments = []
        mode = .browse
    }

    // MARK: - Превью

    func openPreview(_ video: ResolvedVideo) {
        Task { @MainActor [weak self] in
            guard let self,
                  let info = try? await self.resolver.resolve(url: video.url, preview: true) else { return }
            self.isPreviewOpen = true
            PreviewWindowController.shared.show(player: self.previewPlayer, title: video.title)
            self.previewPlayer.play(url: info.videoURL)
        }
    }

    func closePreview() {
        isPreviewOpen = false
        previewPlayer.stop()
        PreviewWindowController.shared.close()
    }

    // MARK: - Профиль

    func showProfilePinned(_ ref: ChannelRef) {
        profileHeld = false
        showProfile(ref)
    }

    func closeProfile() {
        profile = nil
        profileHeld = false
    }

    private func showProfile(_ ref: ChannelRef) {
        guard let url = ref.url else { return }
        Task { @MainActor [weak self] in
            guard let self, let p = try? await self.resolver.channelProfile(url: url) else { return }
            self.profile = p
        }
    }

    // MARK: - Скачивание

    func downloadCurrent() {
        guard let current else { return }
        downloader.download(current)
    }

    // MARK: - Клавиатура

    private func spaceDown() {
        if let user = hoveredUser {
            profileHeld = true
            showProfile(user)
        } else if mode == .browse, let v = hoveredVideo {
            openPreview(v)
        } else {
            active.togglePause()
        }
    }

    private func spaceUp() {
        if profileHeld {
            profileHeld = false
            profile = nil
        }
    }

    private func escape() {
        if profile != nil { closeProfile(); return }
        if isPreviewOpen { closePreview(); return }
        if mode == .watch { backToBrowse(); return }
    }
}
