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
  admin/             Internal admin app (not yet scaffolded)
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
```

Then, from each app:

```bash
# Backend
cd apps/backend && pnpm prisma:generate   # regenerate the Prisma client after schema changes

# Mobile
cd apps/mobile && pnpm start              # then press i / a, or scan the QR code in Expo Go
```

## Database

The full data model — every table, including ones planned for later phases —
lives in [`apps/backend/prisma/schema.prisma`](apps/backend/prisma/schema.prisma).
`packages/shared-types` is a hand-maintained TypeScript mirror of that schema;
keep the two in sync when either changes.

## Environment variables

See [`.env.example`](.env.example) for every variable the project will need,
including ones not wired up yet (WhatsApp, the LLM used for roadmap
generation). Never commit a real `.env`.
