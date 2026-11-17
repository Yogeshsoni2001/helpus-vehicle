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

## Turn on phone login and cloud data

The phone OTP login and shared vehicle data use Supabase Auth and Postgres. They need a HelpUs Supabase project before they can send codes or save owner data:

1. In Supabase, enable Phone under Authentication → Sign In / Providers and configure an SMS provider. Without provider credentials, real SMS codes cannot be delivered. Phone numbers are entered in international format; the form defaults to India (`+91`).
2. Run [`supabase/schema.sql`](supabase/schema.sql) once in the Supabase SQL Editor. It creates profiles, issued QR tags, owner vehicles, alerts, row-level security policies, and a one-time `register_vehicle` RPC. Vehicle registration only succeeds for an unclaimed tag present in `vehicle_tags`.
3. Put the project's URL and publishable/anon key in `supabase-config.js`. The anon key is designed for client apps; never put a `service_role` or secret key in this file.
4. Build the Android APK with `flutter build apk --release --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY` from `mobile_app/`.
5. For each physical QR tag, add its uppercase code to `public.vehicle_tags` from the Supabase SQL Editor. Its QR payload should be `HELPUS:<TAG_CODE>`.

With blank config, both apps offer a free demo OTP: they generate a code locally and show it on the screen. No SMS is sent, no phone number is verified, and the demo session is not a real account. Do not use this mode to protect personal data. After the real project URL/key and SMS provider are configured, rebuild the APK and redeploy the website. Never send SMS provider secrets in the browser or mobile app.

## Prototype boundaries

The phone auth UI and client-side data integration are implemented, with database-side owner policies and one-time tag claiming in the supplied schema. With Supabase configured, the apps send and verify real phone OTPs; without it they run the demo OTP flow above. The website QR camera requires a supported browser over HTTPS; the APK requests Android camera access. Masked calling, SMS alerts, payments, tag ordering/shipping, public scanner event intake, and account deletion still need provider/backend flows before commercial launch. No live tracking is implemented.

## Files

- `index.html` — page content and demo screen markup
- `styles.css` — visual theme and responsive layouts
- `platform.css` — website/app showcase section
- `app.js` — client-side navigation and prototype interactions
- `mobile_app/lib/main.dart` — Flutter Android app
- `downloads/HelpUs.apk` — installable Android demo package

## Brand note

**HelpUs** keeps “Help” at the centre of the name and suggests a simple way for people to help each other around everyday vehicles. Before commercial use, check domain and social handle availability, conduct a trademark search in target markets, and review the final name with counsel. This prototype does not claim availability or legal clearance.
