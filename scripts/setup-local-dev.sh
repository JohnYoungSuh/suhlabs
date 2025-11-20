#!/bin/bash
# Setup local development files from templates
# This creates .yaml files from .yaml.template files for local development
# The .yaml files are in .gitignore and won't be committed
set -e

# Colors for output
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

print_header "Setting up local development files"
echo ""

# Find all template files
TEMPLATES=$(find services/ -name "*.yaml.template" -type f 2>/dev/null | sort)

if [ -z "$TEMPLATES" ]; then
    print_warning "No template files found"
    exit 0
fi

echo "Found template files:"
for template in $TEMPLATES; do
    output_file="${template%.template}"

    if [ -f "$output_file" ]; then
        echo -n "  $(basename $template) → $(basename $output_file) "
        read -p "(already exists, overwrite? y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_warning "Skipped: $(basename $output_file)"
            continue
        fi
    fi

    # Copy template to working file
    cp "$template" "$output_file"
    print_success "Created: $output_file"
done

echo ""
print_header "Local Development Setup Complete"
echo ""
echo "Next steps for local development:"
echo ""
echo "1. Edit the .yaml files (NOT .yaml.template) with your local values:"
echo "   - services/photoprism/kubernetes/02-minio.yaml"
echo "   - services/photoprism/kubernetes/03-mariadb.yaml"
echo "   - services/photoprism/kubernetes/04-photoprism.yaml"
echo "   - services/photoprism/kubernetes/06-authelia.yaml"
echo ""
echo "2. Replace \${VAULT_*} placeholders with actual values:"
echo "   Example: \${VAULT_MINIO_ROOT_PASSWORD} → your-actual-password"
echo ""
echo "3. These .yaml files are in .gitignore and won't be committed"
echo ""
echo "4. Only commit changes to .yaml.template files"
echo ""
print_warning "IMPORTANT: Never commit files with real secrets!"
echo ""
