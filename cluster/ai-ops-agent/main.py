"""
AI Ops/Sec Agent - Main Application

Conversational AI agent for infrastructure automation with:
- Natural language intent parsing
- RAG-based context retrieval
- MCP security guardrails
- Continuous ML improvement
"""

from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks
from pydantic import BaseModel, Field
from typing import Optional, List, Dict
from pathlib import Path
from datetime import datetime
import logging
import os

from ai_ops_agent.intent.parser import IntentParser
from ai_ops_agent.intent.mapper import ActionMapper
from ai_ops_agent.rag.retriever import RAGRetriever
from ai_ops_agent.mcp.policy_engine import PolicyEngine
from ai_ops_agent.mcp.approval import ApprovalWorkflow
from ai_ops_agent.ml.logger import MLLogger
from ai_ops_agent.ml.analytics import MLAnalytics
from ai_ops_agent.models import (
    Intent, ExecutionPlan, PolicyDecision, UserContext
)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="AI Ops/Sec Agent",
    version="2.0.0",
    description="Natural language infrastructure automation with RAG and MCP"
)

# Configuration
OLLAMA_HOST = os.getenv("OLLAMA_HOST", "http://localhost:11434")
QDRANT_HOST = os.getenv("QDRANT_HOST", "http://localhost:6333")
ML_LOG_DIR = os.getenv("ML_LOG_DIR", "/var/log/ai-ops")

# Initialize components
intent_parser = IntentParser(ollama_host=OLLAMA_HOST)
action_mapper = ActionMapper(mappings_path=Path("config/intent-mappings.yaml"))
rag_retriever = RAGRetriever(ollama_host=OLLAMA_HOST, qdrant_host=QDRANT_HOST)
policy_engine = PolicyEngine(policies_path=Path("config/mcp-policies.yaml"))
approval_workflow = ApprovalWorkflow()
ml_logger = MLLogger(log_dir=ML_LOG_DIR)
ml_analytics = MLAnalytics(log_dir=ML_LOG_DIR)

logger.info("AI Ops/Sec Agent initialized")


# Request/Response Models
class ChatRequest(BaseModel):
    """Chat request"""
    query: str = Field(..., description="Natural language request")
    user_id: str = Field(..., description="User ID")
    user_email: str = Field(..., description="User email")
    session_id: Optional[str] = Field(None, description="Session ID for tracking")
    mfa_enabled: bool = Field(default=False, description="Whether user has MFA enabled")


class ChatResponse(BaseModel):
    """Chat response"""
    response: str
    intent: Optional[Intent] = None
    execution_plan: Optional[Dict] = None
    policy_decision: Optional[str] = None
    approval_required: bool = False
    approval_id: Optional[str] = None
    query_id: Optional[str] = None


class FeedbackRequest(BaseModel):
    """Feedback request"""
    query_id: str
    execution_id: Optional[str] = None
    user_id: str
    satisfaction_score: int = Field(..., ge=1, le=5)
    feedback_text: Optional[str] = None
    intent_was_correct: Optional[bool] = None
    corrected_intent: Optional[Dict] = None


# Helper functions
async def _get_user_context(user_id: str, user_email: str, mfa_enabled: bool) -> UserContext:
    """Get user context for authorization"""
    return UserContext(
        user_id=user_id,
        email=user_email,
        roles=["user"],  # TODO: Fetch from auth system
        mfa_enabled=mfa_enabled,
        department=None
    )


async def _generate_informational_response(query: str, context: str) -> str:
    """Generate informational response using RAG context"""

    # For MVP: Return context-aware response
    # TODO: Use Ollama to generate natural language response

    response_parts = [
        f"Based on the suhlabs infrastructure documentation:\n",
        context[:1000],  # Limit to first 1000 chars
        f"\n\nFor more specific actions, try commands like:",
        "- 'Create an email address for user@suhlabs.io'",
        "- 'Deploy a website at domain.suhlabs.io'",
        "- 'Rotate Vault secrets'"
    ]

    return "\n".join(response_parts)


# API Endpoints
@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": "AI Ops/Sec Agent",
        "version": "2.0.0",
        "status": "operational",
        "capabilities": [
            "Natural language intent parsing",
            "RAG-based context retrieval",
            "MCP security guardrails",
            "Continuous ML improvement"
        ]
    }


