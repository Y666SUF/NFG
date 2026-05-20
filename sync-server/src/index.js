import 'dotenv/config';
import cors from 'cors';
import express from 'express';
import http from 'http';
import { WebSocketServer } from 'ws';
import { createInitialState, mergeState } from './gameState.js';

const PORT = Number(process.env.PORT || 3847);
const HOST = process.env.HOST || '0.0.0.0';
const BRIDGE_TOKEN = process.env.BRIDGE_TOKEN || 'dev-bridge-token';
const BRIDGE_CALLBACK_URL = process.env.BRIDGE_CALLBACK_URL || '';
const CORS_ORIGIN = process.env.CORS_ORIGIN || '*';

let gameState = createInitialState();
const clients = new Set();

function now() {
  return Date.now();
}

function broadcast(message) {
  const data = JSON.stringify(message);
  for (const ws of clients) {
    if (ws.readyState === ws.OPEN) ws.send(data);
  }
}

function broadcastState() {
  broadcast({
    type: 'game_state',
    ts: now(),
    payload: gameState,
  });
}

function requireBridgeToken(req, res, next) {
  const token = req.header('X-Bridge-Token');
  if (token !== BRIDGE_TOKEN) {
    return res.status(401).json({ error: 'invalid_bridge_token' });
  }
  next();
}

const app = express();
app.use(cors({ origin: CORS_ORIGIN }));
app.use(express.json({ limit: '1mb' }));

app.get('/health', (_req, res) => {
  res.json({
    ok: true,
    clients: clients.size,
    phase: gameState.phase,
    roundId: gameState.roundId,
  });
});

app.get('/state', (_req, res) => {
  res.json(gameState);
});

app.post('/bridge/push', requireBridgeToken, (req, res) => {
  const body = req.body || {};
  const kind = body.kind;

  if (kind === 'state' && body.state) {
    gameState = mergeState(gameState, body.state);
    broadcastState();
    return res.json({ ok: true });
  }

  if (kind === 'tiktok' && body.event) {
    const event = body.event;
    if (event.text && gameState.recentChat) {
      gameState.recentChat = [
        { user: event.user || 'unknown', text: event.text, ts: now() },
        ...gameState.recentChat,
      ].slice(0, 50);
    }
    broadcast({ type: 'tiktok_event', ts: now(), payload: event });
    return res.json({ ok: true });
  }

  if (kind === 'log' && body.message) {
    broadcast({
      type: 'log',
      ts: now(),
      payload: { level: body.level || 'info', message: body.message },
    });
    return res.json({ ok: true });
  }

  res.status(400).json({ error: 'unknown_kind', kind });
});

app.post('/bridge/command', requireBridgeToken, async (req, res) => {
  res.json({ ok: true, forwarded: false, note: 'optional hook for PC game' });
});

const server = http.createServer(app);
const wss = new WebSocketServer({ server, path: '/ws' });

wss.on('connection', (ws, req) => {
  const url = new URL(req.url || '/', `http://${req.headers.host}`);
  const role = url.searchParams.get('role') || 'client';
  ws.role = role;
  clients.add(ws);

  ws.send(
    JSON.stringify({
      type: 'welcome',
      ts: now(),
      payload: { role, phase: gameState.phase },
    }),
  );
  ws.send(JSON.stringify({ type: 'game_state', ts: now(), payload: gameState }));

  ws.on('message', async (raw) => {
    let msg;
    try {
      msg = JSON.parse(String(raw));
    } catch {
      return;
    }

    if (msg.type === 'ping') {
      ws.send(JSON.stringify({ type: 'pong', ts: now() }));
      return;
    }

    if (msg.type === 'client_action' && BRIDGE_CALLBACK_URL) {
      try {
        await fetch(BRIDGE_CALLBACK_URL, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Bridge-Token': BRIDGE_TOKEN,
          },
          body: JSON.stringify(msg.payload || {}),
        });
      } catch (err) {
        broadcast({
          type: 'log',
          ts: now(),
          payload: { level: 'error', message: `bridge callback failed: ${err.message}` },
        });
      }
    }
  });

  ws.on('close', () => clients.delete(ws));
});

server.listen(PORT, HOST, () => {
  console.log(`NFG Crash sync server http://${HOST}:${PORT}`);
  console.log(`WebSocket ws://${HOST}:${PORT}/ws`);
  console.log(`Bridge token header: X-Bridge-Token`);
});
