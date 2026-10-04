import Foundation

struct Usage {
    /// Uncached input.
    var input = 0
    var cacheRead = 0
    /// Cache writes with the default (short) TTL.
    var cacheWrite = 0
    /// Cache writes with a 1 hour TTL, billed higher by Anthropic.
    var cacheWrite1h = 0
    /// Includes reasoning/thinking tokens.
    var output = 0

    /// Everything the model read, cached or not.
    var totalInput: Int { input + cacheRead + cacheWrite + cacheWrite1h }
    var isEmpty: Bool { totalInput == 0 && output == 0 }

    static func + (a: Usage, b: Usage) -> Usage {
        Usage(input: a.input + b.input, cacheRead: a.cacheRead + b.cacheRead, cacheWrite: a.cacheWrite + b.cacheWrite,
              cacheWrite1h: a.cacheWrite1h + b.cacheWrite1h, output: a.output + b.output)
    }

    static func - (a: Usage, b: Usage) -> Usage {
        Usage(input: a.input - b.input, cacheRead: a.cacheRead - b.cacheRead, cacheWrite: a.cacheWrite - b.cacheWrite,
              cacheWrite1h: a.cacheWrite1h - b.cacheWrite1h, output: a.output - b.output)
    }

    var hasNegative: Bool { [input, cacheRead, cacheWrite, cacheWrite1h, output].contains { $0 < 0 } }
}

/// Aggregated usage of one provider, bucketed by local day ("yyyy-MM-dd").
struct Totals {
    private(set) var days: [String: Usage] = [:]

    mutating func add(_ usage: Usage, model: String?, day: String) {
        days[day, default: Usage()] = days[day, default: Usage()] + usage
    }

    var today: Usage { days[Day.today()] ?? Usage() }
    var allTime: Usage { days.values.reduce(Usage(), +) }
}

enum Day {
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoNoFraction = ISO8601DateFormatter()

    private static let local: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    static func from(timestamp: Any?) -> String {
        switch timestamp {
        case let ts as String:
            if let date = iso.date(from: ts) ?? isoNoFraction.date(from: ts) { return local.string(from: date) }
        case let n as NSNumber:
            // Unix seconds or milliseconds.
            let seconds = n.doubleValue > 1e12 ? n.doubleValue / 1000 : n.doubleValue
            return local.string(from: Date(timeIntervalSince1970: seconds))
        default:
            break
        }
        return today()
    }

    static func today() -> String { local.string(from: Date()) }
}
