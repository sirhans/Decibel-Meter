#!/usr/bin/env bash
set -euo pipefail

PROJECT="Decibel Meter.xcodeproj"
SCHEME="Decibel Meter"
CONFIGURATION="Release"
APP_NAME="Decibel Meter"
EXPORT_OPTIONS="ExportOptions.plist"
BUILD_DIR="build/release"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
APP_PATH="$EXPORT_PATH/$APP_NAME.app"

usage() {
    cat <<USAGE
Usage:
  scripts/release.sh VERSION [--notary-profile KEYCHAIN_PROFILE] [--github]

Examples:
  scripts/release.sh 0.1.0
  scripts/release.sh 0.1.0 --notary-profile notarytool-password
  scripts/release.sh 0.1.0 --notary-profile notarytool-password --github

The script archives the macOS app, exports a Developer ID build, optionally
submits it to Apple's notary service, staples the ticket, creates a zip, and
optionally uploads it to the matching GitHub release tag.
USAGE
}

version="${1:-}"
if [[ -z "$version" || "$version" == "-h" || "$version" == "--help" ]]; then
    usage
    exit 0
fi
shift

notary_profile=""
upload_github=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --notary-profile)
            notary_profile="${2:-}"
            if [[ -z "$notary_profile" ]]; then
                echo "Missing value for --notary-profile" >&2
                exit 1
            fi
            shift 2
            ;;
        --github)
            upload_github=true
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

tag="v$version"
zip_path="$BUILD_DIR/$APP_NAME-$tag.zip"

if [[ ! -f "$EXPORT_OPTIONS" ]]; then
    echo "Missing $EXPORT_OPTIONS" >&2
    exit 1
fi

if [[ -n "$(git status --short)" ]]; then
    echo "Working tree is not clean. Commit or stash changes before releasing." >&2
    git status --short
    exit 1
fi

if git rev-parse "$tag" >/dev/null 2>&1; then
    tag_commit="$(git rev-list -n 1 "$tag")"
    head_commit="$(git rev-parse HEAD)"
    if [[ "$tag_commit" != "$head_commit" ]]; then
        echo "Tag $tag already exists, but it does not point at HEAD." >&2
        echo "Use a new version number or intentionally move the tag yourself." >&2
        exit 1
    fi
else
    git tag -a "$tag" -m "$APP_NAME $version"
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -archivePath "$ARCHIVE_PATH"

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS"

if [[ ! -d "$APP_PATH" ]]; then
    echo "Expected exported app at $APP_PATH" >&2
    exit 1
fi

if [[ -n "$notary_profile" ]]; then
    notary_zip="$BUILD_DIR/$APP_NAME-$tag-notary.zip"
    ditto -c -k --keepParent "$APP_PATH" "$notary_zip"

    xcrun notarytool submit "$notary_zip" \
        --keychain-profile "$notary_profile" \
        --wait

    xcrun stapler staple "$APP_PATH"
fi

ditto -c -k --keepParent "$APP_PATH" "$zip_path"

if [[ "$upload_github" == true ]]; then
    if ! command -v gh >/dev/null 2>&1; then
        echo "GitHub CLI not found. Install gh or upload $zip_path manually." >&2
        exit 1
    fi

    git push origin "$tag"

    if gh release view "$tag" >/dev/null 2>&1; then
        gh release upload "$tag" "$zip_path" --clobber
    else
        gh release create "$tag" "$zip_path" \
            --title "$APP_NAME $version" \
            --notes "Initial release."
    fi
fi

echo "Release asset ready:"
echo "  $zip_path"