@app.get("/health")
async def health():
    """Health check"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "environment": os.getenv("ENVIRONMENT", "development"),
        "components": {
            "ollama": OLLAMA_HOST,
            "qdrant": QDRANT_HOST,
            "ml_logs": ML_LOG_DIR
        }
    }


@app.get("/ready")
async def ready():
    """Readiness check"""

    # TODO: Check Ollama connectivity
    # TODO: Check Qdrant connectivity
    # TODO: Check Vault connectivity

    return {
        "ready": True,
        "timestamp": datetime.utcnow().isoformat()
    }


@app.post("/api/v1/chat", response_model=ChatResponse)
async def chat(request: ChatRequest, background_tasks: BackgroundTasks):
    """
    Main conversational endpoint

    Flow:
    1. Parse intent from natural language
    2. Retrieve context with RAG
    3. Map to execution plan
    4. Evaluate against MCP policies
    5. Execute or require approval
    6. Log everything for ML
    """

    logger.info(f"Chat request from {request.user_id}: {request.query[:100]}")

    try:
        # 1. Parse intent
        intent = await intent_parser.parse(request.query)

        logger.info(
            f"Parsed intent: {intent.category}.{intent.action}.{intent.resource_type} "
            f"(confidence: {intent.confidence:.2f})"
        )

        # 2. Retrieve context with RAG
        rag_contexts = await rag_retriever.retrieve(request.query, top_k=5)
        augmented_context = await rag_retriever.build_context(request.query, rag_contexts)

        logger.info(f"Retrieved {len(rag_contexts)} RAG contexts")

        # 3. Map to execution plan
        try:
            execution_plan = action_mapper.map(intent)
            logger.info(f"Mapped to execution plan: {execution_plan.description}")

        except ValueError as e:
            # No direct mapping - return informational response
            logger.info(f"No action mapping found: {e}")

            response_text = await _generate_informational_response(
                request.query,
                augmented_context
            )

            # Log query (even for informational requests)
            query_id = await ml_logger.log_query(
                user_id=request.user_id,
                query_text=request.query,
                parsed_intent=intent.dict(),
                confidence=intent.confidence,
                session_id=request.session_id
            )

            return ChatResponse(
                response=response_text,
                intent=intent,
                query_id=query_id
            )

        # 4. Log query
        query_id = await ml_logger.log_query(
            user_id=request.user_id,
            query_text=request.query,
            parsed_intent=intent.dict(),
            confidence=intent.confidence,
            session_id=request.session_id
        )

        # 5. Evaluate against MCP policies
        user_context = await _get_user_context(
            request.user_id,
            request.user_email,
            request.mfa_enabled
        )

        policy_results = await policy_engine.evaluate(execution_plan, user_context)
        final_decision = policy_engine.make_final_decision(policy_results)

        logger.info(f"Policy decision: {final_decision}")

        # 6. Log execution plan and policy results
        execution_id = await ml_logger.log_execution(
            query_id,
            execution_plan.dict(),
            status="pending"
        )

        for result in policy_results:
            await ml_logger.log_policy_violation(
                execution_id,
                result.policy_name,
                result.severity,
                result.decision.value,
                result.reason
            )

        # 7. Handle decision
        if final_decision == PolicyDecision.DENY:
            # Denied by policy
            deny_reasons = [
                r.reason for r in policy_results
                if r.decision == PolicyDecision.DENY
            ]

            response_text = "❌ **Request Denied**\n\n" + "\n".join(
                f"- {r}" for r in deny_reasons
            )

            # Log outcome
            await ml_logger.log_outcome(
                execution_id,
                success=False,
                error_message="Denied by policy",
                error_type="policy_violation"
            )

            return ChatResponse(
                response=response_text,
                intent=intent,
                execution_plan=execution_plan.dict(),
                policy_decision="denied",
                query_id=query_id
            )

        elif final_decision == PolicyDecision.REQUIRE_APPROVAL:
            # Requires approval
            approval_id = await approval_workflow.request_approval(
                execution_plan,
                user_context,
                policy_results
            )

            response_text = f"""⏳ **Approval Required**

Request ID: `{approval_id}`

Your request has been sent to approvers. You'll be notified when approved.

**What was requested:**
{execution_plan.description}

**Environment:** {execution_plan.environment}
**Estimated Duration:** {execution_plan.estimated_duration or 'Unknown'}

