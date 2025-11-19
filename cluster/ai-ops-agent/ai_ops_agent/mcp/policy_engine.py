"""
MCP Policy Engine: Evaluate execution plans against security/compliance policies
"""

from pathlib import Path
from typing import List, Dict
from datetime import datetime, time
import logging
import yaml
from ..models import ExecutionPlan, UserContext, PolicyDecision, PolicyResult

logger = logging.getLogger(__name__)


class PolicyEngine:
    """Evaluate execution plans against MCP policies"""

    def __init__(self, policies_path: Path):
        self.policies_path = policies_path
        self.policies = self._load_policies()

    def _load_policies(self) -> Dict:
        """Load policies from YAML"""
        try:
            with open(self.policies_path) as f:
                policies = yaml.safe_load(f)
                logger.info(f"Loaded MCP policies from {self.policies_path}")
                return policies
        except FileNotFoundError:
            logger.warning(f"Policies file not found: {self.policies_path}")
            return {}
        except yaml.YAMLError as e:
            logger.error(f"Failed to parse policies YAML: {e}")
            return {}

    async def evaluate(
        self,
        execution_plan: ExecutionPlan,
        user_context: UserContext
    ) -> List[PolicyResult]:
        """
        Evaluate plan against all applicable policies

        Args:
            execution_plan: Plan to execute
            user_context: User requesting execution

        Returns:
            List of policy evaluation results
        """
        logger.info(f"Evaluating policies for: {execution_plan.description}")

        results = []

        # Evaluate security policies
        if "security" in self.policies:
            results.extend(
                await self._check_security_policies(execution_plan, user_context)
            )

        # Evaluate compliance policies
        if "compliance" in self.policies:
            results.extend(
                await self._check_compliance_policies(execution_plan, user_context)
            )

        # Evaluate operational policies
        if "operational" in self.policies:
            results.extend(
                await self._check_operational_policies(execution_plan, user_context)
            )

        logger.info(f"Policy evaluation complete: {len(results)} results")
        return results

    async def _check_security_policies(
        self,
        plan: ExecutionPlan,
        user: UserContext
    ) -> List[PolicyResult]:
        """Check security-related policies"""

        results = []
        security_policies = self.policies.get("security", {})

        # No production deletion
        if security_policies.get("no_production_deletion", {}).get("enabled"):
            if (plan.intent.action.value == "delete" and
                plan.environment == "production"):

                results.append(PolicyResult(
                    decision=PolicyDecision.DENY,
                    policy_name="no_production_deletion",
                    severity="critical",
                    reason="Direct deletion of production resources is not allowed. "
                           "Use blue-green deployment or request manual approval."
                ))

        # Require MFA
        if security_policies.get("require_mfa", {}).get("enabled"):
            if not user.mfa_enabled and plan.requires_approval:
                results.append(PolicyResult(
                    decision=PolicyDecision.DENY,
                    policy_name="require_mfa",
                    severity="high",
                    reason="MFA is required for privileged operations. "
                           "Enable MFA on your account."
                ))

        # TLS required for websites
        if security_policies.get("tls_required", {}).get("enabled"):
            if (plan.intent.resource_type == "website" and
                not plan.variables.get("tls_enabled", True)):

                results.append(PolicyResult(
                    decision=PolicyDecision.DENY,
                    policy_name="tls_required",
                    severity="high",
                    reason="All websites must have TLS enabled"
                ))

        # No plain text secrets
        if security_policies.get("secrets_encryption", {}).get("enabled"):
            # Check for suspicious plain text patterns
            for key in plan.variables.keys():
                if any(word in key.lower() for word in ['password', 'secret', 'key', 'token']):
                    value = plan.variables.get(key, "")
                    if isinstance(value, str) and not value.startswith("vault:"):
                        results.append(PolicyResult(
                            decision=PolicyDecision.DENY,
                            policy_name="secrets_encryption",
                            severity="critical",
                            reason=f"Secret '{key}' must be stored in Vault, not plain text. "
                                   f"Use 'vault:<path>' format."
                        ))

        return results

    async def _check_compliance_policies(
        self,
        plan: ExecutionPlan,
        user: UserContext
    ) -> List[PolicyResult]:
        """Check compliance-related policies"""

        results = []
        compliance_policies = self.policies.get("compliance", {})

        # Resource tagging
        if compliance_policies.get("resource_tagging", {}).get("enabled"):
            required_tags = compliance_policies["resource_tagging"].get("required_tags", [])
            current_tags = plan.variables.get("tags", {})

            missing_tags = [tag for tag in required_tags if tag not in current_tags]

            if missing_tags:
                results.append(PolicyResult(
                    decision=PolicyDecision.DENY,
                    policy_name="resource_tagging",
                    severity="medium",
                    reason=f"Missing required tags: {', '.join(missing_tags)}. "
                           f"Add these tags to your resource.",
                    metadata={"missing_tags": missing_tags}
                ))

        # Audit logging for high-privilege operations
        if compliance_policies.get("audit_logging", {}).get("enabled"):
            if plan.requires_approval:
                results.append(PolicyResult(
                    decision=PolicyDecision.REQUIRE_APPROVAL,
                    policy_name="audit_logging",
                    severity="high",
                    reason="High-privilege operations require approval and audit logging"
                ))

        # Data residency
        if compliance_policies.get("data_residency", {}).get("enabled"):
            allowed_regions = compliance_policies["data_residency"].get("allowed_regions", [])
            resource_region = plan.variables.get("region")

            if resource_region and allowed_regions and resource_region not in allowed_regions:
                results.append(PolicyResult(
                    decision=PolicyDecision.DENY,
                    policy_name="data_residency",
                    severity="critical",
                    reason=f"Region '{resource_region}' is not in allowed regions: "
                           f"{', '.join(allowed_regions)}"
                ))

        return results

    async def _check_operational_policies(
        self,
        plan: ExecutionPlan,
        user: UserContext
    ) -> List[PolicyResult]:
        """Check operational-related policies"""

        results = []
        operational_policies = self.policies.get("operational", {})

        # Change windows
        if operational_policies.get("change_windows", {}).get("enabled"):
            if plan.environment == "production":
                allowed_windows = operational_policies["change_windows"].get("allowed_windows", [])

                if not self._is_in_change_window(allowed_windows):
                    results.append(PolicyResult(
                        decision=PolicyDecision.DENY,
                        policy_name="change_windows",
                        severity="medium",
                        reason="Production changes only allowed during change windows: "
                               "Monday & Wednesday 09:00-17:00 UTC"
                    ))

        # Rollback plan required
        if operational_policies.get("rollback_required", {}).get("enabled"):
            if plan.environment == "production" and not plan.rollback_plan:
                results.append(PolicyResult(
                    decision=PolicyDecision.REQUIRE_APPROVAL,
                    policy_name="rollback_required",
                    severity="high",
                    reason="Production changes require a rollback plan"
                ))

        return results

    def _is_in_change_window(self, allowed_windows: List[Dict]) -> bool:
        """Check if current time is in allowed change window"""

        now = datetime.now()
        current_day = now.strftime("%A").lower()
        current_time = now.time()

        for window in allowed_windows:
            if window.get("day", "").lower() == current_day:
                start = datetime.strptime(window["start"], "%H:%M").time()
                end = datetime.strptime(window["end"], "%H:%M").time()

                if start <= current_time <= end:
                    return True

        return False

    def make_final_decision(self, results: List[PolicyResult]) -> PolicyDecision:
        """
        Aggregate policy results into final decision

        Decision hierarchy:
        1. If any DENY → final decision is DENY
        2. If any REQUIRE_APPROVAL → final decision is REQUIRE_APPROVAL
        3. Otherwise → ALLOW
        """

        # Count by decision type
        deny_count = sum(1 for r in results if r.decision == PolicyDecision.DENY)
        approval_count = sum(1 for r in results if r.decision == PolicyDecision.REQUIRE_APPROVAL)

        logger.info(f"Policy decisions: {deny_count} DENY, {approval_count} REQUIRE_APPROVAL")

        if deny_count > 0:
            return PolicyDecision.DENY

        if approval_count > 0:
            return PolicyDecision.REQUIRE_APPROVAL

        return PolicyDecision.ALLOW

    def reload_policies(self):
        """Reload policies from file (for hot reload)"""
        self.policies = self._load_policies()
