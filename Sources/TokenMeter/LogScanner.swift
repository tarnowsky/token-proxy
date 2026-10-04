import Foundation

/// Incrementally reads the JSONL session logs written by Claude Code and Codex CLI.
///
/// Claude Code: ~/.claude/projects/**/*.jsonl, one `assistant` line per content block,
/// so the same message usage repeats and is deduplicated by message id + request id.
///
/// Codex: ~/.codex/sessions/**/*.jsonl, `token_count` events carry a cumulative
/// `total_token_usage` per session; we count the delta between consecutive events.
final class LogScanner {
    private let home = FileManager.default.homeDirectoryForCurrentUser
    private var offsets: [URL: UInt64] = [:]
    private var seenClaudeIds = Set<String>()
    private var lastCodexTotal: [URL: Usage] = [:]
    private(set) var totals = Totals()

    func scan() {
        for file in jsonlFiles(in: home.appendingPathComponent(".claude/projects")) {
            readNewLines(file) { claudeLine($0) }
        }
        for file in jsonlFiles(in: home.appendingPathComponent(".codex/sessions")) {
            readNewLines(file) { codexLine($0, file: file) }
        }
    }

    // MARK: - Parsing

    private func claudeLine(_ line: Substring) {
        guard line.contains("\"usage\""),
              let json = parse(line),
              json["type"] as? String == "assistant",
              let message = json["message"] as? [String: Any],
              let usage = message["usage"] as? [String: Any]
        else { return }

        if let id = message["id"] as? String {
            let key = id + ":" + (json["requestId"] as? String ?? "")
            guard seenClaudeIds.insert(key).inserted else { return }
        }

        let input = int(usage["input_tokens"])
            + int(usage["cache_creation_input_tokens"])
            + int(usage["cache_read_input_tokens"])
        let output = int(usage["output_tokens"])
        totals.add(Usage(input: input, output: output), source: .claude,
                   day: Day.from(timestamp: json["timestamp"] as? String))
    }

    private func codexLine(_ line: Substring, file: URL) {
        guard line.contains("\"token_count\""),
              let json = parse(line),
              let payload = json["payload"] as? [String: Any],
              payload["type"] as? String == "token_count",
              let info = payload["info"] as? [String: Any],
              let total = info["total_token_usage"] as? [String: Any]
        else { return }

        // input_tokens already includes cached input, output_tokens includes reasoning.
        let current = Usage(input: int(total["input_tokens"]), output: int(total["output_tokens"]))
        let previous = lastCodexTotal[file] ?? Usage()
        lastCodexTotal[file] = current

        var delta = Usage(input: current.input - previous.input, output: current.output - previous.output)
        if delta.input < 0 || delta.output < 0 { delta = current } // counter reset
        guard delta.input > 0 || delta.output > 0 else { return }

        totals.add(delta, source: .codex, day: Day.from(timestamp: json["timestamp"] as? String))
    }

    // MARK: - File reading

    private func jsonlFiles(in dir: URL) -> [URL] {
        guard let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else { return [] }
        return e.compactMap { $0 as? URL }.filter { $0.pathExtension == "jsonl" }
    }

    /// Reads complete lines appended since the last call; a trailing partial line is left for later.
    private func readNewLines(_ file: URL, _ handle: (Substring) -> Void) {
        let size = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? UInt64) ?? 0
        var offset = offsets[file] ?? 0
        if size < offset { offset = 0 } // file was truncated or replaced
        guard size > offset, let fh = try? FileHandle(forReadingFrom: file) else { return }
        defer { try? fh.close() }

        try? fh.seek(toOffset: offset)
        guard let data = try? fh.read(upToCount: Int(size - offset)),
              let lastNewline = data.lastIndex(of: UInt8(ascii: "\n"))
        else { return }

        let complete = data[data.startIndex...lastNewline]
        offsets[file] = offset + UInt64(complete.count)
        String(decoding: complete, as: UTF8.self).split(separator: "\n").forEach(handle)
    }

    private func parse(_ line: Substring) -> [String: Any]? {
        try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
    }

    private func int(_ value: Any?) -> Int { (value as? NSNumber)?.intValue ?? 0 }
}
