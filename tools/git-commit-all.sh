#!/bin/bash
#
# Git Commit for All SuhLabs Repositories
# Commits and pushes changes in all repos with the same message
#

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

if [ -z "$1" ]; then
    echo -e "${RED}Error: Commit message required${NC}"
    echo "Usage: $0 \"commit message\""
    echo ""
    echo "Example:"
    echo "  $0 \"docs: Update architecture documentation\""
    exit 1
fi

MESSAGE="$1"

REPOS=(
    "aiops-substrate"
    "ai-agent-governance-framework"
    "suhlabs-infr-ai-poc"
    "ml-antipatterns"
    "suhlabs-web"
)

BASE_DIR="$HOME/projects/suhlabs"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   💾 SuhLabs Platform - Commit All Repos${NC}"
echo -e "${BLUE}   Message: \"$MESSAGE\"${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

COMMITTED=0
PUSHED=0
SKIPPED=0

for repo in "${REPOS[@]}"; do
    REPO_PATH="$BASE_DIR/$repo"
    
    if [ ! -d "$REPO_PATH" ]; then
        echo -e "${RED}❌ $repo - Not found${NC}"
        echo ""
        continue
    fi
    
    echo -e "${GREEN}📁 $repo${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    cd "$REPO_PATH"
    
    # Check if there are changes
    if [[ -z $(git status -s) ]]; then
        echo -e "${YELLOW}   ⏭️  No changes to commit${NC}"
        ((SKIPPED++))
        echo ""
        continue
    fi
    
    # Show what will be committed
    echo -e "${BLUE}   Changes:${NC}"
    git status -s | head -n 10
    
    # Add all changes
    git add .
    
    # Commit
    if git commit -m "$MESSAGE"; then
        echo -e "${GREEN}   ✓ Committed${NC}"
        ((COMMITTED++))
        
        # Push
        if git push; then
            echo -e "${GREEN}   ✓ Pushed to remote${NC}"
            ((PUSHED++))
        else
            echo -e "${RED}   ✗ Failed to push${NC}"
        fi
    else
        echo -e "${RED}   ✗ Failed to commit${NC}"
    fi
    
    echo ""
done

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Complete: $COMMITTED committed, $PUSHED pushed, $SKIPPED skipped${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
