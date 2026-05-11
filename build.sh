#!/bin/bash
set -e

FLUTTER_VERSION="3.41.8"
FLUTTER_DIR="/opt/flutter"

echo "==> Installing Flutter $FLUTTER_VERSION..."
git clone https://github.com/flutter/flutter.git \
  -b "$FLUTTER_VERSION" \
  --depth 1 \
  "$FLUTTER_DIR"

export PATH="$PATH:$FLUTTER_DIR/bin"

echo "==> Flutter version check..."
flutter --version

echo "==> Enabling Flutter Web..."
flutter config --enable-web

echo "==> Getting dependencies..."
flutter pub get

echo "==> Running build_runner..."
dart run build_runner build --delete-conflicting-outputs

echo "==> Building Flutter Web..."
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=GOOGLE_SHEETS_API_KEY="$GOOGLE_SHEETS_API_KEY"

echo "==> Build complete! Output in build/web"
