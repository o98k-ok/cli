#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Detect shell profile
if [ -n "$ZSH_VERSION" ] || [ -f "$HOME/.zshrc" ]; then
  PROFILE="$HOME/.zshrc"
elif [ -f "$HOME/.bash_profile" ]; then
  PROFILE="$HOME/.bash_profile"
else
  PROFILE="$HOME/.bashrc"
fi

EXPORT_LINE="export PATH=\"${SCRIPT_DIR}:\$PATH\""

if grep -qF "$SCRIPT_DIR" "$PROFILE" 2>/dev/null; then
  echo "✅ PATH already configured in ${PROFILE}"
else
  echo "" >> "$PROFILE"
  echo "# CLI Tools" >> "$PROFILE"
  echo "$EXPORT_LINE" >> "$PROFILE"
  echo "✅ Added to ${PROFILE}:"
  echo "   ${EXPORT_LINE}"
fi

chmod +x "${SCRIPT_DIR}"/*.sh

echo ""
echo "Run 'source ${PROFILE}' or open a new terminal to apply."
