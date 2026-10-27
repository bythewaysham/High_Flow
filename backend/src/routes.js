import { randomUUID } from 'node:crypto';
import { Router } from 'express';

import { solveAssignment } from './assignment.js';
import { pool, inTransaction } from './db/pool.js';
import { asyncRoute, HttpError } from './errors.js';
import {
  orderSchema,
  productSchema,
  scanSchema,
  telemetrySchema,
} from './validation.js';

export const router = Router();

const orderSelect = `
  SELECT
    o.id,
    o.customer_ref AS "customerRef",
    o.priority,
    o.status,
    o.created_at AS "createdAt",
    o.updated_at AS "updatedAt",
    o.completed_at AS "completedAt",
    COALESCE(
      json_agg(
        json_build_object(
          'sku', p.sku,
          'name', p.name,
          'scanCode', p.scan_code,
          'quantity', oi.quantity,
          'pickedQuantity', oi.picked_quantity,
          'deliveredQuantity', oi.delivered_quantity,
          'bin', json_build_object('x', p.bin_x, 'y', p.bin_y)
        )
      ) FILTER (WHERE oi.id IS NOT NULL),
      '[]'::json
    ) AS items
  FROM orders o
  LEFT JOIN order_items oi ON oi.order_id = o.id
  LEFT JOIN products p ON p.sku = oi.sku`;

router.get(
  '/health',
  asyncRoute(async (_request, response) => {
    await pool.query('SELECT 1');
    response.json({ status: 'ok', database: 'connected', service: 'hiveflow-api' });
  }),
);

router.get(
  '/summary',
  asyncRoute(async (_request, response) => {
    const result = await pool.query(
      `SELECT
         (SELECT COUNT(*)::int FROM orders) AS "totalOrders",
         (SELECT COUNT(*)::int FROM orders WHERE status = 'completed') AS "completedOrders",
         (SELECT COUNT(*)::int FROM orders WHERE status IN ('received', 'queued')) AS "queuedOrders",
         (SELECT COUNT(*)::int FROM orders WHERE status IN ('assigned', 'picking', 'delivering')) AS "activeOrders",
         (SELECT COUNT(*)::int FROM robots WHERE status <> 'unavailable') AS "onlineRobots",
         (SELECT COUNT(*)::int FROM robots WHERE current_task_id IS NOT NULL) AS "busyRobots",
         (SELECT COALESCE(SUM(on_hand), 0)::int FROM products) AS "inventoryUnits",
         (SELECT COUNT(*)::int FROM scan_events) AS "scanEvents"`,
    );
    response.json({ summary: result.rows[0] });
  }),
);

router.get(
  '/inventory',
  asyncRoute(async (_request, response) => {
    const result = await pool.query(
      `SELECT sku, name, category, scan_code AS "scanCode", on_hand AS "onHand",
              json_build_object('x', bin_x, 'y', bin_y) AS bin
       FROM products ORDER BY name`,
    );
    response.json({ items: result.rows });
  }),
);

router.post(
  '/inventory',
  asyncRoute(async (request, response) => {
    const product = productSchema.parse(request.body);
    const result = await pool.query(
      `INSERT INTO products (sku, name, category, scan_code, on_hand, bin_x, bin_y)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING sku, name, category, scan_code AS "scanCode", on_hand AS "onHand",
                 json_build_object('x', bin_x, 'y', bin_y) AS bin`,
      [
        product.sku,
        product.name,
        product.category,
        product.scanCode,
        product.onHand,
        product.bin.x,
        product.bin.y,
      ],
    );
    response.status(201).json({ item: result.rows[0] });
  }),
);

router.get(
  '/robots',
  asyncRoute(async (_request, response) => {
    const result = await pool.query(
      `SELECT
         r.id,
         r.adapter_type AS "adapterType",
         r.status,
         r.battery,
         json_build_object('x', r.position_x, 'y', r.position_y) AS position,
         r.last_seen_at AS "lastSeenAt",
         t.id AS "taskId",
         t.order_id AS "orderId"
       FROM robots r
       LEFT JOIN robot_tasks t ON t.id = r.current_task_id
       ORDER BY r.id`,
    );
    response.json({ robots: result.rows });
  }),
);

