# Flutter Migration Workflow

Step-by-step plan to move the Sanchalan mobile app from Expo / React Native to Flutter, **with a full UI/UX revamp** (new login, new home screens, a proper design system). This is a redesign and rewrite, not a 1:1 port.

## 0. Scope and decisions

**Assumptions (change these first if wrong):**

| Area | Decision |
|---|---|
| `apps/mobile` (Expo 57, RN 0.86) | Rewritten in Flutter with a complete UI revamp (Phase 6). Android first (matches the current APK-only setup). |
| `apps/backend` (Express 5, Prisma, Postgres) | **Unchanged.** Flutter is just a new REST client. |
| `apps/admin` (Vite + React, 3 screens, Vercel) | Unchanged by default. Optional Phase 12 rebuilds it as Flutter web. |
| `packages/shared-types` | Not reusable from Dart. Models are ported by hand. |

**Library choices:**

| Concern | RN today | Flutter |
|---|---|---|
| Routing + guards | expo-router, `Stack.Protected` | `go_router` with `redirect` |
| State | React Context (`auth-`, `organizer-`, `vendor-context`) | `flutter_riverpod` |
| HTTP | axios (`lib/api.ts`) | `dio` + interceptor |
| Token storage | `expo-secure-store` (`lib/authStorage.ts`) | `flutter_secure_storage` |
| Models | TS interfaces | `json_serializable` (plain immutable classes; `freezed` resolved to a 4.0 dev release, so it is not used) |
| Config | `EXPO_PUBLIC_API_URL` | `--dart-define=API_URL=...` |
| Date picker | `datetimepicker` | `showDatePicker` (built in) |
| Fonts | system | `google_fonts` |
| OTP input | plain text field | `pinput` |
| Icons / illustrations | none | `flutter_svg` + Material Symbols |
| Loading states | spinners | `shimmer` skeletons |
| Builds | EAS (`eas.json`) | `flutter build` + CI |

