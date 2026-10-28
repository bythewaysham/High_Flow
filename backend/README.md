# HiveFlow Backend

The backend is a local API for the HiveFlow **Warehouse Ops** screen. It stores
sample inventory, orders, robot assignments, scan events, and decision history
in PostgreSQL. The Flutter simulator can be used without the backend.

This prototype records simulated scans and robot telemetry. It does not connect
to physical robots, cameras, or scanner hardware.

## Requirements

- Node.js 20 or later
- PostgreSQL

## Set up and run

From the project root:

```sh
cd backend
npm install
createdb hiveflow
cp .env.example .env
npm run migrate
npm run seed
npm run dev
```

The API starts on port `3000`. If your PostgreSQL setup needs different
credentials or a different address, update `DATABASE_URL` in `backend/.env`.
Use `npm start` to run the API without the development file watcher.

## Connect the Flutter app

On the same computer, Warehouse Ops uses `http://127.0.0.1:3000` by default.
An Android emulator uses `http://10.0.2.2:3000`.

For a physical phone, connect it and the computer running the API to the same
Wi-Fi network. In Warehouse Ops, enter the computer's local IP address, for
example `http://192.168.1.5:3000`. On macOS, find the address in **System
Settings → Wi-Fi → Details**, or run:

```sh
ipconfig getifaddr en0
```

Web requests from the same hostname are allowed by default. To allow a
different web origin, set `CORS_ORIGIN` in `backend/.env` to that origin.

## API

| Method | Endpoint | Purpose |
|---|---|---|
| `GET` | `/api/health` | Check API and database readiness |
| `GET` | `/api/summary` | Get order, robot, inventory, and scan counts |
| `GET`, `POST` | `/api/inventory` | View inventory or add a product |
| `GET` | `/api/robots` | View robot status and assignments |
| `POST` | `/api/robots/:id/telemetry` | Update a robot's position, battery, and status |
| `GET`, `POST` | `/api/orders` | View orders or create an order |
| `GET` | `/api/orders/:id` | View order details and item progress |
| `POST` | `/api/orders/:id/cancel` | Cancel an order before assignment |
| `POST` | `/api/dispatch` | Assign queued orders to available robots |
| `GET` | `/api/tasks` | View robot tasks |
| `POST` | `/api/scans` | Record a simulated pick or delivery scan |
| `GET` | `/api/orders/:id/history` | View an order's scans and decisions |
| `GET` | `/api/decisions` | View recent operational events |

Dispatch considers travel distance, battery level, and rush priority. Scan
requests use a unique event ID so retrying the same request does not apply the
scan twice.

Example requests:

```sh
curl http://127.0.0.1:3000/api/health
curl http://127.0.0.1:3000/api/inventory

curl -X POST http://127.0.0.1:3000/api/orders \
  -H 'Content-Type: application/json' \
  -d '{"customerRef":"DEMO-1","items":[{"sku":"SKU-BOLT-01","quantity":1}]}'

curl -X POST http://127.0.0.1:3000/api/dispatch
```

Use the order and robot IDs returned by the API to submit a scan:

```sh
curl -X POST http://127.0.0.1:3000/api/scans \
  -H 'Content-Type: application/json' \
  -d '{"eventId":"00000000-0000-4000-8000-000000000001","robotId":"R-01","scanCode":"HF-BOLT-001","scanType":"pick"}'
```

## Security

The local API uses HTTP and has no authentication. Run it only on a trusted
private network; do not expose it directly to the public internet.

## Tests

```sh
npm test
```
