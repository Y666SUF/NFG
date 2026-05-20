# Y666.SUF — Cosmic Gaming Site

A fully 3D, dark-cosmic gaming promo site for the y666suf studio, featuring NFG Crash and a live leaderboard plus the Wordwich / Hangman / Wordwheel arsenal.

## Tech Stack
- **Frontend**: React 19 (CRA + craco), Three.js + @react-three/fiber + @react-three/drei, framer-motion, react-fast-marquee, Tailwind CSS
- **Backend**: FastAPI + Motor (async MongoDB)
- **DB**: MongoDB (any local or hosted instance — e.g. MongoDB Atlas)

## Repo Layout
```
/backend
  server.py              FastAPI app (root + status + /api/leaderboard)
  requirements.txt
  .env.example           copy → .env
/frontend
  src/
    App.js               page composition
    components/
      Scene3D.jsx        WebGL cosmic scene
      Hero.jsx
      FeaturedGame.jsx
      GamesGrid.jsx      bento arsenal
      Leaderboard.jsx    live NFG Crash leaderboard
      LiveSection.jsx
      Navbar.jsx
      Footer.jsx
      TikTokMarquee.jsx
      games.js           game metadata (name, tagline, image)
    index.css            global styles + neon utilities
  public/index.html
  .env.example           copy → .env
```

## Local Setup

### 1. Backend
```bash
cd backend
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env                # then edit MONGO_URL / DB_NAME

# Start (port 8001 to match frontend default)
uvicorn server:app --reload --port 8001
```

### 2. Frontend
```bash
cd frontend
corepack yarn install
cp .env.example .env                # then set REACT_APP_BACKEND_URL=http://localhost:8001
corepack yarn start
```

Open http://localhost:3000

### 3. Seed the Leaderboard (one-time)
```bash
curl -X POST http://localhost:8001/api/leaderboard/seed
```

## NFG Crash → Leaderboard API

Submit a score from your game client:

```
POST {BACKEND_URL}/api/leaderboard/score
Content-Type: application/json

{
  "player_name": "VOIDRUNNER",
  "score": 98420,
  "multiplier": 24.6,
  "game": "nfg_crash"
}
```

Read top players:

```
GET {BACKEND_URL}/api/leaderboard?game=nfg_crash&limit=25
```

Delete an entry (moderation):
```
DELETE {BACKEND_URL}/api/leaderboard/{id}
```

> Currently open POST as requested. For production, add HMAC signature validation or an X-API-Key header check inside `submit_score` in `backend/server.py`.

## Customizing the Site

| What to change         | Where                                                                |
|------------------------|-----------------------------------------------------------------------|
| Game names / taglines  | `frontend/src/components/games.js`                                    |
| Game artwork           | `frontend/src/components/games.js` (each `image` URL)                 |
| Hero copy              | `frontend/src/components/Hero.jsx`                                    |
| TikTok handle          | search `y666.suf` in `frontend/src/components/` (Navbar, Footer, etc.)|
| Theme colors           | `frontend/src/index.css` `:root` variables                            |
| 3D scene density       | `frontend/src/components/Scene3D.jsx` (`Stars`/`Sparkles`/`Asteroids`)|

## Build for Production

```bash
cd frontend
corepack yarn build           # outputs /frontend/build
```

Serve `/frontend/build` from any static host (Vercel, Netlify, Cloudflare Pages, Nginx) and point it at your hosted FastAPI backend via the `REACT_APP_BACKEND_URL` env at build time.

## Routes Added

- `/games/nfg-crash`
- `/games/nfg-wordwich`
- `/games/nfg-wordwheel`
- `/games/nfg-hangman`
- `/sideload`
- `/privacy`
- `/legal`

## Deployment Presets

- Frontend Vercel config: `frontend/vercel.json`
- Backend Render config: `render.yaml`

Set `REACT_APP_BACKEND_URL` on Vercel to your deployed backend URL before building.

## License
Private — all rights reserved by y666suf.
