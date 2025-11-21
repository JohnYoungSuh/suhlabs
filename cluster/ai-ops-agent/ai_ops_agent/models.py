"""
Core data models for AI Ops Agent
"""

from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field
from datetime import datetime
from enum import Enum


class IntentCategory(str, Enum):
    """Intent categories for infrastructure operations"""
    PROVISION = "provision"
    SECURITY = "security"
    IDENTITY = "identity"
    OBSERVABILITY = "observability"
    COMPLIANCE = "compliance"
    QUERY = "query"


class ActionType(str, Enum):
    """Action types"""
    CREATE = "create"
    UPDATE = "update"
    DELETE = "delete"
    ROTATE = "rotate"
    ISSUE = "issue"
    QUERY = "query"
    SCAN = "scan"
    LIST = "list"


class Intent(BaseModel):
    """Structured intent representation"""
    category: IntentCategory
    action: ActionType
    resource_type: str
    entities: Dict[str, str] = Field(default_factory=dict)
    confidence: float = Field(ge=0.0, le=1.0)
    raw_query: str


class ExecutionPlan(BaseModel):
    """Infrastructure execution plan"""
    intent: Intent
    playbook: Optional[str] = None
    terraform_module: Optional[str] = None
    variables: Dict[str, Any] = Field(default_factory=dict)
    requires_approval: bool = True
    environment: str = "development"
    description: str
    estimated_duration: Optional[str] = None
    rollback_plan: Optional[str] = None


class PolicyDecision(str, Enum):
    """MCP policy decisions"""
    ALLOW = "allow"
    DENY = "deny"
    REQUIRE_APPROVAL = "require_approval"


class PolicyResult(BaseModel):
    """Result of policy evaluation"""
    decision: PolicyDecision
    policy_name: str
    severity: str
    reason: str
    metadata: Dict = Field(default_factory=dict)


class UserContext(BaseModel):
    """User context for authorization"""
    user_id: str
    email: str
    roles: List[str] = Field(default_factory=list)
    mfa_enabled: bool = False
    department: Optional[str] = None


class ExecutionResult(BaseModel):
    """Result of execution"""
    success: bool
    summary: str
    error_message: Optional[str] = None
    error_type: Optional[str] = None
    resource_changes: Optional[Dict] = None
    terraform_output: Optional[str] = None
    ansible_output: Optional[str] = None
    duration_seconds: Optional[float] = None


class RAGContext(BaseModel):
    """Retrieved context from RAG pipeline"""
    content: str
    score: float
    metadata: Dict = Field(default_factory=dict)
    source_type: str  # doc, terraform, ansible, k8s, log, vault
    file_path: Optional[str] = None
