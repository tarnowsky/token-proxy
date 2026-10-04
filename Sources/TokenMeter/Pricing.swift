import Foundation

/// API list prices from LiteLLM's community-maintained price table, cached on disk
/// and refreshed once a day. Costs are what the usage would cost at API rates,
/// not what a subscription actually charges.
final class Pricing {
    static let shared = Pricing()

    private static let source = URL(string: "https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json")!
    private static let maxAge: TimeInterval = 24 * 3600
    private static let prefixes = ["", "anthropic/", "openai/", "gemini/", "vertex_ai/", "xai/"]

    private let cacheFile: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TokenMeter")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("prices.json")
    }()

    private var table: [String: [String: Any]] = [:]
    private var resolved: [String: ModelPrice?] = [:]

    var isLoaded: Bool { !table.isEmpty }

    private init() {
        if let data = try? Data(contentsOf: cacheFile) { load(data) }
    }

    /// Downloads a fresh price table if the cached one is missing or older than a day.
    /// `onUpdate` runs on the main queue only when new prices were loaded.
    func refreshIfStale(onUpdate: @escaping () -> Void) {
        let modified = (try? cacheFile.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        if let modified, Date().timeIntervalSince(modified) < Self.maxAge, isLoaded { return }

        URLSession.shared.dataTask(with: Self.source) { [weak self] data, _, _ in
            guard let self, let data, (try? JSONSerialization.jsonObject(with: data)) is [String: Any] else { return }
            try? data.write(to: self.cacheFile, options: .atomic)
            DispatchQueue.main.async {
                self.load(data)
                onUpdate()
            }
        }.resume()
    }

    /// Cost in USD, or nil when the model is unknown or has no price.
    func cost(_ usage: Usage, model: String?) -> Double? {
        guard let model, let price = price(for: model) else { return nil }
        let r = price.rates(promptTokens: usage.totalInput)
        return Double(usage.input) * r.input
            + Double(usage.cacheRead) * r.cacheRead
            + Double(usage.cacheWrite) * r.cacheWrite
            + Double(usage.cacheWrite1h) * r.cacheWrite1h
            + Double(usage.output) * r.output
    }

    private func load(_ data: Data) {
        table = (try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]]) ?? [:]
        resolved = [:]
    }

    private func price(for model: String) -> ModelPrice? {
        if let cached = resolved[model] { return cached }
        let price = lookup(model).flatMap(ModelPrice.init)
        resolved[model] = price
        return price
    }

    /// Exact name, then common provider prefixes, then without a date suffix, then any provider.
    private func lookup(_ model: String) -> [String: Any]? {
        let undated = model.replacingOccurrences(of: #"-\d{4}-?\d{2}-?\d{2}$"#, with: "", options: .regularExpression)
        for name in [model, undated] {
            for prefix in Self.prefixes {
                if let entry = table[prefix + name], entry["input_cost_per_token"] != nil { return entry }
            }
        }
        return table.first { $0.key.hasSuffix("/" + model) && $0.value["input_cost_per_token"] != nil }?.value
    }
}

struct ModelPrice {
    struct Rates {
        var input, cacheRead, cacheWrite, cacheWrite1h, output: Double
    }

    let base: Rates
    /// Higher rates once the prompt exceeds a threshold (e.g. above 200k tokens), ascending.
    let tiers: [(threshold: Int, rates: Rates)]

    init?(_ entry: [String: Any]) {
        func rates(_ suffix: String, fallback: Rates?) -> Rates? {
            func value(_ key: String) -> Double? { (entry[key + suffix] as? NSNumber)?.doubleValue }
            guard let input = value("input_cost_per_token") ?? fallback?.input else { return nil }
            let cacheWrite = value("cache_creation_input_token_cost") ?? fallback?.cacheWrite ?? input
            return Rates(input: input,
                         cacheRead: value("cache_read_input_token_cost") ?? fallback?.cacheRead ?? input,
                         cacheWrite: cacheWrite,
                         cacheWrite1h: value("cache_creation_input_token_cost_above_1hr") ?? fallback?.cacheWrite1h ?? cacheWrite,
                         output: value("output_cost_per_token") ?? fallback?.output ?? 0)
        }

        guard let base = rates("", fallback: nil) else { return nil }
        self.base = base
        let pattern = #/^input_cost_per_token_above_(\d+)k_tokens$/#
        tiers = entry.keys.compactMap { key -> (Int, Rates)? in
            guard let match = key.wholeMatch(of: pattern), let k = Int(match.1),
                  let r = rates("_above_\(k)k_tokens", fallback: base) else { return nil }
            return (k * 1000, r)
        }.sorted { $0.0 < $1.0 }
    }

    func rates(promptTokens: Int) -> Rates {
        tiers.last { promptTokens > $0.threshold }?.rates ?? base
    }
}
