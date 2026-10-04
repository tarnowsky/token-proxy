# TokenMeter

Widget w pasku menu macOS, który zlicza tokeny wejściowe i wyjściowe zużyte przez Claude Code i Codex CLI.

Nie ma proxy: aplikacja co 2 s doczytuje nowe linie z lokalnych logów sesji:

- Claude Code: `~/.claude/projects/**/*.jsonl` (pole `message.usage`, deduplikacja po `message.id` + `requestId`)
- Codex: `~/.codex/sessions/**/*.jsonl` (zdarzenia `token_count`, liczona różnica `total_token_usage`)

Wejście (↑) obejmuje tokeny z cache (odczyt i zapis), wyjście (↓) obejmuje tokeny reasoning/thinking.

## Uruchomienie

```sh
swift build -c release
.build/release/TokenMeter            # widget w pasku menu
.build/release/TokenMeter --print    # sumy dzienne w terminalu
```