router.post(
  '/robots/:id/telemetry',
  asyncRoute(async (request, response) => {
    const telemetry = telemetrySchema.parse(request.body);
    if (telemetry.status === 'idle') {
      const activeTask = await pool.query(
        'SELECT 1 FROM robots WHERE id = $1 AND current_task_id IS NOT NULL',
        [request.params.id],
      );
      if (activeTask.rowCount > 0) {
        throw new HttpError(
          409,
          'A robot with an active task cannot report idle.',
          'robot_has_active_task',
        );
      }
    }
    const result = await pool.query(
      `UPDATE robots
       SET position_x = $2, position_y = $3, battery = $4,
           status = COALESCE($5, status), last_seen_at = NOW(), updated_at = NOW()
       WHERE id = $1
       RETURNING id, status, battery,
                 json_build_object('x', position_x, 'y', position_y) AS position,
                 last_seen_at AS "lastSeenAt"`,
      [
        request.params.id,
        telemetry.x,
        telemetry.y,
        telemetry.battery,
        telemetry.status ?? null,
      ],
    );
    if (result.rowCount === 0) throw new HttpError(404, 'Robot not found.', 'robot_not_found');
    response.json({ robot: result.rows[0] });
  }),
);

router.post(
  '/orders',
  asyncRoute(async (request, response) => {
    const input = orderSchema.parse(request.body);
    const orderId = `ORD-${randomUUID().slice(0, 8).toUpperCase()}`;
    const order = await inTransaction(async (client) => {
      const skus = input.items.map((item) => item.sku);
      const products = await client.query(
        'SELECT sku FROM products WHERE sku = ANY($1::text[])',
        [skus],
      );
      if (products.rowCount !== skus.length) {
        const found = new Set(products.rows.map((row) => row.sku));
        const missing = skus.filter((sku) => !found.has(sku));
        throw new HttpError(
          400,
          `Unknown product SKU(s): ${missing.join(', ')}.`,
          'unknown_product',
        );
      }

      await client.query(
        `INSERT INTO orders (id, customer_ref, priority, status)
         VALUES ($1, $2, $3, 'queued')`,
        [orderId, input.customerRef ?? null, input.priority],
      );
      for (const item of input.items) {
        await client.query(
          'INSERT INTO order_items (order_id, sku, quantity) VALUES ($1, $2, $3)',
          [orderId, item.sku, item.quantity],
        );
      }
      await client.query(
        `INSERT INTO decision_log (order_id, event_type, message, details)
         VALUES ($1, 'order_received', $2, $3)`,
        [
          orderId,
          `Order ${orderId} entered the queue.`,
          JSON.stringify({ priority: input.priority, itemCount: input.items.length }),
        ],
      );

      const result = await client.query(
        `${orderSelect} WHERE o.id = $1 GROUP BY o.id`,
        [orderId],
      );
      return result.rows[0];
    });
    response.status(201).json({ order });
  }),
);

router.get(
  '/orders',
  asyncRoute(async (request, response) => {
    const statuses = new Set([
      'received',
      'queued',
      'assigned',
      'picking',
      'delivering',
      'completed',
      'cancelled',
    ]);
    const status = request.query.status;
    if (status && !statuses.has(status)) {
      throw new HttpError(400, 'Unknown order status filter.', 'invalid_status');
    }
    const result = await pool.query(
      `${orderSelect}
       ${status ? 'WHERE o.status = $1' : ''}
       GROUP BY o.id
       ORDER BY o.created_at DESC
       LIMIT 200`,
      status ? [status] : [],
    );
    response.json({ orders: result.rows });
  }),
);

router.get(
  '/orders/:id',
  asyncRoute(async (request, response) => {
    const result = await pool.query(
      `${orderSelect} WHERE o.id = $1 GROUP BY o.id`,
      [request.params.id],
    );
    if (result.rowCount === 0) throw new HttpError(404, 'Order not found.', 'order_not_found');
    response.json({ order: result.rows[0] });
  }),
);

router.post(
  '/orders/:id/cancel',
  asyncRoute(async (request, response) => {
    const result = await inTransaction(async (client) => {
      const order = await client.query(
        `SELECT id, status FROM orders WHERE id = $1 FOR UPDATE`,
        [request.params.id],
      );
      if (order.rowCount === 0) {
        throw new HttpError(404, 'Order not found.', 'order_not_found');
      }
      if (!['received', 'queued'].includes(order.rows[0].status)) {
        throw new HttpError(
          409,
          'Only orders that have not been assigned can be cancelled.',
          'order_already_started',
        );
      }
      await client.query(
        `UPDATE orders SET status = 'cancelled', updated_at = NOW() WHERE id = $1`,
        [request.params.id],
      );
      await client.query(
        `INSERT INTO decision_log (order_id, event_type, message)
         VALUES ($1, 'order_cancelled', $2)`,
        [request.params.id, `Order ${request.params.id} was cancelled.`],
      );
      return client.query(`${orderSelect} WHERE o.id = $1 GROUP BY o.id`, [
        request.params.id,
      ]);
    });
    response.json({ order: result.rows[0] });
  }),
);

