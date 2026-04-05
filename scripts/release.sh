#!/bin/bash
set -euo pipefail

# Servo Release Script
# Builds, signs, notarizes, creates a GitHub release, and updates the appcast.
#
# Prerequisites:
#   1. Sparkle added to the Xcode project as an SPM package:
#      https://github.com/sparkle-project/Sparkle  (2.x)
#      Add SUFeedURL key to Info.plist build settings:
#        INFOPLIST_KEY_SUFeedURL = https://seanmctex.github.io/servo/appcast.xml
#      Add SUPublicEDKey to Info.plist build settings (from generate_keys output):
#        INFOPLIST_KEY_SUPublicEDKey = <your public key>
#   2. Notarization credentials stored in keychain:
#      xcrun notarytool store-credentials "Servo-notary" --apple-id <you> --team-id 4U7FD3V45R
#   3. GitHub CLI installed and authenticated: brew install gh && gh auth login
#   4. Sparkle private key (~/.sparkle_ed_private_key or in Keychain)

# --- Configuration ---
APP_NAME="Servo"
SCHEME="Servo"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$PROJECT_DIR/Servo.xcodeproj"
APPCAST_FILE="$PROJECT_DIR/docs/appcast.xml"
BUILD_DIR="$PROJECT_DIR/build/release"
SPARKLE_BIN="$(find ~/Library/Developer/Xcode/DerivedData/Servo-*/SourcePackages/artifacts/sparkle/Sparkle/bin -maxdepth 0 2>/dev/null | head -1)"
SIGNING_IDENTITY="Developer ID Application: Sean Mc Mains (4U7FD3V45R)"
NOTARY_PROFILE="Servo-notary"
PBXPROJ="$PROJECT/project.pbxproj"

# --- Preflight checks ---
if [ -z "$SPARKLE_BIN" ]; then
    echo "Error: Sparkle bin directory not found in DerivedData."
    echo "Build the project in Xcode first so SPM resolves the Sparkle package."
    exit 1
fi

if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed. Install with: brew install gh"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo "Error: GitHub CLI is not authenticated. Run: gh auth login"
    exit 1
fi

# --- Get current version from project.pbxproj ---
CURRENT_SHORT_VERSION=$(grep -m1 'MARKETING_VERSION' "$PBXPROJ" | awk -F'= ' '{print $2}' | tr -d '; ')
CURRENT_BUILD=$(grep -m1 'CURRENT_PROJECT_VERSION' "$PBXPROJ" | awk -F'= ' '{print $2}' | tr -d '; ')

echo "=== $APP_NAME Release Script ==="
echo ""
echo "Current version: $CURRENT_SHORT_VERSION (build $CURRENT_BUILD)"
echo ""

# --- Prompt for new version ---
read -p "New version string (e.g. 1.1.0): " NEW_VERSION
read -p "New build number (e.g. 2): " NEW_BUILD

if [ -z "$NEW_VERSION" ] || [ -z "$NEW_BUILD" ]; then
    echo "Error: Version and build number are required."
    exit 1
fi

echo ""
echo "Release notes (enter a blank line to finish):"
RELEASE_NOTES=""
while IFS= read -r line; do
    [ -z "$line" ] && break
    RELEASE_NOTES+="$line"$'\n'
done
RELEASE_NOTES="${RELEASE_NOTES%$'\n'}"

if [ -z "$RELEASE_NOTES" ]; then
    echo "Error: Release notes are required."
    exit 1
fi

TAG="v$NEW_VERSION"

echo ""
echo "--- Summary ---"
echo "Version:       $NEW_VERSION (build $NEW_BUILD)"
echo "Tag:           $TAG"
echo "Release notes:"
echo "$RELEASE_NOTES"
echo "---------------"
echo ""
read -p "Proceed? (y/N): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Aborted."
    exit 0
fi

# --- Step 1: Update version numbers in project.pbxproj ---
echo ""
echo "[1/9] Updating version to $NEW_VERSION (build $NEW_BUILD)..."
# Replace both Debug and Release occurrences
sed -i '' "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = $NEW_VERSION/g" "$PBXPROJ"
sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*/CURRENT_PROJECT_VERSION = $NEW_BUILD/g" "$PBXPROJ"

# --- Step 2: Build Release archive ---
echo "[2/9] Building Release archive..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

xcodebuild -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    archive \
    SKIP_INSTALL=NO \
    2>&1 | tail -5

# --- Step 3: Export and re-sign with Developer ID ---
echo "[3/9] Signing app with Developer ID..."
APP_PATH="$BUILD_DIR/$APP_NAME.xcarchive/Products/Applications/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: $APP_NAME.app not found in archive at $APP_PATH"
    exit 1
fi

