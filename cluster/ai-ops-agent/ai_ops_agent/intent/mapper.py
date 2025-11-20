"""
Action Mapper: Intent → Execution Plan
"""

from pathlib import Path
from typing import Dict, Optional
import yaml
import logging
from ..models import Intent, ExecutionPlan

logger = logging.getLogger(__name__)


class ActionMapper:
    """Map intents to Terraform/Ansible execution plans"""

    def __init__(self, mappings_path: Path):
        self.mappings_path = mappings_path
        self.mappings = self._load_mappings()

    def _load_mappings(self) -> Dict:
        """Load intent → action mappings from YAML"""
        try:
            with open(self.mappings_path) as f:
                mappings = yaml.safe_load(f)
                logger.info(f"Loaded {len(mappings)} intent mappings")
                return mappings
        except FileNotFoundError:
            logger.warning(f"Mappings file not found: {self.mappings_path}")
            return {}
        except yaml.YAMLError as e:
            logger.error(f"Failed to parse mappings YAML: {e}")
            return {}

    def map(self, intent: Intent) -> ExecutionPlan:
        """
        Map intent to execution plan

        Args:
            intent: Parsed intent

        Returns:
            ExecutionPlan with Terraform/Ansible actions

        Raises:
            ValueError: If no mapping found for intent
        """
        # Build lookup key
        key = f"{intent.category.value}.{intent.action.value}.{intent.resource_type}"

        logger.info(f"Looking up mapping for: {key}")

        # Find mapping
        mapping = self._find_mapping(key)

        if not mapping:
            raise ValueError(f"No mapping found for: {key}")

        # Build execution plan
        plan = ExecutionPlan(
            intent=intent,
            playbook=mapping.get("playbook"),
            terraform_module=mapping.get("terraform_module"),
            variables=self._merge_vars(
                mapping.get("default_vars", {}),
                intent.entities
            ),
            requires_approval=mapping.get("requires_approval", True),
            environment=intent.entities.get("environment", "development"),
            description=self._generate_description(intent),
            estimated_duration=mapping.get("estimated_duration"),
            rollback_plan=mapping.get("rollback_plan")
        )

        logger.info(f"Mapped to execution plan: {plan.description}")
        return plan

    def _find_mapping(self, key: str) -> Optional[Dict]:
        """Find mapping for key with fallback logic"""

        # Try exact match first
        parts = key.split(".")
        if len(parts) != 3:
            return None

        category, action, resource_type = parts

        # Navigate nested structure
        try:
            return self.mappings[category][action][resource_type]
        except (KeyError, TypeError):
            # Try wildcard resource type
            try:
                return self.mappings[category][action]["*"]
            except (KeyError, TypeError):
                return None

    def _merge_vars(self, default_vars: Dict, entities: Dict) -> Dict:
        """Merge default variables with extracted entities"""

        merged = default_vars.copy()

        # Entity values override defaults
        for key, value in entities.items():
            if value is not None:
                merged[key] = value

        return merged

    def _generate_description(self, intent: Intent) -> str:
        """Generate human-readable description"""

        action_desc = {
            "create": "Creating",
            "update": "Updating",
            "delete": "Deleting",
            "rotate": "Rotating",
            "issue": "Issuing",
            "query": "Querying",
            "scan": "Scanning",
            "list": "Listing"
        }.get(intent.action.value, "Processing")

        return f"{action_desc} {intent.resource_type}"

    def reload_mappings(self):
        """Reload mappings from file (for hot reload)"""
        self.mappings = self._load_mappings()
