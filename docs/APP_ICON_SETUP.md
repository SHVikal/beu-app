# App Icon Setup

The BeU iOS app now includes:

- `ios/HealthDietCoach/HealthDietCoach/Assets.xcassets/BeULogo.imageset`
- `ios/HealthDietCoach/HealthDietCoach/Assets.xcassets/AppIcon.appiconset`

These assets are already wired into the Xcode project.

## Current branding

- App name: `BeU`
- Background: `#FADADD`
- Wordmark: black `BeU`

## If you want to replace the generated logo later

1. Replace `BeULogo.png` inside:
   - `ios/HealthDietCoach/HealthDietCoach/Assets.xcassets/BeULogo.imageset`
2. Replace the PNGs inside:
   - `ios/HealthDietCoach/HealthDietCoach/Assets.xcassets/AppIcon.appiconset`
3. Keep:
   - full pink background
   - centered wordmark
   - no transparency for the 1024 icon
   - enough padding so the wordmark stays readable at small sizes

## Manual Xcode check

In Xcode:

1. Open `HealthDietCoach.xcodeproj`
2. Select the app target
3. Open `General`
4. Under `App Icons and Launch Screen` confirm:
   - App Icon = `AppIcon`
   - generated launch screen uses:
     - image = `BeULogo`
     - background color = `LaunchBackground`
