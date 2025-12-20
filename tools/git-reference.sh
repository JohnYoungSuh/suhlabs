#!/bin/bash
# Quick Reference Card for SuhLabs Multi-Repo Git Workflow

cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════╗
║          SuhLabs Platform - Multi-Repo Quick Reference            ║
╚═══════════════════════════════════════════════════════════════════╝

📁 YOUR 5 REPOSITORIES
─────────────────────────────────────────────────────────────────────
  1. aiops-substrate               Infrastructure/platform
  2. ai-agent-governance-framework Policy/governance  
  3. suhlabs-infr-ai-poc           Infrastructure AI
  4. ml-antipatterns               ML validation
  5. suhlabs-web                   Marketing site

🚀 DAILY COMMANDS
─────────────────────────────────────────────────────────────────────
  Morning:
    ./tools/git-pull-all.sh        Pull all repos

  During Work:
    ./tools/git-status-all.sh      Check all repos

  Evening:
    ./tools/git-commit-all.sh "message"
                                   Commit all repos

💻 SINGLE REPO COMMANDS
─────────────────────────────────────────────────────────────────────
  git status                       Check current repo
  git add .                        Stage all changes
  git commit -m "message"          Commit
  git push                         Push to remote
  git pull                         Get latest
  git checkout -b feature/name     New branch

📝 COMMIT MESSAGE FORMAT
─────────────────────────────────────────────────────────────────────
  Format:  <type>(<scope>): <description>

  Types:
    feat     New feature
    fix      Bug fix
    docs     Documentation
    chore    Maintenance
    refactor Code refactoring

  Examples:
    feat(governance): Add new validation policy
    fix(infra): Repair certificate renewal
    docs(readme): Update architecture

🏷️  VERSIONING
─────────────────────────────────────────────────────────────────────
  Tag all repos with same version:
    git tag -a v1.0.0 -m "Release v1.0.0"
    git push origin v1.0.0

🔧 VS CODE WORKSPACE
─────────────────────────────────────────────────────────────────────
  Open all 5 repos:
    code ~/projects/suhlabs/suhlabs-platform.code-workspace

  Features:
    ✓ All repos in one window
    ✓ Separate Git for each repo
    ✓ Run helper scripts from Tasks menu

📖 DOCUMENTATION
─────────────────────────────────────────────────────────────────────
  docs/GIT-WORKFLOW.md            Complete workflow guide
  docs/MULTI-REPO-SETUP.md        Setup instructions
  tools/README.md                 Helper scripts docs

🆘 TROUBLESHOOTING
─────────────────────────────────────────────────────────────────────
  Uncommitted changes when pulling:
    git stash
    git pull
    git stash pop

  Make scripts executable:
    chmod +x tools/*.sh

  Check which repo you're in:
    pwd
    git remote -v

╔═══════════════════════════════════════════════════════════════════╗
║  Save this as ~/suhlabs-git-reference.sh and run: ./script.sh    ║
╚═══════════════════════════════════════════════════════════════════╝
EOF
