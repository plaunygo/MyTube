import Foundation

final class DownloadManager {
    var onProgress: ((Double?) -> Void)?
    private var process: Process?
    private var isRunning = false

    func download(_ video: ResolvedVideo) {
        guard !isRunning else { return }
        isRunning = true
        onProgress?(0)

        let dir = FileManager.default
            .urls(for: .moviesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MyTube", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/yt-dlp")
        proc.arguments = [
            "--no-playlist", "--ignore-config", "--no-warnings",
            "-f", "bv*[height<=2160]+ba/b",
            "--merge-output-format", "mp4",
            "-o", dir.appendingPathComponent("%(title)s.%(ext)s").path,
            video.url.absoluteString
        ]

        let out = Pipe()
        proc.standardOutput = out
        proc.standardError = Pipe()

        out.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            guard let r = chunk.range(of: #"\[download\]\s+\d+(?:\.\d+)?%"#,
                                      options: .regularExpression) else { return }
            let raw = chunk[r]
                .replacingOccurrences(of: "[download]", with: "")
                .replacingOccurrences(of: "%", with: "")
                .trimmingCharacters(in: .whitespaces)
            if let p = Double(raw) { self?.onProgress?(p / 100) }
        }

        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.onProgress?(nil)
            }
        }

        process = proc
        try? proc.run()
    }

    func cancel() {
        process?.terminate()
    }
}
