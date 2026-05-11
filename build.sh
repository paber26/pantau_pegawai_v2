#!/bin/bash
set -e

echo "==> Installing Flutter..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1 /opt/flutter
export PATH="$PATH:/opt/flutter/bin"

echo "==> Enabling Flutter Web..."
flutter config --enable-web

echo "==> Getting dependencies..."
flutter pub get

echo "==> Building Flutter Web..."
flutter build web --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define=GOOGLE_SHEETS_API_KEY=$GOOGLE_SHEETS_API_KEY

echo "==> Build complete!"
