# y666suf.com — Product Requirements Document

## Original Problem Statement
> "make y666suf.com into a 3d website based around games as it is my website but i need this to be fully designed around games"

## User Choices
- **Purpose**: Promote game studio y666suf and its TikTok live mini-games
- **Style**: Dark cosmic / space gaming, "fully 3d as over the top as possible"
- **Featured game**: NFG Crash (latest release, with public leaderboard)
- **Other games**: NFG Wordwich, NFG Hangman, NFG Wordwheel
- **TikTok handle**: @y666.suf
- **Leaderboard**: Open POST allowed (no auth)

## Architecture
- **Frontend**: React 19 (CRA + craco) with @react-three/fiber 9 + @react-three/drei 10 for WebGL 3D scenes
- **Backend**: FastAPI + Motor (async MongoDB) — leaderboard CRUD + status checks
- **DB**: MongoDB (`leaderboard` collection storing `{id, player_name, score, game, multiplier, created_at}`)
- **Fonts**: Unbounded (display), Outfit (body), JetBrains Mono (mono) — all via Google Fonts
- **Note**: `Scene3D.jsx` uses `React.createElement` (no JSX) to bypass `@emergentbase/visual-edits` babel plugin which injects `line-number` props that crash R3F.

## User Personas
1. **TikTok Viewers** — discover y666suf's mini-games, click through to TikTok live
2. **Existing Players** — check their NFG Crash leaderboard standing
3. **Brand / Press** — see studio portfolio at a glance

## Core Requirements (static)
- Immersive 3D cosmic hero scene
- Showcase of 4 mini-games with hero card for NFG Crash
- Public live leaderboard (NFG Crash) with API for the game to POST scores
- Prominent TikTok @y666.suf CTAs throughout
- Smooth, no-runtime-error 3D performance

## What's been implemented (2026-05-20)
- ✅ Backend leaderboard API: GET /api/leaderboard, POST /api/leaderboard/score, POST /api/leaderboard/seed, DELETE /api/leaderboard/{id}
- ✅ Seeded 12 sample NFG Crash scores (VOIDRUNNER, NEONGHOST, etc.)
- ✅ Validation: rejects negative scores and empty player names (422)
- ✅ Frontend: Three.js cosmic 3D hero (distorted icosahedron "planet", saturn-style rings, wireframe orb, animated asteroids, stars, sparkles, neon lights)
- ✅ Glass-morphic glowing navbar (sticky, scroll-aware) with anchor scroll
- ✅ Hero with glitch headline "PLAY THE VOID. BREAK THE LOOP."
- ✅ Animated TikTok @y666.suf marquee strip
- ✅ Featured drop card (NFG Crash) with stats grid + CTAs
- ✅ Bento-layout arsenal grid (4 games, AI cosmic posters, neon corner ticks)
- ✅ Live leaderboard table with monospace styling + API documentation snippet
- ✅ Live section: chat-is-the-controller + spinning circular badge "666 SIGNAL"
- ✅ Footer with social links
- ✅ Full backend + frontend test suite passing (100%)

## Prioritized backlog (next iterations)
- **P1**: Auth-protected score submission (HMAC signature) so only the actual game client can POST
- **P1**: Filter leaderboard by timeframe (daily / weekly / all-time)
- **P2**: Per-game leaderboards (Wordwich, Hangman, Wordwheel)
- **P2**: Embed playable demo previews for non-Crash games
- **P2**: Real-time leaderboard updates via WebSocket / SSE during live streams
- **P3**: User profile pages with score history + run replays
- **P3**: Cosmetic skins/badges unlocked at score thresholds
- **P3**: SEO meta + Open Graph for shareability
- **P3**: Mobile 3D tuning (lower particle count auto-switch)

## Next Tasks
- Provide y666suf with the leaderboard ingest endpoint:
  `POST {BACKEND_URL}/api/leaderboard/score` with `{player_name, score, multiplier, game:"nfg_crash"}`
- Optional: add HMAC validation on the endpoint before exposing publicly.
