# Sanchalan Admin

Internal admin web app: vendor review, category proposals, and admin team/account management.
Vite + React + TypeScript, plain CSS, no UI kit.

Admins log in with email + password (the one exception to this project's
otherwise phone+OTP-only auth — see the root [README](../../README.md)'s
"Testing the admin portal" section for how to get a seeded account and run
this alongside the backend).

```bash
cp .env.example .env.local
pnpm dev   # http://localhost:5173
```

```bash
pnpm test   # Vitest + Testing Library (auth gating, role-aware actions, confirmations)
pnpm lint
pnpm build
```

## Roles
`GET /admin/me` returns the admin and their permissions; the UI hides actions the role cannot
perform, and the API enforces the same matrix (`apps/backend/src/lib/admin-permissions.ts`).

| Role | Can |
|---|---|
| `super_admin` | everything, including managing the team |
| `vendor_reviewer` | review vendors and category proposals |
| `support` | view only |

The seeded admin has a temporary password and must change it at first sign-in.
