#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "on" ]]; then
  defaults write com.yourcompany.yourapp LiquidGlassForcedEnabled -bool YES
  echo "[OK] LiquidGlassForcedEnabled = YES"
elif [[ "${1:-}" == "off" ]]; then
  defaults write com.yourcompany.yourapp LiquidGlassForcedEnabled -bool NO
  echo "[OK] LiquidGlassForcedEnabled = NO"
else
  echo "Usage: $0 on|off"
  exit 1
fi
