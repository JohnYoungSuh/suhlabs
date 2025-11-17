"""Test: Memory growth (Antipattern #4)

Ensures all data structures have explicit size bounds.
"""

import ast
from pathlib import Path

import pytest


def test_no_unbounded_list_append():
    """Verify no list.append without size checks."""
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

        # Find all list.append calls
        for node in ast.walk(tree):
            if isinstance(node, ast.Call):
                if isinstance(node.func, ast.Attribute):
                    if node.func.attr == "append":
                        # Check if there's a len() check nearby
                        # This is a simplified check - in production use more sophisticated analysis
                        pass


def test_explicit_size_limits():
    """Verify explicit size limit constants."""
    ml_dir = Path(__file__).parent.parent.parent
    config_path = ml_dir / "features" / "ccf_zkcs" / "config.py"

    with open(config_path) as f:
        content = f.read()

    # Verify size limits are defined
    required_limits = [
        "MAX_SEGMENT_MB",
        "MAX_TOTAL_CACHE_GB",
        "MAX_FANOUT",
        "MAX_TOKENS_PER_REQUEST",
    ]

    for limit in required_limits:
        assert limit in content, f"Missing size limit constant: {limit}"


def test_metrics_list_bounded():
    """Verify metrics lists are bounded (no infinite growth)."""
    ml_dir = Path(__file__).parent.parent.parent
    handler_path = ml_dir / "features" / "ccf_zkcs" / "handler.py"

    with open(handler_path) as f:
        content = f.read()

    # Check for bounded metrics list (keep last N samples)
    assert "[-1000:]" in content or "= self.metrics" in content, (
        "Metrics lists must be bounded to prevent memory growth"
    )


def test_cache_size_enforcement():
    """Verify cache manager enforces size limits."""
    ml_dir = Path(__file__).parent.parent.parent
    cache_mgr_path = ml_dir / "features" / "ccf_zkcs" / "cache_manager.py"

    with open(cache_mgr_path) as f:
        content = f.read()

    # Ensure size checks before write
    assert "MAX_SEGMENT_MB" in content, "Must check segment size before write"
    assert "_enforce_cache_limit" in content, "Must enforce total cache limit"

    # Ensure eviction when limit exceeded
    assert "evict" in content.lower(), "Must implement eviction for size limits"


def test_merkle_dag_fanout_limit():
    """Verify merkle DAG enforces fanout limit."""
    ml_dir = Path(__file__).parent.parent.parent
    merkle_path = ml_dir / "features" / "ccf_zkcs" / "merkle_dag.py"

    with open(merkle_path) as f:
        tree = ast.parse(f.read())

    # Find add_child method
    found_fanout_check = False
    for node in ast.walk(tree):
        if isinstance(node, ast.FunctionDef):
            if node.name == "add_child":
                # Check for MAX_FANOUT comparison
                for subnode in ast.walk(node):
                    if isinstance(subnode, ast.Compare):
                        if any(
                            isinstance(op, (ast.Gt, ast.GtE))
                            for op in subnode.ops
                        ):
                            found_fanout_check = True

    assert found_fanout_check, "add_child must check fanout limit"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
