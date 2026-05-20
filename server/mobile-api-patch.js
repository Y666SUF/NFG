/**
 * Add these lines to your existing mobile-api.js on Windows (do not replace the whole file).
 */

// At top with other requires:
const { registerMobileRewardedAdRoutes } = require("./mobile-rewarded-ad");

// Inside registerMobileApi(app, ctx), after registerMobileChatRoutes (or after auth routes):
registerMobileRewardedAdRoutes(app, { pointStore, validateBearer, broadcast });
