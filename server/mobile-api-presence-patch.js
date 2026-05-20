/**
 * Add to mobile-api.js on Windows (with other mobile routes).
 */

// At top:
const { registerMobilePresenceRoutes, getActiveAppUserCount } = require("./mobile-presence");

// Inside registerMobileApi(app, ctx), after other register* calls:
registerMobilePresenceRoutes(app, { validateBearer });

// In GET /api/mobile/status res.json({ ... }), add:
//   activeAppUsers: getActiveAppUserCount(),
