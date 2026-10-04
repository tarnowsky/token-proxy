# TokenMeter

Widget w pasku menu macOS, który zlicza tokeny wejściowe i wyjściowe zużyte przez agentów AI uruchamianych na tym komputerze.

Nie ma proxy: aplikacja co 2 s doczytuje nowe dane z lokalnych logów sesji. „Połączenie” z providerem oznacza tylko włączenie czytania jego logów (zapamiętywane między uruchomieniami). W menu pojawia się „Połącz z …” dla narzędzi wykrytych na komputerze; pełna lista jest w Ustawieniach.

| Provider | Logi | Uwagi |
|---|---|---|
| Claude Code | `~/.claude/projects/**/*.jsonl` | `message.usage`, deduplikacja po `message.id` + `requestId` |
| Codex | `~/.codex/sessions/**/*.jsonl` | zdarzenia `token_count` (`last_token_usage`), powtórzenia i suma odziedziczona po sesji nadrzędnej są pomijane |
| Gemini CLI | `~/.gemini/tmp/*/chats/*.json` | `tokens` w wiadomościach, deduplikacja po `id` (te same sesje bywają w dwóch katalogach) |
| Grok Build | `~/.grok/sessions/**/updates.jsonl` | eksperymentalne: format nieudokumentowany, niesprawdzony na prawdziwych danych |

Wejście (↑) obejmuje tokeny z cache (odczyt i zapis), wyjście (↓) obejmuje tokeny reasoning/thinking. Nowy provider to jedna klasa w `Sources/TokenMeter/Providers/` dopisana do `Providers.all`.

Status: **1.0.0-beta.1**, tylko macOS 13+.

## Koszt

Przy każdym wierszu menu jest szacunkowy koszt (≈ $) liczony per model i per zapytanie z cennika [LiteLLM](https://github.com/BerriAI/litellm/blob/main/model_prices_and_context_window.json): osobno zwykłe wejście, odczyt z cache, zapis do cache (5 min i 1 h) i wyjście, z wyższymi stawkami dla długiego kontekstu. Cennik jest pobierany raz dziennie do `~/Library/Application Support/TokenMeter/prices.json`.

Przy subskrypcji (Claude Max/Pro, ChatGPT, konto Google) to wartość zużycia wg cennika API, a nie rachunek. Modele bez ceny są wypisane w menu jako „Bez ceny”.

W Ustawieniach można wybrać, co pokazuje pasek menu: tokeny, koszt albo oba.

## Uruchomienie

```sh
swift build -c release
.build/release/TokenMeter            # widget w pasku menu
.build/release/TokenMeter --print    # sumy dzienne z kosztem w terminalu
.build/release/TokenMeter --version
```
