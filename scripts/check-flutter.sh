#!/usr/bin/env bash
set -euo pipefail

cd apps/mobile
flutter pub get
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
