/**
 * Serve the built Hangman iOS web client at /hangman-app (same API origin as platform).
 * Lets iPhone use Safari without waiting for a new IPA when dist/ is built.
 */
const fs = require("fs");
const path = require("path");
const express = require("express");

const companionDir = path.join(__dirname, "..", "hangman v2", "iOS", "app", "dist");

function registerHangmanCompanionWeb(app) {
  if (!fs.existsSync(path.join(companionDir, "index.html"))) {
    return;
  }

  const router = express.Router();
  router.use(
    express.static(companionDir, {
      index: false,
      maxAge: process.env.NODE_ENV === "production" ? "300" : 0,
    })
  );
  router.get("*", (_req, res) => {
    res.sendFile(path.join(companionDir, "index.html"));
  });

  app.use("/hangman-app", router);
  console.log("Hangman companion web: /hangman-app/ (open on iPhone Safari)");
}

module.exports = { registerHangmanCompanionWeb, companionDir };
