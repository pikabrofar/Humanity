#!/usr/bin/env node
// Zernio Poster: keep several Zernio API keys (one per set of connected accounts) and post videos.
//   node zernio-poster.mjs          web UI at http://localhost:4747
//   node zernio-poster.mjs mcp      MCP server on stdio, for Claude Code (see README.md)
// No dependencies (Node 18+). Keys live in ~/.zernio-poster/keys.json, readable only by you.
import http from 'node:http';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import readline from 'node:readline';

const DIR = path.join(os.homedir(), '.zernio-poster');
const KEYS = path.join(DIR, 'keys.json');
const DEFAULT_BASE = process.env.ZERNIO_BASE_URL || 'https://zernio.com/api/v1';
const PORT = +(process.env.PORT || 4747);

// ---------------------------------------------------------------- key store
function loadKeys() {
  try { return JSON.parse(fs.readFileSync(KEYS, 'utf8')); } catch { return []; }
}
function saveKeys(keys) {
  fs.mkdirSync(DIR, { recursive: true, mode: 0o700 });
  fs.writeFileSync(KEYS, JSON.stringify(keys, null, 2), { mode: 0o600 });
}
const mask = k => k.slice(0, 5) + '…' + k.slice(-4);
const publicKey = k => ({ id: k.id, label: k.label, key: mask(k.key), baseUrl: k.baseUrl });

