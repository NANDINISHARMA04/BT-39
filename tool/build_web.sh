#!/usr/bin/env bash
# Rebuilds the ready-made web app in deploy/web, which Vercel serves as-is.
# Run this after changing the app, then commit and push deploy/web.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter build web --release --no-web-resources-cdn --base-href /
rm -rf deploy/web
mkdir -p deploy
cp -R build/web deploy/web
echo "deploy/web updated. Commit and push it to redeploy on Vercel."
