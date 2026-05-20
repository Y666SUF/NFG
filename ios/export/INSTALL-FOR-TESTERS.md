# Install NFG Crash on iPhone (no $99 Apple license)

Each person uses **their own free Apple ID**. The app is re-signed on their device and lasts about **7 days**, then they install again.

---

## What you need

- iPhone + USB cable (first install) **or** AltStore (wireless after setup)
- A **Windows PC or Mac**
- The file **`NFGCrash.ipa`** (from the person who built the app)
- [Sideloadly](https://sideloadly.io) (easiest on Windows) **or** [AltStore](https://altstore.io)

---

## Method 1 — Sideloadly (recommended, especially on Windows)

1. Download and install **Sideloadly** on the PC.
2. Copy **`NFGCrash.ipa`** to the PC (USB drive, Google Drive, Discord, etc.).
3. Plug the **iPhone** into the PC. On the phone, tap **Trust This Computer** if asked.
4. Open **Sideloadly**:
   - Drag **`NFGCrash.ipa`** into the window (or click to browse).
   - Enter the tester’s **Apple ID email** and **app-specific password**  
     (create one at [appleid.apple.com](https://appleid.apple.com) → Sign-In and Security → App-Specific Passwords).
   - Click **Start**.
5. On the iPhone after install:
   - **Settings → General → VPN & Device Management**
   - Under **Developer App**, tap the profile (their Apple ID email).
   - Tap **Trust**.
6. Open **NFG Crash** from the home screen.

**Every ~7 days:** repeat steps 4–5 (same IPA is fine). Data in the app is usually kept.

---

## Method 2 — AltStore (no cable after first setup)

1. On PC: install **AltServer** from [altstore.io](https://altstore.io).
2. On iPhone: install **AltStore** via AltServer (follow their site).
3. Copy **`NFGCrash.ipa`** to the iPhone (Files app, AirDrop, etc.).
4. In **AltStore** → **My Apps** → **+** → pick **`NFGCrash.ipa`**.
5. **Trust** the developer profile: **Settings → General → VPN & Device Management**.
6. Refresh weekly in AltStore (or reinstall when expired).

---

## Why “download IPA and tap Install” doesn’t work

- Safari / Files **cannot** install a raw `.ipa`.
- Your build is signed for **the builder’s** Mac/phone unless it is re-signed.
- Testers must use **Sideloadly / AltStore / ESign** so the IPA is signed with **their** Apple ID — then **Trust** shows **their** email under Developer App.

---

## Optional: link on a website

You can host `NFGCrash.ipa` on Google Drive, Dropbox, or your game server:

```
https://YOUR-SERVER/download/NFGCrash.ipa
```

Still send testers **this guide** — the link only downloads the file; they still use Sideloadly or AltStore to install.

---

## When you have the $99 Apple Developer account

Use **TestFlight** instead: one invite link, no weekly re-sign, no trust step for testers.
