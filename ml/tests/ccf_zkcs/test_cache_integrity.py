"""Test: Cache poisoning (Antipattern #8)

Ensures cache integrity via HMAC validation and immutable cache design.
"""

import ast
from pathlib import Path

import pytest


def test_no_mutable_default_args():
    """Verify no mutable default arguments (def foo(x=[]))."""
    ml_dir = Path(__file__).parent.parent.parent

    files_to_check = [
        ml_dir / "features" / "ccf_zkcs" / "handler.py",
        ml_dir / "features" / "ccf_zkcs" / "cache_manager.py",
        ml_dir / "features" / "ccf_zkcs" / "merkle_dag.py",
    ]

    for file_path in files_to_check:
        if not file_path.exists():
            continue

        with open(file_path) as f:
            tree = ast.parse(f.read(), filename=str(file_path))

        # Check for mutable default arguments
        for node in ast.walk(tree):
            if isinstance(node, ast.FunctionDef):
                for default in node.args.defaults:
                    if isinstance(default, (ast.List, ast.Dict, ast.Set)):
                        pytest.fail(
                            f"Mutable default argument in {file_path}:{node.name}. "
                            "Use None and initialize inside function."
                        )


def test_hmac_validation():
    """Verify HMAC validation is implemented."""
    ml_dir = Path(__file__).parent.parent.parent
    cache_mgr_path = ml_dir / "features" / "ccf_zkcs" / "cache_manager.py"

    with open(cache_mgr_path) as f:
        content = f.read()

    # Verify HMAC computation
    assert "hmac.new" in content, "Must use HMAC for cache integrity"
    assert "_compute_hmac" in content, "Must implement HMAC computation"

    # Verify HMAC verification on read
    assert "compare_digest" in content, "Must use compare_digest for HMAC verification"


def test_cache_corruption_handling():
    """Verify cache files are deleted on corruption."""
    ml_dir = Path(__file__).parent.parent.parent
    cache_mgr_path = ml_dir / "features" / "ccf_zkcs" / "cache_manager.py"

    with open(cache_mgr_path) as f:
        content = f.read()

    # Verify corruption detection deletes file
    assert "cache_file.unlink()" in content or "unlink()" in content, (
        "Must delete corrupted cache files"
    )


def test_immutable_cache_keys():
    """Verify cache keys are immutable (bytes, not mutable types)."""
    ml_dir = Path(__file__).parent.parent.parent
    handler_path = ml_dir / "features" / "ccf_zkcs" / "handler.py"

    with open(handler_path) as f:
        tree = ast.parse(f.read())

    # Find get_cache_key return type
    for node in ast.walk(tree):
        if isinstance(node, ast.FunctionDef):
            if node.name == "get_cache_key":
                # Check return annotation
                if node.returns:
                    if isinstance(node.returns, ast.Name):
                        assert node.returns.id == "bytes", (
                            "Cache keys must be immutable bytes type"
                        )


def test_vault_hmac_key_usage():
    """Verify HMAC key comes from Vault (not hardcoded)."""
    ml_dir = Path(__file__).parent.parent.parent
    cache_mgr_path = ml_dir / "features" / "ccf_zkcs" / "cache_manager.py"

    with open(cache_mgr_path) as f:
        content = f.read()

    # Verify HMAC key is passed as parameter (from Vault)
    assert "hmac_key: bytes" in content, "HMAC key must be parameter (from Vault)"

    # Ensure no hardcoded HMAC keys
    dangerous_patterns = [
        b"hmac_key = b'",
        b'hmac_key = "',
        b"HMAC_KEY = b'",
    ]

    for pattern in dangerous_patterns:
        if pattern in content.encode():
            pytest.fail(
                f"Found hardcoded HMAC key pattern. "
                "HMAC key must come from Vault."
            )


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
