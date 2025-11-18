"""
Approval Workflow: Manage approval workflow for high-risk operations
"""

from typing import List, Optional, Dict
from datetime import datetime, timedelta
from uuid import uuid4
import logging
from ..models import ExecutionPlan, UserContext, PolicyResult

logger = logging.getLogger(__name__)


class ApprovalWorkflow:
    """Manage approval workflow for operations requiring approval"""

    def __init__(self):
        self.pending_approvals: Dict[str, Dict] = {}
        self.approvers_config = {
            "development": ["admin@suhlabs.io"],
            "staging": ["admin@suhlabs.io", "ops@suhlabs.io"],
            "production": ["admin@suhlabs.io", "ops@suhlabs.io", "security@suhlabs.io"]
        }

    async def request_approval(
        self,
        execution_plan: ExecutionPlan,
        user_context: UserContext,
        policy_results: List[PolicyResult]
    ) -> str:
        """
        Request approval from authorized approvers

        Args:
            execution_plan: Plan requiring approval
            user_context: User requesting execution
            policy_results: Policy evaluation results

        Returns:
            Approval request ID
        """

        # Generate approval request ID
        approval_id = f"APR-{datetime.now().strftime('%Y%m%d-%H%M%S')}-{uuid4().hex[:8]}"

        logger.info(f"Creating approval request: {approval_id}")

        # Find approvers for environment
        approvers = self._get_approvers(execution_plan.environment)

        # Create approval record
        self.pending_approvals[approval_id] = {
            "id": approval_id,
            "plan": execution_plan,
            "user": user_context,
            "approvers": approvers,
            "policy_results": policy_results,
            "created_at": datetime.now(),
            "expires_at": datetime.now() + timedelta(hours=24),
            "status": "pending",
            "approved_by": None,
            "approved_at": None,
            "denied_by": None,
            "denied_at": None,
            "denial_reason": None
        }

        # TODO: Send notifications to approvers (email, Slack, etc.)
        logger.info(
            f"Approval request {approval_id} sent to approvers: {', '.join(approvers)}"
        )

        return approval_id

    async def check_approval(self, approval_id: str) -> Optional[str]:
        """
        Check approval status

        Args:
            approval_id: Approval request ID

        Returns:
            Status: "approved", "denied", "expired", "pending", or None if not found
        """

        if approval_id not in self.pending_approvals:
            return None

        approval = self.pending_approvals[approval_id]

        # Check expiration
        if datetime.now() > approval["expires_at"] and approval["status"] == "pending":
            approval["status"] = "expired"
            logger.info(f"Approval request {approval_id} expired")

        return approval["status"]

    async def grant_approval(
        self,
        approval_id: str,
        approver_email: str
    ) -> bool:
        """
        Grant approval

        Args:
            approval_id: Approval request ID
            approver_email: Email of approver

        Returns:
            True if approval granted, False otherwise
        """

        if approval_id not in self.pending_approvals:
            logger.warning(f"Approval request not found: {approval_id}")
            return False

        approval = self.pending_approvals[approval_id]

        # Check if already decided
        if approval["status"] != "pending":
            logger.warning(f"Approval {approval_id} already {approval['status']}")
            return False

        # Verify approver is authorized
        if approver_email not in approval["approvers"]:
            logger.warning(
                f"Unauthorized approver {approver_email} for {approval_id}"
            )
            return False

        # Grant approval
        approval["status"] = "approved"
        approval["approved_by"] = approver_email
        approval["approved_at"] = datetime.now()

        logger.info(f"Approval {approval_id} granted by {approver_email}")

        # TODO: Send notification to requester

        return True

    async def deny_approval(
        self,
        approval_id: str,
        approver_email: str,
        reason: str
    ) -> bool:
        """
        Deny approval

        Args:
            approval_id: Approval request ID
            approver_email: Email of approver
            reason: Reason for denial

        Returns:
            True if denial recorded, False otherwise
        """

        if approval_id not in self.pending_approvals:
            logger.warning(f"Approval request not found: {approval_id}")
            return False

        approval = self.pending_approvals[approval_id]

        # Check if already decided
        if approval["status"] != "pending":
            logger.warning(f"Approval {approval_id} already {approval['status']}")
            return False

        # Verify approver is authorized
        if approver_email not in approval["approvers"]:
            logger.warning(
                f"Unauthorized approver {approver_email} for {approval_id}"
            )
            return False

        # Deny approval
        approval["status"] = "denied"
        approval["denied_by"] = approver_email
        approval["denied_at"] = datetime.now()
        approval["denial_reason"] = reason

        logger.info(f"Approval {approval_id} denied by {approver_email}: {reason}")

        # TODO: Send notification to requester

        return True

    async def get_approval(self, approval_id: str) -> Optional[Dict]:
        """Get approval details"""
        return self.pending_approvals.get(approval_id)

    async def list_pending_approvals(
        self,
        approver_email: Optional[str] = None
    ) -> List[Dict]:
        """
        List pending approvals

        Args:
            approver_email: Filter by approver (optional)

        Returns:
            List of pending approval requests
        """

        pending = []

        for approval_id, approval in self.pending_approvals.items():
            if approval["status"] != "pending":
                continue

            # Check expiration
            if datetime.now() > approval["expires_at"]:
                approval["status"] = "expired"
                continue

            # Filter by approver if specified
            if approver_email and approver_email not in approval["approvers"]:
                continue

            # Return serializable version
            pending.append({
                "id": approval_id,
                "description": approval["plan"].description,
                "requester": approval["user"].email,
                "environment": approval["plan"].environment,
                "created_at": approval["created_at"].isoformat(),
                "expires_at": approval["expires_at"].isoformat(),
                "approvers": approval["approvers"]
            })

        return pending

    def _get_approvers(self, environment: str) -> List[str]:
        """Get list of approvers for environment"""
        return self.approvers_config.get(environment, ["admin@suhlabs.io"])

    def cleanup_expired(self):
        """Remove expired approval requests (housekeeping)"""

        now = datetime.now()
        expired_cutoff = now - timedelta(days=7)  # Keep for 7 days

        to_remove = []

        for approval_id, approval in self.pending_approvals.items():
            if approval["created_at"] < expired_cutoff:
                to_remove.append(approval_id)

        for approval_id in to_remove:
            del self.pending_approvals[approval_id]
            logger.info(f"Removed old approval request: {approval_id}")

        if to_remove:
            logger.info(f"Cleaned up {len(to_remove)} old approval requests")
