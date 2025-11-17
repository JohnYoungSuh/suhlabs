"""Test: Client-controlled IDs (Antipattern #6)

Ensures cache keys are server-generated via BLAKE3, never client-provided.
"""

import ast
from pathlib import Path

import pytest


def test_no_request_id_usage():
    """Verify cache keys are not extracted from request objects."""
    ml_dir = Path(__file__).parent.parent.parent
    handler_path = ml_dir / "features" / "ccf_zkcs" / "handler.py"

    with open(handler_path) as f:
        tree = ast.parse(f.read(), filename=str(handler_path))

    # Look for request.id, request.cache_key patterns
    for node in ast.walk(tree):
        if isinstance(node, ast.Attribute):
            if isinstance(node.value, ast.Name):
                if node.value.id == "request":
                    if node.attr in ["id", "cache_key", "key"]:
                        pytest.fail(
                            f"Found request.{node.attr} usage. "
                            "Cache keys must be server-generated via BLAKE3, "
                            "not client-provided."
                        )


def test_blake3_cache_key_generation():
    """Verify cache keys are generated using BLAKE3."""
    ml_dir = Path(__file__).parent.parent.parent
    handler_path = ml_dir / "features" / "ccf_zkcs" / "handler.py"

    with open(handler_path) as f:
        content = f.read()

    # Verify get_cache_key uses BLAKE3
    assert "blake3" in content.lower(), "Must use BLAKE3 for cache key generation"
    assert "get_cache_key" in content, "Must implement get_cache_key method"

    # Verify canonical token sorting
    assert "sorted(tokens)" in content, (
        "Must sort tokens for canonical key generation"
    )


def test_cache_key_deterministic():
    """Test that cache key generation is deterministic."""
    import sys
    sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent))

    try:
        from ml.features.ccf_zkcs.handler import CCFZKCSHandler
        from unittest.mock import MagicMock, patch

        # Mock dependencies
        with patch('ml.features.ccf_zkcs.handler.TLSContext'), \
             patch('ml.features.ccf_zkcs.handler.VaultClient') as mock_vault, \
             patch('ml.features.ccf_zkcs.handler.CacheManager'):

            # Mock Vault to return dummy HMAC key
            mock_vault.return_value.read.return_value = {
                "data": {"key": "test_hmac_key"}
            }

            handler = CCFZKCSHandler()

            # Test deterministic key generation
            tokens1 = [1, 2, 3, 4, 5]
            tokens2 = [1, 2, 3, 4, 5]

            key1 = handler.get_cache_key(tokens1)
            key2 = handler.get_cache_key(tokens2)

            assert key1 == key2, "Cache keys must be deterministic"

            # Test order independence (sorted)
            tokens3 = [5, 4, 3, 2, 1]
            key3 = handler.get_cache_key(tokens3)

            assert key1 == key3, "Cache keys must be order-independent (sorted)"

    except ImportError as e:
        pytest.skip(f"Cannot import handler: {e}")


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
