# Cura Web

Cura Web is the public site and business dashboard for Cura, a study-focus iOS app.

Students use Cura to find study-friendly places, start focus sessions, and earn rewards from partner locations. Partner businesses use the web dashboard to see simple, privacy-safe analytics about how students use their space.

## Run Locally

```powershell
flutter pub get
flutter run -d chrome
```

## Check The Project

```powershell
flutter analyze
flutter test
```

## Privacy Policy

The public privacy policy route is `/privacy-policy`.

Update the policy text in `web/legal/privacy-policy.md`. The route renders that
editable Markdown source directly, so the website can be updated without
changing the page layout.
