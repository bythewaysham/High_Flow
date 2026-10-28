# HiveFlow

### Warehouse fleet coordination dashboard

HiveFlow is a Flutter prototype for monitoring and coordinating warehouse robot
fleets. It combines an interactive fleet simulator with a **Warehouse Ops**
screen backed by a Node.js and PostgreSQL API.

## What you can do

- View robot positions, routes, battery levels, fleet health, and task status on
  an interactive warehouse map.
- Assign tasks using distance, battery, and order priority.
- Plan routes with space-time A* and cell reservations to avoid route conflicts.
- Try simulator scenarios such as blocked aisles, robot failures, and rush
  orders, then pause or reset the simulation.
- Create and dispatch warehouse orders, review inventory and robot status, and
  record simulated pick and delivery scans in Warehouse Ops.

The simulator runs on sample data. Warehouse Ops uses the local API for stored
orders and inventory. The prototype does not connect to physical robots or
scanner hardware.

## Run the app

Install Flutter, then run the dashboard in a browser:

```sh
flutter pub get
flutter run -d chrome
```

To run it as a desktop app on macOS:

```sh
flutter run -d macos
```

To run on a connected phone or another supported device:

```sh
flutter devices
flutter run -d <device-id>
```

## Start the backend

Warehouse Ops requires Node.js 20+ and PostgreSQL. From the project root, follow
the setup steps in [backend/README.md](./backend/README.md), then start the
Flutter app. The simulator can be used without the backend.

For a physical phone, connect it and the computer running the API to the same
Wi-Fi network, then enter the computer's local address in **Warehouse Ops**.
Android emulators can use `http://10.0.2.2:3000`.

## Run checks

```sh
flutter analyze
flutter test
```
