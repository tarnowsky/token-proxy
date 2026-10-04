import Foundation

/// Claude Code: ~/.claude/projects/**/*.jsonl, one `assistant` line per content block,
/// so the same message usage repeats and is deduplicated by message id + request id.
final class ClaudeProvider: Provider {
    static let id = "claude"
    static let name = "Claude Code"
    static var isDetected: Bool { Files.exists(dir) }
    private static let dir = ".claude/projects"

    private(set) var totals = Totals()
    private var tail = JSONLTail()
    private var seenIds = Set<String>()

    func scan() {
        for file in Files.all(in: Self.dir, ext: "jsonl") {
            tail.readNewLines(file) { line($0) }
        }
    }

    private func line(_ line: Substring) {
        guard line.contains("\"usage\""),
              let json = Files.parse(Data(line.utf8)),
              json["type"] as? String == "assistant",
              let message = json["message"] as? [String: Any],
              let usage = message["usage"] as? [String: Any]
        else { return }

        if let id = message["id"] as? String {
            let key = id + ":" + (json["requestId"] as? String ?? "")
            guard seenIds.insert(key).inserted else { return }
        }

        let cacheWrite1h = Files.int((usage["cache_creation"] as? [String: Any])?["ephemeral_1h_input_tokens"])
        let u = Usage(input: Files.int(usage["input_tokens"]),
                      cacheRead: Files.int(usage["cache_read_input_tokens"]),
                      cacheWrite: Files.int(usage["cache_creation_input_tokens"]) - cacheWrite1h,
                      cacheWrite1h: cacheWrite1h,
                      output: Files.int(usage["output_tokens"]))
        totals.add(u, model: message["model"] as? String, day: Day.from(timestamp: json["timestamp"]))
    }
}
