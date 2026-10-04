import Foundation

/// Gemini CLI: ~/.gemini/tmp/<project>/chats/session-*.json, a whole JSON document rewritten
/// after every turn. Each `gemini` message has a `tokens` object. The same session file can
/// exist under both a hashed and a named project directory, so messages are deduplicated by id.
final class GeminiProvider: Provider {
    static let id = "gemini"
    static let name = "Gemini CLI"
    static var isDetected: Bool { Files.exists(dir) }
    private static let dir = ".gemini/tmp"

    private(set) var totals = Totals()
    private var modified: [URL: Date] = [:]
    private var seenIds = Set<String>()

    func scan() {
        for file in Files.all(in: Self.dir, ext: "json") where file.deletingLastPathComponent().lastPathComponent == "chats" {
            let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            guard let date, modified[file] != date else { continue }
            modified[file] = date
            read(file)
        }
    }

    private func read(_ file: URL) {
        guard let data = try? Data(contentsOf: file),
              let json = Files.parse(data),
              let messages = json["messages"] as? [[String: Any]]
        else { return }

        for message in messages {
            guard let tokens = message["tokens"] as? [String: Any],
                  let id = message["id"] as? String,
                  seenIds.insert(id).inserted
            else { continue }

            // `input` already includes `cached`; thoughts are billed as output.
            let cached = Files.int(tokens["cached"])
            let usage = Usage(input: Files.int(tokens["input"]) - cached + Files.int(tokens["tool"]),
                              cacheRead: cached,
                              output: Files.int(tokens["output"]) + Files.int(tokens["thoughts"]))
            totals.add(usage, model: message["model"] as? String, day: Day.from(timestamp: message["timestamp"]))
        }
    }
}
