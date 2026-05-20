import { hangmanWsUrl, platformWsUrl } from "./config";
import type { WsEnvelope } from "../types";

type Handler = (env: WsEnvelope) => void;

function connect(url: string, label: string, onMessage: Handler): () => void {
  let ws: WebSocket | null = null;
  let closed = false;
  let retryMs = 2000;

  const open = () => {
    if (closed) return;
    try {
      ws = new WebSocket(url);
    } catch {
      scheduleReconnect();
      return;
    }
    ws.onopen = () => {
      retryMs = 2000;
    };
    ws.onmessage = (ev) => {
      try {
        const data = JSON.parse(String(ev.data)) as WsEnvelope;
        if (data?.type) onMessage(data);
      } catch {
        /* ignore */
      }
    };
    ws.onclose = () => scheduleReconnect();
    ws.onerror = () => ws?.close();
  };

  const scheduleReconnect = () => {
    if (closed) return;
    setTimeout(open, retryMs);
    retryMs = Math.min(retryMs * 1.5, 15000);
  };

  open();
  return () => {
    closed = true;
    ws?.close();
  };
}

export function connectHangmanWs(onMessage: Handler): () => void {
  return connect(hangmanWsUrl(), "hangman", onMessage);
}

export function connectPlatformWs(onMessage: Handler): () => void {
  return connect(platformWsUrl(), "platform", onMessage);
}
