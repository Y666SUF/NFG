// Add to mobile-api.js on Windows (with rewarded-ad lines):

const { registerMobileStoreRoutes } = require("./mobile-store");

// inside registerMobileApi:
registerMobileStoreRoutes(app, { pointStore, validateBearer, broadcast });
