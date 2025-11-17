"""Test: No secrets on disk (Antipattern #1)

Ensures no secrets are accessed via os.environ - all secrets must come from Vault.
"""

import ast
import sys
from pathlib import Path

import pytest


def test_no_os_environ_usage():
    """Verify no os.environ usage for secret access."""
    ml_dir = Path(__file__).parent.parent.parent
    handler_path = ml_dir / "features" / "ccf_zkcs" / "handler.py"
    vault_client_path = ml_dir / "common" / "vault_client.py"

    for file_path in [handler_path, vault_client_path]:
        with open(file_path) as f:
            tree = ast.parse(f.read(), filename=str(file_path))

        # Find all os.environ accesses
        for node in ast.walk(tree):
            if isinstance(node, ast.Subscript):
                # Check for os.environ[...]
                if isinstance(node.value, ast.Attribute):
                    if (
                        isinstance(node.value.value, ast.Name)
                        and node.value.value.id == "os"
                        and node.value.attr == "environ"
                    ):
                        # Check if accessing secret-like keys
                        if isinstance(node.slice, ast.Constant):
                            key = node.slice.value
                            if any(
                                secret_word in key.upper()
                                for secret_word in ["SECRET", "KEY", "TOKEN", "PASSWORD"]
                            ):
                                pytest.fail(
                                    f"Found os.environ['{key}'] in {file_path}. "
                                    "Secrets must come from Vault, not environment variables."
                                )


def test_vault_only_for_secrets():
    """Verify all secrets are retrieved from Vault."""
    ml_dir = Path(__file__).parent.parent.parent
    handler_path = ml_dir / "features" / "ccf_zkcs" / "handler.py"

    with open(handler_path) as f:
        content = f.read()

    # Ensure VaultClient is used
    assert "VaultClient" in content, "Handler must use VaultClient"

    # Ensure HMAC key comes from Vault
    assert "vault_client.read" in content, "Secrets must be read from Vault"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
