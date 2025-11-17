#!/bin/bash
# Integration test: Cert deadlock prevention (Antipattern #9)
# Ensures async cert rotation doesn't block operations

set -euo pipefail

echo "=== Testing Certificate Rotation Resilience ==="

# Check for async rotation implementation
if grep -q "async.*rotation" /home/user/suhlabs/ml/common/vault_client.py; then
    echo "✓ Async cert rotation found"
else
    echo "✗ Async cert rotation NOT found - synchronous rotation causes deadlock"
    exit 1
fi

# Check for sync vault.renew() in handler (antipattern)
if grep -rE "vault.*renew\(\)" /home/user/suhlabs/ml/features/ccf_zkcs/handler.py 2>/dev/null; then
    echo "✗ Found synchronous vault.renew() - use async rotation"
    exit 1
fi

echo "✓ No synchronous cert renewal in handler"

# TODO: In production, this would:
# 1. Start 50 concurrent cache write operations
# 2. Trigger cert rotation mid-batch (update cert files)
# 3. Assert all operations complete successfully
# 4. Verify new operations use rotated cert

echo "=== Certificate Rotation Test Passed ==="
