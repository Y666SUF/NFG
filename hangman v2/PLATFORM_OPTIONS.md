# Hangman V2 Platform Options

This repo now includes a dedicated V2 path in `app-v2/`.

## Good options

1. **React + Vite (Web app)**
   - Very smooth UI updates and animations.
   - Fast local dev and easy OBS browser-source usage.
   - Reuses your current Python backend (`server.py`) and websocket feed (`/ws`).
   - Lowest migration risk from your current setup.

2. **Electron + React**
   - Native desktop shell around a web UI.
   - Easy packaging for Windows.
   - Heavier memory footprint and extra maintenance compared to a browser app.

3. **Tauri + React**
   - Very lightweight desktop packaging.
   - Excellent performance once set up.
   - More setup complexity (Rust toolchain + desktop build config).

4. **PySide6 / Qt**
   - Native Python desktop widgets.
   - Can look good, but larger rewrite from your HTML/CSS/JS UI.
   - Slower iteration for modern animated overlays.

## Recommended choice

**React + Vite** is the best option for your project right now.

Why:
- You already have a working FastAPI + websocket backend.
- It gives the smoothest path to a cleaner, faster UI with minimal backend changes.
- It keeps your TikTok/game logic untouched while letting you modernize visuals and UX quickly.

## What was created

- `app-v2/` React + Vite scaffold
- `START_V2.bat` helper to run backend + V2 frontend
- `app-v2/electron/` desktop shell (Electron main + preload)
- `START_V2_ELECTRON.bat` helper to run backend + Electron V2

You can now iterate on V2 UI safely while keeping the original game intact.
