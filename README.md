# TokenMeter

Widget w pasku menu macOS, który zlicza tokeny wejściowe i wyjściowe zużyte przez agentów AI uruchamianych na tym komputerze.

Nie ma proxy: aplikacja co 2 s doczytuje nowe dane z lokalnych logów sesji. „Połączenie” z providerem oznacza tylko włączenie czytania jego logów (zapamiętywane między uruchomieniami). W menu pojawia się „Połącz z …” dla narzędzi wykrytych na komputerze; pełna lista jest w Ustawieniach.

| Provider | Logi | Uwagi |
|---|---|---|
| Claude Code | `~/.claude/projects/**/*.jsonl` | `message.usage`, deduplikacja po `message.id` + `requestId` |
| Codex | `~/.codex/sessions/**/*.jsonl` | zdarzenia `token_count`, liczona różnica `total_token_usage` |
| Gemini CLI | `~/.gemini/tmp/*/chats/*.json` | `tokens` w wiadomościach, deduplikacja po `id` (te same sesje bywają w dwóch katalogach) |
| Grok Build | `~/.grok/sessions/**/updates.jsonl` | eksperymentalne: format nieudokumentowany, niesprawdzony na prawdziwych danych |

Nowy provider to jedna klasa w `Sources/TokenMeter/Providers/` dopisana do `Providers.all`.

Wejście (↑) obejmuje tokeny z cache (odczyt i zapis), wyjście (↓) obejmuje tokeny reasoning/thinking.

## Uruchomienie

```sh
swift build -c release
.build/release/TokenMeter            # widget w pasku menu
.build/release/TokenMeter --print    # sumy dzienne w terminalu
```
