"""Test: Full re-index (Antipattern #3)

Ensures no full collection deletions - only incremental updates.
"""

import ast
import re
from pathlib import Path

import pytest


def test_no_delete_operations():
    """Verify no DELETE FROM or TRUNCATE operations."""
    ml_dir = Path(__file__).parent.parent.parent

    # Check all Python files
    for py_file in (ml_dir / "features" / "ccf_zkcs").rglob("*.py"):
        with open(py_file) as f:
            content = f.read()

        # Check for SQL-like delete operations
        dangerous_patterns = [
            r"DELETE\s+FROM",
            r"TRUNCATE",
            r"drop_collection",
            r"delete_collection",
        ]

        for pattern in dangerous_patterns:
            if re.search(pattern, content, re.IGNORECASE):
                pytest.fail(
                    f"Found dangerous pattern '{pattern}' in {py_file}. "
                    "Use incremental updates only, no full re-indexing."
                )


def test_qdrant_incremental_only():
    """Verify Qdrant operations are incremental (upsert/delete specific points)."""
    infra_dir = Path(__file__).parent.parent.parent.parent
    qdrant_path = infra_dir / "infra" / "qdrant" / "ccf_zkcs_collection.py"

    if not qdrant_path.exists():
        pytest.skip("Qdrant collection file not found")

    with open(qdrant_path) as f:
        content = f.read()

    # Ensure no recreate_collection or delete_collection
    assert "recreate_collection" not in content, (
        "Must not recreate collection - use incremental updates"
    )
    assert "delete_collection" not in content.replace("_ensure_collection", ""), (
        "Must not delete entire collection - use delete specific points"
    )

    # Ensure batch operations are used
    assert "upsert" in content, "Must use upsert for incremental updates"


def test_cache_manager_incremental():
    """Verify cache manager uses incremental eviction, not full clear."""
    ml_dir = Path(__file__).parent.parent.parent
    cache_mgr_path = ml_dir / "features" / "ccf_zkcs" / "cache_manager.py"

    with open(cache_mgr_path) as f:
        content = f.read()

    # Ensure LRU eviction (incremental)
    assert "get_lru_nodes" in content, "Must use LRU eviction (incremental)"

    # Ensure no full cache clear
    dangerous_ops = ["rmtree", "shutil.rmtree", "clear_all", "delete_all"]
    for op in dangerous_ops:
        if op in content:
            pytest.fail(
                f"Found {op} in cache_manager.py. "
                "Must use incremental eviction, not full clear."
            )


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
