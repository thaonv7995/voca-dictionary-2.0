import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { VitePWA } from "vite-plugin-pwa";
import { fileURLToPath, URL } from "node:url";

// In dev, proxy API calls to the Spring Boot backend. In production the SPA is served
// by the backend itself (same origin), so no proxy is needed.
const BACKEND = "http://localhost:22052";

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: "autoUpdate",
      includeAssets: ["favicon.svg", "favicon.ico", "apple-touch-icon.png"],
      manifest: {
        name: "Voca Dictionary",
        short_name: "Voca",
        description: "TOEIC vocabulary with spaced repetition, pronunciation & AI assistant",
        theme_color: "#0e1014",
        background_color: "#080809",
        display: "standalone",
        start_url: "/",
        icons: [
          { src: "/pwa-192x192.png", sizes: "192x192", type: "image/png" },
          { src: "/pwa-512x512.png", sizes: "512x512", type: "image/png" },
          { src: "/maskable-512x512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
          { src: "/apple-touch-icon.png", sizes: "180x180", type: "image/png" },
        ],
      },
      workbox: {
        navigateFallbackDenylist: [/^\/api/, /^\/v1/, /^\/v3/, /^\/swagger/, /^\/actuator/],
      },
    }),
  ],
  server: {
    port: 5173,
    proxy: {
      "/api": BACKEND,
      "/v1": BACKEND,
      "/v3": BACKEND,
      "/swagger-ui": BACKEND,
    },
  },
  resolve: {
    alias: { "@voca/core": fileURLToPath(new URL("./src/core", import.meta.url)) },
  },
  build: { outDir: "dist" },
});
