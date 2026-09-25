# Sanchalan

An event-planning platform — AI-generated task roadmaps, a vendor marketplace,
guest RSVP tracking, and budget management for weddings, birthdays, corporate
events, and more. Built generically from day one: nothing about a specific
event type (e.g. "wedding") is hardcoded into the data model — everything is
`event` and `organizer`, with the specific type stored as data.

## Structure

pnpm workspace monorepo:

```
apps/
  backend/          Express + TypeScript API, Prisma schema/migrations
  mobile/            Expo (React Native) app
  admin/             Internal admin web app (Vite + React + TS) — vendor
                     review queue, email/password login for the team
packages/
  shared-types/      TypeScript interfaces shared by backend and mobile —
                     one definition of what an EventGroup, Task, etc. look
                     like, instead of drifting copies in each app
```

## Prerequisites

- Node.js + [pnpm](https://pnpm.io/)
- [Docker](https://www.docker.com/) (for local Postgres)

## Setup

```bash
# 1. Start local Postgres (identical for every dev — see docker-compose.yml)
docker compose up -d

# 2. Install dependencies across the whole workspace
pnpm install

# 3. Copy env vars and fill in real values
cp .env.example apps/backend/.env

# 4. Apply the database schema
cd apps/backend
pnpm prisma:migrate

# 5. Seed reference data (task templates, plus a one-time admin account —
#    see "Testing the admin portal" below)
pnpm exec prisma db seed
```

Then, from each app:

```bash
# Backend
cd apps/backend && pnpm prisma:generate   # regenerate the Prisma client after schema changes

# Mobile
cd apps/mobile && pnpm start              # then press i / a, or scan the QR code in Expo Go

# Admin
cd apps/admin && cp .env.example .env.local && pnpm dev   # http://localhost:5173
```

## Testing phone + OTP login

Organizers and vendors log in with just a phone number — no email/password.
To try it end to end:

```bash
# Terminal 1 — backend
cd apps/backend && pnpm dev

# Terminal 2 — mobile
cd apps/mobile && pnpm start   # then press i / a, or scan the QR code in Expo Go
```

In the app, pick a role, tap the country-code box if you need something
other than `+91`, and enter just the local number (no country code) — then
tap **Send code**.

**In dev, no real SMS is sent** (avoids burning MSG91 credits) — the 6-digit
code is printed straight to the **backend terminal** instead:

```
[dev] OTP for +919876543210 (organizer): 483920
```

Other things worth knowing while testing:

- **Android emulator**: set `EXPO_PUBLIC_API_URL=http://10.0.2.2:3000` in
  `apps/mobile/.env.local` (copy from `apps/mobile/.env.example`) —
  `localhost` inside the emulator means the emulator itself, not your
  machine. A physical device needs your machine's LAN IP instead, on the
  same network as the backend.
- OTP requests are rate-limited to **3 per phone number per 10 minutes**,
  and each code expires after **5 minutes** with a **5-attempt** limit —
  use a different phone number if you get locked out while testing.

## Testing the admin portal

The admin team (not organizers or vendors) logs in with email + password —
the one deliberate exception to phone-only auth, since admins are internal
staff, not mobile users.

```bash
# Terminal 1 — backend
cd apps/backend && pnpm dev

# Terminal 2 — admin app
cd apps/admin && pnpm dev   # http://localhost:5173
```

Running `pnpm exec prisma db seed` in `apps/backend` (see Setup step 5) seeds
one admin account with a fixed email and a **randomly generated password
printed once to the terminal** — it is never committed to git and won't be
shown again, so copy it down when you see it:

```
========================================================================
Seeded admin account — save this password now, it will not be shown again:
  email:    admin@sanchalan.internal
  password: <random>
========================================================================
```

Re-running the seed script is safe — it skips creating the admin if that
email already exists, so it won't rotate the password out from under you.

Log in at `http://localhost:5173/login` to reach the vendor review queue
(pending review / published / rejected tabs, with Approve/Reject actions on
each vendor's detail page). Approve/Reject is restricted to the `super_admin`
and `vendor_reviewer` admin roles — a `support` admin can view the queue but
not act on it.

## Database

The full data model — every table, including ones planned for later phases —
lives in [`apps/backend/prisma/schema.prisma`](apps/backend/prisma/schema.prisma).
`packages/shared-types` is a hand-maintained TypeScript mirror of that schema;
keep the two in sync when either changes.

## Environment variables

See [`.env.example`](.env.example) for every variable the project will need,
including ones not wired up yet (WhatsApp, the LLM used for roadmap
generation). Never commit a real `.env`.
