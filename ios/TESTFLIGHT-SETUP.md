# NFG Crash — TestFlight & App Store Connect

Bundle ID: **`com.nfg.crash`** · Team: **`T6KK9EW9D6`**

## 1. App Store Connect (one-time)

1. [App Store Connect](https://appstoreconnect.apple.com) → **Apps** → **+** → **New App**
2. Platform: **iOS** · Name: **NFG Crash** · Bundle ID: `com.nfg.crash`
3. SKU: e.g. `nfg-crash` · User access: **Full Access**

### In-App Purchases (required for paid point packs)

**Features** → **In-App Purchases** → **+** → **Consumable** (create all three):

| Reference name | Product ID | Suggested price |
|----------------|------------|-----------------|
| 10,000 points | `points_10k` | £1.99 |
| 50,000 points | `points_50k` | £7.99 |
| 100,000 points | `points_100k` | £12.99 |

Status must be **Ready to Submit** (metadata + screenshot for IAP review).

### Agreements

**Agreements, Tax, and Banking** must be active before IAP or paid apps work.

### App metadata

| Field | Value |
|-------|--------|
| Privacy Policy URL | `https://y666suf.com/privacy` |
| Category | Games → Entertainment |
| Age rating | **17+** (simulated gambling) |
| Contains ads | **Yes** (AdMob rewarded) |
| In-App Purchases | **Yes** |

### Review notes (example)

> Companion app for a TikTok LIVE crash game. Virtual points only — no cash-out. Users verify TikTok by commenting `!link CODE` on the host’s live stream. Requires the host’s game server at y666suf.com while playing. Rewarded ads optional for bonus points.

---

## 2. Build on Mac

```bash
cd /path/to/NFG
chmod +x scripts/build-crash-testflight.sh
./scripts/build-crash-testflight.sh
```

Output: `ios/export/appstore/NFG-Crash-AppStore.ipa`

`AppDistribution.isAppStoreSubmission` is **`true`** in `NFGCrash/Config/AppDistribution.swift` (StoreKit only, no test-store UI).

---

## 3. Upload to TestFlight

**Option A — Transporter (Mac App Store)**

1. Open **Transporter**
2. Drag `NFG-Crash-AppStore.ipa` → **Deliver**

**Option B — Xcode**

1. **Window → Organizer** → select archive → **Distribute App** → **App Store Connect** → Upload

After processing (~5–30 min): App Store Connect → **TestFlight** → build appears → add **Internal** or **External** testers.

### Sandbox IAP testing

**Users and Access** → **Sandbox** → **Testers** → add Apple ID used on test device.

On iPhone: **Settings → App Store → Sandbox Account** → sign in with sandbox tester.

---

## 4. PC server (required for play + ads + IAP credit)

```powershell
git pull origin main
# Deploy mobile-store.js (verify-purchase) + mobile-rewarded-ad.js
.\run-electron-cloudflare.bat
```

Optional dev test store (sideload only, **not** App Store build):

```powershell
$env:NFG_ALLOW_TEST_STORE = "1"
```

Production App Store builds use **StoreKit** → `POST /api/mobile/store/verify-purchase`.

---

## 5. In-app: Ads & IAP diagnostics

**Wallet → Ads & IAP setup** — confirms AdMob IDs, server rewarded-ad API, StoreKit product load, and test ad flow.

See also `ios/ADMOB-SETUP.md` and `ios/APP-STORE-COMPLIANCE.md`.

---

## 6. Checklist before external TestFlight

- [ ] IAP products created and **Ready to Submit**
- [ ] Privacy URL live
- [ ] PC stack running (`https://y666suf.com/api/mobile/hangman/state` or crash state OK)
- [ ] Rewarded ad claim works on device
- [ ] Sandbox purchase credits points on server
- [ ] No test-store buttons in Release build
