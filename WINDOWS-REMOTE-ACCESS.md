# Play NFG Crash from anywhere (not just same Wi‑Fi)

The iPhone app can use your PC’s **public IP** or a **tunnel URL**. You must expose port **3847** on the game server.

---

## On the Windows PC (game server)

### 1. Server listens on all interfaces

In `server/index.js`, the HTTP server should bind to **`0.0.0.0`** (not only `127.0.0.1`). On startup it should print LAN and local URLs.

### 2. Windows Firewall

Allow inbound **TCP 3847**:

```powershell
New-NetFirewallRule -DisplayName "NFG Crash 3847" -Direction Inbound -Protocol TCP -LocalPort 3847 -Action Allow
```

Or: Windows Security → Firewall → Advanced → Inbound Rules → New Rule → Port → TCP **3847**.

### 3. Router port forwarding

1. Find your PC’s **local** IP (e.g. `192.168.0.101`) — `ipconfig`
2. Find your **public** IP — search “what is my ip” in a browser on the PC
3. Router admin → **Port forwarding** / **Virtual server**:
   - External port: **3847**
   - Internal IP: your PC (e.g. `192.168.0.101`)
   - Internal port: **3847**
   - Protocol: **TCP**

### 4. Test from outside your Wi‑Fi

On iPhone (**mobile data**, not home Wi‑Fi):

1. Open NFG Crash → **server icon** (top left) → Server settings  
2. The iPhone app uses: `http://86.22.165.214:3847`  
3. **Test connection** → should say Connected  
4. Save

Or from another network’s browser: `http://YOUR_PUBLIC_IP:3847/api/mobile/status`

---

## Easier alternatives (no port forwarding)

| Method | Notes |
|--------|--------|
| **Tailscale** | Install on PC + phone; use PC’s Tailscale IP in the app, e.g. `http://100.x.x.x:3847` |
| **Cloudflare Tunnel** | HTTPS URL, no open ports on router |
| **ngrok** | `ngrok http 3847` → use the `https://….ngrok.io` URL in the app (HTTPS works with ATS) |

---

## Cursor prompt (server bind check)

## PROMPT START

In my NFG Crash Windows `server/index.js`, ensure the HTTP server listens on **`0.0.0.0`** port **3847** so phones on the internet can connect when port forwarding is set. Log the machine’s LAN IP(s) and remind to forward port 3847. Do not change game logic.

## PROMPT END

---

## iPhone app (already updated)

- **Server** toolbar button → enter public URL  
- Presets: local Wi‑Fi vs remote  
- **Test connection** before save  
- HTTP allowed for custom IPs (companion app)

**CGNAT:** Some ISPs don’t give a real public IP; use Tailscale or a tunnel if forwarding fails.
