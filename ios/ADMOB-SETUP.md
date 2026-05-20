# AdMob setup — get paid from ads in NFG Crash

## Do you need to sign up first?

**Yes.** Google does not pay you until you:

1. Create a **Google AdMob** account  
2. Link a **payment profile** (bank details)  
3. Add your **iOS app** and create ad units  
4. Ship the app with the **real** AdMob App ID + Rewarded ad unit ID  

Until then, the app can use **Google’s test ad IDs** (no money, but ads work for development).

---

## Step-by-step: sign up and get paid

### 1. Google account

Use a Google account at [https://admob.google.com](https://admob.google.com) → **Get started**.

### 2. AdMob app

- **Apps** → **Add app** → **iOS**  
- Name: **NFG Crash**  
- Bundle ID: `com.nfg.crash` (must match Xcode)  
- Copy the **AdMob App ID** (looks like `ca-app-pub-xxxxxxxx~yyyyyyyy`)

### 3. Rewarded ad unit

- Open your app in AdMob → **Ad units** → **Add ad unit** → **Rewarded**  
- Copy the **Ad unit ID** (looks like `ca-app-pub-xxxxxxxx/zzzzzzzz`)

### 4. Payment profile

- AdMob → **Payments** → complete **account verification**  
- Add **bank account** and tax info (UK: usually UTR / VAT if applicable)  
- Google pays when balance hits the **payment threshold** (often **£70 / $100**, varies by country)

### 5. IDs in this project (production)

Already configured in:

- `NFGCrash/Config/AdMobConfig.swift`
- `NFGCrash/Info.plist` → `GADApplicationIdentifier`

| Unit | ID |
|------|-----|
| **App** | `ca-app-pub-6359780264957734~8558662810` |
| **Rewarded (NFG Crash Coins)** | `ca-app-pub-6359780264957734/1707833917` |

Wallet → **Watch ad for 10,000 pts** uses the rewarded unit; points are granted by your **game server** after the ad completes.

### 6. Google Mobile Ads SDK

Added via Swift Package Manager in `NFGCrash.xcodeproj`:

`https://github.com/googleads/swift-package-manager-google-mobile-ads.git`

Open Xcode → resolve packages if prompted, then build.

**Test IDs** (only if you switch back for debugging — do not earn money):

- App ID: `ca-app-pub-3940256099942544~1458002511`  
- Rewarded: `ca-app-pub-3940256099942544/1712485313`  

### 7. App Store

- Declare **contains ads** in App Store Connect  
- Privacy labels: AdMob collects data for advertising (see Google’s checklist)  
- If you use personalized ads, show the **ATT** prompt (Tracking transparency)

---

## How you earn money

| Event | What happens |
|--------|----------------|
| User **completes** a rewarded video | AdMob records an impression / reward |
| Many users watch ads | Revenue accrues in AdMob (CPM / eCPM varies) |
| Balance ≥ threshold | Google **pays to your bank** (monthly cycle) |

Typical rewarded eCPM is roughly **$5–$30 per 1,000 completions** (country and fill rate vary). This is an estimate, not a guarantee.

**Important:** Points (10,000) are granted by **your game server** after the app calls `/api/mobile/rewarded-ad/claim`. AdMob pays **you**; users get in-game points from **your** server.

---

## Optional: stronger anti-cheat

In AdMob → Rewarded ad unit → enable **Server-side verification (SSV)**.  
Then only accept claims when Google’s callback validates the `transaction_id`.  
(Not wired in v1 — add when you go live.)

---

## Windows server

Apply `WINDOWS-UPDATE-REWARDED-ADS.md` on your PC so claims update the same `points.live.json` as TikTok live.
