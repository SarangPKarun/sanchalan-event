# Sanchalan Admin

Internal admin web app — vendor review queue and (currently) nothing else.
Vite + React + TypeScript, plain CSS, no UI kit.

Admins log in with email + password (the one exception to this project's
otherwise phone+OTP-only auth — see the root [README](../../README.md)'s
"Testing the admin portal" section for how to get a seeded account and run
this alongside the backend).

```bash
cp .env.example .env.local
pnpm dev   # http://localhost:5173
```
