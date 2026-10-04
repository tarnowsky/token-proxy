import Foundation

struct Usage {
    var input = 0
    var output = 0

    static func + (a: Usage, b: Usage) -> Usage {
        Usage(input: a.input + b.input, output: a.output + b.output)
    }

    var isEmpty: Bool { input == 0 && output == 0 }
}

/// Aggregated usage of one provider, bucketed by local day ("yyyy-MM-dd").
struct Totals {
    private(set) var days: [String: Usage] = [:]

    mutating func add(_ usage: Usage, day: String) {
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
