# Fix: iPhone can't reach game (connection refused on 86.22.165.214:3847)

The iPhone app is correct — **nothing on the internet can connect to port 3847** on your public IP right now. Tests show **connection refused** (not timeout). Fix the PC + router, then the app will sync.

---

## PROMPT START (paste in Cursor on Windows PC)

My iPhone app uses **`http://86.22.165.214:3847`** but gets **connection refused**. Fix networking so **port 3847 is open on the public IP** and the game server accepts remote connections.

### 1. Confirm game is listening

PowerShell while Electron/game is running:

```powershell
netstat -an | findstr ":3847"
```

You must see **`0.0.0.0:3847`** or **`[::]:3847`** in **LISTENING**.  
If you only see **`127.0.0.1:3847`**, edit `server/index.js`:

```javascript
const HOST = process.env.HOST || "0.0.0.0";
server.listen(PORT, HOST, () => { ... });
```

Restart the game.

### 2. Windows Firewall — allow inbound 3847

Run **as Administrator**:

```powershell
New-NetFirewallRule -DisplayName "NFG Crash 3847 IN" -Direction Inbound -Protocol TCP -LocalPort 3847 -Action Allow -Profile Any
```

Or run `scripts\windows-firewall-3847.bat` as Admin.

### 3. Router port forwarding

1. `ipconfig` → note PC **IPv4** (e.g. `192.168.0.101`)
2. Router admin → Port forwarding / Virtual server:
   - **External port:** 3847
   - **Internal IP:** your PC
   - **Internal port:** 3847
   - **Protocol:** TCP
3. On PC browser open https://api.ipify.org — must show **86.22.165.214** (if different, iPhone app IP is wrong)

### 4. Test from OUTSIDE your home network

On iPhone **mobile data** (Wi‑Fi off), Safari:

```
http://86.22.165.214:3847/api/mobile/status
```

You should see JSON like `{"ok":true,...}`.  
If Safari can't load it, the app cannot either.

Or use https://www.canyouseeme.org — port **3847**.

### 5. CGNAT / double router

If port forward still fails:
- ISP may use **CGNAT** (no real inbound ports) → use **Tailscale** on PC + phone, app URL `http://100.x.x.x:3847`
- Or **Cloudflare Tunnel** / **ngrok**: `ngrok http 3847`

### 6. Local test (same Wi‑Fi only)

If you only need home Wi‑Fi temporarily, change iPhone build `GameServerConfig.publicHost` to PC LAN IP and reinstall — but for mobile data you **must** fix port 3847 above.

Do not change game logic — only networking and confirm `registerMobileApi` + `0.0.0.0` listen.

## PROMPT END

---

## Quick checklist

| Step | Pass? |
|------|--------|
| Game/Electron running | |
| `netstat` shows `0.0.0.0:3847` LISTENING | |
| Firewall rule for 3847 | |
| Router forward 3847 → PC | |
| Safari on 4G loads `/api/mobile/status` | |

When all pass, iPhone app shows **Online** and live game data.
