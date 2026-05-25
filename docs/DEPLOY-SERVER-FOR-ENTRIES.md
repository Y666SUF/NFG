# Deploy server fix (entries panel)

The iOS app reads live game state from **https://y666suf.com**. Until the Windows game PC runs the updated `server/game.js`, the server clears `openBets` when the round is **running** or **ended**, so the Entries list looks empty.

## What to copy

From this Mac (or GitHub `emergent/ui-polish-2026`):

- `server/game.js` — must include:
  - `openBets: this.bets.size > 0 ? this.listOpenBets() : []`
  - `recentCrashes` tracking in constructor + `_finishRound` + `getState()`

## On the Windows PC

1. Stop the NFG Crash Node process (or restart the service you use for port 3847).
2. Replace `game.js` in the same folder as your live server (where `index.js` lives).
3. Start the server again.
4. Confirm in a browser: `https://y666suf.com/api/state` during a round with bets — `openBets` should be a non-empty array while the rocket is flying.

Build **51** on the iPhone also caches entries client-side if the server is still old, but deploying the server is the proper fix for all clients.
