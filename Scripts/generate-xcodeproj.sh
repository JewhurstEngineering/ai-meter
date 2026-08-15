#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
rm -rf CursorUsageTracker.xcodeproj
xcodegen generate
echo "Opened via: open AIMeter.xcodeproj"
