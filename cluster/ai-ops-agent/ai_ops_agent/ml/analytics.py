"""
ML Analytics: Analyze logs for insights and fine-tuning
"""

from typing import List, Dict
from datetime import datetime, timedelta
import json
import logging

logger = logging.getLogger(__name__)


class MLAnalytics:
    """Analyze ML logs for insights"""

    def __init__(self, log_dir: str = "/var/log/ai-ops"):
        self.log_dir = log_dir
        self.feedback_log = f"{log_dir}/feedback.jsonl"
        self.outcomes_log = f"{log_dir}/outcomes.jsonl"
        self.policy_violations_log = f"{log_dir}/policy_violations.jsonl"

    async def get_intent_accuracy(self, days: int = 7) -> Dict:
        """
        Calculate intent classification accuracy

        Args:
            days: Lookback period in days

        Returns:
            Accuracy metrics dict
        """

        cutoff = datetime.now() - timedelta(days=days)
        correct = 0
        incorrect = 0

        try:
            with open(self.feedback_log, 'r') as f:
                for line in f:
                    try:
                        entry = json.loads(line)

                        # Check timestamp
                        timestamp = datetime.fromisoformat(entry["timestamp"])
                        if timestamp < cutoff:
                            continue

                        # Check if intent was correct
                        if entry.get("intent_was_correct") is True:
                            correct += 1
                        elif entry.get("intent_was_correct") is False:
                            incorrect += 1

                    except (json.JSONDecodeError, KeyError, ValueError):
                        continue

        except FileNotFoundError:
            logger.warning(f"Feedback log not found: {self.feedback_log}")

        total = correct + incorrect

        return {
            "accuracy": correct / total if total > 0 else 0.0,
            "total_samples": total,
            "correct_predictions": correct,
            "incorrect_predictions": incorrect
        }

    async def get_error_patterns(self, limit: int = 10) -> List[Dict]:
        """
        Identify most common error patterns

        Args:
            limit: Max number of patterns to return

        Returns:
            List of error pattern dicts
        """

        error_counts = {}

        try:
            with open(self.outcomes_log, 'r') as f:
                for line in f:
                    try:
                        entry = json.loads(line)

                        if not entry.get("success", True):
                            error_type = entry.get("error_type", "unknown")
                            error_message = entry.get("error_message", "")

                            if error_type not in error_counts:
                                error_counts[error_type] = {
                                    "error_type": error_type,
                                    "count": 0,
                                    "sample_messages": []
                                }

                            error_counts[error_type]["count"] += 1

                            if len(error_counts[error_type]["sample_messages"]) < 3:
                                error_counts[error_type]["sample_messages"].append(
                                    error_message
                                )

                    except (json.JSONDecodeError, KeyError):
                        continue

        except FileNotFoundError:
            logger.warning(f"Outcomes log not found: {self.outcomes_log}")

        # Sort by count and return top N
        sorted_errors = sorted(
            error_counts.values(),
            key=lambda x: x["count"],
            reverse=True
        )

        return sorted_errors[:limit]

    async def get_policy_violation_trends(self, days: int = 30) -> List[Dict]:
        """
        Analyze policy violation trends

        Args:
            days: Lookback period in days

        Returns:
            List of violation trend dicts
        """

        cutoff = datetime.now() - timedelta(days=days)
        violations_by_policy = {}

        try:
            with open(self.policy_violations_log, 'r') as f:
                for line in f:
                    try:
                        entry = json.loads(line)

                        # Check timestamp
                        timestamp = datetime.fromisoformat(entry["timestamp"])
                        if timestamp < cutoff:
                            continue

                        policy_name = entry.get("policy_name", "unknown")
                        decision = entry.get("decision", "unknown")
                        severity = entry.get("severity", "unknown")

                        key = (policy_name, decision, severity)

                        if key not in violations_by_policy:
                            violations_by_policy[key] = {
                                "policy_name": policy_name,
                                "decision": decision,
                                "severity": severity,
                                "count": 0
                            }

                        violations_by_policy[key]["count"] += 1

                    except (json.JSONDecodeError, KeyError, ValueError):
                        continue

        except FileNotFoundError:
            logger.warning(f"Policy violations log not found: {self.policy_violations_log}")

        # Sort by count
        sorted_violations = sorted(
            violations_by_policy.values(),
            key=lambda x: x["count"],
            reverse=True
        )

        return sorted_violations

    async def get_user_satisfaction(self, days: int = 7) -> Dict:
        """
        Calculate user satisfaction metrics

        Args:
            days: Lookback period in days

        Returns:
            Satisfaction metrics dict
        """

        cutoff = datetime.now() - timedelta(days=days)
        scores = []

        try:
            with open(self.feedback_log, 'r') as f:
                for line in f:
                    try:
                        entry = json.loads(line)

                        # Check timestamp
                        timestamp = datetime.fromisoformat(entry["timestamp"])
                        if timestamp < cutoff:
                            continue

                        score = entry.get("satisfaction_score")
                        if score is not None:
                            scores.append(score)

                    except (json.JSONDecodeError, KeyError, ValueError):
                        continue

        except FileNotFoundError:
            logger.warning(f"Feedback log not found: {self.feedback_log}")

        if not scores:
            return {
                "average_score": 0.0,
                "total_feedback": 0,
                "satisfied_users": 0,
                "dissatisfied_users": 0,
                "satisfaction_rate": 0.0
            }

        satisfied = sum(1 for s in scores if s >= 4)
        dissatisfied = sum(1 for s in scores if s <= 2)

        return {
            "average_score": sum(scores) / len(scores),
            "total_feedback": len(scores),
            "satisfied_users": satisfied,
            "dissatisfied_users": dissatisfied,
            "satisfaction_rate": satisfied / len(scores)
        }
