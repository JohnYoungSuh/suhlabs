"""Test: Non-mTLS Ollama (Antipattern #2)

Ensures all HTTP calls use TLSContext and no plaintext HTTP.
"""

import ast
import re
from pathlib import Path

import pytest


def test_no_plaintext_http():
    """Verify no plaintext HTTP URLs in code."""
    ml_dir = Path(__file__).parent.parent.parent

    # Check all Python files in features
    for py_file in (ml_dir / "features" / "ccf_zkcs").rglob("*.py"):
        with open(py_file) as f:
            content = f.read()

        # Check for http:// URLs (should only have https://)
        http_matches = re.findall(r'http://[^\s\'"]+', content)
        if http_matches:
            pytest.fail(
                f"Found plaintext HTTP URL in {py_file}: {http_matches}. "
                "All connections must use HTTPS with mTLS."
            )

        # Check for localhost:11434 (default Ollama HTTP port)
        if ":11434" in content or "localhost:11434" in content:
            pytest.fail(
                f"Found :11434 (Ollama HTTP port) in {py_file}. "
                "Must use HTTPS with TLSContext."
            )


def test_tls_context_usage():
    """Verify TLSContext is used for all network operations."""
    ml_dir = Path(__file__).parent.parent.parent
    handler_path = ml_dir / "features" / "ccf_zkcs" / "handler.py"
    vault_client_path = ml_dir / "common" / "vault_client.py"

    # Handler must use TLSContext
    with open(handler_path) as f:
        handler_content = f.read()

    assert "TLSContext" in handler_content, "Handler must use TLSContext"
    assert "self.tls_context" in handler_content, "Handler must initialize TLSContext"

    # VaultClient must require TLSContext
    with open(vault_client_path) as f:
        vault_content = f.read()

    assert "tls_context: TLSContext" in vault_content, (
        "VaultClient must require TLSContext parameter"
    )


def test_vault_addr_is_https():
    """Verify Vault address uses HTTPS."""
    ml_dir = Path(__file__).parent.parent.parent
    vault_client_path = ml_dir / "common" / "vault_client.py"

    with open(vault_client_path) as f:
        tree = ast.parse(f.read())

    # Find vault_addr default value
    for node in ast.walk(tree):
        if isinstance(node, ast.Assign):
            for target in node.targets:
                if isinstance(target, ast.Name) and target.id == "vault_addr":
                    if isinstance(node.value, ast.Constant):
                        addr = node.value.value
                        if not addr.startswith("https://"):
                            pytest.fail(
                                f"Vault address must use HTTPS: {addr}"
                            )


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
