# App Store compliance checklist — NFG Crash

Use this before you have an Apple Developer license and again before each App Store submission.

**This app is a companion to a TikTok LIVE crash game using virtual points only.** Real-money gambling and bypassing Apple IAP are the main rejection risks.

---

## Critical — must fix before App Store submit

| Issue | Guideline | What to do |
|--------|-----------|------------|
| **Test store (£ buttons, no Apple payment)** | 3.1.1 In-App Purchase | **Removed from the app UI.** If you add paid points later, use **StoreKit** + server receipt verify only. |
| **Virtual betting / crash game** | 5.3.4 Gambling | No real-money wagering in the app. Market as **entertainment / companion app**, age **17+**, in-app disclaimer (no cash-out, no real prizes in app). If points have real-world value, Apple may treat as gambling — document that points are **play credits** for the stream game only. |
| **Rewarded ads for in-game currency** | 3.1.1 + AdMob policies | Allowed if optional, clear “watch ad for points,” no forcing ads to progress. Use **AdMob** (already integrated). |
| **Privacy Policy URL** | 5.1.1 | Host `website/privacy.html` at `https://y666suf.com/privacy` for App Store Connect; full text also in-app under Legal → Privacy Policy. |
| **App Privacy (nutrition labels)** | 5.1.2 | Declare data collected (AdMob: identifiers, usage data, etc.). |
| **Tracking (ATT)** | 5.1.2 | If personalized ads: `NSUserTrackingUsageDescription` + App Tracking Transparency prompt (added in project). |

---

## Already OK or in progress

| Item | Status |
|------|--------|
| TikTok link via live comment (not typed impersonation) | Good — explain in Review Notes |
| Bearer auth / server-side balance | Good |
| AdMob App ID + rewarded unit in app | Good — wait for AdMob account approval |
| Test store removed from app | Done — Leaderboard is balances only |
| Legal disclaimer screen | Implemented (`LegalComplianceView`) |
| ATS: no global arbitrary loads | Tightened for `y666suf.com` (remove if you change domain) |

---

## App Store Connect (when you have license)

1. **Bundle ID:** `com.nfg.crash` (must match Xcode + AdMob).
2. **Category:** Games → Entertainment (or Games → Casino only if licensed — avoid unless you have gambling licenses).
3. **Age rating:** Likely **17+** (frequent/intense simulated gambling, unrestricted web access if any).
4. **Contains ads:** Yes (AdMob rewarded).
5. **In-App Purchases:** Create consumable IAP products matching 10k/50k/100k **before** enabling store in app.
6. **Review notes:** Explain app requires user’s PC server / live stream, TikTok `!link` verification, virtual points only.

---

## Before archive for App Store

- [ ] Set `AppDistribution.isAppStoreSubmission = true` in `AppDistribution.swift` (hides test store even in Debug if needed).
- [ ] Confirm **Release** build has no “Test store” / `test-purchase` UI.
- [ ] Implement **StoreKit 2** + `POST /api/mobile/store/verify-purchase` (not in v1).
- [ ] Host privacy policy at e.g. `https://y666suf.com/privacy` or your site.
- [ ] Complete AdMob + Apple privacy questionnaires consistently.
- [ ] Add full **SKAdNetwork** list from [Google’s iOS list](https://developers.google.com/admob/ios/privacy/download-sdk-list) (expand beyond single ID).
- [ ] App chat: add **report/block** if chat is public (UGC guideline 1.2).
- [ ] No `NSAllowsArbitraryLoads` in shipping plist (project updated).

---

## What NOT to claim in review

- Do not say users can “buy points with card/PayPal” outside IAP.
- Do not market as real-money gambling or cash prizes from the app.

---

## Sideload vs App Store

| Feature | Sideload / TestFlight internal | App Store |
|---------|-------------------------------|-----------|
| Test store | DEBUG only | **No** |
| Rewarded ads | Yes | Yes (AdMob approved) |
| Real IAP | After StoreKit | Required for paid points |
