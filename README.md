# Decibel Meter

A macOS decibel meter that floats above other apps and warns you when your
environment may be too noisy for safety.

## Release

The release script archives the app, exports a Developer ID build, notarizes it,
staples the notary ticket, zips the app, and uploads the zip to the matching
GitHub release.

One-time setup:

```sh
xcrun notarytool store-credentials "notarytool-password" \
    --apple-id "YOUR_APPLE_ID" \
    --team-id "YOUR_TEAM_ID" \
    --password "APP_SPECIFIC_PASSWORD"
```

Install and authenticate the GitHub CLI:

```sh
brew install gh
gh auth login
```

Release the next patch version:

```sh
scripts/release-next.sh
```

To use a different notary profile:

```sh
NOTARY_PROFILE="your-profile-name" scripts/release-next.sh
```
