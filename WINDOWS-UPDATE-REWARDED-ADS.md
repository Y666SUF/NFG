# Windows server — rewarded ads (+10,000 pts)

Copy these files from the Mac reference server into your Windows game repo, then restart `npm start`.

## New / updated files

1. **`mobile-rewarded-ad.js`** (new) — copy from this repo: `nfg-crash/server/mobile-rewarded-ad.js`
2. **`mobile-api.js`** — add lines from `nfg-crash/server/mobile-api-patch.js`

## Endpoints (Bearer token, same as wallet)

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/api/mobile/rewarded-ad/status` | Can user claim? cooldown, daily count |
| `POST` | `/api/mobile/rewarded-ad/claim` | Grant **10,000** pts after ad completed |

Limits (default in `mobile-rewarded-ad.js`):

- **10,000** points per claim  
- **Unlimited** watches per day (no daily cap, no cooldown)  

Claims stored in `data/mobile-ad-claims.json`.

## Test with curl

```bash
curl -H "Authorization: Bearer YOUR_TOKEN" http://127.0.0.1:3847/api/mobile/rewarded-ad/status
curl -X POST -H "Authorization: Bearer YOUR_TOKEN" http://127.0.0.1:3847/api/mobile/rewarded-ad/claim
```

Do not expose claim without auth — points must stay server-authoritative.
