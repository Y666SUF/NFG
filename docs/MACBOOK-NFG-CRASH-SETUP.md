# NFG Crash on your MacBook (no terminal installs)

Your full project lives in **one GitHub repo**:

**https://github.com/Y666SUF/NFG**  
**Branch:** `emergent/ui-polish-2026` (polished UI + arcade + entries fix + crash wreckage)

---

## Already on this Mac?

If you have `~/Documents/nfg-crash` (or `~/Documents/NFG`), you already have the code. Sync from GitHub:

```bash
cd ~/Documents/nfg-crash
git fetch origin
git checkout emergent/ui-polish-2026
git pull origin emergent/ui-polish-2026
```

---

## Fresh Mac (first time)

```bash
cd ~/Documents
git clone https://github.com/Y666SUF/NFG.git nfg-crash
cd nfg-crash
git checkout emergent/ui-polish-2026
chmod +x scripts/sync-*.sh ios/scripts/*.sh
```

Server deps (only if you run the game server on the Mac):

```bash
npm install
```

---

## Install on iPhone **without Terminal** (recommended)

1. Plug in your iPhone and trust this Mac.
2. Open **`ios/NFGCrash.xcodeproj`** in Xcode (double-click in Finder).
3. Top toolbar: select your **iPhone** (not Simulator).
4. **Product → Run** (or **⌘R**).

Xcode builds, signs, and installs. Repeat **⌘R** after pulls — no `devicectl` scripts needed.

**Confirm build:** Settings in the app → **App build 51 — entries fix**.

---

## Optional: terminal scripts

Only if you prefer command line:

```bash
cd ~/Documents/nfg-crash/ios
./scripts/build-iphone.sh
./scripts/install-iphone.sh
```

---

## Push your Mac work to GitHub

```bash
cd ~/Documents/nfg-crash
./scripts/sync-push-branch.sh "describe your change"
```

Or manual:

```bash
git add -A
git commit -m "your message"
git push origin emergent/ui-polish-2026
```

---

## Windows game PC (live server)

Copy `server/game.js` from this repo to the PC and restart Node so **Entries** and **recent crashes** work for everyone. See `docs/DEPLOY-SERVER-FOR-ENTRIES.md`.

---

## Two apps on the phone?

- **`com.nfg.crash`** — this branch (Xcode Run / Emergent polish)
- **`com.yusufali.nfgcrash`** — older TestFlight build  

They can both be installed; use the one you just built from Xcode.
