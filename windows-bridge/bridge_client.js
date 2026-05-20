/**
 * Drop-in helper for your Windows NFG crash game (Node.js).
 * Set NFG_SYNC_URL and NFG_BRIDGE_TOKEN in .env
 */

const SYNC_URL = process.env.NFG_SYNC_URL || 'http://127.0.0.1:3847';
const BRIDGE_TOKEN = process.env.NFG_BRIDGE_TOKEN || 'change-me-to-a-long-secret';

async function post(path, body) {
  const res = await fetch(`${SYNC_URL}${path}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Bridge-Token': BRIDGE_TOKEN,
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`bridge push failed: ${res.status}`);
}

export async function pushState(state) {
  await post('/bridge/push', { kind: 'state', state });
}

export async function pushTiktok(event) {
  await post('/bridge/push', { kind: 'tiktok', event });
}

export async function pushLog(message, level = 'info') {
  await post('/bridge/push', { kind: 'log', message, level });
}
