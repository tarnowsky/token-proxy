# TokenMeter

A macOS menu bar widget that counts input and output tokens used by AI coding agents running on this machine.

There is no proxy: every 2 seconds the app reads new data from the agents' local session logs. "Connecting" a provider only turns on reading its logs (remembered across launches). The menu offers "Connect to …" for tools detected on this machine; the full list is in Settings.

| Provider | Logs | Notes |
|---|---|---|
| Claude Code | `~/.claude/projects/**/*.jsonl` | `message.usage`, deduplicated by `message.id` + `requestId` |
| Codex | `~/.codex/sessions/**/*.jsonl` | `token_count` events (`last_token_usage`); repeated events and totals inherited from a parent session are skipped |
| Gemini CLI | `~/.gemini/tmp/*/chats/*.json` | `tokens` on each message, deduplicated by `id` (the same session can exist in two directories) |
| Grok Build | `~/.grok/sessions/**/updates.jsonl` | experimental: undocumented format, not yet verified on real data |

Input (↑) includes cached tokens (reads and writes), output (↓) includes reasoning/thinking tokens. A new provider is one class in `Sources/TokenMeter/Providers/` added to `Providers.all`.

Status: **1.0.0-beta.1**, macOS 13+ only.

## Cost

Each menu row shows an estimated cost (≈ $), computed per model and per request from the [LiteLLM](https://github.com/BerriAI/litellm/blob/main/model_prices_and_context_window.json) price table: uncached input, cache reads, cache writes (5 min and 1 h), and output are priced separately, with higher rates for long context. The price table is downloaded once a day to `~/Library/Application Support/TokenMeter/prices.json`.

With a subscription (Claude Max/Pro, ChatGPT, Google account) this is the value of your usage at API prices, not what you are billed. Models without a price are listed in the menu under "No price".

In Settings you can choose what the menu bar shows (tokens, cost, or both) and the language (English, Polish, or the system language, which is the default).

## Running

```sh
swift build -c release
.build/release/TokenMeter            # menu bar widget
.build/release/TokenMeter --print    # daily totals with cost in the terminal
.build/release/TokenMeter --version
```
