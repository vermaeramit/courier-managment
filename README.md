# Courier Management System — MVP

An internal courier operations system: a SQL Server database (all access via stored
procedures), a .NET 8 Web API (Dapper, no EF), a React + TypeScript admin panel, and
a Flutter rider app. Built for the courier company's own staff — there is no customer
self-booking. Customers receive a public tracking link and (stubbed) SMS/WhatsApp
notifications.

```
courier-mvp/
  database/     01_schema.sql, 02_stored_procedures.sql, 03_seed.sql
  api/          .NET 8 Web API (Controller → Service → Repository → proc)
  web-admin/    React + TypeScript (Vite)
  rider-app/    Flutter
  README.md
```

## What's implemented (the four MVP priorities)

1. **Real-time tracking** — a fixed status lifecycle, an append-only `TrackingEvents`
   audit trail, and a public unauthenticated lookup `GET /api/track/{trackingId}`
   returning current status + full history (with last-known location).
2. **COD handling** — shipments flagged COD get a `CodTransactions` row at booking;
   riders record collected cash on delivery; HQ/branch reconciliation reports show
   expected vs collected vs deposited per rider and per branch for a date range.
3. **Multi-branch** — all data is branch-scoped in the application layer (managers see
   only their branch, admin sees everything), plus an origin→destination handoff.
4. **Rider route + ops** — a rider's daily stop list, barcode/QR scanning, photo + OTP
   proof of delivery, COD entry, and an **offline queue** that syncs when connectivity
   returns. Stop navigation opens the device maps app (maps key is configurable).

Non-goals from the brief (customer self-booking, credit accounts, auto-assignment,
3PL integration, public developer API/webhooks, advanced analytics) are intentionally
not built.

## Architecture & conventions

- **Layering:** Controller (thin) → Service (orchestration + side effects) →
  Repository (pure data access, one connection per call via `ISqlConnectionFactory`) →
  stored procedure.
- **Procs own transactions.** Any multi-table write (e.g. booking writes the shipment +
  first tracking event + COD row) runs inside `BEGIN TRAN … COMMIT` with
  `SET XACT_ABORT ON`. The C# layer never coordinates partial writes.
- **Dapper maps by name.** Request-DTO property names match proc `@parameters` (minus
  the `@`); every call uses `commandType: CommandType.StoredProcedure`. No inline SQL.
- **Notifications are best-effort.** Rider push (OneSignal) is enqueued to a background
  worker; a push failure is caught and logged, never rolling back a core write. Customer
  SMS/WhatsApp is a clearly-marked **stub** (`ICustomerNotifier`) — wire a real provider
  (Twilio/Gupshup/MSG91) behind it later.
- **Money is `decimal`** in C# and `DECIMAL` in SQL. **Timestamps are UTC**
  (`SYSUTCDATETIME()`).
- **Branch scoping** is enforced in services: non-admin calls pass the caller's
  `BranchId`; admin passes `null` (no filter).
- **No hardcoded secrets.** Connection string, JWT key, OneSignal keys, and maps key all
  come from configuration / environment / `--dart-define`.
- **TrackingId** = `<OriginBranchCode><8-digit zero-padded sequence>` (e.g. `ROH00000042`),
  generated in `usp_Shipment_Create` from a SQL `SEQUENCE`.
- **Status lifecycle:** `Booked → PickedUp → AtOriginHub → InTransit → AtDestinationHub
  → OutForDelivery → Delivered`, plus terminal `Failed` and `RTO`.

## Prerequisites

- SQL Server 2019+ (or SQL Server Express / Azure SQL / the `mssql` Docker image)
- .NET 8 SDK
- Node 18+ (for the web admin)
- Flutter (latest stable) + Android Studio / Xcode (for the rider app)

---

## 1) Database

Run the three scripts **in order** against your SQL Server. They are idempotent where
practical (`01` recreates objects, `02` uses `CREATE OR ALTER`, `03` guards inserts).

```bash
# Using sqlcmd (adjust -S server and auth):
sqlcmd -S localhost -i database/01_schema.sql
sqlcmd -S localhost -i database/02_stored_procedures.sql
sqlcmd -S localhost -i database/03_seed.sql
```

`01_schema.sql` creates the `CourierMvp` database if it doesn't exist. You can also run
each file in Azure Data Studio / SSMS.

### Seeded accounts & passwords

All seed users share the password **`Passw0rd!`**:

| Email                     | Role          | Branch |
| ------------------------- | ------------- | ------ |
| admin@courier.test        | Admin         | HQ     |
| manager.roh@courier.test  | BranchManager | ROH    |
| rider.roh@courier.test    | Rider         | ROH    |
| manager.blr@courier.test  | BranchManager | BLR    |

The seeded `PasswordHash` is a real ASP.NET Core Identity (PBKDF2 / V3) hash of
`Passw0rd!`. It is self-describing, so it verifies regardless of the API's hasher
settings. To mint a new hash for a different password, run the API in Development and
call `GET /api/auth/dev-hash?password=YourPass` (this endpoint is disabled outside
Development).

Seed serviceable destination pincodes: `110085, 110086, 110042` (ROH) and
`560034, 560095, 560068` (BLR). Booking validates the **receiver** pincode against these.

---

## 2) Backend API (.NET 8)

```bash
cd api
dotnet restore
dotnet run --project CourierMvp.Api
```

Runs at `http://localhost:5080` with Swagger at `http://localhost:5080/swagger`.

### Configuration (never hardcode secrets)

Set via environment variables or user-secrets — examples (bash):