**Non-goals:** no new backend features, no backend changes, no iOS in this migration. The revamp changes look, layout and flow, not what the product does: only design for features that exist today (guests/RSVP, bookings and payments stay out; see the roadmap's "do not build before Phase 4").

**Roadmap note:** roadmap item 1.6 says "React Native app". Update it when this is approved. Keep the Phase 1 MVP and pilot unblocked: the Expo app stays shippable until Phase 11.

---

## 1. Pre-flight

- [x] Commit or discard the uncommitted changes on `apk-build` (`README.md`, `apps/admin/app.json`, `apps/admin/vercel.json`, `spec.md`).
- [x] Remove the plaintext admin password from `README.md` and rotate it.
- [x] Note that `apps/backend/src/lib/otp.ts` returns a fixed OTP (`123456`). Flutter testing relies on it locally; fix it before any real pilot.
- [x] Tag the last RN build: `git tag rn-final`.
- [x] Branch: `git checkout -b flutter-migration`.
- [ ] Install the Flutter SDK, Android SDK and a JDK. Run `flutter doctor` until clean.
- [x] Freeze the feature list. Use `spec.md` (screens section) as the parity checklist. No new RN features during migration.
- [ ] Start the backend locally: `docker compose up -d`, then run the backend. OTPs print to the console when `NODE_ENV` is not `production`.

## 2. Scaffold the Flutter project

```bash
flutter create --org com.sanchalan --project-name sanchalan --platforms=android apps/mobile_flutter
```

- Keep `apps/mobile` until parity. Name the new app `apps/mobile_flutter` and rename at cutover.
- Set the Android `applicationId` to `com.sanchalan.app` (same as the Expo app, so Play/installs upgrade in place).
- Make pnpm ignore the folder if it has no `package.json` (it shouldn't need one).
- Add dependencies:

```bash
cd apps/mobile_flutter
flutter pub add flutter_riverpod go_router dio flutter_secure_storage freezed_annotation json_annotation intl
flutter pub add google_fonts pinput flutter_svg shimmer
flutter pub add flutter_localizations --sdk=flutter
flutter pub add --dev build_runner freezed json_serializable flutter_lints mocktail
```

- Folder layout:

```
lib/
  main.dart
  app.dart                # MaterialApp.router, theme
  core/
    config.dart           # String.fromEnvironment('API_URL')
    api_client.dart       # dio + interceptors
    auth_storage.dart
    router.dart           # go_router + guards
    theme/                # colors, typography, spacing, app_theme.dart
  models/                 # freezed models
  features/
    auth/                 # welcome, phone, otp
    organizer/            # shell (bottom nav), home, profile_setup, events, event_setup, event_home, vendors, vendor_detail
    vendor/               # dashboard, profile, under_review, suspended
  shared/
    widgets/              # design-system widgets (buttons, cards, chips, empty states, skeletons)
    modals/               # past work, edit event, regenerate roadmap, country picker
assets/
  images/
  illustrations/
```

**Exit check:** `flutter run` shows the default app on an emulator.

## 3. Core layer (do this before any screen)

Port from `apps/mobile/lib/`:

1. **`config.ts` → `core/config.dart`**: `const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:3000');` (10.0.2.2 is the emulator's host loopback; confirm the backend port.)
2. **`authStorage.ts` → `core/auth_storage.dart`**: read/write/clear access token, refresh token, role via `flutter_secure_storage`.
3. **`api.ts` → `core/api_client.dart`**, a dio instance with an interceptor that:
   - adds `Authorization: Bearer` to every request except `/auth/*`;
   - on **401** makes **one coalesced** refresh call (share a single in-flight `Future` across concurrent requests), then retries the original request;
   - clears the session only when the refresh itself is rejected. **Network errors and 5xx must not log the user out.**
4. **`types.ts` and `packages/shared-types/*` → `models/`**: port `models`, `enums`, `auth`, `vendor`, `vendor-self`, `roadmap`, `event-setup`. Use `@JsonSerializable` and run `dart run build_runner build -d`. Check each field name against `apps/backend/prisma/schema.prisma` and the API table in `spec.md`.

**Exit check:** unit tests for the refresh interceptor (concurrent 401s trigger exactly one refresh) and model JSON round-trips pass.

**Status: done (code and tests).** `lib/core/{auth_storage,api_client,providers,config}.dart`, `lib/models/*` and 39 tests are in place, `flutter analyze` is clean.
- The tests found a bug the RN `api.ts` also has: with a dead session, each concurrent request cleared the tokens and fired the expiry action separately. The Dart client now ends the session once, inside the shared refresh.
- Money fields accept numbers or numeric strings, so a Decimal serialization change on the backend can't crash the app (`startingPrice` currently arrives as a number).
- [x] Models checked against real backend responses (recorded from a throwaway Neon database, saved in `apps/mobile_flutter/test/fixtures/live/`, 55 tests green). Findings:
  - `POST /event-groups/:id/generate-roadmap` returns tasks **without** `createdAt` / `updatedAt` (shared-types says they exist), so `TaskWithDependencies` makes them optional.
  - `DELETE /event-groups/:id` returned a 500 on the remote database: it runs about 20 queries in one Prisma transaction and exceeded the default 5 s limit (network latency to Neon). Backend issue, not fixed here; consider a longer `$transaction` timeout. No fixture was recorded for it.

## 4. State management

Map each React Context to Riverpod:

| RN | Flutter |
|---|---|
| `auth-context.tsx` | `authProvider` (`AsyncNotifier`): token/role, login, logout, restore on launch |
| `organizer-context.tsx` | `organizerProvider`, `eventsProvider`, per-event providers (`family`) |
| `vendor-context.tsx` | `vendorProvider` (profile, status, past work) |

Behavior to keep: if a stored session has **no role**, force re-login (commit `78cfde3`).

**Status: done (code and tests, no UI yet).**
- `features/auth/auth_controller.dart` (`authControllerProvider`) ports the session restore, sign-in and sign-out rules, including the no-role re-login. The router in Phase 5 redirects from it. The API client signals a dead session through `sessionExpiredProvider`, so it has no dependency on the auth layer.
- `features/organizer/organizer_providers.dart` (`organizerDataProvider` with `refetch()` and a silent `reloadEvents()`, plus per-event providers) and `features/vendor/vendor_providers.dart` (`vendorDataProvider` with `refetch()` and `apply()`, plus directory providers).
- One typed repository per area (`auth_`, `organizer_`, `vendor_repository.dart`) so screens never build URLs. Event creation and roadmap generation keep the 90 s timeout the RN app used.
- Riverpod 3 retries failed providers automatically; the data providers turn that off so a failure shows an error with a Retry button, as in the RN app.
- 95 tests pass, covering every restore branch and each call's method, path, query and body.

## 5. Routing and guards

Rebuild the expo-router tree in `core/router.dart` with `go_router`. The `redirect` callback replaces `Stack.Protected`.

| Group | Routes |
|---|---|
| Auth | `/phone`, `/otp` |
| Organizer | `/profile-setup`, `/events`, `/event-setup`, `/event-home/:id`, `/vendors`, `/vendors/:id` |
| Vendor | `/vendor/profile`, `/vendor/home`, `/vendor/under-review`, `/vendor/suspended` |

Redirect rules:
- Unauthenticated → `/phone`. Authenticated users on auth routes → their role's home.
- Organizer without a profile → `/profile-setup`.
- Vendor by status: `published` → home, `pending_review` → under-review, `suspended` → suspended, `draft` / `rejected` → profile.
- Re-evaluate on auth/vendor state changes (`refreshListenable`).

## 6. UI/UX revamp (design before screens)

Goal: a friendly, modern app that a first-time family organizer or a small vendor can use without help. Do this phase **before** building screens, so Phase 7 builds from approved designs.

### 6A. Understand the app first
Write a one-page flow map (in `docs/ux-flow.md`) before any widget code.

- **Organizer goals:** plan an event, get an AI roadmap of tasks, keep the budget under control, find and shortlist vendors.
- **Vendor goals:** get listed, pass admin review, show past work, stay visible.
- **Vendor journey (status driven):** draft → pending_review → published, with rejected (fix and resubmit) and suspended branches.
- **Organizer journey:** login → profile setup → create event (sub-events, budget split) → generate roadmap → work through tasks → browse vendors.
- Users are likely non-technical and on mid-range Android phones with patchy networks. Design for that: big touch targets, plain language, fast first paint.

### 6B. Design system (`lib/core/theme/`, `lib/shared/widgets/`)
- [ ] Color tokens: a warm, celebratory palette (primary, secondary, surface, success/warning/error, status colors for task and vendor states). Light theme only.
- [ ] Typography scale with `google_fonts` (one display face for headings, one readable body face).
- [ ] Spacing, radius and elevation tokens (4/8/12/16/24 spacing; rounded cards).
- [ ] One Material 3 `ThemeData` built from the tokens (`app_theme.dart`). No hardcoded colors or sizes in screens.
- [ ] Reusable widgets: `PrimaryButton`, `SecondaryButton`, `AppCard`, `StatusChip`, `SectionHeader`, `EmptyState`, `ProgressRing`, `AppTextField`, `Skeleton`, `ErrorRetry`.
- [ ] Icon set (Material Symbols) and a small illustration set for empty states and onboarding.
- [ ] Motion rules: short (150-300 ms) transitions, hero transitions for event cards, no decorative animation that slows the app.
- [ ] A widget gallery screen (debug only) showing every component, so the system can be reviewed in one place.

### 6C. Login revamp
- [ ] **Welcome screen:** logo, one-line promise ("Plan every celebration, stress-free"), "Get started" button. Replaces the plain splash.
- [ ] **Phone screen:** one job per screen. Two large role cards ("I'm planning an event" / "I'm a vendor"), country code and number in one row, a single large CTA, inline validation (E.164) with plain-language errors.
- [ ] **OTP screen:** six boxed digits (`pinput`), auto-advance and auto-submit, SMS autofill, resend countdown, clear messages for wrong code, expired code and too many attempts (5 attempts, 3 requests per 10 minutes).
- [ ] Keyboard-safe layout; works on a 360dp-wide screen.

### 6D. Organizer home (the screen after login)
- [ ] **Bottom navigation:** Home · Events · Vendors · Profile (`StatefulShellRoute` in go_router).
- [ ] **Home tab:**
  - greeting with the organizer's name;
  - active-event hero card: event name, days-to-go countdown, overall task progress ring;
  - "Next up": the 3 most urgent roadmap tasks, tap to open the task;
  - budget snapshot: planned total with a bar per top category;
  - quick actions: add task, add budget category, browse vendors;
  - event switcher when there are multiple events;
  - empty state with a "Plan your first event" CTA when there are none.
- [ ] **Event detail** with tabs: Roadmap · Budget · Vendors. Guests/RSVP appear only as a "coming soon" card, because the backend has no API for them.
- [ ] Roadmap generate, regenerate and restore stay easy to find, with a clear "AI is building your plan" loading state.

### 6E. Vendor home (status-aware dashboard)
- [ ] **draft:** "Complete your profile" checklist with a % complete bar and a CTA to the next missing item.
- [ ] **pending_review:** friendly under-review screen with a timeline (submitted → being reviewed → live) and an "edit while you wait" option if the backend allows it.
- [ ] **published:** profile preview card as organizers see it, plus the past-work list.
- [ ] **rejected:** show the admin's reason prominently with a "Fix and resubmit" CTA.
- [ ] **suspended:** explanation and a support contact action.

### 6F. Cross-cutting UX
- [ ] Skeleton loaders instead of blank screens or bare spinners.
- [ ] Pull-to-refresh on lists.
- [ ] Inline form validation and clear, human error copy.
- [ ] Error and retry states; an offline banner (network errors never log the user out).
- [ ] Accessibility: 48dp minimum touch targets, WCAG AA contrast, works at large text scale.
- [ ] Strings in ARB files with `flutter_localizations` (English only now, ready for Hindi and other languages per the roadmap).

### 6G. Process and sign-off
1. Ask for brand inputs first: logo, brand colors, any Figma. If none, propose a palette and wireframes.
2. Wireframe every screen above (Figma, paper, or Claude-generated previews).
3. **Review the wireframes with the product owner before coding.**
4. Build the design-system widgets and the gallery screen.
5. Only then start Phase 7.

**Exit check:** signed-off wireframes for welcome, phone, OTP, organizer home, event detail, vendor dashboard, and the design-system gallery reviewed on a real device.

Time-box this phase. Design only features that exist today; park anything else in a backlog.

## 7. Screen build (from the approved designs)

Order by risk. For each screen: build the **revamped** UI from Phase 6, wire it to the Riverpod providers and the existing API, verify against the running backend, tick the checklist. The parity checklist is about **features**: every capability the RN app has must still be reachable, even though layouts change.

**7.1 Auth**
- [ ] Welcome
- [ ] Phone: role cards, country-code picker (`countryCodes.ts` → Dart list), E.164 validation
- [ ] OTP: six-box entry, resend, error states

**7.2 Organizer**
- [ ] Shell with bottom navigation
- [ ] Home tab (hero card, next up, budget snapshot, quick actions)
- [ ] Profile setup
- [ ] Events list (multiple events, cards)
- [ ] Event setup
- [ ] Event detail: budget categories add/edit/delete; roadmap generate / regenerate / restore; task modal; edit-event modal
- [ ] Vendors list with filters
- [ ] Vendor detail (read-only)

**7.3 Vendor**
- [ ] Dashboard for every status (draft, pending_review, published, rejected, suspended)
- [ ] Profile editor + past-work modal (text only)

**7.4 Shared**
- [ ] `PastWorkModal`, `EditEventModal`, `RegenerateRoadmapModal` (bottom sheets / dialogs)
- [ ] `CountryCodePicker`

## 8. Platform configuration

- [ ] App name "Sanchalan", launcher icon (`flutter_launcher_icons`) and native splash (`flutter_native_splash`) from `apps/mobile/assets`, restyled to match the new brand.
- [ ] Lock to portrait (`SystemChrome.setPreferredOrientations`).
- [ ] Light theme only.
- [ ] `AndroidManifest.xml`: `INTERNET` permission. For local HTTP testing only, allow cleartext in a debug manifest, not release.
- [ ] Optional: keep the `sanchalan://` deep link scheme.

## 9. Testing

- [ ] Unit: API interceptor, auth storage, models.
- [ ] Widget: phone and OTP validation, route guards for each role/status.
- [ ] Golden tests for the design-system widgets.
- [ ] Screenshot pass on a small (360dp) and a large phone, and at large text scale.
- [ ] Manual feature-parity pass: run every `spec.md` screen on the same backend with both an organizer and a vendor account, side by side with the RN build.
- [ ] Failure cases: airplane mode, backend 500, expired access token, revoked refresh token.
- [ ] `flutter analyze` and `flutter test` clean.

## 10. Build and release

```bash
flutter build apk --release --dart-define=API_URL=https://project-w-9foi.onrender.com
flutter build appbundle --release --dart-define=API_URL=https://project-w-9foi.onrender.com
```

- [ ] Create an upload keystore, store outside the repo, reference via `android/key.properties` (gitignored).
- [ ] Replace EAS: pick manual builds or a GitHub Actions workflow (there is no CI today).
- [ ] Update `DEPLOY_AND_APK.md` with the Flutter build steps.
- [ ] Confirm the release APK installs over the old Expo build (same package and signing key; if the signing key differs, users must uninstall first).
- [ ] CORS needs no change: the backend only allows `ADMIN_APP_ORIGIN`, and native apps send no Origin.

## 11. Cutover

- [ ] Feature-parity checklist fully ticked; pilot users smoke-tested the Flutter APK.
- [ ] `git mv apps/mobile apps/mobile_rn_archive` (or delete; it stays in the `rn-final` tag), then `git mv apps/mobile_flutter apps/mobile`.
- [ ] Update `pnpm-workspace.yaml`, root scripts, `README.md`, `spec.md`, `.env.example`, `DEPLOY_AND_APK.md`.
- [ ] Remove `eas.json` and the Expo dependencies.
- [ ] Update the roadmap (item 1.6) and project memory.
- [ ] Merge `flutter-migration` into `main`.

## 12. Optional: admin to Flutter web

Only if you want a single codebase. The admin has 3 screens (`/login`, `/vendors`, `/vendors/:id`).

- [ ] Reuse the Flutter core layer (`dio`, models). Swap `flutter_secure_storage` for its web implementation (or in-memory + refresh cookie).
- [ ] Vercel doesn't ship Flutter; build in CI (`flutter build web`) and deploy `build/web` with the SPA rewrite from the current `apps/admin/vercel.json`.
- [ ] Keep `ADMIN_APP_ORIGIN` correct on the backend.

Recommendation: skip this, since the React admin works and is small.

## 13. Risks and rollback

| Risk | Mitigation |
|---|---|
| Refresh-token race logs users out | Coalesced refresh + the interceptor unit test (Phase 3) |
| Model drift from backend | Generate from the Prisma schema / spec table; add JSON fixtures from real responses |
| Parity gaps slip through | `spec.md` screen checklist as the exit gate; the redesign must keep every feature reachable |
| Redesign scope creep delays the pilot | Design only features that exist today; time-box Phase 6; park extras in a backlog |
| Design rework after screens are built | Wireframe sign-off (6G) before Phase 7 |
| Different signing key blocks in-place upgrade | Reuse the same key, or plan an uninstall for pilot users |
| Migration stalls the MVP | Expo app stays shippable until cutover; rollback = `git checkout rn-final` |

**Definition of done:** design signed off (Phase 6), all Phase 7 boxes ticked, tests green, release APK verified on a physical device against production, docs updated, Expo app removed.
