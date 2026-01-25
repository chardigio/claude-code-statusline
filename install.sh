#!/bin/bash

# install.sh - Install Claude Code custom statusline
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/chardigio/claude-code-statusline/main/install.sh | bash
#
# Or from a local clone:
#   ./install.sh
#
# This script:
# 1. Downloads statusline.sh to ~/.claude/
# 2. Configures Claude Code to use it

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}!${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_info() { echo -e "${BLUE}→${NC} $1"; }

CLAUDE_DIR="$HOME/.claude"
STATUSLINE_PATH="$CLAUDE_DIR/statusline.sh"
SETTINGS_PATH="$CLAUDE_DIR/settings.json"

# Determine if running from local repo or remote
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_STATUSLINE="$SCRIPT_DIR/statusline.sh"

echo ""
echo "Claude Code Statusline Installer"
echo "================================="
echo ""

# Check for jq (required for settings.json manipulation)
if ! command -v jq &>/dev/null; then
    print_error "jq is required but not installed"
    print_info "Install with: brew install jq"
    exit 1
fi

# Create ~/.claude if needed
if [[ ! -d "$CLAUDE_DIR" ]]; then
    mkdir -p "$CLAUDE_DIR"
    print_status "Created $CLAUDE_DIR"
fi

# Download or copy statusline.sh
if [[ -f "$LOCAL_STATUSLINE" ]]; then
    # Running from local clone
    cp "$LOCAL_STATUSLINE" "$STATUSLINE_PATH"
    print_status "Copied statusline.sh to $STATUSLINE_PATH"
else
    # Running via curl - download from GitHub
    DOWNLOAD_URL="https://raw.githubusercontent.com/chardigio/claude-code-statusline/main/statusline.sh"
    if curl -fsSL "$DOWNLOAD_URL" -o "$STATUSLINE_PATH"; then
        print_status "Downloaded statusline.sh to $STATUSLINE_PATH"
    else
        print_error "Failed to download statusline.sh"
        exit 1
    fi
fi

chmod +x "$STATUSLINE_PATH"

# Configure Claude Code settings
if [[ -f "$SETTINGS_PATH" ]]; then
    # Backup existing settings
    cp "$SETTINGS_PATH" "$SETTINGS_PATH.backup"

    # Update settings with statusline config
    UPDATED=$(jq '.statusLine = {"type": "command", "command": "~/.claude/statusline.sh", "padding": 0}' "$SETTINGS_PATH")
    echo "$UPDATED" > "$SETTINGS_PATH"
    print_status "Updated $SETTINGS_PATH (backup at $SETTINGS_PATH.backup)"
else
    # Create new settings file
    cat > "$SETTINGS_PATH" << 'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 0
  }
}
EOF
    print_status "Created $SETTINGS_PATH"
fi

echo ""
print_status "Installation complete!"
echo ""
echo "The statusline will appear next time you start Claude Code."
echo ""
echo "Preview:"
echo "  🧠 O4.5 📈 ██░░░░░░42k ⚡️ ███▒░░░░2h30m ██▒░░░░░4d5h 💰 \$1.23"
echo "  📁 ~/project 🌿 main↑2 ✏️ +15/-3"
echo ""
