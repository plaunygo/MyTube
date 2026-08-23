import Foundation

struct ResolvedVideo: Identifiable, Hashable {
    let id: String
    let url: URL
    let title: String
    let channel: String
    let channelID: String?
    let thumbnail: URL?
    let duration: Int

    var channelRef: ChannelRef {
        var u: URL? = nil
        if let channelID, !channelID.isEmpty {
            u = URL(string: "https://www.youtube.com/channel/\(channelID)")
        }
        return ChannelRef(name: channel, url: u, avatar: nil)
    }
}

struct ChannelRef: Equatable {
    let name: String
    let url: URL?
    let avatar: URL?
}

struct PlaybackInfo {
    let videoURL: URL
    let audioURL: URL?
}

struct VideoComment: Identifiable {
    let id: String
    let author: String
    let authorURL: URL?
    let avatar: URL?
    let text: String
    let likes: Int
    let timeText: String
}

struct CommentsPage {
    let comments: [VideoComment]
    let nextToken: String?
}

struct ChannelProfile {
    let name: String
    let url: URL
    let avatar: URL?
    let subscribers: Int?
    let joined: String?
    let country: String?
    let description: String
    let videos: [ResolvedVideo]
}

enum ResolverError: Error {
    case badData
    case failed
    case failedWith(String)
}

func compactNumber(_ n: Int) -> String {
    if n >= 1_000_000 { return String(format: "%.1f млн", Double(n) / 1_000_000) }
    if n >= 1_000     { return String(format: "%.1f тыс.", Double(n) / 1_000) }
    return "\(n)"
}
