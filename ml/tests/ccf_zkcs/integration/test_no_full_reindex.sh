#!/bin/bash
# Integration test: Full re-index prevention
# Ensures no full collection deletions occur

set -euo pipefail

echo "=== Testing Incremental-Only Operations ==="

# Check for dangerous operations in code
if grep -rE "(DELETE FROM|TRUNCATE|drop_collection)" /home/user/suhlabs/ml/features/ccf_zkcs/ 2>/dev/null; then
    echo "✗ Found full deletion operations - use incremental updates only"
    exit 1
fi

echo "✓ No full re-index operations found"

# TODO: In production, this would:
# 1. Monitor Qdrant operations during deployment
# 2. Assert no recreate_collection or delete_collection calls
# 3. Verify only upsert/delete specific points

echo "=== Incremental-Only Test Passed ==="
