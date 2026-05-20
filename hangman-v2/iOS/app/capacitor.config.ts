import type { CapacitorConfig } from "@capacitor/cli";

const config: CapacitorConfig = {
  appId: "com.nfg.hangman",
  appName: "NFG Hangman",
  webDir: "dist",
  ios: {
    contentInset: "automatic",
    backgroundColor: "#0b1020",
  },
  server: {
    androidScheme: "https",
  },
};

export default config;