# Sign nested frameworks/XPCs first, then the app bundle
find "$APP_PATH" -name "*.framework" -o -name "*.xpc" | while read bundle; do
    codesign --force --options runtime --sign "$SIGNING_IDENTITY" "$bundle"
done

codesign --deep --force --options runtime \
    --sign "$SIGNING_IDENTITY" \
    "$APP_PATH"
echo "    App signed with: $SIGNING_IDENTITY"

# --- Step 4: Create zip for notarization ---
echo "[4/9] Creating zip for notarization..."
ZIP_PATH="$BUILD_DIR/$APP_NAME.zip"
cd "$BUILD_DIR/$APP_NAME.xcarchive/Products/Applications"
zip -r -y "$ZIP_PATH" "$APP_NAME.app"
cd "$PROJECT_DIR"

# --- Step 5: Notarize ---
echo "[5/9] Submitting to Apple for notarization (this may take a few minutes)..."
xcrun notarytool submit "$ZIP_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

# --- Step 6: Staple the notarization ticket ---
echo "[6/9] Stapling notarization ticket..."
xcrun stapler staple "$APP_PATH"

# Re-zip after stapling so the distributed zip includes the ticket
rm "$ZIP_PATH"
cd "$BUILD_DIR/$APP_NAME.xcarchive/Products/Applications"
zip -r -y "$ZIP_PATH" "$APP_NAME.app"
cd "$PROJECT_DIR"

ZIP_SIZE=$(stat -f%z "$ZIP_PATH")
echo "    Zip created: $ZIP_PATH ($ZIP_SIZE bytes)"

# --- Step 7: Sign the zip with Sparkle EdDSA key ---
echo "[7/9] Signing with Sparkle EdDSA key..."
SIGNATURE=$("$SPARKLE_BIN/sign_update" "$ZIP_PATH" 2>&1)
ED_SIGNATURE=$(echo "$SIGNATURE" | grep -o 'sparkle:edSignature="[^"]*"' | sed 's/sparkle:edSignature="//;s/"//')

if [ -z "$ED_SIGNATURE" ]; then
    echo "Error: Failed to get EdDSA signature."
    echo "sign_update output: $SIGNATURE"
    exit 1
fi
echo "    Signature: ${ED_SIGNATURE:0:20}..."

# --- Step 8: Create GitHub release ---
echo "[8/9] Creating GitHub release $TAG..."

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
DOWNLOAD_URL="https://github.com/$REPO/releases/download/$TAG/$APP_NAME.zip"

gh release create "$TAG" "$ZIP_PATH" \
    --title "$APP_NAME $NEW_VERSION" \
    --notes "$RELEASE_NOTES"

echo "    Release created: https://github.com/$REPO/releases/tag/$TAG"

# --- Step 9: Update appcast.xml ---
echo "[9/9] Updating appcast.xml..."

HTML_NOTES=""
while IFS= read -r line; do
    HTML_NOTES+="                    <li>$line</li>"
done <<< "$RELEASE_NOTES"

PUB_DATE=$(date -R)

ITEM_FILE=$(mktemp)
cat > "$ITEM_FILE" <<ITEMEOF
        <item>
            <title>Version $NEW_VERSION</title>
            <pubDate>$PUB_DATE</pubDate>
            <sparkle:version>$NEW_BUILD</sparkle:version>
            <sparkle:shortVersionString>$NEW_VERSION</sparkle:shortVersionString>
            <description><![CDATA[
                <h2>What's New</h2>
                <ul>
$HTML_NOTES
                </ul>
            ]]></description>
            <enclosure
                url="$DOWNLOAD_URL"
                length="$ZIP_SIZE"
                type="application/octet-stream"
                sparkle:edSignature="$ED_SIGNATURE"
            />
        </item>
ITEMEOF

python3 -c "
import sys
appcast = open(sys.argv[1]).read()
item = open(sys.argv[2]).read()
marker = '<language>en</language>'
idx = appcast.find(marker)
if idx == -1:
    print('Error: could not find <language> marker in appcast.xml', file=sys.stderr)
    sys.exit(1)
insert_at = appcast.index('\n', idx) + 1
result = appcast[:insert_at] + item + appcast[insert_at:]
open(sys.argv[1], 'w').write(result)
" "$APPCAST_FILE" "$ITEM_FILE"

rm "$ITEM_FILE"

echo ""
echo "=== Release $NEW_VERSION complete! ==="
echo ""
echo "Remaining steps:"
echo "  1. Commit the updated project.pbxproj and appcast.xml"
echo "  2. Push to main so GitHub Pages serves the new appcast"
echo "     git add Servo.xcodeproj/project.pbxproj docs/appcast.xml"
echo "     git commit -m 'Release $NEW_VERSION'"
echo "     git push"