```bash
export ConnectionStrings__CourierDb="Server=localhost;Database=CourierMvp;Trusted_Connection=True;TrustServerCertificate=True;"
export Jwt__SigningKey="a-long-random-key-at-least-32-characters"
export OneSignal__AppId="your-onesignal-app-id"
export OneSignal__ApiKey="your-onesignal-rest-api-key"
export Maps__ApiKey="your-maps-key"   # informational; the rider app consumes the maps key
```

`appsettings.json` holds **dev-only placeholders** and CORS origins. If OneSignal keys
are blank, push is skipped (logged) and everything else still works.

### Key endpoints

| Area      | Endpoint |
| --------- | -------- |
| Auth      | `POST /api/auth/login` |
| Branches  | `GET/POST/PUT /api/branches`, `GET /api/branches/serviceability/{pincode}` |
| Booking   | `POST /api/shipments` (TrackingId + invoice + barcode + first event + COD row) |
| Shipments | `GET /api/shipments?status=&from=&to=`, `GET /api/shipments/{id}` |
| Status    | `POST /api/shipments/{id}/status` (+ appends a tracking event) |
| Handoff   | `POST /api/shipments/{id}/handoff` |
| Assign    | `POST /api/shipments/{id}/assign-rider` (manual) |
| Public    | `GET /api/track/{trackingId}` (no auth) |
| Rider     | `GET /api/rider/stops`, `POST /api/shipments/{id}/pod`, `POST /api/shipments/{id}/issue-otp` |
| COD       | `POST /api/cod/record`, `POST /api/cod/{shipmentId}/deposit`, `GET /api/cod/reconciliation/by-rider`, `…/by-branch` |
| Dashboard | `GET /api/dashboard` |

---

## 3) Web admin (React + TypeScript)

```bash
cd web-admin
cp .env.example .env        # set VITE_API_BASE_URL if not http://localhost:5080
npm install
npm run dev                 # http://localhost:5173
```

Screens: login (role-aware nav), shipment booking (pincode serviceability check +
printable label/invoice), shipment list with filters, shipment detail with the full
tracking timeline + status updates, rider assignment, COD reconciliation (per rider /
per branch, date range), and a dashboard with daily counts. The API client attaches the
JWT to every request.

The dev server origin (`http://localhost:5173`) is in the API's CORS allowlist
(`Cors:AllowedOrigins`).

---

## 4) Rider app (Flutter)

The repo ships only `lib/` + `pubspec.yaml`. Generate the native projects, then run.
See `rider-app/PLATFORM_SETUP.md` for the camera/location permission snippets.

```bash
cd rider-app
flutter create .            # generates android/, ios/ without touching lib/
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:5080 \
  --dart-define=ONESIGNAL_APP_ID=<your-onesignal-app-id> \
  --dart-define=MAPS_API_KEY=<your-maps-key>
```

(`10.0.2.2` is the Android emulator's alias for the host's `localhost`; use your LAN IP
on a physical device.)

Features: login (stores JWT, registers the rider with OneSignal using `Users.Id` as the
external user id), daily stop list, barcode/QR scan to open a shipment, navigate (opens
the maps app), status updates, photo + OTP proof of delivery, COD entry, and an
**offline queue** (`SyncQueue`) that persists status/POD/COD writes locally and flushes
them when connectivity returns. Tapping a push notification deep-links to the shipment.

---

## End-to-end happy path

1. Log in to the web admin as `manager.roh@courier.test`.
2. Book a shipment to a serviceable pincode (e.g. `560034`), COD ₹500 → note the
   TrackingId (e.g. `ROH00000001`).
3. Open `GET /api/track/ROH00000001` (or the detail page) → status `Booked` + event.
4. Rider assignment screen → assign `rider.roh@courier.test` (a push fires if OneSignal
   is configured).
5. In the rider app: log in, see the stop, set `OutForDelivery` (toggle airplane mode to
   test offline → action queues → re-enable → it syncs), then complete delivery with a
   photo/OTP and COD `500`.
6. COD reconciliation (per rider / per branch) shows expected `500` vs collected `500`.
7. A manager from BLR sees none of ROH's data; admin sees all (branch scoping).

## Assumptions & conventional choices (documented per the brief)

- **Auth:** JWT bearer; passwords hashed with ASP.NET Core Identity's `PasswordHasher`
  (PBKDF2). The hasher ignores the `user` argument by design, so login keys purely on the
  stored hash.
- **POD storage:** the rider app sends the **local photo path** as `photoUrl` for the MVP.
  A production build would upload the image to blob storage first and send the resulting
  URL; the API/DB already store a `PhotoUrl` string.
- **OTP:** `POST /api/shipments/{id}/issue-otp` generates a 6-digit OTP, stores it, and
  (stub) "sends" it to the receiver. For dev convenience the endpoint echoes the OTP in
  its response; in production it would not.
- **Route optimisation:** stops are returned ordered by pincode as a sensible default.
  The exact stop sequence can be optimised by calling a maps Directions API with the
  configured `MAPS_API_KEY`; the navigation button already launches the maps app.
- **Handoff / current location of parcel:** tracked via `Shipments.CurrentBranchId`,
  updated by `usp_Shipment_Handoff`.
- **Notifications:** rider push via OneSignal on status change/assignment, queued to a
  background worker. Customer SMS/WhatsApp is a logging stub (`ICustomerNotifier`).
- **Rider assignment is manual** (no auto-assignment), per the non-goals.
- **Money** uses `decimal`/`DECIMAL` throughout; **all timestamps are UTC**.
- **`pubspec.lock` and generated Flutter platform folders** are gitignored; run
  `flutter create .` to regenerate them.

## Notes on building without the SDKs installed

This code was authored as a complete, conventional MVP. If you don't have the .NET SDK,
Node, or Flutter locally yet, install the prerequisites above, then follow each section.
Restoring NuGet/npm/pub packages requires network access on first run.
