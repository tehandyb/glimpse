#!/usr/bin/env bash
# bootstrap.sh — set up Glimpse for local development
# Run from the repo root: bash bootstrap.sh

set -e

REPO="$(cd "$(dirname "$0")" && pwd)"

echo "Glimpse bootstrap"
echo "================="
echo ""

# 1. Secrets.xcconfig
if [ -f "$REPO/Secrets.xcconfig" ]; then
  echo "Secrets.xcconfig already exists — skipping"
else
  cp "$REPO/Secrets.xcconfig.example" "$REPO/Secrets.xcconfig"
  echo "Created Secrets.xcconfig from example."
  echo ""
  echo "  Fill in your Meta credentials before building:"
  echo "  $REPO/Secrets.xcconfig"
  echo ""
  echo "  Get them at: https://developers.meta.com/wearables"
  echo ""
fi

# 2. xcodegen
if ! command -v xcodegen &>/dev/null; then
  echo "xcodegen not found — installing via Homebrew..."
  brew install xcodegen
fi

echo "Regenerating Xcode project..."
xcodegen generate
echo "Done."
echo ""

echo "Next steps:"
echo "  1. Fill in Secrets.xcconfig with your Meta App ID and client token"
echo "  2. Open Glimpse.xcodeproj in Xcode"
echo "  3. Set your Development Team under Signing & Capabilities"
echo "  4. Run on device"
