# Cura-Web Handoff

Updated: 2026-06-16

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

- Landing page supports student/business copy, intro animation, scroll video, dashboard entry, App Store CTA, and `mailto:info@cura.coffee`.
- `/dashboard` requires a signed-in Supabase user who owns a `businesses` row.
- Dashboard analytics come from `business_dashboard_summary(p_business_id, p_start_date, p_end_date)`.
- The dashboard fetches current and previous date windows to show deltas.
- Owner mutations go directly to the canonical `businesses -> offers` model with RLS.

## June 16 Offer Work

The dashboard now matches the mobile owner portal for offer creation.

Owners can create/edit:

- Study rewards: require study minutes at the business location.
- Walk-in promos: no study required, redeemable in person.
- Run length in hours/days/weeks.
- POS coupon code shown later to the barista in the mobile redemption flow.
- Active/paused state.

Dashboard cards now show offer type, run window, POS code, redemption counts, and study progress where relevant.

Relevant files:

- `lib/pages/dashboard_page.dart`
- `lib/services/analytics_service.dart`
- `lib/widgets/dashboard_widgets.dart`
- `supabase/business_offer_management.sql`

## Backend Contract

Use the same canonical Supabase schema as mobile:

- `study_locations -> businesses -> offers`
- `student_offer_progress` for student-facing progress
- `offer_redemptions` for one-use redemption attempts
- `business_dashboard_summary` for owner analytics

`supabase/business_offer_management.sql` is a web-side alignment helper. The canonical full schema lives in the mobile repo's `supabase/rewards_schema.sql`.

Security rules:

- POS codes should not be broadly selectable from active offer rows.
- Owners receive POS codes only through owner-validated dashboard/RPC paths.
- Keep all table writes constrained by RLS ownership checks.
- Do not apply live Supabase SQL without explicit approval.

## Deployment Notes

- `git push origin main` triggers GitHub Actions and production deployment.
- DNS is managed in GoDaddy and points `cura.coffee` to GitHub Pages.
- Custom domain and HTTPS are already configured.
- The `matyasbeyene.github.io/Cura-Web/` URL is not the canonical target because the build is rooted for `cura.coffee`.

## Still Open

- Confirm production Supabase redirect URLs include `https://cura.coffee` for OAuth.
- Apply the updated offer/redemption SQL to Supabase when ready.
- Add a real App Store URL when the mobile app has one.
- A stronger barista/POS verification path would require barista auth or POS integration; the current flow is a physical handoff MVP.
