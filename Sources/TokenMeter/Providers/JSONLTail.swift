import Foundation

/// Shared file helpers for providers that read local session logs.
enum Files {
    static let home = FileManager.default.homeDirectoryForCurrentUser

    static func exists(_ relativePath: String) -> Bool {
        FileManager.default.fileExists(atPath: home.appendingPathComponent(relativePath).path)
    }

    static func all(in relativePath: String, ext: String) -> [URL] {
        let dir = home.appendingPathComponent(relativePath)
        guard let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else { return [] }
        return e.compactMap { $0 as? URL }.filter { $0.pathExtension == ext }
    }

    static func parse(_ data: Data) -> [String: Any]? {
        try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    static func int(_ value: Any?) -> Int { (value as? NSNumber)?.intValue ?? 0 }
}

/// Remembers how far each JSONL file has been read and yields only newly appended lines.
struct JSONLTail {
    private var offsets: [URL: UInt64] = [:]

    /// Reads complete lines appended since the last call; a trailing partial line is left for later.
    mutating func readNewLines(_ file: URL, _ handle: (Substring) -> Void) {
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
}
