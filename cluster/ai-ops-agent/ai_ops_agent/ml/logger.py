"""
ML Logger: Log queries, executions, and outcomes for continuous improvement
"""

from typing import Optional, Dict
from uuid import UUID, uuid4
from datetime import datetime
import logging
import json

logger = logging.getLogger(__name__)


class MLLogger:
    """
    Log all queries, executions, and outcomes for ML improvement

    Note: For MVP, logs to files. In production, use PostgreSQL.
    """

    def __init__(self, log_dir: str = "/var/log/ai-ops"):
        self.log_dir = log_dir
        self.queries_log = f"{log_dir}/queries.jsonl"
        self.executions_log = f"{log_dir}/executions.jsonl"
        self.outcomes_log = f"{log_dir}/outcomes.jsonl"
        self.feedback_log = f"{log_dir}/feedback.jsonl"
        self.policy_violations_log = f"{log_dir}/policy_violations.jsonl"

        # Ensure log directory exists
        import os
        os.makedirs(log_dir, exist_ok=True)

    async def log_query(
        self,
        user_id: str,
        query_text: str,
        parsed_intent: Dict,
        confidence: float,
        session_id: Optional[str] = None
    ) -> str:
        """
        Log user query

        Args:
            user_id: User ID
            query_text: Raw query text
            parsed_intent: Parsed intent dict
            confidence: Confidence score
            session_id: Session ID (optional)

        Returns:
            Query ID (UUID string)
        """

        query_id = str(uuid4())

        log_entry = {
            "id": query_id,
            "user_id": user_id,
            "query_text": query_text,
            "parsed_intent": parsed_intent,
            "confidence": confidence,
            "session_id": session_id,
            "timestamp": datetime.now().isoformat()
        }

        self._append_json_line(self.queries_log, log_entry)

        logger.info(f"Logged query {query_id}")
        return query_id

    async def log_execution(
        self,
        query_id: str,
        execution_plan: Dict,
        status: str = "pending"
    ) -> str:
        """
        Log execution plan

        Args:
            query_id: Associated query ID
            execution_plan: Execution plan dict
            status: Status (pending, running, success, failed)

        Returns:
            Execution ID (UUID string)
        """

        execution_id = str(uuid4())

        log_entry = {
            "id": execution_id,
            "query_id": query_id,
            "execution_plan": execution_plan,
            "status": status,
            "started_at": datetime.now().isoformat(),
            "completed_at": None
        }

        self._append_json_line(self.executions_log, log_entry)

        logger.info(f"Logged execution {execution_id}")
        return execution_id

    async def update_execution_status(
        self,
        execution_id: str,
        status: str,
        terraform_output: Optional[str] = None,
        ansible_output: Optional[str] = None
    ):
        """Update execution status (in-memory for MVP)"""

        # For MVP: Just log the update
        log_entry = {
            "execution_id": execution_id,
            "status": status,
            "terraform_output": terraform_output,
            "ansible_output": ansible_output,
            "completed_at": datetime.now().isoformat()
        }

        self._append_json_line(self.executions_log, log_entry)

        logger.info(f"Updated execution {execution_id} status: {status}")

    async def log_outcome(
        self,
        execution_id: str,
        success: bool,
        error_message: Optional[str] = None,
        error_type: Optional[str] = None,
        resource_changes: Optional[Dict] = None
    ):
        """
        Log execution outcome

        Args:
            execution_id: Execution ID
            success: Whether execution succeeded
            error_message: Error message if failed
            error_type: Error type
            resource_changes: Dict of resource changes
        """

        log_entry = {
            "execution_id": execution_id,
            "success": success,
            "error_message": error_message,
            "error_type": error_type,
            "resource_changes": resource_changes,
            "timestamp": datetime.now().isoformat()
        }

        self._append_json_line(self.outcomes_log, log_entry)

        logger.info(
            f"Logged outcome for execution {execution_id}: "
            f"{'success' if success else 'failure'}"
        )

    async def log_policy_violation(
        self,
        execution_id: str,
        policy_name: str,
        severity: str,
        decision: str,
        reason: str
    ):
        """
        Log policy violation

        Args:
            execution_id: Execution ID
            policy_name: Policy that was violated/triggered
            severity: Severity level
            decision: Decision (allow, deny, require_approval)
            reason: Human-readable reason
        """

        log_entry = {
            "execution_id": execution_id,
            "policy_name": policy_name,
            "severity": severity,
            "decision": decision,
            "reason": reason,
            "timestamp": datetime.now().isoformat()
        }

        self._append_json_line(self.policy_violations_log, log_entry)

        logger.info(
            f"Logged policy violation: {policy_name} ({decision}) "
            f"for execution {execution_id}"
        )

    async def log_feedback(
        self,
        query_id: str,
        execution_id: str,
        user_id: str,
        satisfaction_score: int,
        feedback_text: Optional[str] = None,
        intent_was_correct: Optional[bool] = None,
        corrected_intent: Optional[Dict] = None
    ):
        """
        Log user feedback

        Args:
            query_id: Query ID
            execution_id: Execution ID
            user_id: User ID
            satisfaction_score: 1-5 score
            feedback_text: Free-text feedback
            intent_was_correct: Whether intent parsing was correct
            corrected_intent: Corrected intent if wrong
        """

        log_entry = {
            "query_id": query_id,
            "execution_id": execution_id,
            "user_id": user_id,
            "satisfaction_score": satisfaction_score,
            "feedback_text": feedback_text,
            "intent_was_correct": intent_was_correct,
            "corrected_intent": corrected_intent,
            "timestamp": datetime.now().isoformat()
        }

        self._append_json_line(self.feedback_log, log_entry)

        logger.info(f"Logged feedback for query {query_id}")

        # If user corrected intent, create fine-tuning example
        if corrected_intent:
            await self._create_finetuning_example(query_id, corrected_intent)

    async def _create_finetuning_example(
        self,
        query_id: str,
        corrected_intent: Dict
    ):
        """Create fine-tuning training example from corrected intent"""

        # TODO: In production, add to fine-tuning dataset table
        logger.info(f"Created fine-tuning example from query {query_id}")

    def _append_json_line(self, file_path: str, data: Dict):
        """Append JSON line to file"""

        try:
            with open(file_path, 'a') as f:
                f.write(json.dumps(data) + '\n')
        except Exception as e:
            logger.error(f"Failed to write to {file_path}: {e}")
