#!/bin/bash
#
# Git Status for All SuhLabs Repositories
# Shows the status of all 5 repos in the SuhLabs platform
#

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

REPOS=(
    "aiops-substrate"
    "ai-agent-governance-framework"
    "suhlabs-infr-ai-poc"
    "ml-antipatterns"
    "suhlabs-web"
)

BASE_DIR="$HOME/projects/suhlabs"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   📊 SuhLabs Platform - Git Status Report${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

for repo in "${REPOS[@]}"; do
    REPO_PATH="$BASE_DIR/$repo"
    
    if [ ! -d "$REPO_PATH" ]; then
        echo -e "${RED}❌ $repo${NC} - Not found at $REPO_PATH"
        echo ""
        continue
    fi
    
    echo -e "${GREEN}📁 $repo${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    cd "$REPO_PATH"
    
    # Get current branch
    BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    
    # Check if there are changes
    if [[ -n $(git status -s) ]]; then
        echo -e "   Branch: ${YELLOW}$BRANCH${NC}"
        echo -e "   Status: ${YELLOW}⚠️  Has changes${NC}"
        echo ""
        git status -sb
    else
        echo -e "   Branch: ${GREEN}$BRANCH${NC}"
        echo -e "   Status: ${GREEN}✓ Clean${NC}"
    fi
    
    # Show commits ahead/behind
    UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo "")
    if [ -n "$UPSTREAM" ]; then
        AHEAD=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
        BEHIND=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo "0")
        
        if [ "$AHEAD" -gt 0 ] || [ "$BEHIND" -gt 0 ]; then
            echo -e "   Remote: ${YELLOW}↑$AHEAD ↓$BEHIND${NC}"
        fi
    fi
    
    echo ""
done

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Status check complete${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
