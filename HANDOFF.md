# Cura-Web — Engineering Handoff

_Last updated: 2026-06-12_

This document describes the **Cura-Web** project end to end: what it is, how it's
built, where it lives, how it deploys, how it connects to the backend and the
domain, how to run it locally, and what's left to do. It is intentionally a map +
operations guide — not a line-by-line walkthrough of the source.

---

## 1. What this is

Cura-Web is the **marketing website + business portal** for **Cura**, a study-focus
iOS app. It is a single **Flutter Web** app with two halves:

- **Landing page** — a marketing page with a scroll-scrubbed hero video, an
  intro animation, fade-in quotes, and "Sign in" / "Download on the App Store" CTAs.
- **Business dashboard** — an analytics portal where **partner businesses** (e.g.
  cafés/libraries that host Cura study sessions) see how students use their location.

**Web is business-only by design.** The student/customer experience stays in the
mobile app; the web app exists for marketing + the business analytics portal.

It is a **separate codebase** from the Cura mobile app but talks to the **same
Supabase backend**.

---

## 2. The moving parts (how everything relates)

```
                        BUILD / SHIP                              RUN (a visitor)
  ┌──────────────┐   git push    ┌─────────────────┐        ┌─────────────────────┐
  │ Dev machine  │ ───main────▶  │ GitHub repo     │        │  Visitor's browser  │
  │ (Flutter)    │               │ matyasbeyene/   │        └──────────┬──────────┘
  └──────────────┘               │ Cura-Web        │           1. asks for cura.coffee
                                 └───────┬─────────┘                   │
                                  GitHub │ Actions                     ▼
                                  build  │ (flutter build web)   ┌───────────────┐
                                         ▼                       │ GoDaddy DNS   │
                                 ┌─────────────────┐  A records  │ cura.coffee   │
                                 │ GitHub Pages    │ ◀───────────│ → Pages IPs   │
                                 │ (static host +  │             └───────────────┘
                                 │  CDN + HTTPS)   │                     │
                                 └───────┬─────────┘   2. serves static Flutter app
                                         │                             │
                                         └──────────── serves app ─────┘
                                                                       │
                                              3. app (in browser) calls backend directly
                                                                       ▼
                                                             ┌─────────────────────┐
                                                             │ Supabase (cura-dev) │
                                                             │ Auth + Postgres/RPC │
                                                             │ (shared w/ mobile)  │
                                                             └─────────────────────┘
```

- **GoDaddy** = domain registrar + DNS. It only points the name `cura.coffee` at
  GitHub Pages. It does not host anything.
- **GitHub** = source of truth + build system (Actions) + host (Pages).
- **GitHub Pages** = the actual web server: serves the compiled static files over a
  CDN with auto HTTPS.
- **Supabase** = the backend (auth + database). The browser talks to it **directly** —
  there is **no custom server** of our own. The app is a static frontend + a
  Backend-as-a-Service.

---

## 3. Repository & local layout

- **Repo:** https://github.com/matyasbeyene/Cura-Web (**public** — safe, see §9)
- **Branch:** `main` (deploys from here)
- **Local path:** `C:\Users\matik\Downloads\coffee_landing`
- **Related repo (mobile app, separate):** `github.com/nandanpraveen/curamvpcode`
  (local `C:\Users\matik\Downloads\curamvpcode`). Its `HANDOFF.md` is the
  authoritative product/backend brief.

Key files (the map — see the files themselves for detail):

| Path | Role |
|------|------|
| `lib/main.dart` | App entry; `Supabase.initialize`; `go_router` routes |
| `lib/config/supabase_config.dart` | Supabase URL + **public** publishable key |
| `lib/pages/landing_page.dart` | Landing page (hero video, intro, quotes, nav) |
| `lib/pages/sign_in_page.dart` | Email/password + Google sign-in |
| `lib/pages/dashboard_page.dart` | Business dashboard (data load, states, layout) |
| `lib/services/analytics_service.dart` | Data layer — models + the dashboard RPC call |
| `lib/widgets/top_nav.dart` | Top nav, sign-in button, App Store badge, logo |
| `lib/widgets/dashboard_widgets.dart` | KPI cards, charts, heatmap, breakdowns |
| `lib/scroll_video/scroll_video_scrubber.dart` | Scroll-driven DOM `<video>` hero |
| `lib/theme/app_theme.dart` | Brand colors + fonts |
| `web/index.html` | Page shell; body background = the video's border |
| `web/media/scene.mp4` · `poster.jpg` · `scene.json` | Hero video, poster, runtime config |
| `tool/serve.py` | Local static server (SPA fallback, no-cache) |
| `tool/prep_video.ps1` · `swap-video.bat` | Re-encode + swap the hero video |
| `.github/workflows/deploy.yml` | CI: build Flutter web + deploy to Pages |

