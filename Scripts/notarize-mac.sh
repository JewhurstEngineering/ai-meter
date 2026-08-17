#!/usr/bin/env bash
# Back-compat wrapper. Mac releases go through Scripts/release.sh (Developer ID,
# Sparkle nested signing, notarization, staple, signed appcast).
set -euo pipefail
exec "$(dirname "$0")/release.sh" "${1:-Release}"
