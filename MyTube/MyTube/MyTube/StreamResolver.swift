import Foundation

actor StreamResolver {
    private let ytdlpPath = "/opt/homebrew/bin/yt-dlp"
    private var lastStderr = ""

    static func videoID(from url: URL) -> String? {
        if let v = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "v" })?.value { return v }
        let p = url.pathComponents
        if url.host?.contains("youtu.be") == true, p.count > 1 { return p[1] }
        for key in ["shorts", "embed", "live"] {
            if let i = p.firstIndex(of: key), p.count > i + 1 { return p[i + 1] }
        }
        return nil
    }

    // MARK: - Воспроизведение: цепочка стратегий

    func resolve(url: URL, preview: Bool = false) async throws -> PlaybackInfo {
        for client in ["ios", "web_safari", "tv"] {
            if let u = try? await hlsURL(url: url, preview: preview, client: client) {
                return PlaybackInfo(videoURL: u, audioURL: nil)
            }
        }
        do {
            let data = try await execute([
                "--no-playlist", "--ignore-config", "--no-warnings", "--dump-json",
                "-f", "18/b",
                url.absoluteString
            ])
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let s = json["url"] as? String, let u = URL(string: s) else {
                throw ResolverError.failed
            }
            return PlaybackInfo(videoURL: u, audioURL: nil)
        } catch {
            throw ResolverError.failedWith(String(lastStderr.prefix(400)))
        }
    }

    private func hlsURL(url: URL, preview: Bool, client: String) async throws -> URL {
        let fmt = preview
            ? "b[protocol^=m3u8][height<=720]/b[protocol^=m3u8]"
            : "b[protocol^=m3u8]"
        let data = try await execute([
            "--no-playlist", "--ignore-config", "--no-warnings", "--dump-json",
            "--extractor-args", "youtube:player_client=\(client)",
            "-f", fmt,
            url.absoluteString
        ])
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let s = json["url"] as? String, let u = URL(string: s) else {
            throw ResolverError.failed
        }
        return u
    }

    // MARK: - Поиск

    func search(query: String, limit: Int = 30) async throws -> [ResolvedVideo] {
        let data = try await execute([
            "ytsearch\(limit):\(query)",
            "--flat-playlist", "--ignore-config", "--no-warnings", "-J"
        ])
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = json["entries"] as? [[String: Any]] else {
            throw ResolverError.badData
        }
        return entries.compactMap { makeVideo(from: $0) }
    }

    // MARK: - Метаданные по ссылке

    func metadata(url: URL) async throws -> ResolvedVideo {
        let data = try await execute([
            "--no-playlist", "--ignore-config", "--no-warnings", "--dump-json",
            url.absoluteString
        ])
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ResolverError.badData
        }
        let urlStr = (json["webpage_url"] as? String) ?? url.absoluteString
        return ResolvedVideo(
            id: (json["id"] as? String) ?? urlStr,
            url: URL(string: urlStr) ?? url,
            title: (json["title"] as? String) ?? "Video",
            channel: (json["channel"] as? String) ?? ((json["uploader"] as? String) ?? ""),
            channelID: json["channel_id"] as? String,
            thumbnail: normalizeThumb(json["thumbnail"] as? String)
                ?? URL(string: "https://i.ytimg.com/vi/\(json["id"] as? String ?? "")/mqdefault.jpg"),
            duration: (json["duration"] as? Int) ?? 0
        )
    }

    // MARK: - Комментарии через InnerTube (без аккаунта, с пагинацией)

    func comments(videoID: String) async throws -> CommentsPage {
        let first = try await postNext(["videoId": videoID])
        let tokens = Self.findAllContinuations(first, into: [])
        for token in tokens.prefix(3) {
            let second = try await postNext(["continuation": token])
            var list: [VideoComment] = []
            Self.parseComments(second, into: &list)
            if !list.isEmpty {
                return CommentsPage(comments: list,
                                    nextToken: Self.findAllContinuations(second, into: []).first)
            }
        }
        return CommentsPage(comments: [], nextToken: nil)
    }

    func moreComments(token: String) async throws -> CommentsPage {
        let data = try await postNext(["continuation": token])
        var list: [VideoComment] = []
        Self.parseComments(data, into: &list)
        return CommentsPage(comments: list,
                            nextToken: Self.findAllContinuations(data, into: []).first)
    }

    private func postNext(_ body: [String: Any]) async throws -> [String: Any] {
        var full = body
        full["context"] = [
            "client": [
                "clientName": "WEB",
                "clientVersion": "2.20250701.00.00",
                "hl": "ru"
            ]
        ]
        var req = URLRequest(url: URL(string: "https://www.youtube.com/youtubei/v1/next?prettyPrint=false")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
                     forHTTPHeaderField: "User-Agent")
        req.httpBody = try JSONSerialization.data(withJSONObject: full)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw ResolverError.failed }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ResolverError.badData
        }
        return json
    }

    private static func findAllContinuations(_ node: Any, into acc: [String]) -> [String] {
        var result = acc
        if let dict = node as? [String: Any] {
            if let cir = dict["continuationItemRenderer"] as? [String: Any],
               let ep = cir["continuationEndpoint"] as? [String: Any],
               let cmd = ep["continuationCommand"] as? [String: Any],
               let token = cmd["token"] as? String {
                result.append(token)
            }
            for (_, v) in dict { result = findAllContinuations(v, into: result) }
        } else if let arr = node as? [Any] {
            for v in arr { result = findAllContinuations(v, into: result) }
        }
        return result
    }

    private static func parseComments(_ node: Any, into out: inout [VideoComment]) {
        if let dict = node as? [String: Any] {
            if let cr = dict["commentRenderer"] as? [String: Any] {
                let author = ((cr["authorText"] as? [String: Any])?["runs"] as? [[String: Any]])?
                    .first?["text"] as? String ?? "?"
                let text = ((cr["contentText"] as? [String: Any])?["runs"] as? [[String: Any]])?
                    .compactMap { $0["text"] as? String }.joined() ?? ""
                let avatar = ((cr["authorThumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]])?
                    .last?["url"] as? String
                var authorURL: URL? = nil
                if let md = (cr["authorEndpoint"] as? [String: Any])?["commandMetadata"] as? [String: Any],
                   let w = (md["webCommandMetadata"] as? [String: Any])?["url"] as? String {
                    authorURL = URL(string: "https://www.youtube.com" + w)
                }
                let likes = (cr["likeCount"] as? Int) ?? 0
                let time = ((cr["publishedTimeText"] as? [String: Any])?["runs"] as? [[String: Any]])?
                    .first?["text"] as? String ?? ""
                if !text.isEmpty {
                    out.append(VideoComment(
                        id: (cr["commentId"] as? String) ?? UUID().uuidString,
                        author: author,
                        authorURL: authorURL,
                        avatar: avatar.flatMap { URL(string: $0) },
                        text: text,
                        likes: likes,
                        timeText: time
                    ))
                }
            }
            for (_, v) in dict { parseComments(v, into: &out) }
        } else if let arr = node as? [Any] {
            for v in arr { parseComments(v, into: &out) }
        }
    }

    // MARK: - Профиль канала

    func channelProfile(url: URL) async throws -> ChannelProfile {
        async let about = fetchAbout(url: url)
        let data = try await execute([
            "--ignore-config", "--no-warnings", "--flat-playlist", "-J",
            url.absoluteString + "/videos"
        ])
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ResolverError.badData
        }
        let name = (json["title"] as? String) ?? (json["channel"] as? String) ?? "Канал"
        let description = (json["description"] as? String) ?? ""
        let subscribers = json["channel_follower_count"] as? Int
        var avatar: URL? = (json["avatar"] as? String).flatMap { URL(string: $0) }
        if avatar == nil, let thumbs = json["thumbnails"] as? [[String: Any]],
           let t = thumbs.first?["url"] as? String {
            avatar = URL(string: t)
        }
        let entries = json["entries"] as? [[String: Any]] ?? []
        let videos = entries.prefix(6).compactMap { makeVideo(from: $0) }
        let aboutResult = await about
        let countryName = aboutResult.country.flatMap {
            Locale.current.localizedString(forRegionCode: $0)
        }
        return ChannelProfile(
            name: name, url: url, avatar: avatar,
            subscribers: subscribers,
            joined: aboutResult.joined,
            country: countryName,
            description: description, videos: videos
        )
    }

    private func fetchAbout(url: URL) async -> (joined: String?, country: String?) {
        var req = URLRequest(url: URL(string: url.absoluteString + "/about")!)
        req.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let html = String(data: data, encoding: .utf8) else { return (nil, nil) }
        let joined = Self.firstMatch(#""joinedDateText":\{"runs":\[\{"text":"([^"]+)""#, in: html)
        var country = Self.firstMatch(#""countryCode":"([A-Z]{2})""#, in: html)
        if country == nil {
            country = Self.firstMatch(#""country":"([A-Z]{2})""#, in: html)
        }
        return (joined, country)
    }

    private static func firstMatch(_ pattern: String, in s: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = s as NSString
        guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges > 1 else { return nil }
        let r = m.range(at: 1)
        return r.location == NSNotFound ? nil : ns.substring(with: r)
    }

    // MARK: - Вспомогательные

    private func makeVideo(from e: [String: Any]) -> ResolvedVideo? {
        guard var urlStr = e["url"] as? String else { return nil }
        if urlStr.hasPrefix("/") { urlStr = "https://www.youtube.com" + urlStr }
        guard let url = URL(string: urlStr), !urlStr.contains("/shorts/") else { return nil }
        let duration = e["duration"] as? Int ?? 0
        guard duration == 0 || duration > 60 else { return nil }
        let id = (e["id"] as? String) ?? urlStr
        let thumb = normalizeThumb(e["thumbnail"] as? String)
            ?? URL(string: "https://i.ytimg.com/vi/\(id)/mqdefault.jpg")
        return ResolvedVideo(
            id: id, url: url,
            title: (e["title"] as? String) ?? "Video",
            channel: (e["channel"] as? String) ?? ((e["uploader"] as? String) ?? ""),
            channelID: e["channel_id"] as? String,
            thumbnail: thumb,
            duration: duration
        )
    }

    private func normalizeThumb(_ s: String?) -> URL? {
        guard var out = s else { return nil }
        if let r = out.range(of: #"(hqdefault|sddefault|maxresdefault|mqdefault|default)\.(jpg|webp)"#,
                             options: .regularExpression) {
            out.replaceSubrange(r, with: "mqdefault.jpg")
        }
        return URL(string: out)
    }

    private func execute(_ arguments: [String], timeout: TimeInterval? = nil) async throws -> Data {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let proc = Process()
                    proc.executableURL = URL(fileURLWithPath: self.ytdlpPath)
                    proc.arguments = arguments
                    let out = Pipe()
                    let err = Pipe()
                    proc.standardOutput = out
                    proc.standardError = err

                    let lock = NSLock()
                    var finished = false
                    if let timeout {
                        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                            lock.lock()
                            if !finished { proc.terminate() }
                            lock.unlock()
                        }
                    }

                    try proc.run()
                    let data = out.fileHandleForReading.readDataToEndOfFile()
                    let errData = err.fileHandleForReading.readDataToEndOfFile()
                    proc.waitUntilExit()
                    lock.lock(); finished = true; lock.unlock()

                    let errText = String(data: errData, encoding: .utf8) ?? ""
                    Task { await self.setStderr(errText) }

                    guard proc.terminationStatus == 0 else {
                        cont.resume(throwing: ResolverError.failed); return
                    }
                    cont.resume(returning: data)
                } catch { cont.resume(throwing: error) }
            }
        }
    }

    private func setStderr(_ s: String) { lastStderr = s }
}
