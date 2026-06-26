# Cura-Web Handoff

Updated: 2026-06-26

Repo: `C:\Users\nanda\Documents\Cura-Web`
Remote: `https://github.com/matyasbeyene/Cura-Web`
Branch: `main`
Live site: `https://cura.coffee`

Cura-Web is the public landing site plus the business owner dashboard. Student product workflows stay in the mobile app; web is for marketing, auth, dashboard analytics, and owner offer management.

## Stack And Runbook

- Flutter Web / Dart 3.12.
- Routing: `go_router` hash routes for static hosting.
- Backend: shared Supabase project `urryrjnjwpkvqmgkzfdc`.
- Client key is the public publishable key only. Never commit service-role keys.
- Hosting: GitHub Pages from pushes to `main`; the workflow builds with `flutter build web --release --base-href "/"`.

Local validation:

```powershell
flutter analyze
flutter test
flutter build web
python tool/serve.py 8000 build/web
```

## Current Product State

- Landing page supports student/business copy, intro animation, scroll video, dashboard entry, App Store CTA sections, and `mailto:info@cura.coffee`.
- The top appbar no longer shows the App Store button, and the business-view appbar no longer shows the small mail/contact button.
- `/dashboard` requires a signed-in Supabase user who owns a `businesses` row.
- Dashboard analytics come from `business_dashboard_summary(p_business_id, p_start_date, p_end_date)`.
- The dashboard fetches current and previous date windows to show deltas.
- Owner mutations go directly to the canonical `businesses -> offers` model with RLS.

## June 26 Points Offer Migration

The dashboard now matches the mobile owner portal for points-only offer creation. The legacy study-hours and walk-in-promo options are removed from the web UI and service writes.

Owners can create/edit:

- Dollar-off or percent-off deals with a computed Cura points cost.
- Run length in hours/days/weeks.
- POS coupon code shown later to the barista in the mobile redemption flow.
- Active/paused state.

Dashboard cards now show points cost, discount, run window, POS code, redemption counts, and visibility.

Relevant files:

- `lib/pages/dashboard_page.dart`
- `lib/services/analytics_service.dart`
- `lib/widgets/dashboard_widgets.dart`
- `supabase/business_offer_management.sql`

## Backend Contract

Use the same canonical Supabase schema as mobile:

- `study_locations -> businesses -> offers`
- `student_offer_progress` for student-facing progress
- `offer_redemptions` for redemption attempts; history can repeat, only pending attempts are unique per student/offer
- `business_dashboard_summary` for owner analytics

`supabase/business_offer_management.sql` is a web-side alignment helper. It constrains offers to `offer_type = 'points'`, deletes legacy/non-points offers when applied, and keeps broad selects away from POS codes. The canonical full schema lives in the mobile repo's `supabase/rewards_schema.sql`.

Security rules:

- POS codes should not be broadly selectable from active offer rows.
- Owners receive POS codes only through owner-validated dashboard/RPC paths.
- Keep all table writes constrained by RLS ownership checks.
- Live Supabase SQL was not applied from this shell because there is no Supabase CLI, `psql`, service key, or database URL available.

## Deployment Notes

- `git push origin main` triggers GitHub Actions and production deployment.
- DNS is managed in GoDaddy and points `cura.coffee` to GitHub Pages.
- Custom domain and HTTPS are already configured.
- The `matyasbeyene.github.io/Cura-Web/` URL is not the canonical target because the build is rooted for `cura.coffee`.

## Still Open

- Confirm production Supabase redirect URLs include `https://cura.coffee` for OAuth.
- Apply the updated offer/redemption SQL to Supabase from an authenticated database environment.
- Add a real App Store URL when the mobile app has one.
- A stronger barista/POS verification path would require barista auth or POS integration; the current flow is a physical handoff MVP.
