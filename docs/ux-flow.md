# Sanchalan app: user flows and screen inventory

Basis for the Flutter UI revamp (FLUTTER_MIGRATION.md, Phase 6). It describes what the app does today and who uses it. It does not add features.

## Who uses it

| Role | Who | What they want |
|---|---|---|
| Organizer | A family member or small committee planning a wedding or other celebration, often on a mid-range Android phone with patchy data | Know what to do and by when, keep the budget under control, find trustworthy vendors |
| Vendor | A small business (photographer, caterer, decorator, venue) | Get listed, pass admin review, show past work, stay visible |
| Admin | Internal team | Review vendors (separate React web app, not in this app) |

Language is plain English for now. Strings go in ARB files so Hindi and others can be added later.

## Organizer journey

1. **Welcome** then **phone number** (pick "I'm planning an event") then **OTP**.
2. **Profile setup**: name and organizer type (individual, family, company, committee). Shown once.
3. **Events**: list of the organizer's events, or an empty state with "Plan your first event".
4. **New event**: type, name, region, date, guest estimate, total budget and tier. The server builds starting budget categories with the LLM (slow, up to 90 s, needs a good waiting state).
5. **Event detail** (the main working screen):
   - **Roadmap**: tasks grouped by category with due dates and status (not started, in progress, done, overdue). Generate, regenerate (keep my work / replace all / add missing) and restore removed tasks. Add, edit, delete a task.
   - **Budget**: total versus allocated, a row per category, add, rename, change amount or tier, delete, with a warning when allocations exceed the total. Edit event details, rescale or keep the budget when the total changes, delete the event.
   - **Vendors**: shortlist entry point into the directory for this event.
6. **Vendor directory**: published vendors, filter by category and price tier, open a vendor to see description, experience, starting price, links, categories and past work (read only).

Not built (do not design): guests and RSVP, bookings, payments, reviews, documents, notifications. Show at most a "coming soon" card.

## Vendor journey (driven by status)

| Status | What the vendor sees |
|---|---|
| draft | Profile editor with a completeness checklist (business name, contact, price tier, service area, description of 30 to 1000 characters, 1 to 5 categories, at least one past-work entry, up to 10) and "Submit for review" |
| pending_review | Under-review screen, option to withdraw |
| published | Home with a preview of the public profile, an Edit button, past-work list. Editing business name, service area, price tier or description sends the profile back to review (warn before saving) |
| rejected | Profile editor with the admin's reason on top, resubmit |
| suspended | Explanation and a support contact; no actions |

## Screen inventory

| Screen | Route | Data it needs |
|---|---|---|
| Welcome | `/welcome` (new) | none |
| Phone | `/phone` | role, country, number; `POST /auth/otp/request` |
| OTP | `/otp` | phone, role; `POST /auth/otp/verify`, resend |
| Profile setup | `/profile-setup` | `POST /organizers/me/profile` |
| Organizer home | `/home` (new, Phase 7 shell) | organizer, events, active event tasks and budget |
| Events | `/events` | `GET /event-groups/me` |
| New event | `/event-setup` | `POST /event-groups` |
| Event detail | `/event-home/:id` | event with tasks and budget, task categories |
| Vendors | `/vendors` | `GET /vendors` with filters |
| Vendor detail | `/vendors/:id` | `GET /vendors/:id` |
| Vendor dashboard | `/vendor/home`, `/vendor/profile`, `/vendor/under-review`, `/vendor/suspended` | `GET /vendor/me` with completeness |

## Design principles

- One job per screen; one primary action per screen.
- Big touch targets (48 dp or more), readable at large text sizes, works at 360 dp wide.
- Skeletons while loading, plain-language errors with a Retry, an offline banner. A network error never signs the user out.
- Celebratory but calm: warm colors, generous spacing, display font only for headings.
- Every state is designed: loading, empty, error, success, and the vendor statuses.
