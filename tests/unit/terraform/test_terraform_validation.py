"""
Unit tests for Terraform configuration validation.

These tests verify Terraform syntax, formatting, and basic validation
without actually creating infrastructure.
"""

import os
import subprocess
from pathlib import Path

import pytest


class TestTerraformSyntax:
    """Test Terraform syntax and formatting."""

    @pytest.fixture
    def terraform_dirs(self):
        """Return list of Terraform directories."""
        base_dir = Path(__file__).parent.parent.parent.parent
        return [
            base_dir / "infra" / "local",
            base_dir / "infra" / "proxmox",
        ]

    @pytest.mark.terraform
    @pytest.mark.unit
    def test_terraform_format(self, terraform_dirs):
        """Test that all Terraform files are properly formatted."""
        for tf_dir in terraform_dirs:
            if not tf_dir.exists():
                pytest.skip(f"Directory {tf_dir} does not exist")

            result = subprocess.run(
                ["terraform", "fmt", "-check", "-recursive", str(tf_dir)],
                capture_output=True,
                text=True,
            )

            assert result.returncode == 0, (
                f"Terraform files in {tf_dir} are not formatted.\n"
                f"Run 'terraform fmt -recursive' to fix.\n"
                f"Output: {result.stdout}\n{result.stderr}"
            )

    @pytest.mark.terraform
    @pytest.mark.unit
    def test_terraform_validate(self, terraform_dirs):
        """Test that Terraform configuration is valid."""
        for tf_dir in terraform_dirs:
            if not tf_dir.exists():
                pytest.skip(f"Directory {tf_dir} does not exist")

            # Initialize without backend
            init_result = subprocess.run(
                ["terraform", "init", "-backend=false"],
                cwd=tf_dir,
                capture_output=True,
                text=True,
            )

            assert init_result.returncode == 0, (
                f"Terraform init failed in {tf_dir}\n"
                f"Output: {init_result.stdout}\n{init_result.stderr}"
            )

            # Validate configuration
            validate_result = subprocess.run(
                ["terraform", "validate"],
                cwd=tf_dir,
                capture_output=True,
                text=True,
            )

            assert validate_result.returncode == 0, (
                f"Terraform validate failed in {tf_dir}\n"
                f"Output: {validate_result.stdout}\n{validate_result.stderr}"
            )

    @pytest.mark.terraform
    @pytest.mark.unit
    def test_terraform_files_exist(self, terraform_dirs):
        """Test that required Terraform files exist."""
        required_files = ["main.tf", "variables.tf", "outputs.tf"]

        for tf_dir in terraform_dirs:
            if not tf_dir.exists():
                pytest.skip(f"Directory {tf_dir} does not exist")

            for file_name in required_files:
                file_path = tf_dir / file_name
                assert file_path.exists(), (
                    f"Required file {file_name} not found in {tf_dir}"
                )

    @pytest.mark.terraform
    @pytest.mark.unit
    def test_no_hardcoded_secrets(self, terraform_dirs):
        """Test that no hardcoded secrets exist in Terraform files."""
        secret_patterns = [
            "password",
            "secret",
            "token",
            "api_key",
            "access_key",
        ]

        for tf_dir in terraform_dirs:
            if not tf_dir.exists():
                pytest.skip(f"Directory {tf_dir} does not exist")

            for tf_file in tf_dir.glob("**/*.tf"):
                content = tf_file.read_text().lower()

                for pattern in secret_patterns:
                    # Check if pattern exists but NOT in variable declaration
                    if f'= "{pattern}"' in content or f"= '{pattern}'" in content:
                        if "variable" not in content:
                            pytest.fail(
                                f"Possible hardcoded secret '{pattern}' "
                                f"found in {tf_file}"
                            )


class TestTerraformModules:
    """Test Terraform module structure."""

    @pytest.mark.terraform
    @pytest.mark.unit
    def test_module_documentation(self):
        """Test that modules have proper documentation."""
        base_dir = Path(__file__).parent.parent.parent.parent
        modules_dir = base_dir / "infra" / "modules"

        if not modules_dir.exists():
            pytest.skip("No modules directory found")

        for module_dir in modules_dir.iterdir():
            if module_dir.is_dir():
                readme = module_dir / "README.md"
                assert readme.exists(), (
                    f"Module {module_dir.name} missing README.md"
                )

    @pytest.mark.terraform
    @pytest.mark.unit
    def test_variable_descriptions(self, terraform_dirs):
        """Test that all variables have descriptions."""
        for tf_dir in terraform_dirs:
            if not tf_dir.exists():
                pytest.skip(f"Directory {tf_dir} does not exist")

            variables_file = tf_dir / "variables.tf"
            if not variables_file.exists():
                continue

            content = variables_file.read_text()

            # Simple check: if 'variable' exists, 'description' should exist nearby
            if "variable" in content:
                assert "description" in content, (
                    f"Variables in {variables_file} should have descriptions"
                )
