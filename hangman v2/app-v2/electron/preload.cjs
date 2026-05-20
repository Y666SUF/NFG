const { contextBridge } = require("electron");

contextBridge.exposeInMainWorld("hangmanV2", {
  platform: "electron"
});
