"""
Unit tests for Ansible playbook validation.

These tests verify Ansible syntax, YAML formatting, and best practices
without actually running playbooks.
"""

import subprocess
from pathlib import Path

import pytest
import yaml


class TestAnsibleSyntax:
    """Test Ansible playbook syntax."""

    @pytest.fixture
    def ansible_dir(self):
        """Return Ansible directory path."""
        base_dir = Path(__file__).parent.parent.parent.parent
        return base_dir / "ansible"

    @pytest.fixture
    def playbooks(self, ansible_dir):
        """Return list of Ansible playbooks."""
        if not ansible_dir.exists():
            pytest.skip(f"Ansible directory {ansible_dir} does not exist")
        return list(ansible_dir.glob("*.yml")) + list(ansible_dir.glob("*.yaml"))

    @pytest.mark.ansible
    @pytest.mark.unit
    def test_ansible_syntax_check(self, playbooks):
        """Test that all playbooks pass syntax check."""
        if not playbooks:
            pytest.skip("No Ansible playbooks found")

        for playbook in playbooks:
            result = subprocess.run(
                ["ansible-playbook", "--syntax-check", str(playbook)],
                capture_output=True,
                text=True,
            )

            assert result.returncode == 0, (
                f"Syntax check failed for {playbook.name}\n"
                f"Output: {result.stdout}\n{result.stderr}"
            )

    @pytest.mark.ansible
    @pytest.mark.unit
    def test_yaml_valid(self, playbooks):
        """Test that all playbooks are valid YAML."""
        if not playbooks:
            pytest.skip("No Ansible playbooks found")

        for playbook in playbooks:
            try:
                with open(playbook, "r") as f:
                    yaml.safe_load(f)
            except yaml.YAMLError as e:
                pytest.fail(f"Invalid YAML in {playbook.name}: {e}")

    @pytest.mark.ansible
    @pytest.mark.unit
    def test_playbook_structure(self, playbooks):
        """Test that playbooks have proper structure."""
        if not playbooks:
            pytest.skip("No Ansible playbooks found")

        for playbook in playbooks:
            with open(playbook, "r") as f:
                content = yaml.safe_load(f)

            assert isinstance(content, list), (
                f"{playbook.name} should be a list of plays"
            )

            for play in content:
                assert isinstance(play, dict), (
                    f"Each play in {playbook.name} should be a dictionary"
                )

                # Check for required keys
                if "hosts" not in play and "import_playbook" not in play:
                    pytest.fail(
                        f"Play in {playbook.name} missing 'hosts' or 'import_playbook'"
                    )

    @pytest.mark.ansible
    @pytest.mark.unit
    def test_no_hardcoded_passwords(self, playbooks):
        """Test that no hardcoded passwords exist in playbooks."""
        password_indicators = ["password:", "passwd:", "secret:", "token:"]

        if not playbooks:
            pytest.skip("No Ansible playbooks found")

        for playbook in playbooks:
            content = playbook.read_text().lower()

            for indicator in password_indicators:
                if indicator in content:
                    # Check if it's using vault or variable
                    if "vault" not in content and "{{" not in content:
                        pytest.fail(
                            f"Possible hardcoded password in {playbook.name}. "
                            f"Use ansible-vault or variables."
                        )


class TestAnsibleInventory:
    """Test Ansible inventory files."""

    @pytest.fixture
    def inventory_files(self):
        """Return list of inventory files."""
        base_dir = Path(__file__).parent.parent.parent.parent
        inventory_dir = base_dir / "inventory"

        if not inventory_dir.exists():
            pytest.skip("Inventory directory does not exist")

        return list(inventory_dir.glob("*.yml")) + list(inventory_dir.glob("*.yaml"))

    @pytest.mark.ansible
    @pytest.mark.unit
    def test_inventory_valid_yaml(self, inventory_files):
        """Test that inventory files are valid YAML."""
        if not inventory_files:
            pytest.skip("No inventory files found")

        for inventory in inventory_files:
            try:
                with open(inventory, "r") as f:
                    yaml.safe_load(f)
            except yaml.YAMLError as e:
                pytest.fail(f"Invalid YAML in {inventory.name}: {e}")

    @pytest.mark.ansible
    @pytest.mark.unit
    def test_inventory_structure(self, inventory_files):
        """Test that inventory has proper structure."""
        if not inventory_files:
            pytest.skip("No inventory files found")

        for inventory in inventory_files:
            with open(inventory, "r") as f:
                content = yaml.safe_load(f)

            assert content is not None, f"{inventory.name} is empty"
            assert isinstance(content, dict), (
                f"{inventory.name} should be a dictionary"
            )


class TestAnsibleRoles:
    """Test Ansible roles structure."""

    @pytest.fixture
    def roles_dir(self):
        """Return roles directory path."""
        base_dir = Path(__file__).parent.parent.parent.parent
        return base_dir / "ansible" / "roles"

    @pytest.mark.ansible
    @pytest.mark.unit
    def test_role_structure(self, roles_dir):
        """Test that roles have proper directory structure."""
        if not roles_dir.exists():
            pytest.skip("Roles directory does not exist")

        for role_dir in roles_dir.iterdir():
            if not role_dir.is_dir():
                continue

            # Check for main task file
            tasks_dir = role_dir / "tasks"
            if tasks_dir.exists():
                main_yml = tasks_dir / "main.yml"
                assert main_yml.exists() or (tasks_dir / "main.yaml").exists(), (
                    f"Role {role_dir.name} missing tasks/main.yml"
                )

    @pytest.mark.ansible
    @pytest.mark.unit
    def test_role_metadata(self, roles_dir):
        """Test that roles have metadata."""
        if not roles_dir.exists():
            pytest.skip("Roles directory does not exist")

        for role_dir in roles_dir.iterdir():
            if not role_dir.is_dir():
                continue

            meta_file = role_dir / "meta" / "main.yml"
            if meta_file.exists():
                with open(meta_file, "r") as f:
                    metadata = yaml.safe_load(f)

                assert "galaxy_info" in metadata, (
                    f"Role {role_dir.name} missing galaxy_info in metadata"
                )
