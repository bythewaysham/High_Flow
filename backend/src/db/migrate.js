import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

import { pool } from './pool.js';

const schemaPath = new URL('./schema.sql', import.meta.url);

try {
  const schema = await readFile(fileURLToPath(schemaPath), 'utf8');
  await pool.query(schema);
  console.log('HiveFlow database schema is ready.');
} catch (error) {
  console.error('Could not apply the HiveFlow database schema.', error);
  process.exitCode = 1;
} finally {
  await pool.end();
}
