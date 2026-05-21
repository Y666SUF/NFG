# TestFlight — fix signing (one-time)

The **Release archive already built** on your Mac:

`ios/archive/NFGCrash-AppStore.xcarchive`

CLI export failed because Xcode needs a paid **Apple Distribution** certificate and **App Store** provisioning profile for `com.nfg.crash`.

## 1. Apple Developer + App Store Connect

1. [developer.apple.com/account](https://developer.apple.com/account) — membership must be **Active** (paid program).
2. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **Agreements** — accept any pending (Paid Apps, etc.).
3. **Users and Access** — your Apple ID must be **Admin** or **App Manager** (not only Developer if profiles are blocked).

## 2. Xcode account

1. **Xcode → Settings → Accounts** → **+** → sign in with the **same Apple ID** as the paid developer account.
2. Select your team → **Download Manual Profiles**.
3. If you see “No provider associated with App Store Connect user”, sign out/in or use the account that owns team **T6KK9EW9D6**.

## 3. Project signing

1. Open `ios/NFGCrash.xcodeproj`
2. Target **NFGCrash** → **Signing & Capabilities**
3. **Team:** Yusuf Ali (`T6KK9EW9D6`)
4. **Automatically manage signing:** ON
5. Add capability **In-App Purchase** if missing (+ button)
6. **Bundle ID:** `com.nfg.crash`

## 4. Upload to TestFlight (easiest)

1. **Product → Archive** (scheme **NFGCrash**, destination **Any iOS Device**)
2. Organizer opens → select archive → **Distribute App**
3. **App Store Connect** → **Upload** → follow prompts (creates distribution cert/profile if needed)
4. Wait ~10–30 min in App Store Connect → **TestFlight**

Or open the existing archive:

```bash
open "/Users/y666suf/Documents/nfg-crash/ios/archive/NFGCrash-AppStore.xcarchive"
```

Then **Distribute App** from Organizer.

## 5. App Store Connect app record

If the app does not exist yet:

- **Apps** → **+** → **NFG Crash** · Bundle ID `com.nfg.crash`
- See `ios/TESTFLIGHT-SETUP.md` for IAP products and metadata.

## 6. Rebuild from terminal (after signing works)

```bash
cd ~/Documents/nfg-crash
./scripts/build-crash-testflight.sh
```

Upload the IPA with **Transporter** or Organizer.
