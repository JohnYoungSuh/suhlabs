#!/bin/bash
#
# Install Git hooks for SuhLabs repositories
# Run this script to set up pre-commit and commit-msg hooks
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_SOURCE="$SCRIPT_DIR/hooks"
GIT_HOOKS_DIR="$SCRIPT_DIR/../.git/hooks"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   🔧 Installing Git Hooks${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if we're in a git repository
if [ ! -d "$GIT_HOOKS_DIR" ]; then
    echo -e "${RED}❌ Error: Not in a git repository${NC}"
    echo "Run this script from the repository root."
    exit 1
fi

# Install pre-commit hook
echo "📥 Installing pre-commit hook..."
if [ -f "$GIT_HOOKS_DIR/pre-commit" ]; then
    echo -e "${YELLOW}  ⚠ Backing up existing pre-commit hook...${NC}"
    mv "$GIT_HOOKS_DIR/pre-commit" "$GIT_HOOKS_DIR/pre-commit.backup"
fi

cp "$HOOKS_SOURCE/pre-commit" "$GIT_HOOKS_DIR/pre-commit"
chmod +x "$GIT_HOOKS_DIR/pre-commit"
echo -e "${GREEN}  ✓ pre-commit hook installed${NC}"

# Install commit-msg hook
echo "📥 Installing commit-msg hook..."
if [ -f "$GIT_HOOKS_DIR/commit-msg" ]; then
    echo -e "${YELLOW}  ⚠ Backing up existing commit-msg hook...${NC}"
    mv "$GIT_HOOKS_DIR/commit-msg" "$GIT_HOOKS_DIR/commit-msg.backup"
fi

cp "$HOOKS_SOURCE/commit-msg" "$GIT_HOOKS_DIR/commit-msg"
chmod +x "$GIT_HOOKS_DIR/commit-msg"
echo -e "${GREEN}  ✓ commit-msg hook installed${NC}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Git hooks installed successfully!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "What these hooks do:"
echo ""
echo "  pre-commit:"
echo "    → Detects secrets (passwords, API keys)"
echo "    → Runs ShellCheck on .sh files"
echo "    → Warns about large files (>5MB)"
echo ""
echo "  commit-msg:"
echo "    → Enforces conventional commit format"
echo "    → Example: feat(api): Add new feature"
echo ""
echo "To disable temporarily:"
echo "  git commit --no-verify"
echo ""
echo "To uninstall:"
echo "  rm $GIT_HOOKS_DIR/pre-commit"
echo "  rm $GIT_HOOKS_DIR/commit-msg"
echo ""
