# Spotify chat commands (Crash vs Hangman)

When **both** NFG Crash (Node) and Hangman (Python) are running, they may both receive the same TikTok chat. Unprefixed `!song` / `!queue` would queue twice — so each game uses its own prefix.

## NFG Crash (Node — `/api/chat`)

| Command | Action |
|---------|--------|
| `!csong <search>` | Queue track |
| `!cqueue <search>` | Same |
| `!caddsong <search>` | Same |
| `!crashsong` / `!crashqueue` / `!crashaddsong` | Long form |

Legacy `!song`, `!queue`, `!addsong` → rejected with hint to use `!csong` or `!hsong`.

## NFG Hangman (Python — TikTok comment handler)

| Command | Action |
|---------|--------|
| `!hsong <search>` | Queue track |
| `!hqueue <search>` | Same |
| `!haddsong <search>` | Same |
| `!hangmansong` / `!hangmanqueue` | Long form |

| Admin (broadcaster) | Action |
|---------------------|--------|
| `!hqueueallow @user` | Allow viewer to queue |
| `!hqueuedeny @user` | Revoke |
| `!hqueuelist` | List allowed |

Legacy bare commands → one-line hint in stream feed.

## Implementation

- Crash: `server/spotify-commands.js`
- Hangman: `hangman v2/spotify_commands.py`, `hangman v2/server.py`
- Cross-ignore: `hangman v2/nfg_platform.py` (`is_nfg_crash_spotify_noise`)

Same Spotify Web API credentials can be shared via `.env` (`HANGMAN_SPOTIFY_*` / `NFG_SPOTIFY_*`); only one desktop queue, but commands are routed to the correct game handler.
