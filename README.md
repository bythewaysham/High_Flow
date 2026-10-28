# HiveFlow

## Warehouse fleet coordination dashboard

HiveFlow is a Flutter prototype for viewing a warehouse robot fleet, trying
route-planning scenarios, and managing sample warehouse orders. It has two
separate parts:

- A local simulator with sample robots, tasks, routes, and scenario controls.
- A **Warehouse Ops** screen that reads and updates orders and inventory through
  a Node.js API backed by PostgreSQL.

The app is designed for desktop and phone-sized screens. It is a software
prototype: it does not connect to or control physical robots.

## Dashboard sections

### Overview

See the sample warehouse floor, robot locations and routes, active pick
missions, fleet health, and recent decisions. The overview also includes
controls for trying simulator events.

### Simulation

Run or pause the local fleet simulation and inspect how sample robot routes
change. You can block or reopen an aisle, simulate a robot failure, add a rush
order, and reset the demo.

### Fleet

Review the sample robot roster, including each robot's current position,
battery, state, task, and route. The failure control lets you try task
reassignment in the simulator.

### Decisions

Review a local activity feed describing assignments, route changes, and
scenario events.

### Warehouse Ops

Connect to the backend to view stored orders, inventory, robot assignments,
and backend activity. Create normal or rush orders, assign queued orders to
available robots, and record simulated pick and delivery scans.

## How the simulator works

The local demo starts with a deterministic sample fleet of eight robots on a
16-by-10 warehouse grid. Shelves restrict movement through the grid, and the
aisle-block control adds or removes a blocked cell.

The HiveFlow planner uses space-time A* over a bounded planning window. Its
reservation table tracks cells and edges over time, including wait steps and
opposite-direction edge swaps. Task assignment uses the Hungarian method with
distance, battery, and rush priority represented in the assignment cost.

The baseline/HiveFlow comparison graphic is a visual preview, not a live
benchmark between two connected fleet planners. Simulation activity, counters,
and decision messages are illustrative sample data; they are not measurements
from a real warehouse.

## Technology

- **App:** Flutter and Dart
- **API:** Node.js, Express, and Zod request validation
- **Database:** PostgreSQL
- **Assignment:** Hungarian method
- **Routing:** Space-time A* with time-based cell and edge reservations

## Run the Flutter app

Install the Flutter SDK, then run these commands from the project root:

```sh
flutter pub get
flutter run -d chrome
```

To run the desktop app on macOS:

```sh
flutter run -d macos
```

To run on a connected device, list available devices and use its ID:

```sh
flutter devices
flutter run -d <device-id>
```

## Run the backend

Warehouse Ops needs Node.js 20 or later and a running PostgreSQL server. From
the project root, set up and start the API:

```sh
cd backend
npm install
createdb hiveflow
cp .env.example .env
npm run migrate
npm run seed
npm run dev
```

The API listens on port `3000` by default. Update `DATABASE_URL` in
`backend/.env` if your PostgreSQL connection details differ. Use `npm start`
instead of `npm run dev` to start the API without the development file watcher.
The simulator can run without the API; Warehouse Ops needs a working API and
database connection.

### Connect a phone to the local API

- A native app on the same computer uses `http://127.0.0.1:3000` by default.
  The web app uses the hostname in the browser's address bar.
- An Android emulator can use `http://10.0.2.2:3000`.
- A physical phone and the computer running the API must be on the same Wi-Fi.
  In Warehouse Ops, enter the computer's local IP, such as
  `http://192.168.1.5:3000`. On macOS, find it in **System Settings > Wi-Fi >
  Details**, or run `ipconfig getifaddr en0`.

The Android emulator address does not work on a physical phone. Warehouse Ops
also has a **Phone setup** guide and a backend address field. To set the API
address when launching the app, use:

```sh
flutter run -d <device-id> \
  --dart-define=HIVEFLOW_API_URL=http://<server-address>:3000
```

## What Warehouse Ops stores

The backend stores the sample product catalog and stock counts, robot status
and telemetry, orders and their items, robot tasks, scan events, and decision
history. The seed command adds eight sample products and eight sample robots;
existing records with the same IDs are left unchanged.

The order workflow is:

1. Create an order from products in the catalog and choose normal or rush
   priority.
2. Dispatch queued orders to available robots. The API matches robots and
   orders using travel distance, battery, and priority costs.
3. Record simulated pick and delivery scans for items in the assigned order.
   Pick scans reduce stock; completed delivery scans advance order progress.
4. Review the updated orders, robot assignments, inventory, and decision
   history in Warehouse Ops.

Scan requests have unique event IDs so retrying the same scan does not apply it
twice. The app offers simulated QR scans and typed barcode input. Camera
scanning, RFID readers, and vendor-specific robot integrations are not
connected.

## API endpoints

The full API guide, request examples, and backend-specific setup are in
[backend/README.md](./backend/README.md).

| Method | Endpoint | Purpose |
|---|---|---|
| `GET` | `/api/health` | Check API and database readiness |
| `GET` | `/api/summary` | Read order, robot, inventory, and scan counts |
| `GET`, `POST` | `/api/inventory` | List inventory or add a product |
| `GET` | `/api/robots` | List robots and their current assignments |
| `POST` | `/api/robots/:id/telemetry` | Update robot position, battery, and status |
| `GET`, `POST` | `/api/orders` | List orders or create an order |
| `GET` | `/api/orders/:id` | Read order details and item progress |
| `POST` | `/api/orders/:id/cancel` | Cancel an order before assignment |
| `POST` | `/api/dispatch` | Assign queued orders to available robots |
| `GET` | `/api/tasks` | List robot tasks |
| `POST` | `/api/scans` | Record a simulated pick or delivery scan |
| `GET` | `/api/orders/:id/history` | Read an order's scan and decision history |
| `GET` | `/api/decisions` | Read recent operational events |

## Project layout

```text
lib/
  demo/          Local sample fleet and simulation state
  screens/       Dashboard and Warehouse Ops screens
  services/      Flutter API client
  simulation/    Grid routing and assignment algorithms
  theme/         App colors and theme
  widgets/       Reusable dashboard components, including the warehouse map
backend/
  src/           Express API, validation, assignment, and database code
  test/          Backend tests
test/            Flutter tests
```

## Run tests

From the project root:

```sh
flutter analyze
flutter test
```

Run backend tests separately:

```sh
cd backend
npm test
```

## Prototype limits

- Simulator robots and warehouse activity use local sample data. Scenario
  controls do not send commands to hardware.
- Warehouse Ops uses a local API and sample database; it is not a hosted
  warehouse service.
- QR and barcode flows record simulated scans. No camera, physical scanner, or
  RFID reader is connected.
- No live robot-vendor adapters, WebSocket fleet updates, or real-world
  performance benchmarks are included.
- The backend uses HTTP and has no authentication. Keep it on a trusted private
  network and do not expose it directly to the public internet.
