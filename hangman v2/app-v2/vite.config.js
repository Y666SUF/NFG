import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    strictPort: true,
    proxy: {
      "/ws": {
        target: "ws://127.0.0.1:19876",
        ws: true
      },
      "/api": {
        target: "http://127.0.0.1:19876",
        changeOrigin: true
      }
    }
  }
});
