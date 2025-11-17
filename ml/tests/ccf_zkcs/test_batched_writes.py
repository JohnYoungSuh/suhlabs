"""Test: No Qdrant txn (Antipattern #5)

Ensures all Qdrant writes use batch operations.
"""

import ast
from pathlib import Path

import pytest


def test_qdrant_batch_operations():
    """Verify all Qdrant upserts are batched."""
    infra_dir = Path(__file__).parent.parent.parent.parent
    qdrant_path = infra_dir / "infra" / "qdrant" / "ccf_zkcs_collection.py"

    if not qdrant_path.exists():
        pytest.skip("Qdrant collection file not found")

    with open(qdrant_path) as f:
        tree = ast.parse(f.read(), filename=str(qdrant_path))

    # Find all upsert calls
    found_batched_upsert = False
    for node in ast.walk(tree):
        if isinstance(node, ast.FunctionDef):
            if "batch" in node.name.lower():
                # Check if function contains upsert
                for subnode in ast.walk(node):
                    if isinstance(subnode, ast.Call):
                        if isinstance(subnode.func, ast.Attribute):
                            if subnode.func.attr == "upsert":
                                found_batched_upsert = True

    assert found_batched_upsert, (
        "Qdrant upserts must be batched. "
        "Use upsert_node_batch() instead of individual upserts."
    )


def test_no_individual_upsert():
    """Verify no individual upsert calls outside batch context."""
    infra_dir = Path(__file__).parent.parent.parent.parent
    qdrant_path = infra_dir / "infra" / "qdrant" / "ccf_zkcs_collection.py"

    if not qdrant_path.exists():
        pytest.skip("Qdrant collection file not found")

    with open(qdrant_path) as f:
        content = f.read()

    # Check that upsert is only called within batch methods
    lines = content.split("\n")
    for i, line in enumerate(lines):
        if "client.upsert(" in line or "self.client.upsert(" in line:
            # Look for enclosing function
            for j in range(i, max(0, i - 20), -1):
                if "def " in lines[j]:
                    func_line = lines[j]
                    if "batch" not in func_line.lower():
                        pytest.fail(
                            f"Found non-batched upsert at line {i+1}. "
                            f"Function: {func_line.strip()}. "
                            "All upserts must be batched."
                        )
                    break


def test_batch_delete_operations():
    """Verify delete operations are also batched."""
    infra_dir = Path(__file__).parent.parent.parent.parent
    qdrant_path = infra_dir / "infra" / "qdrant" / "ccf_zkcs_collection.py"

    if not qdrant_path.exists():
        pytest.skip("Qdrant collection file not found")

    with open(qdrant_path) as f:
        content = f.read()

    # Ensure delete_nodes_batch exists
    assert "delete_nodes_batch" in content, (
        "Must implement batched delete operations"
    )


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
