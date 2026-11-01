#!/usr/bin/env node
'use strict';
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const args = process.argv.slice(2);
const arg = (key, fallback) => args.includes('--' + key) ? args[args.indexOf('--' + key) + 1] : fallback;
const root = path.resolve(arg('root', 'build/web'));
const base = '/' + arg('base', '/').replace(/^\/+|\/+$/g, '') + '/';
const prefix = base === '//' ? '/' : base;
const port = Number(arg('port', '5555'));
const compare = args.includes('--compare');
const variants = {js: '/private/tmp/pr6-js', wasm: '/private/tmp/pr6-wasm', optimized: '/private/tmp/pr6-optimized'};
const mime = {'.html': 'text/html; charset=utf-8', '.js': 'application/javascript', '.mjs': 'application/javascript', '.wasm': 'application/wasm', '.json': 'application/json', '.css': 'text/css', '.ttf': 'font/ttf', '.otf': 'font/otf', '.png': 'image/png'};
const measurements = [];
const benchmark = fs.readFileSync(path.join(__dirname, 'benchmark.html'));
const server = http.createServer(async (req, res) => {
  let url;
  try { url = new URL(req.url, 'http://localhost'); } catch { res.writeHead(400).end(); return; }
  res.setHeader('Cache-Control', 'no-store');
  if (compare && url.pathname === '/benchmark') { res.setHeader('Content-Type', mime['.html']); res.end(benchmark); return; }
  if (compare && url.pathname === '/measurements' && req.method === 'POST') {
    let body = '';
    for await (const chunk of req) { body += chunk; if (body.length > 10000) { res.writeHead(413).end(); return; } }
    try { measurements.push(JSON.parse(body)); fs.writeFileSync('/private/tmp/pr6-browser-measurements.json', JSON.stringify(measurements, null, 2)); res.writeHead(204).end(); }
    catch { res.writeHead(400).end(); }
    return;
  }
  if (url.pathname.startsWith('/api/')) {
    const upstream = http.request({hostname: '127.0.0.1', port: 8080, method: req.method, path: req.url, headers: {...req.headers, host: 'localhost:8080'}}, incoming => {
      res.writeHead(incoming.statusCode, {...incoming.headers, 'cache-control': 'no-store'}); incoming.pipe(res);
    });
    upstream.on('error', () => { res.writeHead(503, {'Content-Type': mime['.json']}); res.end(JSON.stringify({message: 'Сервер временно недоступен. Повторите запрос.'})); });
    req.pipe(upstream); return;
  }
  let directory = root, activePrefix = prefix, measuring = false;
  const match = compare && url.pathname.match(/^\/measure\/(js|wasm|optimized)\//);
  if (match) { directory = variants[match[1]]; activePrefix = match[0]; measuring = true; }
  if (url.pathname === activePrefix.slice(0, -1)) { res.writeHead(302, {Location: activePrefix}).end(); return; }
  if (!url.pathname.startsWith(activePrefix)) { res.writeHead(404).end('Not found'); return; }
  let relative;
  try { relative = decodeURIComponent(url.pathname.slice(activePrefix.length)); } catch { res.writeHead(400).end(); return; }
  let file = path.resolve(directory, relative || 'index.html');
  if (!file.startsWith(directory + path.sep)) { res.writeHead(403).end(); return; }
  if (!fs.existsSync(file) || !fs.statSync(file).isFile()) {
    if (path.extname(relative)) { res.writeHead(404).end('Not found'); return; }
    file = path.join(directory, 'index.html');
  }
  res.setHeader('Content-Type', mime[path.extname(file)] || 'application/octet-stream');
  if (path.basename(file) === 'index.html') {
    let content = fs.readFileSync(file, 'utf8');
    if (url.searchParams.has('slowBootstrap')) content = content.replace('src="flutter_bootstrap.js"', 'src="flutter_bootstrap.js?slow=1"');
    if (measuring) {
      content = content.replace(/<base href="[^"]*">/, '<base href="' + activePrefix + '">');
      content = content.replace('<head>', `<head><script>window.addEventListener('flutter-first-frame',()=>{parent.postMessage({type:'first-frame',ms:performance.now(),bytes:performance.getEntriesByType('resource').reduce((s,r)=>s+r.transferSize,0),resources:performance.getEntriesByType('resource').map(r=>({name:r.name.split('/').pop(),bytes:r.transferSize}))},location.origin)},{once:true});</script>`);
    }
    res.end(content); return;
  }
  if (url.searchParams.has('slow') && path.basename(file) === 'flutter_bootstrap.js') {
    setTimeout(() => fs.createReadStream(file).pipe(res), 12000); return;
  }
  fs.createReadStream(file).pipe(res);
});
server.listen(port, '127.0.0.1', () => console.log(`Web: http://localhost:${port}${prefix}; SPA fallback enabled${compare ? '; benchmark: /benchmark' : ''}`));
