#!/bin/bash
#
# Git Pull for All SuhLabs Repositories
# Pulls latest changes from remote for all 5 repos
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
echo -e "${BLUE}   📥 SuhLabs Platform - Pulling All Repos${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

UPDATED=0
FAILED=0

for repo in "${REPOS[@]}"; do
    REPO_PATH="$BASE_DIR/$repo"
    
    if [ ! -d "$REPO_PATH" ]; then
        echo -e "${RED}❌ $repo${NC} - Not found at $REPO_PATH"
        ((FAILED++))
        echo ""
        continue
    fi
    
    echo -e "${BLUE}📥 Pulling $repo...${NC}"
    
    cd "$REPO_PATH"
    
    # Get current branch
    BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    
    # Check for uncommitted changes
    if [[ -n $(git status -s) ]]; then
        echo -e "${YELLOW}   ⚠️  Warning: Uncommitted changes detected${NC}"
        echo -e "${YELLOW}   Stashing changes...${NC}"
        git stash push -m "Auto-stash by git-pull-all.sh"
        STASHED=true
    else
        STASHED=false
    fi
    
    # Pull
    if git pull --rebase; then
        echo -e "${GREEN}   ✓ Updated from remote ($BRANCH)${NC}"
        ((UPDATED++))
        
        # Pop stash if we stashed
        if [ "$STASHED" = true ]; then
            echo -e "${YELLOW}   Applying stashed changes...${NC}"
            git stash pop
        fi
    else
        echo -e "${RED}   ✗ Failed to pull${NC}"
        ((FAILED++))
    fi
    
    echo ""
done

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Pull complete: $UPDATED updated, $FAILED failed${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
