# MacBook Cursor — Build NFG Hangman IPA (word reveal fix)

You are on a **MacBook** in the **NFG** repo (`Y666SUF/NFG`). The **Windows PC** already has the latest Hangman sync code. Your job: **build a new `NFG-Hangman.ipa`** so the iPhone shows **revealed letters** in the word (e.g. `_ _ _ _ S _ _`), not just letter count / all underscores. Green/red keyboard must match desktop.

**Do all steps yourself.** End with: IPA path, size, `git status`, and pass/fail for a device test on LIVE.

---

## Must match PC stack (already running)

| Item | Value |
|------|--------|
| Public API | `https://y666suf.com` |
| State poll (2s) | `GET /api/mobile/hangman/state` |
| App guess | `POST /api/mobile/hangman/guess` |
| Hangman WS | `wss://y666suf.com/hangman/ws` |
| Sideload | `https://y666suf.com/sideload` |
| Source folder | `hangman v2/` (with space) — **not** `hangman-v2/` |

---

## Step 1 — Sync repo with PC

```bash
cd ~/path/to/NFG   # or clone: git clone https://github.com/Y666SUF/NFG.git && cd NFG
git pull origin main
git log -3 --oneline
```

Confirm recent commits mention Hangman mask / mobile / IPA. If PC-only files are missing, pull again after PC pushes.

---

## Step 2 — Verify iOS word-display fixes exist

These files must have the **mask-first** logic (from PC update):

- `hangman v2/iOS/app/src/lib/hangmanState.js` — prefers `mask` / `maskedWord`; merges WS + nested `state`
- `hangman v2/iOS/app/src/components/WordDisplay.jsx` — renders mask string `_ _ S _ _`
- `hangman v2/iOS/app/src/App.jsx` — `applyHangmanPayload(data)` on WebSocket (full payload)
- `hangman v2/iOS/app/.env.production` — `VITE_NFG_API_BASE=https://y666suf.com`

```bash
grep -l "maskedWord\|MaskText\|applyHangmanPayload(data)" \
  "hangman v2/iOS/app/src/lib/hangmanState.js" \
  "hangman v2/iOS/app/src/components/WordDisplay.jsx" \
  "hangman v2/iOS/app/src/App.jsx"
```

If fixes are missing, apply the same logic from PC `main` before building.

---

## Step 3 — Build web bundle (production API)

```bash
cd "hangman v2/iOS/app"
npm install --include=dev
npm run build
# Must bake in https://y666suf.com (check .env.production)
grep -o 'y666suf.com' dist/assets/*.js | head -1
```

---

## Step 4 — Capacitor sync + native patches

```bash
cd "hangman v2/iOS/app"
npx cap sync ios
PATCH_DIR="native-ios-patches"
IOS_APP="ios/App/App"
cp -f "$PATCH_DIR/AppDelegate.swift" "$IOS_APP/AppDelegate.swift" 2>/dev/null || true
cp -f "$PATCH_DIR/Info.plist" "$IOS_APP/Info.plist" 2>/dev/null || true
```

If `ios/App` does not exist: `npx cap add ios` then `npx cap sync ios`.

---

## Step 5 — Archive IPA

**Option A — repo script (both IPAs):**

```bash
cd /path/to/NFG
chmod +x scripts/build-all-ipas.sh
./scripts/build-all-ipas.sh
```

**Option B — Hangman only:**

```bash
cd "hangman v2/iOS/app"
HM_ARCHIVE="ios/archive/App.xcarchive"
rm -rf "$HM_ARCHIVE" ios/export/App.ipa
xcodebuild -project ios/App/App.xcodeproj -scheme App -configuration Debug \
  -destination 'generic/platform=iOS' -archivePath "$HM_ARCHIVE" archive
mkdir -p ios/export
xcodebuild -exportArchive -archivePath "$HM_ARCHIVE" -exportPath ios/export \
  -exportOptionsPlist ios/export/ExportOptions.plist
cp ios/export/App.ipa ../../releases/ipa/NFG-Hangman.ipa
```

Use your **Apple Development** team in Xcode if archive fails on signing.

---

## Step 6 — Commit + push IPA (so PC can sideload)

```bash
ls -lh releases/ipa/NFG-Hangman.ipa
git add releases/ipa/NFG-Hangman.ipa "hangman v2/iOS/app/"
git commit -m "Refresh NFG-Hangman.ipa with word mask display for iOS Play tab."
git push origin main
```

---

## Step 7 — Device test (LIVE with PC stack up)

1. PC running `run-electron-cloudflare.bat` (3847 + 19876 + tunnel).
2. iPhone: delete old **NFG Hangman** → install from **https://y666suf.com/sideload**.
3. **Play** tab within ~2s: same mask as desktop (`_ _ _ _ S _ _`), green/red keys match.
4. Guess on TikTok chat → phone updates within 2s.
5. Guess from app (after `!link`) → desktop + phone update; app must not crash.

**Pass:** revealed letters visible in word row; keyboard sync; guesses work.  
**Fail:** only underscore count / no letters → rebuild with Step 3–5; confirm `.env.production` and `hangmanState.js` on Mac.

---

## Do not break

- Crash bets, `!link`, 6-wrong-out rule, TikTok bridge, Cloudflare tunnel paths.
- Use `hangman v2/` only for Hangman Python + iOS.

---

## Report back to PC user

1. IPA size + path  
2. `git log -1`  
3. Device test pass/fail (mask + keyboard + guess)  
4. Any Mac-only file changes
