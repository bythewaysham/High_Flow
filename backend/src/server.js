import 'dotenv/config';

import express from 'express';

import { pool } from './db/pool.js';
import { errorHandler } from './errors.js';
import { router } from './routes.js';

const app = express();
app.disable('x-powered-by');
app.use((request, response, next) => {
  const origin = request.get('Origin');
  if (origin) {
    let originUrl;
    try {
      originUrl = new URL(origin);
    } catch {
      response.status(403).json({
        error: { code: 'origin_not_allowed', message: 'This web origin is not allowed.' },
      });
      return;
    }
    const configuredOrigins = (process.env.CORS_ORIGIN ?? '')
      .split(',')
      .map((value) => value.trim())
      .filter(Boolean);
    if (
      originUrl.hostname !== request.hostname &&
      !configuredOrigins.includes(origin)
    ) {
      response.status(403).json({
        error: { code: 'origin_not_allowed', message: 'This web origin is not allowed.' },
      });
      return;
    }
    response.setHeader('Access-Control-Allow-Origin', origin);
    response.setHeader('Vary', 'Origin');
  }
  response.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  response.setHeader('Access-Control-Allow-Headers', 'Accept, Content-Type');
  if (request.method === 'OPTIONS') {
    response.sendStatus(204);
    return;
  }
  next();
});
app.use(express.json({ limit: '1mb' }));
app.use('/api', router);
app.use((_request, response) => {
  response.status(404).json({
    error: { code: 'not_found', message: 'API route not found.' },
  });
});
app.use(errorHandler);

const host = process.env.HOST ?? '0.0.0.0';
const port = Number(process.env.PORT ?? 3000);
const server = app.listen(port, host, () => {
  console.log(`HiveFlow API listening at http://${host}:${port}`);
});

async function shutdown(signal) {
  console.log(`${signal} received; closing HiveFlow API.`);
  server.close(async (error) => {
    await pool.end();
    if (error) {
      console.error('Could not close the API server cleanly.', error);
      process.exitCode = 1;
    }
  });
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
