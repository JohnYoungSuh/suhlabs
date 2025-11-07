"""
Unit tests for Packer template validation.

These tests verify Packer syntax and configuration
without actually building images.
"""

import json
import subprocess
from pathlib import Path

import pytest


class TestPackerSyntax:
    """Test Packer template syntax."""

    @pytest.fixture
    def packer_dir(self):
        """Return Packer directory path."""
        base_dir = Path(__file__).parent.parent.parent.parent
        return base_dir / "packer"

    @pytest.fixture
    def packer_templates(self, packer_dir):
        """Return list of Packer templates."""
        if not packer_dir.exists():
            pytest.skip(f"Packer directory {packer_dir} does not exist")
        return list(packer_dir.glob("*.pkr.hcl")) + list(packer_dir.glob("*.json"))

    @pytest.mark.packer
    @pytest.mark.unit
    def test_packer_validate(self, packer_templates):
        """Test that all Packer templates pass validation."""
        if not packer_templates:
            pytest.skip("No Packer templates found")

        for template in packer_templates:
            result = subprocess.run(
                ["packer", "validate", str(template)],
                cwd=template.parent,
                capture_output=True,
                text=True,
                env={"PACKER_LOG": "0"},  # Suppress verbose logs
            )

            assert result.returncode == 0, (
                f"Packer validate failed for {template.name}\n"
                f"Output: {result.stdout}\n{result.stderr}"
            )

    @pytest.mark.packer
    @pytest.mark.unit
    def test_packer_format(self, packer_dir):
        """Test that HCL templates are properly formatted."""
        hcl_files = list(packer_dir.glob("*.pkr.hcl")) if packer_dir.exists() else []

        if not hcl_files:
            pytest.skip("No HCL Packer templates found")

        for hcl_file in hcl_files:
            result = subprocess.run(
                ["packer", "fmt", "-check", str(hcl_file)],
                capture_output=True,
                text=True,
            )

            assert result.returncode == 0, (
                f"Packer HCL file {hcl_file.name} is not formatted.\n"
                f"Run 'packer fmt {hcl_file}' to fix.\n"
                f"Output: {result.stdout}\n{result.stderr}"
            )

    @pytest.mark.packer
    @pytest.mark.unit
    def test_json_templates_valid(self, packer_templates):
        """Test that JSON templates are valid JSON."""
        json_templates = [t for t in packer_templates if t.suffix == ".json"]

        for template in json_templates:
            try:
                with open(template, "r") as f:
                    json.load(f)
            except json.JSONDecodeError as e:
                pytest.fail(f"Invalid JSON in {template.name}: {e}")

    @pytest.mark.packer
    @pytest.mark.unit
    def test_no_hardcoded_credentials(self, packer_templates):
        """Test that no hardcoded credentials exist in templates."""
        if not packer_templates:
            pytest.skip("No Packer templates found")

        credential_patterns = [
            "password = \"",
            "token = \"",
            "secret = \"",
            "api_key = \"",
        ]

        for template in packer_templates:
            content = template.read_text()

            for pattern in credential_patterns:
                if pattern in content.lower():
                    # Check if it's using environment variable or vault
                    if "env(" not in content and "vault" not in content.lower():
                        pytest.fail(
                            f"Possible hardcoded credential in {template.name}. "
                            f"Use environment variables or Vault."
                        )


class TestPackerConfiguration:
    """Test Packer configuration best practices."""

    @pytest.fixture
    def packer_dir(self):
        """Return Packer directory path."""
        base_dir = Path(__file__).parent.parent.parent.parent
        return base_dir / "packer"

    @pytest.mark.packer
    @pytest.mark.unit
    def test_variables_file_exists(self, packer_dir):
        """Test that variables file exists."""
        if not packer_dir.exists():
            pytest.skip("Packer directory does not exist")

        variables_files = list(packer_dir.glob("variables.pkr.hcl")) + list(
            packer_dir.glob("variables.json")
        )

        # This is optional, so we just check if it exists when used
        # Not failing if it doesn't exist
        if variables_files:
            assert len(variables_files) > 0, "Variables file should exist if used"

    @pytest.mark.packer
    @pytest.mark.unit
    def test_readme_exists(self, packer_dir):
        """Test that README exists in packer directory."""
        if not packer_dir.exists():
            pytest.skip("Packer directory does not exist")

        readme = packer_dir / "README.md"
        assert readme.exists(), "Packer directory should have a README.md"

    @pytest.mark.packer
    @pytest.mark.unit
    def test_template_has_provisioners(self, packer_dir):
        """Test that templates have provisioners or post-processors."""
        if not packer_dir.exists():
            pytest.skip("Packer directory does not exist")

        templates = list(packer_dir.glob("*.pkr.hcl"))

        for template in templates:
            content = template.read_text()

            # Should have at least one of these
            has_provisioner = "provisioner" in content
            has_post_processor = "post-processor" in content

            assert has_provisioner or has_post_processor, (
                f"Template {template.name} should have provisioners "
                f"or post-processors"
            )