router.post(
  '/dispatch',
  asyncRoute(async (_request, response) => {
    const assignments = await inTransaction(async (client) => {
      const robotsResult = await client.query(
        `SELECT id, battery, position_x, position_y
         FROM robots
         WHERE status = 'idle' AND current_task_id IS NULL AND battery > 10
         ORDER BY id
         FOR UPDATE SKIP LOCKED`,
      );
      const ordersResult = await client.query(
        `SELECT o.id, o.priority, o.created_at, oi.sku, oi.quantity,
                p.bin_x, p.bin_y
         FROM orders o
         JOIN order_items oi ON oi.order_id = o.id
         JOIN products p ON p.sku = oi.sku
         WHERE o.status IN ('received', 'queued')
         ORDER BY (o.priority = 'rush') DESC, o.created_at, o.id
         FOR UPDATE OF o SKIP LOCKED`,
      );
      const orderMap = new Map();
      for (const row of ordersResult.rows) {
        const order = orderMap.get(row.id) ?? {
          id: row.id,
          priority: row.priority,
          createdAt: row.created_at,
          bins: [],
        };
        order.bins.push({ x: row.bin_x, y: row.bin_y });
        orderMap.set(row.id, order);
      }
      const robots = robotsResult.rows;
      const orders = [...orderMap.values()];
      if (robots.length === 0 || orders.length === 0) return [];

      const costs = robots.map((robot) =>
        orders.map((order) => {
          let x = robot.position_x;
          let y = robot.position_y;
          let distance = 0;
          for (const bin of order.bins) {
            distance += Math.abs(x - bin.x) + Math.abs(y - bin.y);
            x = bin.x;
            y = bin.y;
          }
          const batteryPenalty = (100 - robot.battery) * 0.1;
          const rushBenefit = order.priority === 'rush' ? -100_000 : 0;
          return distance + batteryPenalty + rushBenefit;
        }),
      );
      const matching = solveAssignment(costs);
      const created = [];
      for (let robotIndex = 0; robotIndex < matching.length; robotIndex++) {
        const orderIndex = matching[robotIndex];
        if (orderIndex < 0) continue;
        const robot = robots[robotIndex];
        const order = orders[orderIndex];
        const taskId = randomUUID();
        await client.query(
          `INSERT INTO robot_tasks (id, robot_id, order_id) VALUES ($1, $2, $3)`,
          [taskId, robot.id, order.id],
        );
        await client.query(
          `UPDATE robots
           SET current_task_id = $2, status = 'assigned', updated_at = NOW()
           WHERE id = $1`,
          [robot.id, taskId],
        );
        await client.query(
          `UPDATE orders SET status = 'assigned', updated_at = NOW() WHERE id = $1`,
          [order.id],
        );
        const distance = costs[robotIndex][orderIndex];
        await client.query(
          `INSERT INTO decision_log (order_id, robot_id, task_id, event_type, message, details)
           VALUES ($1, $2, $3, 'task_assigned', $4, $5)`,
          [
            order.id,
            robot.id,
            taskId,
            `${robot.id} assigned to ${order.id}; estimated pick travel cost ${distance.toFixed(1)}.`,
            JSON.stringify({
              priority: order.priority,
              estimatedTravelCost: Number(distance.toFixed(1)),
              assignmentAlgorithm: 'Hungarian',
            }),
          ],
        );
        created.push({ taskId, robotId: robot.id, orderId: order.id });
      }
      return created;
    });
    response.json({ assignments });
  }),
);

router.get(
  '/tasks',
  asyncRoute(async (request, response) => {
    const statuses = new Set([
      'assigned',
      'picking',
      'delivering',
      'completed',
      'cancelled',
    ]);
    const status = request.query.status;
    if (status && !statuses.has(status)) {
      throw new HttpError(400, 'Unknown task status filter.', 'invalid_status');
    }
    const result = await pool.query(
      `SELECT t.id, t.order_id AS "orderId", t.robot_id AS "robotId",
              t.status, o.priority, t.assigned_at AS "assignedAt",
              t.completed_at AS "completedAt"
       FROM robot_tasks t
       JOIN orders o ON o.id = t.order_id
       ${status ? 'WHERE t.status = $1' : ''}
       ORDER BY t.assigned_at DESC
       LIMIT 200`,
      status ? [status] : [],
    );
    response.json({ tasks: result.rows });
  }),
);

