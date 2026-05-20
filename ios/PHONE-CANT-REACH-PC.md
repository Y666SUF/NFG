# iPhone says "timed out" / PC not reachable

The phone must reach your **game PC** on **TCP port 3847** over Wi‑Fi. A timeout means nothing answered — not a wrong password or TikTok issue.

## Checklist (do in order)

### 1. Game is running on the PC
On the **Windows PC** that hosts the stream game:

```bat
cd path\to\tiktok-live-crash-game
npm start
```

Leave that window open. You should see the game in a browser at `http://127.0.0.1:3847`.

**Test on the PC itself** (browser or PowerShell):

```powershell
curl http://127.0.0.1:3847/api/mobile/status
```

You want JSON with `"ok": true`. If that fails, fix the game first.

### 2. Correct IP in the iPhone app
On the **same PC**, run:

```bat
ipconfig
```

Use the **Wi‑Fi** adapter’s **IPv4 Address** (e.g. `192.168.0.42`), not `127.0.0.1`.

In NFG Crash → **gear** → server URL:

```text
http://192.168.0.42:3847
```

(no trailing slash)

**Do not use** your Mac’s IP unless the game is running on the Mac.

### 3. Same network
- iPhone on **Wi‑Fi** (not cellular)
- Same router as the PC
- Avoid **guest Wi‑Fi** (often blocks phone → PC)

### 4. Windows Firewall
On the game PC, **Run as administrator**:

`scripts\windows-firewall-3847.bat`

(from this repo), or manually allow **inbound TCP 3847**.

### 5. Mobile API on Windows
The iOS app needs `server/mobile-auth.js` and `server/mobile-api.js` on the PC copy of the game. Use `WINDOWS-CURSOR-PROMPT.md` in Cursor on Windows if you have not applied those changes yet.

(Without them you usually get **404**, not timeout — timeout means the PC IP/port is unreachable.)

### 6. iPhone local network permission
**Settings → NFG Crash → Local Network → On**

## Quick test from another device
On your Mac (same Wi‑Fi), if PC IP is `192.168.0.42`:

```bash
curl -m 5 http://192.168.0.42:3847/api/mobile/status
```

If this times out, the phone will too — fix PC firewall / IP / `npm start`.

## Testing with the game on this Mac
If the game runs on the Mac in `Documents/test`:

```bash
cd ~/Documents/test && npm start
```

Use the LAN URL printed in the terminal (e.g. `http://192.168.0.238:3847`) in the iPhone app.
