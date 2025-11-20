#!/bin/bash
# Install and configure pre-commit hooks for secret detection
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_header "Installing Pre-Commit Hooks"
echo ""

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "Python 3 is required but not installed."
    exit 1
fi

# Install pre-commit
echo "Installing pre-commit..."
pip3 install pre-commit detect-secrets --quiet

print_success "Pre-commit installed"

# Create baseline for detect-secrets
echo ""
echo "Creating baseline for detect-secrets (this scans existing code)..."
detect-secrets scan --baseline .secrets.baseline

print_success "Baseline created"

# Install git hooks
echo ""
echo "Installing git hooks..."
pre-commit install

print_success "Git hooks installed"

# Run hooks on all files (optional)
echo ""
read -p "Run pre-commit hooks on all files now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Running pre-commit on all files..."
    pre-commit run --all-files || true
fi

echo ""
print_header "Pre-Commit Setup Complete"
echo ""
echo "Pre-commit hooks are now active and will run automatically on 'git commit'"
echo ""
echo "Useful commands:"
echo "  pre-commit run --all-files    # Run on all files manually"
echo "  pre-commit run <hook-id>      # Run specific hook"
echo "  SKIP=<hook-id> git commit     # Skip specific hook (use with caution!)"
echo ""
print_warning "Hooks that will run on commit:"
echo "  - detect-secrets              # Scan for secrets and credentials"
echo "  - gitleaks                    # Detect hardcoded secrets"
echo "  - detect-private-key          # Check for private SSH/TLS keys"
echo "  - check-k8s-secrets           # Prevent committing .yaml files with secrets"
echo "  - check-vault-placeholders    # Ensure placeholders are not replaced"
echo ""
