# HelpUs

HelpUs is a polished, responsive front-end concept for a privacy-first QR vehicle contact service. The brand promise is **“Your vehicle, always reachable.”**

## Run locally

This is a static website with no build step. Open `index.html` in a current browser, or serve this folder with any static web server. Google Fonts are loaded from the web; the system font stack is used if they are unavailable.

## Included screens and interactions

- Marketing site with product story, how it works, privacy, pricing, FAQ, responsive layouts, and an app feature preview.
- Owner dashboard with overview, vehicles, scan alerts, and privacy settings.
- Vehicle registration is gated behind scanning a HelpUs-formatted QR tag in the web app and native Android app.
- Demo vehicle form, preference switches, share action, and toast feedback.
- Public QR scan page with example vehicle contact actions and alert choices.
- A separate native Flutter Android app with Home, Vehicles, Alerts, and Settings tabs.
- English/Hindi toggle for the hero and primary navigation.

## Android APK

The installable Android demo is available at [`downloads/HelpUs.apk`](downloads/HelpUs.apk). The Flutter project is in `mobile_app/`. To rebuild it, install Flutter and the Android SDK, then run `flutter build apk --release` from that folder. This development build uses the default debug signing key; create a private release signing key before publishing through an app store.

## Prototype boundaries

This is a prototype. Demo content is illustrative and does not persist data. The scanner accepts HelpUs QR formats (`HELPUS:<tag-id>`, `helpus://tag/<tag-id>`, or a HelpUs `/tag/<tag-id>` link) and unlocks the registration form after a scan. This client-side format check is not proof that a tag was issued by HelpUs; production must verify each unused tag with a backend before registering the vehicle. The website scanner needs browser camera access on a supported browser over HTTPS; the APK requests Android camera access. The demo does not create accounts, verify OTPs, place orders, collect payment, send alerts, make calls/SMS, generate active QR tags, or connect to an administrator service. Masked telephony, SMS, login/OTP, payments, shipping, server-side tag verification, persistence, and account deletion require a backend and configured service providers before launch. No live tracking is implemented.

## Files

- `index.html` — page content and demo screen markup
- `styles.css` — visual theme and responsive layouts
- `platform.css` — website/app showcase section
- `app.js` — client-side navigation and prototype interactions
- `mobile_app/lib/main.dart` — Flutter Android app
- `downloads/HelpUs.apk` — installable Android demo package

## Brand note

**HelpUs** keeps “Help” at the centre of the name and suggests a simple way for people to help each other around everyday vehicles. Before commercial use, check domain and social handle availability, conduct a trademark search in target markets, and review the final name with counsel. This prototype does not claim availability or legal clearance.
