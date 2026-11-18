# curbside-ios
Curbside iOS app: SwiftUI + MapKit neighbor memory map

## Develop

```bash
brew install xcodegen
xcodegen generate     # after adding, moving or removing files; commit the result
open Curbside.xcodeproj
```

iOS 26.0+, iPhone only, Swift 6 strict concurrency. Tests use Swift Testing.

## Release

Actions → TestFlight → Run workflow. Needs the App Store Connect record for `com.Xomware.Curbside` and the `ASC_*` / `APPLE_TEAM_ID` secrets in Infisical (`code`, prod, `/shared` or `/curbside`). Privacy label and review notes: xom-research `docs/features/curbside/ios-settings-release/RELEASE.md`.
