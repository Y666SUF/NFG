# Windows Cursor prompt — Legal, compliance & privacy website on y666suf.com

Copy **everything below the line** into Cursor on your **Windows PC** (NFG Crash game server / tunnel machine).

---

You are helping me publish **NFG Crash** legal and privacy pages on my **existing domain** **y666suf.com**.

## My setup (do not break)

- **Domain:** `y666suf.com` (root domain, no subdomain required)
- **Public URL:** `https://y666suf.com` → **Cloudflare Tunnel** → Windows PC
- **Game server:** Node/Express on port **3847** (TikTok LIVE crash game + `/api/mobile/*`)
- **iOS app:** `com.nfg.crash` — in-app copy must **match** the website text
- **Contact email (placeholder — keep unless I say otherwise):** `privacy@y666suf.com`

**Do not break:** TikTok bridge, bets, WebSocket, mobile API, app chat, leaderboard, rewarded ads, presence heartbeats, Cloudflare tunnel.

---

## Goal

1. Create a small **static website** folder with:
   - Home / info page
   - **Privacy Policy** (required for App Store Connect)
   - **Legal & compliance** (entertainment-only, virtual points, ads, TikTok verify, age 17+)

2. Serve it on **https://y666suf.com** using the **same domain and tunnel** I already use (prefer serving from the existing Express app on port 3847).

3. These URLs must work in a browser:

| URL | Page |
|-----|------|
| `https://y666suf.com/` | Landing — what NFG Crash is + links |
| `https://y666suf.com/privacy` | Full privacy policy |
| `https://y666suf.com/legal` | Legal & compliance (terms-style summary) |

4. Optional redirects: `/privacy.html` → `/privacy`, `/legal.html` → `/legal`

---

## Task 1 — Create folder `website/` next to the game server

Create these files (dark theme, mobile-friendly, same tone as the iOS app). **Last updated date: 20 May 2026.**

### `website/index.html`

Landing page for NFG Crash with short description and links to Privacy Policy and Legal & compliance. Mention: companion app for TikTok LIVE crash game; virtual points only; no cash-out; no real-money gambling. Footer: contact `privacy@y666suf.com`.

### `website/privacy.html`

Use **exactly** this privacy policy content (sections and wording must match the iOS app):

**Introduction**
- NFG Crash is a companion app for a TikTok LIVE “crash” style game operated by the stream host.
- Virtual points for entertainment and leaderboard competition.
- No cash-out, no withdrawals, no real-money gambling in the App.

**Who we are**
- Data controller: operator of the NFG Crash live game service.
- Contact: privacy@y666suf.com
- App connects to game servers under y666suf.com.

**Information we collect**
- Account/identity: TikTok username and display name after verify comment on live stream; session token on device.
- Device: random device ID, iOS/app version.
- Gameplay: virtual balance, bets, cash-outs, app chat messages, game state on server.
- Advertising: optional Google AdMob — device IDs, ad interaction, personalized ads if user allows ATT.
- Technical logs: IP and timestamps (e.g. Cloudflare).

**How we use information**
- Operate game, verify TikTok, leaderboards/chat, optional rewarded ads, security.
- We do not sell personal information.

**Legal bases (EEA/UK)**
- Service performance, legitimate interests, consent where required (e.g. ATT).

**Sharing with third parties**
- Game servers/hosting (Cloudflare), Google AdMob when viewing ads, TikTok for live stream, law enforcement if required.
- App chat visible to other players in same session.
- Google privacy: https://policies.google.com/privacy

**Retention, Security, Children (not under 13; recommend 17+), Your rights, International transfers, Changes, Contact** — same as standard policy; contact privacy@y666suf.com.

Style: dark background `#0f0f14`, readable fonts, max-width ~720px.

### `website/legal.html`

**Legal & compliance** page matching the iOS app “Legal & compliance” screen:

1. **Entertainment only** — Companion for TikTok LIVE crash game. Points for fun and leaderboard with viewers — not real money. No cash-out, withdrawals, or real-money gambling. Virtual bets for fun.

2. **Points & purchases** — Virtual play credits for fun and leaderboard. No cash-out or real-money redemption. If paid packs are added later, **Apple In-App Purchase only** (no external payment for points in App Store build).

3. **Advertising** — Optional rewarded video ads (Google AdMob) for in-game points. Limit tracking: iOS Settings → Privacy & Security → Tracking.

4. **TikTok account** — Verification requires posting a comment from your TikTok account while live. App does not accept manually entered usernames for betting/wallet.

5. **Age** — Recommended 17+ due to simulated betting mechanics.

Link prominently to Privacy Policy: `/privacy`.

Same dark styling as privacy page.

---

## Task 2 — Serve static files from Express (port 3847)

Find the main Express app entry (e.g. `server.js`, `index.js`, or wherever `app.listen(3847)` lives).

Add **before** or **alongside** API routes (must not shadow `/api/*`):

```javascript
const path = require("path");
const websiteDir = path.join(__dirname, "website"); // adjust if website/ is one level up

app.get("/privacy", (req, res) => res.sendFile(path.join(websiteDir, "privacy.html")));
app.get("/legal", (req, res) => res.sendFile(path.join(websiteDir, "legal.html")));
app.get("/", (req, res, next) => {
  // Only serve landing if path is exactly / (API paths unchanged)
  if (req.path === "/" || req.path === "/index.html") {
    return res.sendFile(path.join(websiteDir, "index.html"));
  }
  next();
});
// Optional: express.static for assets if you add CSS/images later
// app.use(express.static(websiteDir, { index: "index.html" }));
```

**Important:** `/api/mobile/*` and game WebSocket routes must keep working. If `/` currently returns JSON or redirects, replace only the root GET handler for browsers; leave APIs untouched.

If the tunnel sends **all** paths to port 3847, this is enough. If something else serves the root, tell me what you found and wire `website/` there instead.

---

## Task 3 — Verify locally then via tunnel

1. On Windows: `curl http://127.0.0.1:3847/privacy` — should return HTML.
2. `curl http://127.0.0.1:3847/legal` — should return HTML.
3. Browser: `https://y666suf.com/privacy` and `https://y666suf.com/legal` over HTTPS.

---

## Task 4 — App Store Connect URLs (for my notes)

After deploy, I will set in App Store Connect:

- **Privacy Policy URL:** `https://y666suf.com/privacy`
- **Marketing URL (optional):** `https://y666suf.com/`
- Support URL (optional): same or `mailto:privacy@y666suf.com`

---

## Task 5 — Report back

When done, reply with:

1. Paths of files created
2. Exact code snippet added to Express (file name + line area)
3. Confirmation that `https://y666suf.com/privacy` and `/legal` load in browser
4. Anything I must change in Cloudflare dashboard (only if needed)

---

## Reference copy from Mac repo (if synced)

If I have the Mac project `nfg-crash` copied to Windows, you can start from:

- `website/privacy.html` — already written; copy and serve as-is
- iOS `LegalComplianceView.swift` / `PrivacyPolicyContent.swift` — wording must stay in sync

Do not invent gambling/real-money features. Keep **virtual points only, no cash-out**.

---

**End of prompt — paste above into Windows Cursor.**
