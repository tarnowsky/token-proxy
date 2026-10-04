import Foundation

enum Source: String, CaseIterable {
    case claude = "Claude"
    case codex = "Codex"
}

struct Usage {
    var input = 0
    var output = 0

    static func + (a: Usage, b: Usage) -> Usage {
        Usage(input: a.input + b.input, output: a.output + b.output)
    }
}

/// Aggregated usage per source, bucketed by local day ("yyyy-MM-dd").
struct Totals {
    private(set) var days: [Source: [String: Usage]] = [:]

    mutating func add(_ usage: Usage, source: Source, day: String) {
        days[source, default: [:]][day, default: Usage()].input += usage.input
        days[source, default: [:]][day, default: Usage()].output += usage.output
    }

    func today(_ source: Source) -> Usage {
        days[source]?[Day.today()] ?? Usage()
    }

    func allTime(_ source: Source) -> Usage {
        days[source]?.values.reduce(Usage(), +) ?? Usage()
    }
}

enum Day {
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let local: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    static func from(timestamp: String?) -> String {
        guard let ts = timestamp, let date = iso.date(from: ts) else { return today() }
        return local.string(from: date)
    }

    static func today() -> String { local.string(from: Date()) }
}
