import { pool } from './pool.js';

const products = [
  ['SKU-BOLT-01', 'Hex bolts', 'Fasteners', 'HF-BOLT-001', 240, 2, 1],
  ['SKU-SENSOR-01', 'Proximity sensor', 'Electronics', 'HF-SENSOR-001', 48, 5, 1],
  ['SKU-MOTOR-01', 'Drive motor', 'Motors', 'HF-MOTOR-001', 32, 8, 1],
  ['SKU-CABLE-01', 'Power cable', 'Electrical', 'HF-CABLE-001', 90, 11, 1],
  ['SKU-WHEEL-01', 'Robot wheel', 'Parts', 'HF-WHEEL-001', 64, 14, 1],
  ['SKU-GRIPPER-01', 'Robot gripper', 'Parts', 'HF-GRIPPER-001', 24, 2, 5],
  ['SKU-BATTERY-01', 'Battery pack', 'Power', 'HF-BATTERY-001', 18, 8, 5],
  ['SKU-BRACKET-01', 'Mounting bracket', 'Hardware', 'HF-BRACKET-001', 120, 11, 5],
];

const robots = [
  ['R-01', 'generic', 1, 2, 91],
  ['R-02', 'generic', 5, 1, 76],
  ['R-03', 'generic', 13, 2, 68],
  ['R-04', 'generic', 2, 7, 80],
  ['R-05', 'generic', 7, 8, 54],
  ['R-06', 'generic', 14, 7, 87],
  ['R-07', 'generic', 8, 1, 63],
  ['R-08', 'generic', 0, 5, 43],
];

const client = await pool.connect();
try {
  await client.query('BEGIN');
  for (const product of products) {
    await client.query(
      `INSERT INTO products (sku, name, category, scan_code, on_hand, bin_x, bin_y)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       ON CONFLICT (sku) DO NOTHING`,
      product,
    );
  }
  for (const robot of robots) {
    await client.query(
      `INSERT INTO robots (id, adapter_type, position_x, position_y, battery)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (id) DO NOTHING`,
      robot,
    );
  }
  await client.query('COMMIT');
  console.log(`Seeded ${products.length} catalog items and ${robots.length} sample robots.`);
} catch (error) {
  await client.query('ROLLBACK');
  console.error('Could not seed HiveFlow sample data.', error);
  process.exitCode = 1;
} finally {
  client.release();
  await pool.end();
}
