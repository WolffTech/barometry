#!/usr/bin/env bash

# Builds the distributable Barometry disk image: Release archive signed with
# Developer ID and the Hardened Runtime, notarized and stapled, then packed by
# Scripts/build-dmg.sh into a DMG that is itself signed, notarized and stapled.
# The same DMG is the GitHub download and the Sparkle update.
#
#   Scripts/release.sh <version> [build-number]
#
# Environment:
#   NOTARY_PROFILE  notarytool keychain profile (default: barometry-notary).
#                   Create one with:
#                     xcrun notarytool store-credentials barometry-notary \
#                       --apple-id <apple-id> --team-id 45QKSLQ5S4
#                   (it asks for an app-specific password and keeps it in Keychain).
#   NOTARY_KEY_FILE, NOTARY_KEY_ID, NOTARY_ISSUER_ID
#                   App Store Connect API key; when all three are set they are
#                   used instead of the keychain profile (CI has no profile).
#   SKIP_NOTARIZE=1 sign the app and the DMG but submit nothing to Apple;
#                   useful to inspect the bundle and the image offline.
#
# Output lands in build/release/<version>/. Nothing is uploaded except the
# notarization submission to Apple.
set -euo pipefail

TEAM_ID=45QKSLQ5S4
VERSION="${1:?usage: release.sh <version> [build-number]}"
BUILD_NUMBER="${2:-$(git rev-list --count HEAD)}"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "version must look like 1.2.3 (received: $VERSION)" >&2
  exit 1
fi
NOTARY_PROFILE="${NOTARY_PROFILE:-barometry-notary}"
if [[ -n "${NOTARY_KEY_FILE:-}" && -n "${NOTARY_KEY_ID:-}" && -n "${NOTARY_ISSUER_ID:-}" ]]; then
  NOTARY_AUTH=(--key "$NOTARY_KEY_FILE" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID")
  NOTARY_AUTH_DESCRIPTION="API key $NOTARY_KEY_ID"
else
  NOTARY_AUTH=(--keychain-profile "$NOTARY_PROFILE")
  NOTARY_AUTH_DESCRIPTION="profile $NOTARY_PROFILE"
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/build/release/$VERSION"
ARCHIVE="$OUT/Barometry.xcarchive"
EXPORT="$OUT/export"
APP="$EXPORT/Barometry.app"
DMG="$OUT/Barometry-$VERSION.dmg"

# Submits a file to notarytool and prints Apple's log when it is not accepted.
notarize() {
  local submission submission_id
  echo "Notarizing $(basename "$1") ($NOTARY_AUTH_DESCRIPTION)..."
  submission="$(xcrun notarytool submit "$1" "${NOTARY_AUTH[@]}" --wait 2>&1)" || true
  echo "$submission"
  if [[ "$submission" != *"status: Accepted"* ]]; then
    echo "Notarization was not accepted; fetching the log..." >&2
    submission_id="$(sed -n 's/^ *id: //p' <<<"$submission" | head -1)"
    if [[ -n "$submission_id" ]]; then
      xcrun notarytool log "$submission_id" "${NOTARY_AUTH[@]}" >&2
    fi
    exit 1
  fi
}

# The DMG is signed with the certificate that signed the exported app. Renewed
# Developer ID certificates share one name, so match by SHA-1 fingerprint.
signing_identity() {
  local certs identity
  certs="$(mktemp -d)"
  (cd "$certs" && codesign --display --extract-certificates "$APP" 2> /dev/null)
  identity="$(openssl x509 -inform DER -in "$certs/codesign0" -noout -fingerprint -sha1 \
    | sed 's/^.*=//; s/://g')"
  rm -rf "$certs"
  if ! security find-identity -v -p codesigning | grep -q " $identity \"Developer ID Application: .*($TEAM_ID)\""; then
    echo "the identity that signed $APP ($identity) is not in the keychain" >&2
    exit 1
  fi
  echo "$identity"
}

# Packs the stapled app into the styled image and signs it.
build_dmg() {
  Scripts/build-dmg.sh "$APP" "$DMG"
  echo "Signing disk image..."
  codesign --force --sign "$(signing_identity)" --timestamp "$DMG"
  codesign --verify --verbose=2 "$DMG"
}

cd "$ROOT"
xcodegen generate

rm -rf "$OUT"
mkdir -p "$OUT"

# project.yml signs ad-hoc for local builds; the archive uses Developer ID so
# the export can re-sign it with the same identity.
echo "Archiving $VERSION ($BUILD_NUMBER)..."
xcodebuild archive \
  -project Barometry.xcodeproj \
  -scheme Barometry \
  -onlyUsePackageVersionsFromResolvedFile \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE" \
  ARCHS=arm64 \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  -quiet

# Export re-signs the app and everything nested in it with the Developer ID
# identity and a secure timestamp.
cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>Developer ID Application</string>
</dict>
</plist>
PLIST

echo "Exporting..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" \
  -exportPath "$EXPORT" \
  -quiet

echo "Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$APP"
codesign --display --verbose=2 "$APP" 2>&1 | grep -E '^(Identifier|Authority|TeamIdentifier|CodeDirectory)' | sed 's/^/  /'
signature="$(codesign --display --verbose=2 "$APP" 2>&1)"
if [[ "$signature" != *"flags="*"(runtime)"* ]]; then
  echo "$APP is not signed with the Hardened Runtime" >&2
  exit 1
fi

# Sparkle: the export must have re-signed every nested piece with our team
# (library validation and notarization both reject the upstream signature),
# and the plist must name this repository's feed and a real ed25519 key
# (44-character base64), not a placeholder.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
if [[ ! -d "$SPARKLE" ]]; then
  echo "Sparkle.framework is not embedded in $APP" >&2
  exit 1
fi
for nested in "$SPARKLE/Versions/B/Autoupdate" "$SPARKLE/Versions/B/Updater.app" "$SPARKLE/Versions/B/XPCServices/"*.xpc "$SPARKLE"; do
  team="$(codesign --display --verbose=2 "$nested" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
  if [[ "$team" != "$TEAM_ID" ]]; then
    echo "$nested is signed by team ${team:-none}, not $TEAM_ID" >&2
    exit 1
  fi
done
feed_url="$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$APP/Contents/Info.plist")"
if [[ "$feed_url" != "https://github.com/WolffTech/barometry/"* ]]; then
  echo "SUFeedURL does not point at this repository: $feed_url" >&2
  exit 1
fi
public_key="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$APP/Contents/Info.plist")"
if [[ ! "$public_key" =~ ^[A-Za-z0-9+/]{43}=$ ]]; then
  echo "SUPublicEDKey is not an ed25519 public key: $public_key" >&2
  exit 1
fi

if [[ "${SKIP_NOTARIZE:-0}" == "1" ]]; then
  build_dmg
  echo "SKIP_NOTARIZE set; signed app at $APP, unnotarized image at $DMG"
  exit 0
fi

# The app is notarized and stapled before it goes into the image so a copy
# dragged out of the DMG carries its own ticket; the DMG then gets its own
# ticket so Gatekeeper accepts the download without a network round-trip.
ditto -c -k --keepParent "$APP" "$OUT/notarize.zip"
notarize "$OUT/notarize.zip"
rm -f "$OUT/notarize.zip"

echo "Stapling app..."
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"

build_dmg
notarize "$DMG"
echo "Stapling disk image..."
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"

(cd "$OUT" && shasum -a 256 "$(basename "$DMG")" > "$DMG.sha256")
echo "Release ready: $DMG"
cat "$DMG.sha256"
