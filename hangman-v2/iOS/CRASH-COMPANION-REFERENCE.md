# NFG Crash companion — layout reference for Hangman

Hangman Capacitor app mirrors these Crash native paths:

| Crash (Swift) | Hangman tab |
|---------------|-------------|
| `NFGTheme` colors `#0b1020` / cyan / purple | `src/styles/theme.css` |
| `TikTokLiveBadge` + in-app count | `TopBar.tsx` |
| `GameView` / bet UI | **Play** — masked word + keyboard |
| `LeaderboardView` | **Board** — use `/api/hangman/leaderboard` only |
| `AppChatView` + online pill | **Chat** |
| `LinkTikTokView` / `WalletView` legal links | **Account** |

Crash repo (Mac): `/Users/y666suf/Documents/nfg-crash/ios/NFGCrash/`
