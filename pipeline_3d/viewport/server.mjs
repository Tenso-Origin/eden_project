import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PORT = process.env.PORT ? parseInt(process.env.PORT, 10) : 8088;
const HOST = process.env.HOST || '0.0.0.0';

// Pastas monitoradas para modelos 3D
const WATCH_DIRS = [
  'd:/Tenso/Documents/eden_project/pipeline_3d',
  path.join(__dirname, '..'),
  __dirname
];

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.glb': 'model/gltf-binary',
  '.gltf': 'model/gltf+json',
  '.bin': 'application/octet-stream',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
  '.blend': 'application/octet-stream'
};

// Gerenciamento de clientes SSE (Server-Sent Events)
const sseClients = new Set();

function broadcastSSE(data) {
  const payload = `data: ${JSON.stringify(data)}\n\n`;
  for (const client of sseClients) {
    try {
      client.write(payload);
    } catch {
      sseClients.delete(client);
    }
  }
}

// Observa mudanças nas pastas de modelos
let debounceTimer = null;
for (const dir of WATCH_DIRS) {
  if (fs.existsSync(dir)) {
    try {
      fs.watch(dir, { recursive: false }, (eventType, filename) => {
        if (!filename) return;
        const ext = path.extname(filename).toLowerCase();
        if (['.glb', '.gltf', '.blend', '.png'].includes(ext)) {
          clearTimeout(debounceTimer);
          debounceTimer = setTimeout(() => {
            console.log(`[SSE Watcher] Arquivo modificado: ${filename} -> Notificando viewport`);
            broadcastSSE({
              event: 'reload',
              file: filename,
              timestamp: Date.now()
            });
          }, 300);
        }
      });
      console.log(`[Watcher] Monitorando alterações em: ${dir}`);
    } catch (e) {
      console.warn(`[Watcher] Não foi possível observar ${dir}:`, e.message);
    }
  }
}

// Coleta lista de modelos disponíveis
function listAvailableModels() {
  const models = [];
  const seen = new Set();

  for (const dir of WATCH_DIRS) {
    if (!fs.existsSync(dir)) continue;
    try {
      const files = fs.readdirSync(dir);
      for (const file of files) {
        const ext = path.extname(file).toLowerCase();
        if (['.glb', '.gltf'].includes(ext) && !seen.has(file)) {
          seen.add(file);
          const fullPath = path.join(dir, file);
          const stat = fs.statSync(fullPath);
          models.push({
            name: file,
            size: stat.size,
            mtime: stat.mtimeMs,
            path: fullPath,
            sourceDir: dir
          });
        }
      }
    } catch (err) {
      console.error(`Erro ao listar ${dir}:`, err.message);
    }
  }

  // Ordena por tempo de modificação mais recente primeiro
  models.sort((a, b) => b.mtime - a.mtime);
  return models;
}

const server = http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', '*');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  const parsedUrl = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const reqPath = decodeURI(parsedUrl.pathname);

  // Endpoint SSE
  if (reqPath === '/events') {
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache, no-transform',
      'Connection': 'keep-alive',
      'Access-Control-Allow-Origin': '*'
    });
    res.write(`data: ${JSON.stringify({ event: 'connected', time: Date.now() })}\n\n`);
    sseClients.add(res);

    req.on('close', () => {
      sseClients.delete(res);
    });
    return;
  }

  // API de lista de modelos
  if (reqPath === '/api/models') {
    const models = listAvailableModels();
    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify(models));
    return;
  }

  // Rota para baixar/visualizar modelo 3D por nome: /models/:name
  if (reqPath.startsWith('/models/')) {
    const filename = path.basename(reqPath);
    let targetPath = null;

    for (const dir of WATCH_DIRS) {
      const candidate = path.join(dir, filename);
      if (fs.existsSync(candidate)) {
        targetPath = candidate;
        break;
      }
    }

    if (!targetPath) {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end(`404 Modelo não encontrado: ${filename}`);
      return;
    }

    const stat = fs.statSync(targetPath);
    const ext = path.extname(targetPath).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';

    res.writeHead(200, {
      'Content-Type': contentType,
      'Content-Length': stat.size,
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'Access-Control-Allow-Origin': '*'
    });

    const stream = fs.createReadStream(targetPath);
    stream.pipe(res);
    return;
  }

  // Roteamento de arquivos estáticos da interface web
  let filePath = path.join(__dirname, reqPath === '/' ? 'viewport.html' : reqPath);

  // Fallback se não existir em __dirname
  if (!fs.existsSync(filePath)) {
    filePath = path.join(__dirname, 'viewport.html');
  }

  if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';
    const stat = fs.statSync(filePath);

    res.writeHead(200, {
      'Content-Type': contentType,
      'Content-Length': stat.size,
      'Cache-Control': 'no-cache, no-store, must-revalidate'
    });

    const stream = fs.createReadStream(filePath);
    stream.pipe(res);
  } else {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('404 Arquivo não encontrado');
  }
});

server.listen(PORT, HOST, () => {
  console.log(`\n======================================================`);
  console.log(`  BLENDER 3D CAD - VIEWPORT THREE.JS (DESACOPLADO)`);
  console.log(`======================================================`);
  console.log(`  Regra MCP 3D Modeling: Viewport ativo em http://${HOST}:${PORT}`);
  console.log(`  -> URL Principal: http://127.0.0.1:${PORT}`);
  console.log(`  -> Hostname     : http://localhost:${PORT}`);
  console.log(`  -> SSE Stream   : http://127.0.0.1:${PORT}/events`);
  console.log(`======================================================\n`);
});
