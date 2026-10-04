import Foundation

/// Grok Build: ~/.grok/sessions/<cwd>/<session>/updates.jsonl, an ACP update stream.
/// The token fields in that stream are not documented, so this looks for the first object
/// in each line that carries both input and output token counts. Not verified on real data yet.
final class GrokProvider: Provider {
    static let id = "grok"
    static let name = "Grok Build"
    static let experimental = true
    static var isDetected: Bool { Files.exists(dir) }
    private static let dir = ".grok/sessions"

    private(set) var totals = Totals()
    private var tail = JSONLTail()

    func scan() {
        for file in Files.all(in: Self.dir, ext: "jsonl") where file.lastPathComponent == "updates.jsonl" {
            tail.readNewLines(file) { line($0) }
        }
    }

    private func line(_ line: Substring) {
        // usage_update reports context window fill, not consumption.
        guard line.contains("okens"), !line.contains("usage_update"),
              let json = Files.parse(Data(line.utf8)),
              let usage = findUsage(in: json)
        else { return }
        totals.add(usage, model: nil, day: Day.from(timestamp: json["timestamp"]))
    }

    private func findUsage(in value: Any) -> Usage? {
        if let dict = value as? [String: Any] {
            let input = dict["inputTokens"] ?? dict["input_tokens"]
            let output = dict["outputTokens"] ?? dict["output_tokens"]
            if input != nil, output != nil {
                let usage = Usage(input: Files.int(input), output: Files.int(output))
                return usage.isEmpty ? nil : usage
            }
            return dict.values.lazy.compactMap(findUsage).first
        }
        if let array = value as? [Any] {
            return array.lazy.compactMap(findUsage).first
        }
        return nil
    }
}