---

## 4. Tech stack

- **Flutter 3.44.0 / Dart 3.12**, Web (CanvasKit renderer).
- Packages: `go_router` (routing), `supabase_flutter` (auth + data),
  `fl_chart` (charts), `google_fonts` (Fraunces + Inter), `http` (video blob fetch),
  `web` (DOM interop for the hero video).
- **Routing is hash-based:** real URLs are `/#/`, `/#/sign-in`, `/#/dashboard`.
  This is what makes deep links work on a plain static host (no server rewrites needed).
- **Brand tokens** (`lib/theme/app_theme.dart`): espresso `#3B2A20`, mocha `#4A3528`,
  latte `#E8DCC8`, cream `#FAF6EF`, warmBlack `#1A1410`, forest `#3A5A40`,
  forestDark `#2F4A37`, border `#D2D2D2`. Fonts: **Fraunces** (display) + **Inter** (body).
  This light palette is intentionally different from the dark mobile app.

---

## 5. Domain & DNS (GoDaddy → GitHub Pages)

- **Live site:** **https://cura.coffee** (apex domain, served at root).
- Domain registered + DNS managed at **GoDaddy**.
- DNS records (GoDaddy → cura.coffee → Manage DNS):

  | Type | Name | Value |
  |------|------|-------|
  | A | @ | 185.199.108.153 |
  | A | @ | 185.199.109.153 |
  | A | @ | 185.199.110.153 |
  | A | @ | 185.199.111.153 |
  | CNAME | www | matyasbeyene.github.io |

  GoDaddy's default parked `@` A-record and any domain Forwarding must be removed or
  they conflict.
- **Custom domain** is set in GitHub repo **Settings → Pages → Custom domain =
  `cura.coffee`**, and the CI also writes a `CNAME` file into the build so it sticks
  across deploys.
