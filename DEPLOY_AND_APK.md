# Sanchalan: Deploy (Neon + Render) and Build the Android APK

> **Part 3 is out of date.** The Expo/EAS app was removed (it stays in git under the `rn-final` tag).
> The mobile app is now Flutter in `apps/mobile_flutter`. Build a release APK with
> `flutter build apk --release --dart-define=API_URL=https://<your-render-url>` (there is no default
> URL in release builds). Signing and CI are Phase 10 of `FLUTTER_MIGRATION.md`, and this part will be
> rewritten then. Parts 1 and 2 (Neon, Render) are unchanged.

```
APK (phone) --HTTPS--> Render (apps/backend, Express) --> Neon (Postgres)
```

Do the steps in order. Part 1 (database) and Part 2 (backend) must be finished
before Part 3 (APK), because the APK has the backend URL baked in at build time.

---

## Part 1: Database on Neon

1. Sign up at https://neon.tech and click **Create project**.
   - Name: `sanchalan`
   - Postgres version: 16
   - Region: pick the one closest to your Render region (e.g. Singapore for
     India users). Use the same region for Render in Part 2.
2. On the project dashboard click **Connect**.
   - Turn **Connection pooling OFF** to get the *direct* connection string.
   - Copy it. It looks like:
     `postgresql://USER:PASSWORD@ep-xxxx.ap-southeast-1.aws.neon.tech/neondb?sslmode=require`
   - Use the direct (non-pooled) string everywhere. Prisma migrations can hang
     on the pooled one, and this app is small enough not to need pooling.
3. Apply the migrations and seed from your own machine, once:

   ```bash
   cd apps/backend
   pnpm install                      # from repo root if not done yet

   # Windows PowerShell: $env:DATABASE_URL="..."   then run the commands below
   export DATABASE_URL="postgresql://USER:PASSWORD@ep-xxxx.../neondb?sslmode=require"

   npx prisma migrate deploy         # creates all tables (use deploy, NOT migrate dev)
   npx prisma db seed                # vendor categories + the admin account
   ```

4. **Save the admin password.** The seed prints it once:
   `email: admin@sanchalan.internal / password: <random>`. It is never shown
   again. If you lose it, delete the admin row in Neon's SQL Editor and re-run
   the seed.

---

## Part 2: Backend on Render

### 2.1 Push the code to GitHub

Render deploys from a Git repo.

```bash
git remote -v                        # check a GitHub remote exists
git push origin main
```

### 2.2 Create the web service

1. https://render.com > **New +** > **Web Service** > connect your GitHub repo.
2. Fill in:

   | Field | Value |
   |---|---|
   | Name | `sanchalan-backend` |
   | Region | Same as Neon |
   | Branch | `main` |
   | Root Directory | *(leave blank, build from the repo root because of the pnpm workspace)* |
   | Runtime | Node |
   | Instance type | Free works for testing (it sleeps after 15 min idle, and the first request takes about 50 s to wake it) |

3. **Build Command** (one line):

   ```bash
   npm i -g pnpm && pnpm install --frozen-lockfile --prod=false && pnpm --filter @sanchalan/backend prisma:generate && pnpm --filter @sanchalan/backend build
   ```

   - `--prod=false` is needed because `typescript` and `prisma` are needed at
     build time, and Render sets `NODE_ENV=production`.
   - If `npm i -g pnpm` installs a version that rejects the lockfile, use
     `corepack enable` instead of it (the repo pins pnpm 12.4.2).

4. **Start Command**:

   ```bash
   pnpm --filter @sanchalan/backend exec node dist/index.js
   ```

   Do not use `pnpm start`. It passes `--env-file=.env`, and there is no `.env`
   file on Render, so Node would exit with an error.

5. **Health Check Path**: leave it default or set `/`. (The API has no `/health`
   route. If you want one, add it to [app.ts](apps/backend/src/app.ts).)

### 2.3 Environment variables

In Render > service > **Environment**, add every variable. All are required by
[env.ts](apps/backend/src/lib/env.ts) and the server crashes at boot if one is
missing or invalid.

| Key | Value |
|---|---|
| `NODE_ENV` | `production` |
| `DATABASE_URL` | Neon direct string from Part 1 |
| `JWT_ACCESS_SECRET` | random string of 32+ characters (see below) |
| `JWT_REFRESH_SECRET` | a different random string of 32+ characters |
| `JWT_ACCESS_EXPIRES_IN` | `15m` |
| `JWT_REFRESH_EXPIRES_IN` | `30d` |
| `OTP_PROVIDER_API_KEY` | your MSG91 auth key |
| `OTP_PROVIDER_BASE_URL` | `https://api.msg91.com/api/v5/otp` |
| `OTP_EXPIRES_IN_MINUTES` | `5` |
| `OTP_MAX_REQUESTS_PER_WINDOW` | `3` |
| `OTP_REQUEST_WINDOW_MINUTES` | `10` |
| `OTP_MAX_VERIFY_ATTEMPTS` | `5` |
| `LLM_PROVIDER` | `anthropic`, `openai`, `google` or `groq` |
| `LLM_MODEL` | model name for that provider |
| `LLM_API_KEY` | your LLM provider key |
| `ADMIN_APP_ORIGIN` | URL of the admin web app (or `http://localhost:5173` for now) |

Do not set `PORT`. Render provides it.