// ---------------------------------------------------------------- Zernio API
async function zernio(k, method, route, body) {
  const res = await fetch(k.baseUrl.replace(/\/$/, '') + route, {
    method,
    headers: { Authorization: `Bearer ${k.key}`, ...(body ? { 'Content-Type': 'application/json' } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let data; try { data = JSON.parse(text); } catch { data = text; }
  if (!res.ok) throw new Error(`${method} ${route}: ${res.status} ${typeof data === 'string' ? data.slice(0, 300) : JSON.stringify(data).slice(0, 300)}`);
  return data;
}

async function accountsFor(k) {
  const data = await zernio(k, 'GET', '/accounts');
  const list = Array.isArray(data) ? data : data.accounts || data.data || [];
  return list.map(a => ({
    keyId: k.id, keyLabel: k.label,
    id: a._id || a.id, platform: a.platform,
    name: a.username || a.displayName || a.name || a.platform,
  }));
}

async function allAccounts() {
  const out = [], errors = [];
  for (const k of loadKeys()) {
    try { out.push(...await accountsFor(k)); } catch (e) { errors.push({ key: k.label, error: e.message }); }
  }
  return { accounts: out, errors };
}

/// Uploads a video once per key (media belongs to the key's workspace), then posts to the chosen accounts.
async function postVideo({ file, filename, contentType = 'video/mp4', caption = '', title, accounts, schedule }) {
  const keys = loadKeys();
  const byKey = new Map();
  for (const a of accounts) {
    if (!byKey.has(a.keyId)) byKey.set(a.keyId, []);
    byKey.get(a.keyId).push(a);
  }
  const results = [];
  for (const [keyId, accs] of byKey) {
    const k = keys.find(x => x.id === keyId);
    if (!k) { results.push({ keyId, error: 'unknown key' }); continue; }
    try {
      const presign = await zernio(k, 'POST', '/media/presign', { filename, contentType });
      const put = await fetch(presign.uploadUrl, { method: 'PUT', headers: { 'Content-Type': contentType }, body: file });
      if (!put.ok) throw new Error(`upload: ${put.status}`);
      const platforms = accs.map(a => ({
        platform: a.platform, accountId: a.id,
        platformSpecificData: a.platform === 'youtube' ? { title: (title || caption).slice(0, 100), visibility: 'public' }
          : a.platform === 'tiktok' ? { privacyLevel: 'PUBLIC_TO_EVERYONE', allowComment: true, allowDuet: true, allowStitch: true } : {},
      }));
      const body = { content: caption, mediaItems: [{ type: 'video', url: presign.publicUrl }], platforms };
      if (schedule) body.scheduledFor = schedule; else body.publishNow = true;
      const post = await zernio(k, 'POST', '/posts', body);
      results.push({ key: k.label, accounts: accs.map(a => `${a.platform}:${a.name}`), ok: true, post: post.post?._id || post._id || post.id || post });
    } catch (e) {
      results.push({ key: k.label, accounts: accs.map(a => `${a.platform}:${a.name}`), error: e.message });
    }
  }
  return results;
}

function addKey({ label, key, baseUrl }) {
  if (!key) throw new Error('key required');
  const keys = loadKeys();
  const k = { id: Math.random().toString(36).slice(2, 10), label: label || `Key ${keys.length + 1}`, key: key.trim(), baseUrl: baseUrl || DEFAULT_BASE };
  keys.push(k); saveKeys(keys);
  return publicKey(k);
}

// ---------------------------------------------------------------- web UI
const PAGE = `<!doctype html><meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1">
<title>Zernio Poster</title>
<style>
:root{--bg:#0f0f12;--card:#1a1a20;--fg:#eee;--mut:#999;--acc:#f0883e;--line:#2c2c34}
@media (prefers-color-scheme:light){:root{--bg:#f6f6f8;--card:#fff;--fg:#111;--mut:#666;--line:#ddd}}
body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.45 system-ui,sans-serif}
main{max-width:760px;margin:0 auto;padding:24px 16px}h1{font-size:22px}h2{font-size:16px;margin:0 0 12px}
section{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:16px;margin:16px 0}
input,textarea{width:100%;box-sizing:border-box;background:transparent;color:var(--fg);border:1px solid var(--line);border-radius:8px;padding:8px;font:inherit;margin:4px 0 10px}
button{background:var(--acc);color:#111;border:0;border-radius:8px;padding:9px 14px;font-weight:600;cursor:pointer}
button.ghost{background:transparent;color:var(--mut);border:1px solid var(--line);padding:4px 10px}
.row{display:flex;gap:8px;align-items:center;justify-content:space-between;padding:6px 0;border-bottom:1px solid var(--line)}
.mut{color:var(--mut);font-size:13px}label.acc{display:flex;gap:8px;align-items:center;padding:4px 0}label.acc input{width:auto;margin:0}
pre{white-space:pre-wrap;font-size:12px;color:var(--mut)}
</style><main>
<h1>Zernio Poster</h1>
<section><h2>API keys</h2><div id=keys></div>
<input id=label placeholder="Label (e.g. sentidoS)"><input id=key placeholder="sk_…" type=password>
<button onclick=addKey()>Add key</button></section>
<section><h2>Post a video</h2><div id=accounts class=mut>Loading accounts…</div>
<input id=file type=file accept="video/*"><textarea id=caption rows=3 placeholder="Caption"></textarea>
<input id=title placeholder="YouTube title (optional; defaults to the caption)">
<input id=when type=datetime-local><div class=mut style="margin:-6px 0 10px">Leave empty to publish now.</div>
<button id=go onclick=post()>Post</button><pre id=out></pre></section>
<script>
const j=(u,o)=>fetch(u,o).then(async r=>{const d=await r.json();if(!r.ok)throw new Error(d.error);return d});
async function refresh(){
  const keys=await j('/api/keys');
  document.getElementById('keys').innerHTML=keys.map(k=>'<div class=row><span><b>'+k.label+'</b> <span class=mut>'+k.key+'</span></span><button class=ghost onclick="del(\\''+k.id+'\\')">Remove</button></div>').join('')||'<div class=mut>No keys yet.</div>';
  const {accounts,errors}=await j('/api/accounts');
  document.getElementById('accounts').innerHTML=accounts.map((a,i)=>'<label class=acc><input type=checkbox data-i='+i+'> '+a.platform+' · '+a.name+' <span class=mut>('+a.keyLabel+')</span></label>').join('')
    +errors.map(e=>'<div class=mut>⚠ '+e.key+': '+e.error+'</div>').join('')||'No accounts.';
  window.ACC=accounts;
}
async function addKey(){await j('/api/keys',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({label:label.value,key:key.value})});key.value=label.value='';refresh()}
async function del(id){await j('/api/keys/'+id,{method:'DELETE'});refresh()}
async function post(){
  const f=file.files[0],sel=[...document.querySelectorAll('[data-i]:checked')].map(c=>ACC[c.dataset.i]);
  if(!f||!sel.length)return out.textContent='Pick a video and at least one account.';
  go.disabled=true;out.textContent='Uploading '+(f.size/1e6).toFixed(1)+' MB…';
  const q=new URLSearchParams({filename:f.name,contentType:f.type||'video/mp4',caption:caption.value,title:title.value,
    accounts:JSON.stringify(sel),schedule:when.value?new Date(when.value).toISOString():''});
  try{out.textContent=JSON.stringify(await j('/api/post?'+q,{method:'POST',body:f}),null,2)}catch(e){out.textContent=e.message}
  go.disabled=false;
}
refresh();
</script>`;

function readBody(req) {
  return new Promise((ok, no) => { const c = []; req.on('data', d => c.push(d)); req.on('end', () => ok(Buffer.concat(c))); req.on('error', no); });
}

function serve() {
  http.createServer(async (req, res) => {
    const send = (code, data) => { res.writeHead(code, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(data)); };
    try {
      const u = new URL(req.url, 'http://x');
      if (req.method === 'GET' && u.pathname === '/') { res.writeHead(200, { 'Content-Type': 'text/html' }); return res.end(PAGE); }
      if (u.pathname === '/api/keys' && req.method === 'GET') return send(200, loadKeys().map(publicKey));
      if (u.pathname === '/api/keys' && req.method === 'POST') return send(200, addKey(JSON.parse(await readBody(req))));
      if (u.pathname.startsWith('/api/keys/') && req.method === 'DELETE') {
        saveKeys(loadKeys().filter(k => k.id !== u.pathname.split('/').pop())); return send(200, { ok: true });
      }
      if (u.pathname === '/api/accounts') return send(200, await allAccounts());
      if (u.pathname === '/api/post' && req.method === 'POST') {
        const q = Object.fromEntries(u.searchParams);
        return send(200, await postVideo({ ...q, accounts: JSON.parse(q.accounts), schedule: q.schedule || undefined, file: await readBody(req) }));
      }
      send(404, { error: 'not found' });
    } catch (e) { send(500, { error: e.message }); }
  }).listen(PORT, '127.0.0.1', () => console.log(`Zernio Poster: http://localhost:${PORT}`)); // local only
}

// ---------------------------------------------------------------- MCP (stdio, JSON-RPC)
const TOOLS = [
  { name: 'list_accounts', description: 'List social accounts connected to every saved Zernio key.', inputSchema: { type: 'object', properties: {} } },
  { name: 'post_video', description: 'Upload a local video and post it to the given accounts (from list_accounts). Publishes now unless schedule (ISO time) is set.',
    inputSchema: { type: 'object', required: ['path', 'accounts'], properties: {
      path: { type: 'string', description: 'Local video file path' }, caption: { type: 'string' },
      title: { type: 'string', description: 'YouTube title' }, schedule: { type: 'string' },
      accounts: { type: 'array', description: 'Account ids (the "id" field from list_accounts)', items: { type: 'string' } } } } },
];

function mcp() {
  const write = m => process.stdout.write(JSON.stringify(m) + '\n');
  readline.createInterface({ input: process.stdin }).on('line', async line => {
    let msg; try { msg = JSON.parse(line); } catch { return; }
    const reply = result => write({ jsonrpc: '2.0', id: msg.id, result });
    if (msg.method === 'initialize') return reply({ protocolVersion: msg.params?.protocolVersion || '2024-11-05', capabilities: { tools: {} }, serverInfo: { name: 'zernio-poster', version: '1.0.0' } });
    if (msg.method === 'tools/list') return reply({ tools: TOOLS });
    if (msg.method === 'tools/call') {
      const { name, arguments: a = {} } = msg.params;
      try {
        let out;
        if (name === 'list_accounts') out = await allAccounts();
        else if (name === 'post_video') {
          const { accounts } = await allAccounts();
          const chosen = accounts.filter(x => a.accounts.includes(x.id));
          if (!chosen.length) throw new Error('none of those account ids are connected');
          out = await postVideo({ file: fs.readFileSync(a.path), filename: path.basename(a.path), caption: a.caption, title: a.title, schedule: a.schedule, accounts: chosen });
        } else throw new Error('unknown tool ' + name);
        return reply({ content: [{ type: 'text', text: JSON.stringify(out, null, 2) }] });
      } catch (e) { return reply({ content: [{ type: 'text', text: e.message }], isError: true }); }
    }
    if (msg.id !== undefined) write({ jsonrpc: '2.0', id: msg.id, error: { code: -32601, message: 'method not found' } });
  });
}

process.argv[2] === 'mcp' ? mcp() : serve();