- **HTTPS** is auto-issued by GitHub (Let's Encrypt) once DNS resolves. Turn on
  **Settings → Pages → Enforce HTTPS** after the cert is provisioned.

> Note: the `matyasbeyene.github.io/Cura-Web/` URL will look broken (assets 404)
> because the build is rooted (`--base-href "/"`) for the apex domain. Judge the site
> only by **cura.coffee**.

---

## 6. Hosting & deployment (GitHub Pages + Actions)

- **Host:** GitHub Pages (static + CDN + HTTPS). No server to run or pay for.
- **Pipeline:** `.github/workflows/deploy.yml`. On every **push to `main`** (or manual
  "Run workflow"):
  1. Check out the repo.
  2. Install Flutter (stable channel, cached).
  3. `flutter pub get`.
  4. `flutter build web --release --base-href "/"`.
  5. Write `build/web/CNAME` = `cura.coffee` and copy `index.html` → `404.html`
     (SPA fallback).
  6. Upload the artifact and deploy to GitHub Pages.
- **Shipping a change = `git push origin main`.** The site rebuilds and redeploys
  automatically (≈2–4 min).
- **First-time enablement (one-time, in the GitHub UI since `gh` CLI is not installed):**
  Settings → Pages → **Source: GitHub Actions**, set the custom domain, then push.
- **Operational caution:** a direct push to `main` arms a production auto-deploy, so
  the Claude Code auto-mode safety classifier blocks it until the user explicitly
  approves each push. Approve the push prompt (or run `git push origin main` yourself).
- **Watching a run without `gh`:** the repo is public, so the Actions API works
  unauthenticated, e.g.
  `GET https://api.github.com/repos/matyasbeyene/Cura-Web/actions/runs?per_page=1`
  → read `.workflow_runs[0].status` / `.conclusion`.

---

## 7. Backend (Supabase)

- **Project:** `cura-dev` — ref `urryrjnjwpkvqmgkzfdc`,
  URL `https://urryrjnjwpkvqmgkzfdc.supabase.co`.
- **Client key:** the **public publishable key**
  `sb_publishable_mKpJWmhRXjClxarqdUfxWw_uIBzABHq` (safe to ship in the browser).
  **Never** put the service-role key in client code or the repo.
- **Same backend as the mobile app** — one Supabase project serves both.

### Data model (all RLS-protected)
`profiles`, `focus_sessions`, `focus_session_events`, `study_locations`,
`businesses`, `offers`.

- A **business** = a `businesses` row whose `owner_id` is its login user.
- It links to a `study_locations` row via `study_location_id`.
- Its **visits** = `focus_sessions` where `location_id` = that `study_location_id`.

### Analytics RPC (the heart of the dashboard)
The dashboard does **not** query tables directly. It calls one SECURITY DEFINER
Postgres function:

```
business_dashboard_summary(p_business_id uuid, p_start_date date, p_end_date date)
```

- Requires an **authenticated** caller (raises "Authentication required" otherwise).
- Returns **privacy-safe** JSON with **k-anonymity** (groups smaller than 3 students
  are hidden): keys `totals, trend, gender, level, year, major, hourly,
  duration_buckets, deals, insights, privacy_threshold, generated_at`.
- The dashboard requests two periods (current + previous) to compute ↑/↓ deltas.

### Auth
- **One Supabase auth** for students and businesses.
- **Email/password:** works on web now.
- **Google OAuth:** the provider + Web client are configured Supabase-side. For the
  live site, **`https://cura.coffee` (and `https://cura.coffee/**`) must be in
  Supabase → Authentication → URL Configuration → Redirect URLs** (and add
  `http://localhost:8000` for local dev). The web sign-in redirects back to the page
  origin.
- **Dashboard access gating:** `/dashboard` requires (a) a signed-in user and
  (b) that the user owns a `businesses` row. Otherwise it shows a "sign in" or
  "partner businesses only" state.

---

## 8. Local development

From `C:\Users\matik\Downloads\coffee_landing`:

```powershell
flutter pub get
flutter analyze                 # must be clean before building
flutter build web               # output in build/web
python tool/serve.py 8000 build/web    # serve at http://localhost:8000
```

Gotchas (learned the hard way — keep in mind):

- **Use `tool/serve.py`** for a stable static server (SPA fallback, no-cache).
  `flutter run -d chrome` quits the moment its Chrome window closes.
- **`?nointro=1`** on the URL skips the intro animation while testing.
- The **hero video** is a real DOM `<video>` placed *behind a transparent Flutter
  view* and loaded via a **blob** (`http.get` → object URL) — not a Flutter platform
  view. The page `body` background (in `web/index.html`) is the video's border.
- A **backgrounded browser tab throttles** both `<video>` decode and Flutter
  animation, so the intro/video may appear frozen in automation; verify in a real
  foreground browser.
- After changes: `flutter analyze` clean → `flutter build web` → hard-refresh
  (Ctrl+F5).

### Swapping the hero video
The clip is `web/media/scene.mp4` with runtime config in `web/media/scene.json`
(not hardcoded). Re-encode/swap with `tool/prep_video.ps1` or drag-drop onto
`swap-video.bat`, then rebuild + push.

---

## 9. Secrets & security

- Only **public** keys live in the client/repo: the Supabase **publishable** key.
  That's why the repo can safely be **public**.
- **Never commit** the Supabase **service-role** key or any private token.
- **Do not change the live Supabase schema** without explicit approval.

---

## 10. Known gaps / TODO

- **Bear logo image:** `top_nav` loads `web/media/logo.png` with a "Cura" text
  fallback, and that PNG isn't in the repo yet — so the wordmark currently renders as
  text. Drop the cropped bear PNG at `web/media/logo.png` to show the logo.
- **Post-login redirect:** signing in doesn't yet bounce a business owner straight to
  `/dashboard`; they sign in, then navigate to Dashboard. Nice-to-have.
- **Supabase prod redirect URL:** confirm `https://cura.coffee` is added to
  Authentication → Redirect URLs so Google sign-in works in production.
- **Enforce HTTPS:** flip the toggle in Settings → Pages once the cert is issued.
- **More pages:** the original plan mentioned ~4 pages; only landing + sign-in +
  dashboard exist. Customer/student web is intentionally out of scope.

---

## 11. Quick reference

| Thing | Value |
|------|------|
| Live URL | https://cura.coffee |
| Repo | https://github.com/matyasbeyene/Cura-Web (public, branch `main`) |
| Local | `C:\Users\matik\Downloads\coffee_landing` |
| Host | GitHub Pages (static + CDN + auto HTTPS) |
| Deploy | `git push origin main` → Actions builds + deploys (needs push approval) |
| DNS | GoDaddy → apex A-records to `185.199.108–111.153`; `www` CNAME → `matyasbeyene.github.io` |
| Backend | Supabase `cura-dev` (`urryrjnjwpkvqmgkzfdc`) — shared with mobile |
| Dashboard data | `business_dashboard_summary(p_business_id, p_start_date, p_end_date)` RPC |
| Client key | publishable key only (public-safe); never service-role |
| Stack | Flutter 3.44 / Dart 3.12 · go_router · supabase_flutter · fl_chart |
| Routing | hash URLs: `/#/`, `/#/sign-in`, `/#/dashboard` |
| Run locally | `python tool/serve.py 8000 build/web` |
| Mobile app repo | `github.com/nandanpraveen/curamvpcode` (separate; see its `HANDOFF.md`) |
