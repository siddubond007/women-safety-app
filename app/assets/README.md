# App assets

Reusable asset folders:

- brand/: app_logo.png is the full brand lockup used inside the UI; app_icon.png is the standalone app icon source.
- images/onboarding/: full-screen onboarding background artwork.
- images/illustrations/: future illustrations used by feature screens.
- icons/: custom standalone icon assets. Prefer Flutter's built-in Icons for standard UI symbols unless a custom brand icon is needed.

Use app/lib/core/assets/app_assets.dart for image paths and app/lib/core/branding/app_brand.dart for brand paths. Add new asset folders to app/pubspec.yaml when they are introduced.
