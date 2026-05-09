# BeU TestFlight Release Checklist

## Backend
- Confirm the hosted backend health check works:
  - `https://beu-backend-zxxo.onrender.com/health`
- Confirm the production backend URL in the iOS app is hosted, not local.

## Core User Flows on Real iPhone
- Test onboarding from a fresh install.
- Test Home, Plan, Progress, and Profile tabs.
- Test the `Describe in words` meal flow.
- Test the meal photo upload flow.
- Test the camera flow on a real iPhone.
- Test meal edit and delete.
- Test supplement and health condition save flows.

## Apple Health
- Test Apple Health authorization on a real iPhone.
- Test Apple Health sync after granting permission.
- Confirm readiness and activity data appear after sync.

## Permissions and Branding
- Confirm app display name is `BeU`.
- Confirm app icon is the BeU icon in the installed app.
- Confirm camera permission text is clear.
- Confirm photo library permission text is clear.
- Confirm Apple Health permission text is clear.

## Release Settings
- Confirm the bundle identifier matches the App ID in Apple Developer.
- Confirm signing team and provisioning are correct in Xcode.
- Confirm the app archives successfully in `Any iOS Device (arm64)`.

## Final Pre-Upload Pass
- Reinstall the app cleanly on device.
- Test one complete meal log from input to saved result.
- Test one complete daily plan refresh after a meal change.
- Archive the app in Xcode and validate before upload.