router.post(
  '/scans',
  asyncRoute(async (request, response) => {
    const scan = scanSchema.parse(request.body);
    const result = await inTransaction(async (client) => {
    const priorScan = await client.query(
      `SELECT event_id AS "eventId", robot_id AS "robotId", order_id AS "orderId",
              scan_code AS "scanCode", product_sku AS sku,
              scan_type AS "scanType", scanned_at AS "scannedAt"
       FROM scan_events WHERE event_id = $1`,
      [scan.eventId],
    );
    if (priorScan.rowCount > 0) {
      const previous = priorScan.rows[0];
      if (
        previous.robotId !== scan.robotId ||
        previous.scanCode !== scan.scanCode ||
        previous.scanType !== scan.scanType
      ) {
        throw new HttpError(
          409,
          'This scan event ID was already used for a different scan.',
          'scan_event_id_reused',
        );
      }
      return { scan: previous, duplicate: true, orderStatus: undefined };
    }

    const robotResult = await client.query(
        `SELECT r.id AS robot_id, r.status AS robot_status, r.current_task_id,
                t.order_id, t.status AS task_status
         FROM robots r
         JOIN robot_tasks t ON t.id = r.current_task_id
         WHERE r.id = $1
           AND t.status IN ('assigned', 'picking', 'delivering')
         FOR UPDATE OF r, t`,
        [scan.robotId],
      );
      if (robotResult.rowCount === 0) {
        throw new HttpError(
          409,
          'This robot has no active order to scan against.',
          'robot_has_no_active_task',
        );
      }
      const robot = robotResult.rows[0];
      const productResult = await client.query(
        'SELECT sku FROM products WHERE scan_code = $1',
        [scan.scanCode],
      );
      if (productResult.rowCount === 0) {
        throw new HttpError(404, 'No product matches this QR code.', 'unknown_scan_code');
      }
      const sku = productResult.rows[0].sku;
      const itemResult = await client.query(
        `SELECT quantity, picked_quantity, delivered_quantity
         FROM order_items
         WHERE order_id = $1 AND sku = $2
         FOR UPDATE`,
        [robot.order_id, sku],
      );
      if (itemResult.rowCount === 0) {
        throw new HttpError(
          409,
          'This parcel is not part of the robot’s assigned order.',
          'product_not_in_order',
        );
      }
      const item = itemResult.rows[0];
      const inserted = await client.query(
        `INSERT INTO scan_events
           (event_id, robot_id, task_id, order_id, product_sku, scan_code, scan_type, metadata)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         ON CONFLICT (event_id) DO NOTHING
         RETURNING id, event_id AS "eventId", robot_id AS "robotId",
                   order_id AS "orderId", product_sku AS sku, scan_type AS "scanType",
                   scanned_at AS "scannedAt"`,
        [
          scan.eventId,
          robot.robot_id,
          robot.current_task_id,
          robot.order_id,
          sku,
          scan.scanCode,
          scan.scanType,
          JSON.stringify(scan.metadata),
        ],
      );
      if (inserted.rowCount === 0) {
        const previous = await client.query(
          `SELECT event_id AS "eventId", robot_id AS "robotId", order_id AS "orderId",
                  scan_code AS "scanCode", product_sku AS sku,
                  scan_type AS "scanType", scanned_at AS "scannedAt"
           FROM scan_events WHERE event_id = $1`,
          [scan.eventId],
        );
        const priorEvent = previous.rows[0];
        if (
          priorEvent.robotId !== scan.robotId ||
          priorEvent.scanCode !== scan.scanCode ||
          priorEvent.scanType !== scan.scanType
        ) {
          throw new HttpError(
            409,
            'This scan event ID was already used for a different scan.',
            'scan_event_id_reused',
          );
        }
        return { scan: priorEvent, duplicate: true, orderStatus: undefined };
      }

      let orderStatus;
      if (scan.scanType === 'pick') {
        if (robot.task_status === 'delivering') {
          throw new HttpError(409, 'This order is already at the delivery stage.', 'order_already_delivering');
        }
        if (item.picked_quantity >= item.quantity) {
          throw new HttpError(
            409,
            'The required quantity for this item has already been picked.',
            'item_quantity_already_picked',
          );
        }
        const stock = await client.query(
          `UPDATE products
           SET on_hand = on_hand - 1, updated_at = NOW()
           WHERE sku = $1 AND on_hand > 0
           RETURNING on_hand`,
          [sku],
        );
        if (stock.rowCount === 0) {
          throw new HttpError(409, 'No stock remains for this product.', 'out_of_stock');
        }
        await client.query(
          `UPDATE order_items SET picked_quantity = picked_quantity + 1
           WHERE order_id = $1 AND sku = $2`,
          [robot.order_id, sku],
        );
        const progress = await client.query(
          `SELECT BOOL_AND(picked_quantity = quantity) AS all_picked
           FROM order_items WHERE order_id = $1`,
          [robot.order_id],
        );
        const allPicked = progress.rows[0].all_picked;
        orderStatus = allPicked ? 'delivering' : 'picking';
        await client.query(
          `UPDATE orders SET status = $2, updated_at = NOW() WHERE id = $1`,
          [robot.order_id, orderStatus],
        );
        await client.query(
          `UPDATE robot_tasks SET status = $2 WHERE id = $1`,
          [robot.current_task_id, allPicked ? 'delivering' : 'picking'],
        );
        await client.query(
          `UPDATE robots SET status = $2, updated_at = NOW() WHERE id = $1`,
          [robot.robot_id, allPicked ? 'delivering' : 'picking'],
        );
      } else {
        if (robot.task_status !== 'delivering') {
          throw new HttpError(
            409,
            'Pick the order items before recording a delivery scan.',
            'items_not_picked',
          );
        }
        if (item.delivered_quantity >= item.picked_quantity) {
          throw new HttpError(
            409,
            'This item has not been picked or has already been delivered.',
            'nothing_to_deliver',
          );
        }
        await client.query(
          `UPDATE order_items SET delivered_quantity = delivered_quantity + 1
           WHERE order_id = $1 AND sku = $2`,
          [robot.order_id, sku],
        );
        const progress = await client.query(
          `SELECT BOOL_AND(delivered_quantity = quantity) AS all_delivered
           FROM order_items WHERE order_id = $1`,
          [robot.order_id],
        );
        const allDelivered = progress.rows[0].all_delivered;
        orderStatus = allDelivered ? 'completed' : 'delivering';
        await client.query(
          `UPDATE orders
           SET status = $2, updated_at = NOW(),
               completed_at = CASE WHEN $2 = 'completed' THEN NOW() ELSE completed_at END
           WHERE id = $1`,
          [robot.order_id, orderStatus],
        );
        await client.query(
          `UPDATE robot_tasks
           SET status = $2,
               completed_at = CASE WHEN $2 = 'completed' THEN NOW() ELSE completed_at END
           WHERE id = $1`,
          [robot.current_task_id, allDelivered ? 'completed' : 'delivering'],
        );
        await client.query(
          `UPDATE robots
           SET status = $2,
               current_task_id = CASE WHEN $2 = 'idle' THEN NULL ELSE current_task_id END,
               updated_at = NOW()
           WHERE id = $1`,
          [robot.robot_id, allDelivered ? 'idle' : 'delivering'],
        );
      }

      await client.query(
        `INSERT INTO decision_log (order_id, robot_id, task_id, event_type, message, details)
         VALUES ($1, $2, $3, $5, $4, $6)`,
        [
          robot.order_id,
          robot.robot_id,
          robot.current_task_id,
          `QR ${scan.scanType} scan recorded for ${sku} on ${robot.order_id}.`,
          scan.scanType,
          JSON.stringify({ scanCode: scan.scanCode, eventId: scan.eventId }),
        ],
      );
      return { scan: inserted.rows[0], duplicate: false, orderStatus };
    });
    response.status(result.duplicate ? 200 : 201).json(result);
  }),
);

