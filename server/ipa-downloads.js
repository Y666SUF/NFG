/**
 * Direct .ipa downloads for NFG companion apps (Crash, Hangman, …).
 */
const fs = require("fs");
const path = require("path");
const os = require("os");

const IPA_DOWNLOADS_DIR = path.join(os.homedir(), "Downloads");

const IPA_CATALOG = {
  crash: {
    id: "crash",
    downloadPath: "/download/nfg-crash.ipa",
    fileName: "NFG-Crash.ipa",
    defaultBasename: "NFG-Crash.ipa",
    namePattern: /nfg[\s_-]*crash/i,
    envVar: "NFG_IPA_FILE",
  },
  hangman: {
    id: "hangman",
    downloadPath: "/download/nfg-hangman.ipa",
    fileName: "NFG-Hangman.ipa",
    defaultBasename: "NFG-Hangman.ipa",
    namePattern: /nfg[\s_-]*hangman/i,
    envVar: "NFG_HANGMAN_IPA_FILE",
  },
};

function listDownloadedIpaFiles() {
  let entries = [];
  try {
    entries = fs.readdirSync(IPA_DOWNLOADS_DIR, { withFileTypes: true });
  } catch {
    return [];
  }
  return entries
    .filter((entry) => entry && entry.isFile() && /\.ipa$/i.test(entry.name))
    .map((entry) => {
      const fullPath = path.join(IPA_DOWNLOADS_DIR, entry.name);
      let mtimeMs = 0;
      let size = 0;
      try {
        const st = fs.statSync(fullPath);
        mtimeMs = Number(st.mtimeMs) || 0;
        size = Number(st.size) || 0;
      } catch {
        mtimeMs = 0;
        size = 0;
      }
      return { fullPath, name: entry.name, mtimeMs, size };
    })
    .sort((a, b) => b.mtimeMs - a.mtimeMs);
}

function resolveIpaFilePath(catalogEntry) {
  const envPath = String(process.env[catalogEntry.envVar] || "").trim();
  const defaultPath = path.join(IPA_DOWNLOADS_DIR, catalogEntry.defaultBasename);
  if (envPath && fs.existsSync(envPath)) return envPath;
  if (fs.existsSync(defaultPath)) return defaultPath;
  const ipaFiles = listDownloadedIpaFiles();
  if (!ipaFiles.length) return "";
  const preferred = ipaFiles.filter((f) => catalogEntry.namePattern.test(f.name));
  const pool = preferred.length ? preferred : ipaFiles;
  return pool[0].fullPath;
}

function getIpaDownloadMeta(appId) {
  const entry = IPA_CATALOG[appId];
  if (!entry) return { ok: false, appId, path: "", name: "", size: 0, updatedAt: null };
  const filePath = resolveIpaFilePath(entry);
  if (!filePath) {
    return { ok: false, appId, path: "", name: "", size: 0, updatedAt: null };
  }
  let size = 0;
  let mtimeMs = 0;
  try {
    const st = fs.statSync(filePath);
    size = Number(st.size) || 0;
    mtimeMs = Number(st.mtimeMs) || 0;
  } catch {
    /* ignore */
  }
  return {
    ok: true,
    appId,
    path: filePath,
    name: path.basename(filePath),
    size,
    updatedAt: mtimeMs > 0 ? new Date(mtimeMs).toISOString() : null,
    downloadUrl: entry.downloadPath,
    fileName: entry.fileName,
  };
}

function registerIpaDownloads(app) {
  app.get("/api/ipa/download-info", (_req, res) => {
    const crash = getIpaDownloadMeta("crash");
    const hangman = getIpaDownloadMeta("hangman");
    res.json({
      ok: true,
      apps: {
        crash: {
          ok: crash.ok,
          downloadUrl: IPA_CATALOG.crash.downloadPath,
          fileName: IPA_CATALOG.crash.fileName,
          sourceName: crash.name || null,
          sizeBytes: crash.size || 0,
          updatedAt: crash.updatedAt,
        },
        hangman: {
          ok: hangman.ok,
          downloadUrl: IPA_CATALOG.hangman.downloadPath,
          fileName: IPA_CATALOG.hangman.fileName,
          sourceName: hangman.name || null,
          sizeBytes: hangman.size || 0,
          updatedAt: hangman.updatedAt,
        },
      },
      downloadUrl: IPA_CATALOG.crash.downloadPath,
      fileName: IPA_CATALOG.crash.fileName,
    });
  });

  for (const entry of Object.values(IPA_CATALOG)) {
    app.get(entry.downloadPath, (_req, res) => {
      const ipaPath = resolveIpaFilePath(entry);
      if (!ipaPath) {
        return res.status(404).json({
          ok: false,
          error: "ipa_not_found",
          app: entry.id,
          message: `No .ipa found. Place ${entry.defaultBasename} in ${IPA_DOWNLOADS_DIR} or set ${entry.envVar}.`,
        });
      }
      res.setHeader("Content-Type", "application/octet-stream");
      return res.download(ipaPath, entry.fileName);
    });
  }
}

module.exports = {
  IPA_CATALOG,
  IPA_DOWNLOADS_DIR,
  registerIpaDownloads,
  getIpaDownloadMeta,
  resolveIpaFilePath,
};