To check status: `/approval status {approval_id}`
"""

            return ChatResponse(
                response=response_text,
                intent=intent,
                execution_plan=execution_plan.dict(),
                policy_decision="requires_approval",
                approval_required=True,
                approval_id=approval_id,
                query_id=query_id
            )

        else:  # ALLOW
            # Execute immediately (for MVP, just return plan)
            # TODO: Implement actual Terraform/Ansible execution

            response_text = f"""✅ **Execution Approved**

**Action:** {execution_plan.description}
**Environment:** {execution_plan.environment}

**Execution Plan:**
"""

            if execution_plan.playbook:
                response_text += f"\n📋 Ansible Playbook: `{execution_plan.playbook}`"

            if execution_plan.terraform_module:
                response_text += f"\n🏗️  Terraform Module: `{execution_plan.terraform_module}`"

            response_text += f"\n\n**Variables:**\n```json\n{execution_plan.variables}\n```"

            response_text += f"\n\n⚠️ **Note:** For MVP, execution is manual. Use the playbook/module above."

            # Log successful outcome (for MVP - no actual execution yet)
            await ml_logger.log_outcome(
                execution_id,
                success=True,
                resource_changes={"status": "plan_generated"}
            )

            return ChatResponse(
                response=response_text,
                intent=intent,
                execution_plan=execution_plan.dict(),
                policy_decision="allowed",
                query_id=query_id
            )

    except Exception as e:
        logger.error(f"Error processing chat request: {e}", exc_info=True)

        raise HTTPException(
            status_code=500,
            detail=f"Internal error: {str(e)}"
        )


@app.post("/api/v1/feedback")
async def submit_feedback(request: FeedbackRequest):
    """Submit user feedback for ML improvement"""

    logger.info(f"Feedback from {request.user_id} for query {request.query_id}")

    try:
        await ml_logger.log_feedback(
            query_id=request.query_id,
            execution_id=request.execution_id or "none",
            user_id=request.user_id,
            satisfaction_score=request.satisfaction_score,
            feedback_text=request.feedback_text,
            intent_was_correct=request.intent_was_correct,
            corrected_intent=request.corrected_intent
        )

        return {
            "status": "success",
            "message": "Thank you for your feedback!"
        }

    except Exception as e:
        logger.error(f"Error logging feedback: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/approvals/pending")
async def list_pending_approvals(approver_email: Optional[str] = None):
    """List pending approval requests"""

    try:
        pending = await approval_workflow.list_pending_approvals(approver_email)

        return {
            "total": len(pending),
            "approvals": pending
        }

    except Exception as e:
        logger.error(f"Error listing approvals: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/v1/approvals/{approval_id}/approve")
async def approve_request(approval_id: str, approver_email: str):
    """Approve a request"""

    try:
        success = await approval_workflow.grant_approval(approval_id, approver_email)

        if success:
            return {
                "status": "success",
                "message": f"Approval {approval_id} granted"
            }
        else:
            raise HTTPException(
                status_code=400,
                detail="Failed to grant approval. Check approval ID and permissions."
            )

    except Exception as e:
        logger.error(f"Error granting approval: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/analytics/accuracy")
async def get_accuracy(days: int = 7):
    """Get intent classification accuracy"""

    try:
        accuracy = await ml_analytics.get_intent_accuracy(days=days)
        return accuracy

    except Exception as e:
        logger.error(f"Error getting accuracy: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/analytics/errors")
async def get_error_patterns(limit: int = 10):
    """Get common error patterns"""

    try:
        errors = await ml_analytics.get_error_patterns(limit=limit)
        return {"errors": errors}

    except Exception as e:
        logger.error(f"Error getting error patterns: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/analytics/policy-violations")
async def get_policy_violations(days: int = 30):
    """Get policy violation trends"""

    try:
        violations = await ml_analytics.get_policy_violation_trends(days=days)
        return {"violations": violations}

    except Exception as e:
        logger.error(f"Error getting violations: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/analytics/satisfaction")
async def get_satisfaction(days: int = 7):
    """Get user satisfaction metrics"""

    try:
        satisfaction = await ml_analytics.get_user_satisfaction(days=days)
        return satisfaction

    except Exception as e:
        logger.error(f"Error getting satisfaction: {e}")
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=os.getenv("ENVIRONMENT") == "development"
    )
