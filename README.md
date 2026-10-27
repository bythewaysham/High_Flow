# HiveFlow

**The self-healing brain for warehouse robot fleets.**

HiveFlow is a Flutter dashboard prototype for the Aurix Hackathon 2026 (Track 3: Smart Logistics & Warehouse Automation), presented by Team Code Breakers, IILM University.

## Run the prototype

The Flutter dashboard includes both its local simulator and a **Warehouse Ops**
screen connected to the Node.js/PostgreSQL backend. Follow
[backend/README.md](./backend/README.md) to start the backend, then open
Warehouse Ops to see stored orders, inventory, robots, and backend decisions.
The simulator tabs remain a separate sample-data demo.

```sh
flutter pub get
flutter run -d chrome
```

Start the backend in a second terminal first:

```sh
cd backend
npm run dev
```

The backend listens on port 3000 for laptop/web and phone access. On the Flutter
web dashboard, Warehouse Ops derives the backend host from the browser address.
For a physical phone, connect it to the same Wi-Fi as the laptop, run
`ipconfig getifaddr en0` on the Mac, then enter
`http://<Mac-Wi-Fi-IP>:3000` in Warehouse Ops and tap Connect. The
`http://10.0.2.2:3000` address is for an Android emulator only. Warehouse Ops
includes a Phone setup button with these steps. To prefill the phone app with
the current laptop IP when launching it, use
`flutter run -d <device-id> --dart-define=HIVEFLOW_API_URL=http://<Mac-Wi-Fi-IP>:3000`.

Run a native laptop build with:

```sh
flutter run -d macos
```

For a phone-sized web preview, open the Chrome window in responsive/device mode. To install/run as a native phone app, use a connected Android or iOS device:

```sh
flutter devices
flutter run -d <device-id>
```

## What is included

- Responsive operator dashboard for laptop and phone-sized screens.
- Supplied HiveFlow logo in the dashboard, browser/PWA icons, and native app icons.
- A deterministic eight-robot sample simulation that advances routes on a timer.
- A 2D warehouse map, robot roster, fleet health, run counters, and route-conflict counter.
- Hungarian task-to-robot assignment using distance, battery, and rush-priority costs.
- Space-time A* with vertex reservations, edge-swap checks, wait actions, and a bounded horizon.
- Baseline-versus-HiveFlow route comparison using the same sample robots, tasks, and layout.
- Interactive aisle-block, robot-failure/task-reassignment, rush-order, pause, and reset controls.
- A decision log with structured, rule-based explanations for assignments, routes, and scenario events.
- Backend-connected Warehouse Ops screen for persisted orders, inventory, robot assignments, and scan/decision history.
- Order creation, Hungarian dispatch, and simulated QR pick/delivery scans that update PostgreSQL inventory and order state.
- Scanner choices for simulated QR, typed/keyboard-wedge barcode input, and clearly marked planned camera/RFID integrations.

## Prototype status

The assignment, routing, simulation, and local recovery logic run inside this Flutter app against seeded sample data. Scenario controls affect only the simulator; they do not control physical robots. Warehouse Ops uses the Node.js API and PostgreSQL for persistent sample orders, inventory, robot tasks, and simulated scanner events.

WebSocket updates, robot-vendor adapters, camera/physical scanner integration, live robot controls, CSV import, and AI-generated explanations are not connected. The QR flow records simulated scan events using the catalog's scan codes. The sample layout and orders are illustrative. No live-warehouse benchmark, cycle-time or throughput improvement, or zero-deadlock guarantee is claimed by this prototype.

Node.js and PostgreSQL are required for Warehouse Ops. The local simulator can still be used independently when the backend is offline.

## Verify

```sh
flutter analyze
flutter test
```
