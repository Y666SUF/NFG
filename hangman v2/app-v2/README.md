# Hangman V2 Desktop (Electron + React)

This is the V2 desktop app shell for the existing Hangman backend.

## Run (Electron dev)

1. Start backend from project root:

```bash
py -m uvicorn server:app --host 0.0.0.0 --port 19876
```

2. In another terminal:

```bash
cd app-v2
npm install
npm run dev
```

This launches:
- Vite dev server on `http://127.0.0.1:5173`
- Electron desktop window connected to it

The Vite dev server proxies:
- `/ws` -> `ws://127.0.0.1:19876`
- `/api/*` -> `http://127.0.0.1:19876`

## Run browser-only mode (optional)

```bash
cd app-v2
npm run dev:ui
```

## Run Electron against production frontend build

```bash
cd app-v2
npm run build
npm run electron
```

## Notes

- Backend gameplay/TikTok logic remains in Python (`server.py`).
- Electron only wraps the V2 React UI as a desktop app.
