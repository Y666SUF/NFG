# Windows server — test in-app store

Copy **`server/mobile-store.js`** to your Windows game folder and add to **`mobile-api.js`**:

```js
const { registerMobileStoreRoutes } = require("./mobile-store");
// inside registerMobileApi:
registerMobileStoreRoutes(app, { pointStore, validateBearer, broadcast });
```

Restart the game server.

## Products (test — no real payment)

| Product ID | Points | Price label |
|------------|--------|-------------|
| `points_10k` | 10,000 | £1.99 |
| `points_50k` | 50,000 | £7.99 |
| `points_100k` | 100,000 | £12.99 |

`POST /api/mobile/store/test-purchase` with Bearer token + `{ "productId": "points_10k" }`.
