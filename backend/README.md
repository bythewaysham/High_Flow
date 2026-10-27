# HiveFlow API

The local Node.js and PostgreSQL API stores warehouse sample inventory, orders,
robot state, assignments, QR scan events, and decision history. It accepts
simulated robot scans and telemetry; it does not connect to physical robots or
scanner hardware.

## Run locally

Requirements: Node.js 20+ and a running PostgreSQL server.

```sh
cd backend
npm install
createdb hiveflow
cp .env.example .env
npm run migrate
npm run seed
npm run dev
```

By default the API listens on port `3000` on the laptop's network interfaces.
The API has no authentication and uses HTTP for this hardware-free prototype:
use it only on a trusted private network and never expose it to the public
internet. If PostgreSQL requires credentials, set `DATABASE_URL` in
`backend/.env`.
Browser requests are allowed from the same hostname as the API by default. To
use a different hostname for a local web demo, set `CORS_ORIGIN` in
`backend/.env` to that exact origin.

The Flutter app defaults to `http://127.0.0.1:3000` on laptop/web builds and
`http://10.0.2.2:3000` in the Android emulator. For a physical phone, connect
the phone and laptop to the same Wi-Fi and enter the laptop's local IPv4 address
in **Warehouse Ops** (for example `http://192.168.1.5:3000`). On macOS, find it
in System Settings → Wi-Fi → Details, or run `ipconfig getifaddr en0`.

## API workflow

1. `GET /api/inventory` lists products, stock counts, warehouse bin coordinates,
   and the QR/barcode value expected from a scanner.
2. `POST /api/orders` creates an order from known product SKUs.
3. `POST /api/dispatch` uses the Hungarian assignment method to assign queued
   orders to available robots using pick-bin travel distance, battery, and rush
   priority.
4. `POST /api/scans` accepts a robot ID, product scan code, scan type (`pick` or
   `deliver`), and a unique event UUID. Pick scans decrement inventory and
   advance order progress. Delivery scans complete item quantities and release
   the robot when the entire order is delivered. Repeating an event UUID is
   idempotent.
5. `GET /api/orders`, `GET /api/robots`, `GET /api/decisions`, and
   `GET /api/orders/:id/history` show the stored operational state and audit
   trail.

## Endpoint reference

| Method | Endpoint | Purpose |
|---|---|---|
| `GET` | `/api/health` | API and PostgreSQL readiness |
| `GET` | `/api/summary` | Order, robot, inventory, and scan counters |
| `GET` | `/api/inventory` | List stock, product scan codes, and warehouse bins |
| `POST` | `/api/inventory` | Add a product to the catalog |
| `GET` | `/api/robots` | Current robot state and assigned task |
| `POST` | `/api/robots/:id/telemetry` | Save position, battery, and robot status |
| `GET` | `/api/orders` | List orders; optionally filter with `?status=completed` |
| `POST` | `/api/orders` | Create and queue an order |
| `GET` | `/api/orders/:id` | Read order and scanned item progress |
| `POST` | `/api/orders/:id/cancel` | Cancel an order before assignment |
| `POST` | `/api/dispatch` | Assign queued orders to available robots |
| `GET` | `/api/tasks` | List assignments; optionally filter with `?status=picking` |
| `POST` | `/api/scans` | Record an idempotent item pick or delivery scan |
| `GET` | `/api/orders/:id/history` | Read order scans and decisions |
| `GET` | `/api/decisions` | Read recent assignment/order/scan audit events |

Example:

```sh
curl http://127.0.0.1:3000/api/health
curl http://127.0.0.1:3000/api/inventory
curl -X POST http://127.0.0.1:3000/api/orders \
  -H 'Content-Type: application/json' \
  -d '{"customerRef":"DEMO-1","items":[{"sku":"SKU-BOLT-01","quantity":1}]}'
curl -X POST http://127.0.0.1:3000/api/dispatch
```

Use the returned order ID and assigned robot ID when sending a QR scan:

```sh
curl -X POST http://127.0.0.1:3000/api/scans \
  -H 'Content-Type: application/json' \
  -d '{"eventId":"00000000-0000-4000-8000-000000000001","robotId":"R-01","scanCode":"HF-BOLT-001","scanType":"pick"}'
```

The Flutter **Warehouse Ops** screen reads the summary, inventory, orders,
robots, and decision feed from this API. It can create orders, dispatch queued
orders, and send simulated pick/delivery QR events. No camera, physical scanner,
or real robot is connected yet.

## Verify

```sh
npm test
```
