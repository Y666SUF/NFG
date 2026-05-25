# Why Cursor “freezes” on NFG Crash iOS — and how to fix it

## Cause

1. **`devicectl device install` without `--timeout`** can hang for many minutes on “Enabling developer disk image services.” Cursor waits until you cancel — it looks frozen.
2. **`git stash -u` with `ios/.derivedData/`** (~300MB+) inside the repo made checkout/stash very slow.
3. **Full `xcodebuild`** takes 1–2 minutes; that is normal, not a freeze.

## Fix (run in Terminal.app, not inside a long Cursor agent task)

You are on branch **`emergent/ui-polish-2026`**. A device build already exists if you ran build earlier.

```bash
cd ~/Documents/nfg-crash/ios
chmod +x scripts/*.sh

# Simulator (quick compile check)
./scripts/build-simulator.sh

# Device build (if needed)
./scripts/build-iphone.sh

# Install to iPhone (~2s with timeout — does not hang)
./scripts/install-iphone.sh
```

Or one line install only:

```bash
xcrun devicectl device install app \
  --device 780913DE-A5CD-5D65-9A69-F9CC38DD7D59 \
  --timeout 120 \
  --quiet \
  ~/Documents/nfg-crash/ios/.derivedData/Build/Products/Release-iphoneos/NFGCrash.app
```

## TestFlight

Use Xcode: **Product → Archive → Distribute App**. Do not wait on Cursor for archive/upload.

## Restore your old branch work (optional)

```bash
cd ~/Documents/nfg-crash
git stash list
git stash pop   # restores cursor/nfg-crash-iap-testflight WIP when you go back
```

## Bundle ID note

`emergent/ui-polish-2026` uses **`com.nfg.crash`**. Your older TestFlight builds may be **`com.yusufali.nfgcrash`** — they can both install as separate apps on the phone.
