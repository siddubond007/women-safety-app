# Branding and reusable assets

## Where things belong

- **app/branding/brand.json** is the editable brand profile: display name, short name, tagline, description, and palette.
- **app/lib/core/branding/app_brand.dart** is generated from that profile and is the single source used by Flutter UI.
- **app/assets/brand/app_logo.png** is the replaceable full logo/wordmark.
- **app/assets/brand/app_icon.png** is the replaceable standalone launcher-icon source.
- **app/assets/images/onboarding/** contains only the three full-screen onboarding backgrounds.
- **app/assets/images/illustrations/** is for future feature illustrations.
- **app/assets/icons/** is for future custom icon files. Standard buttons and feature icons can continue using Flutter Material Icons.
- **app/lib/core/assets/app_assets.dart** centralizes paths for the onboarding images.
- **app/lib/core/theme/sakhi_design_system.dart** holds shared typography, spacing, radii, and aliases to the configured brand colors.

Avoid copying raw asset paths throughout widgets; reference the central classes instead.

## Change the app name or logo at handover

1. Edit app/branding/brand.json and change appName, shortName, tagline, description, and colors as needed.
2. Put the new full logo in PNG format and the new standalone icon in PNG format. The easiest replacement is to keep the stable filenames app_logo.png and app_icon.png. A square icon PNG with transparent safe padding is best for launcher icons.
3. From the app directory, run the rebrand script. It syncs the Flutter brand class, Android launcher label, iOS display name, web manifest, and launcher icons:

   .\tool\rebrand.ps1

   You can pass new values and image paths in one command instead of editing JSON first:

   .\tool\rebrand.ps1 -AppName "New App Name" -ShortName "New" -Tagline "New tagline" -Description "New app description" -LogoPath "C:\Brand\logo.png" -IconPath "C:\Brand\icon.png"

4. Then run flutter analyze, flutter test, and flutter build apk --release. Review generated icon files in git diff before committing.

The script accepts an existing Flutter installation on PATH or the current setup's D:\Development\flutter\bin\flutter.bat. If package download is unavailable, it will stop and print the failing command.

The Android application ID and iOS bundle identifier are intentionally not renamed by this workflow. Changing those identifiers can affect signing, app store identity, deep links, and upgrades, so treat that as a separate release decision.