Generate the JWT secrets (run twice, use one value for each):

```bash
node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"
```

> **OTP warning.** With `NODE_ENV=production` the backend sends real SMS via
> MSG91 (see [auth.service.ts](apps/backend/src/services/auth.service.ts)).
> With any other value it only prints the OTP in the logs. You need a working
> MSG91 account, with a sender ID and DLT template registered for India, for
> phone login to work in the APK. To test before MSG91 is ready, set
> `NODE_ENV=development` temporarily and read the OTP from the Render **Logs**
> tab. Switch it back to `production` afterwards.

### 2.4 Deploy and verify

1. Click **Create Web Service** and wait for the build to finish.
2. Your URL is `https://sanchalan-backend.onrender.com` (or similar). Test it:

   ```bash
   curl -i https://sanchalan-backend.onrender.com/
   ```

   Any HTTP response (even a 404) means the server is up. Connection errors
   or a crash loop mean you should check **Logs**.
3. Common failures:
   - `ZodError` at boot: an environment variable is missing or too short.
   - `Can't reach database server`: wrong `DATABASE_URL`, or `?sslmode=require`
     is missing.
   - `Cannot find module`: the build command did not run fully. Re-check 2.2.

Every new `git push` to `main` redeploys. When you add new Prisma migrations,
run `npx prisma migrate deploy` from your machine against the Neon URL before
(or right after) deploying.

---

## Part 3: Build the APK (EAS)

Prerequisite: Part 2 is done and you have the Render URL.

### 3.1 Set the package name

Edit [apps/mobile/app.json](apps/mobile/app.json):

```json
{
  "expo": {
    "name": "Sanchalan",
    "android": {
      "package": "com.sanchalan.app",
      "adaptiveIcon": { "...": "keep as is" }
    }
  }
}
```

The package name is permanent once you publish to the Play Store. Choose it
carefully.

### 3.2 Install EAS and log in

```bash
npm i -g eas-cli
eas login                  # free account at https://expo.dev
cd apps/mobile
eas build:configure        # choose Android; this creates eas.json
```

### 3.3 Configure `eas.json` for an APK

Replace the contents of `apps/mobile/eas.json`:

```json
{
  "cli": { "version": ">= 12.0.0" },
  "build": {
    "preview": {
      "distribution": "internal",
      "android": { "buildType": "apk" },
      "env": {
        "EXPO_PUBLIC_API_URL": "https://sanchalan-backend.onrender.com"
      }
    },
    "production": {
      "autoIncrement": true,
      "env": {
        "EXPO_PUBLIC_API_URL": "https://sanchalan-backend.onrender.com"
      }
    }
  }
}
```

- Replace the URL with your real Render URL. No trailing slash.
- `preview` produces an installable **.apk**. `production` produces an **.aab**
  for the Play Store.
- Only `EXPO_PUBLIC_*` values are embedded in the app. Never put secrets such
  as DB URLs, JWT secrets or API keys here.
- The [.env.local](apps/mobile/.env.local) file is ignored by EAS cloud builds.
  The URL in `eas.json` is what counts.

### 3.4 Build

```bash
cd apps/mobile
eas build -p android --profile preview
```

- First run: EAS asks to generate an Android keystore. Answer **Yes**. EAS
  stores it for you, and you must keep using the same one for future updates.
- The monorepo uses pnpm workspaces. EAS detects this, and
  `@sanchalan/shared-types` is resolved from the repo. If the build fails at
  the install step, check that `pnpm-lock.yaml` is committed.
- The build takes 10 to 20 minutes. When it finishes you get a link and QR
  code to the `.apk`.

### 3.5 Install on a phone

1. Open the build link on the phone (or download the APK and copy it over).
2. Allow **Install unknown apps** for your browser or file manager.
3. Install, open, and log in with a phone number.

### 3.6 Smoke test checklist

- [ ] App opens and shows the login screen.
- [ ] Request OTP works (SMS arrives, or read it in Render logs if `NODE_ENV` is not `production`).
- [ ] Log in, then create an event, add tasks and a budget.
- [ ] Close and reopen the app, and confirm the data is still there (it is coming from Neon).
- [ ] Admin login works with `admin@sanchalan.internal` and the seeded password.

---

## Part 4: Updating later

| Change | What to do |
|---|---|
| Backend code | `git push`. Render redeploys automatically. |
| DB schema | `pnpm prisma:migrate` locally to create the migration, commit it, then run `npx prisma migrate deploy` with the Neon URL. |
| Mobile code or backend URL | Rebuild: `eas build -p android --profile preview`. |
| Play Store release | `eas build -p android --profile production`, then `eas submit -p android`. |

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| App shows "Network Error" | Wrong `EXPO_PUBLIC_API_URL`, or it is `http://`/`localhost`. The URL is fixed at build time, so rebuild after changing it. |
| First request takes about 50 s, then works | Render free tier cold start. Upgrade the instance, or ping it with an uptime monitor. |
| OTP SMS never arrives | MSG91 key, sender ID or DLT template is not set up. Check Render logs. |
| Neon first query is slow | Neon free tier suspends the compute when idle. It wakes within a second or two. |
| 401 after a while | Access tokens last 15 minutes. The app must use the refresh token. Check your client's refresh logic. |



npm i -g eas-cli
eas login
cd apps/mobile
eas build -p android --profile preview