router.get(
  '/orders/:id/history',
  asyncRoute(async (request, response) => {
    const exists = await pool.query('SELECT 1 FROM orders WHERE id = $1', [
      request.params.id,
    ]);
    if (exists.rowCount === 0) throw new HttpError(404, 'Order not found.', 'order_not_found');

    const [scans, decisions] = await Promise.all([
      pool.query(
        `SELECT event_id AS "eventId", robot_id AS "robotId", product_sku AS sku,
                scan_type AS "scanType", scanned_at AS "scannedAt"
         FROM scan_events WHERE order_id = $1 ORDER BY scanned_at`,
        [request.params.id],
      ),
      pool.query(
        `SELECT event_type AS type, robot_id AS "robotId", message, details,
                created_at AS "createdAt"
         FROM decision_log WHERE order_id = $1 ORDER BY created_at`,
        [request.params.id],
      ),
    ]);
    response.json({ scans: scans.rows, decisions: decisions.rows });
  }),
);

router.get(
  '/decisions',
  asyncRoute(async (_request, response) => {
    const result = await pool.query(
      `SELECT id, order_id AS "orderId", robot_id AS "robotId",
              event_type AS type, message, details, created_at AS "createdAt"
       FROM decision_log ORDER BY created_at DESC LIMIT 200`,
    );
    response.json({ decisions: result.rows });
  }),
);
