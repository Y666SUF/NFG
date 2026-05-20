# Sync Mac ↔ Windows PC with GitHub (public repo)

Use **one public repo** so both machines always have the same code.

Recommended repo name: **`nfg-crash`** (or `nfg-live` if you prefer).

---

## What’s in the repo

| Path | Machine use |
|------|-------------|
| `ios/` | NFG **Crash** native iOS app (Xcode) |
| `hangman-v2/iOS/app/` | NFG **Hangman** Capacitor app |
| `server/` | Mobile API files → copy to Windows `server/` |
| `website/` | Privacy/legal HTML for y666suf.com |
| `WINDOWS-*.md` | Paste-into-Cursor prompts for your **PC** |

**Windows game project** (full Hangman + Crash Node server) can live in the same repo root on PC, or only `server/` is synced and the rest of the PC game stays local — see below.

---

## One-time: create the public repo (Mac)

### 1. Install GitHub CLI (optional but easy)

```bash
brew install gh
gh auth login
```

### 2. From this folder on your MacBook

```bash
cd /Users/y666suf/Documents/nfg-crash
git add -A
git status   # confirm no .env files listed
git commit -m "Initial commit: Crash iOS, Hangman companion, server mobile APIs, Windows docs"
gh repo create nfg-crash --public --source=. --remote=origin --push
```

If you already created an empty repo on GitHub:

```bash
git remote add origin https://github.com/YOUR_USERNAME/nfg-crash.git
git branch -M main
git push -u origin main
```

Replace `YOUR_USERNAME` with your GitHub account.

---

## On your Windows PC (first time)

### 1. Install Git

https://git-scm.com/download/win

### 2. Clone the repo

```powershell
cd $HOME\Documents
git clone https://github.com/YOUR_USERNAME/nfg-crash.git
cd nfg-crash
```

### 3. Wire server files into your live game

If your **running** Hangman/Crash server is another folder (e.g. `hangman v2` on PC):

```powershell
# Copy mobile modules into your PC server's server\ folder
Copy-Item -Path server\mobile-*.js -Destination C:\path\to\your\game\server\ -Force
# Merge mobile-api.js manually or replace if this repo is the source of truth
```

Or run the game **directly from the cloned repo** if that matches your PC layout.

### 4. Hangman app on PC (optional build)

```powershell
cd hangman-v2\iOS\app
copy .env.example .env
npm install
npm run build
```

---

## Daily workflow

### MacBook (after you change code)

```bash
cd /Users/y666suf/Documents/nfg-crash
git pull
# ... edit files ...
git add -A
git commit -m "Describe your change"
git push
```

### Windows PC (get latest)

```powershell
cd $HOME\Documents\nfg-crash
git pull
# Restart game server if server\ files changed
# Rebuild Hangman app if hangman-v2\ changed
```

---

## Rules (public repo)

- **Never commit** `.env`, tokens, Apple keys, or `data/*.json` with player secrets.
- **Do commit** `server/*.js`, iOS/Hangman source, `WINDOWS-*.md`, `website/`.
- **Ignore** `node_modules/`, `DerivedData/`, `.ipa` (see `.gitignore`).

---

## Two machines, one source of truth

```text
GitHub (public)  ←── push ──  MacBook (edit iOS + docs)
      │
      └── pull ──  Windows PC (run game server + tunnel)
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `git push` rejected | `git pull --rebase` then push again |
| PC has old server | `git pull` then restart Node |
| Merge conflicts on `mobile-api.js` | Resolve in VS Code / Cursor, keep both Hangman + Crash routes |
| Accidentally committed `.env` | `git rm --cached .env`, rotate secrets, push fix |

---

## Repo URL for App Store / notes

- Crash iOS: clone on Mac, open `ios/NFGCrash.xcodeproj`
- Hangman: clone on Mac, `cd hangman-v2/iOS/app && npx cap open ios`
- PC server updates: pull repo, copy `server/` or run from clone
