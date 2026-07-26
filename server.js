const http = require('http');
const fs = require('fs');
const path = require('path');

const rootDir = __dirname;
const analyticsFile = path.join(rootDir, 'analytics.json');
const port = process.env.PORT || 3000;

function readAnalytics() {
  try {
    return JSON.parse(fs.readFileSync(analyticsFile, 'utf8'));
  } catch (error) {
    return {};
  }
}

function writeAnalytics(data) {
  fs.writeFileSync(analyticsFile, JSON.stringify(data, null, 2));
}

function sendJson(res, data, statusCode = 200) {
  res.writeHead(statusCode, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(data));
}

function serveStaticFile(res, filePath) {
  const extension = path.extname(filePath).toLowerCase();
  const contentTypes = {
    '.html': 'text/html; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.js': 'application/javascript; charset=utf-8',
    '.json': 'application/json; charset=utf-8',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.gif': 'image/gif',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon'
  };

  const contentType = contentTypes[extension] || 'application/octet-stream';

  fs.readFile(filePath, (error, content) => {
    if (error) {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('Not found');
      return;
    }

    res.writeHead(200, { 'Content-Type': contentType });
    res.end(content);
  });
}

const server = http.createServer((req, res) => {
  const requestUrl = new URL(req.url, `http://${req.headers.host || 'localhost'}`);

  if (req.method === 'GET' && requestUrl.pathname === '/api/analytics') {
    sendJson(res, readAnalytics());
    return;
  }

  if (req.method === 'POST' && requestUrl.pathname === '/api/analytics') {
    let body = '';

    req.on('data', (chunk) => {
      body += chunk;
    });

    req.on('end', () => {
      let payload = {};

      try {
        payload = body ? JSON.parse(body) : {};
      } catch (error) {
        sendJson(res, { error: 'Invalid JSON' }, 400);
        return;
      }

      if (payload.action === 'reset') {
        writeAnalytics({});
        sendJson(res, {});
        return;
      }

      const photo = payload.photo || requestUrl.searchParams.get('photo');
      const action = payload.action || requestUrl.searchParams.get('action');

      if (!photo || !action) {
        sendJson(res, { error: 'Missing photo or action' }, 400);
        return;
      }

      const analytics = readAnalytics();
      if (!analytics[photo]) {
        analytics[photo] = { opens: 0, saves: 0 };
      }

      if (action === 'open') {
        analytics[photo].opens += 1;
      } else if (action === 'save') {
        analytics[photo].saves += 1;
      } else {
        sendJson(res, { error: 'Invalid action' }, 400);
        return;
      }

      writeAnalytics(analytics);
      sendJson(res, analytics);
    });

    return;
  }

  let requestedPath = decodeURIComponent(requestUrl.pathname);
  if (requestedPath === '/') {
    requestedPath = '/index.html';
  }

  const filePath = path.join(rootDir, requestedPath);

  if (!filePath.startsWith(rootDir)) {
    res.writeHead(403, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Forbidden');
    return;
  }

  fs.existsSync(filePath) ? serveStaticFile(res, filePath) : serveStaticFile(res, path.join(rootDir, 'index.html'));
});

server.listen(port, () => {
  console.log(`Analytics server running at http://localhost:${port}`);
});
