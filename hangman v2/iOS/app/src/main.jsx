import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import "./styles.css";

/* Prevent pinch/double-tap zoom in Capacitor WKWebView */
function preventViewportZoom() {
  const block = (e) => e.preventDefault();
  document.addEventListener("gesturestart", block, { passive: false });
  document.addEventListener("gesturechange", block, { passive: false });
  document.addEventListener("gestureend", block, { passive: false });
  let lastTouchEnd = 0;
  document.addEventListener(
    "touchend",
    (e) => {
      const now = Date.now();
      if (now - lastTouchEnd < 350) e.preventDefault();
      lastTouchEnd = now;
    },
    { passive: false }
  );
}
preventViewportZoom();

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
