#!/usr/bin/env node
// Serve a directory with a shared key/value state that every open page sees
// live. State is saved to <dir>/.share/state.json and pushed over SSE.
//
//   node server.mjs <dir> [port]
//
// Endpoints (besides static files):
//   GET  /_shared/client.js   window.Shared: on(cb), set(key, value), name
//   GET  /_shared/events      SSE: full state on connect and on every change
//   GET  /_shared/state       current state as JSON
//   POST /_shared/set         {key, value, by}; value null deletes the key
import { createServer } from 'node:http';
import { existsSync, mkdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { networkInterfaces } from 'node:os';
import { extname, join, normalize, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(process.argv[2] ?? '.');
const PORT = Number(process.argv[3] ?? 4321);
const HERE = dirname(fileURLToPath(import.meta.url));
const SHARE = join(ROOT, '.share');
const STATE = join(SHARE, 'state.json');
mkdirSync(SHARE, { recursive: true });

const TYPES = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.css': 'text/css', '.json': 'application/json', '.svg': 'image/svg+xml',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp',
  '.gif': 'image/gif', '.txt': 'text/plain; charset=utf-8',
};

let state = existsSync(STATE) ? JSON.parse(readFileSync(STATE, 'utf8')) : {};
const clients = new Set();
const broadcast = () => {
  const msg = `data: ${JSON.stringify(state)}\n\n`;
  for (const res of clients) res.write(msg);
};

createServer((req, res) => {
  const url = new URL(req.url, 'http://x');
  const path = decodeURIComponent(url.pathname);

  if (path === '/_shared/client.js') {
    res.writeHead(200, { 'content-type': TYPES['.js'], 'cache-control': 'no-store' });
    return res.end(readFileSync(join(HERE, 'client.js')));
  }
  if (path === '/_shared/state') {
    res.writeHead(200, { 'content-type': TYPES['.json'], 'cache-control': 'no-store' });
    return res.end(JSON.stringify(state));
  }
  if (path === '/_shared/events') {
    res.writeHead(200, { 'content-type': 'text/event-stream', 'cache-control': 'no-store', connection: 'keep-alive' });
    res.write(`data: ${JSON.stringify(state)}\n\n`);
    clients.add(res);
    const ping = setInterval(() => res.write(': ping\n\n'), 25000);
    req.on('close', () => { clearInterval(ping); clients.delete(res); });
    return;
  }
  if (path === '/_shared/set' && req.method === 'POST') {
    let body = '';
    req.on('data', c => { body += c; if (body.length > 1e6) req.destroy(); });
    req.on('end', () => {
      try {
        const { key, value, by } = JSON.parse(body);
        if (typeof key !== 'string' || !key) throw new Error('key');
        if (value === null || value === undefined) delete state[key];
        else state[key] = { value, by: String(by ?? '').slice(0, 40), at: new Date().toISOString() };
        writeFileSync(STATE, JSON.stringify(state, null, 2));
        broadcast();
        res.writeHead(204).end();
      } catch {
        res.writeHead(400).end();
      }
    });
    return;
  }

  // Static files; never serve the .share dir (state, ngrok creds, logs).
  const file = normalize(join(ROOT, path === '/' ? 'index.html' : path));
  if (!file.startsWith(ROOT) || file.startsWith(SHARE)) return res.writeHead(403).end();
  if (!existsSync(file) || !statSync(file).isFile()) return res.writeHead(404).end();
  res.writeHead(200, { 'content-type': TYPES[extname(file)] ?? 'application/octet-stream', 'cache-control': 'no-store' });
  res.end(readFileSync(file));
}).listen(PORT, '0.0.0.0', () => {
  const ips = Object.values(networkInterfaces()).flat()
    .filter(i => i && i.family === 'IPv4' && !i.internal).map(i => `http://${i.address}:${PORT}`);
  console.log(`serving ${ROOT} on http://localhost:${PORT} ${ips.join(' ')}`);
});
