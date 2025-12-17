# AI Ops/Sec Automation Architecture

**Version**: 1.0.0
**Date**: 2025-11-16
**Status**: Design Phase

---

## Executive Summary

This document outlines the architecture for an AI-powered Operations and Security automation system that translates natural language requests into secure, reproducible IT operations. The system integrates with the existing suhlabs infrastructure stack (Vault, Kubernetes, Terraform, Ansible) to provide a conversational interface for infrastructure automation.

**Core Capabilities:**
1. **Conversational Triggers**: Parse natural language → Infrastructure actions
2. **RAG Pipeline**: Context-aware responses using embedded configs, logs, and docs
3. **MCP Enforcement**: Model Control Protocol for compliance and security guardrails
4. **Continuous ML Loop**: Query logging and feedback for LLM fine-tuning

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         User Interface Layer                         │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐   │
│  │   CLI      │  │   API      │  │   Slack    │  │   WebUI    │   │
│  └──────┬─────┘  └──────┬─────┘  └──────┬─────┘  └──────┬─────┘   │
└─────────┼────────────────┼────────────────┼────────────────┼─────────┘
          │                │                │                │
          └────────────────┴────────────────┴────────────────┘
                                   │
          ┌────────────────────────▼─────────────────────────┐
          │        AI Ops/Sec Agent (FastAPI)                 │
          │                                                    │
          │  ┌──────────────────────────────────────────┐    │
          │  │  1. Conversational Trigger System        │    │
          │  │     - Intent Parser (NLU)                │    │
          │  │     - Entity Extractor                   │    │
          │  │     - Action Classifier                  │    │
          │  └──────────────┬───────────────────────────┘    │
          │                 │                                 │
          │  ┌──────────────▼───────────────────────────┐    │
          │  │  2. RAG Pipeline (Retrieval)             │    │
          │  │     - Query Embeddings (Ollama)          │    │
          │  │     - Vector Search (Qdrant)             │    │
          │  │     - Context Augmentation               │    │
          │  └──────────────┬───────────────────────────┘    │
          │                 │                                 │
          │  ┌──────────────▼───────────────────────────┐    │
          │  │  3. MCP Enforcement Layer                │    │
          │  │     - Policy Validator                   │    │
          │  │     - Security Guardrails                │    │
          │  │     - Approval Workflow                  │    │
          │  └──────────────┬───────────────────────────┘    │
          │                 │                                 │
          │  ┌──────────────▼───────────────────────────┐    │
          │  │  4. Execution Engine                     │    │
          │  │     - Terraform Runner                   │    │
          │  │     - Ansible Runner                     │    │
          │  │     - Kubectl Wrapper                    │    │
          │  │     - Vault Client                       │    │
          │  └──────────────┬───────────────────────────┘    │
          │                 │                                 │
          │  ┌──────────────▼───────────────────────────┐    │
          │  │  5. Continuous ML Logging                │    │
          │  │     - Query Logger                       │    │
          │  │     - Outcome Tracker                    │    │
          │  │     - Error Analyzer                     │    │
          │  │     - Feedback Collector                 │    │
          │  └──────────────────────────────────────────┘    │
          └────────────────────────────────────────────────────┘
                                   │
          ┌────────────────────────┴─────────────────────────┐
          │                                                   │
    ┌─────▼─────┐  ┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐
    │  Ollama   │  │   Qdrant    │  │   Vault     │  │  PostgreSQL │
    │   (LLM)   │  │  (VectorDB) │  │  (Secrets)  │  │  (ML Logs)  │
    └─────┬─────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘
          │                │                │                │
    ┌─────▼─────┐  ┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐
    │ Embeddings│  │ Embeddings  │  │  PKI Certs  │  │  Analytics  │
    │ Generation│  │   Storage   │  │  & Secrets  │  │  Dashboard  │
    └───────────┘  └─────────────┘  └─────────────┘  └─────────────┘
                                   │
          ┌────────────────────────┴─────────────────────────┐
          │           Infrastructure Layer                    │
          │                                                   │
    ┌─────▼─────┐  ┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐
    │ Terraform │  │   Ansible   │  │ Kubernetes  │  │    DNS      │
    │   (IaC)   │  │   (Config)  │  │   (K8s)     │  │  (CoreDNS)  │
    └───────────┘  └─────────────┘  └─────────────┘  └─────────────┘
```

---

## Component 1: Conversational Trigger System

### Purpose
Parse natural language requests and map them to infrastructure automation actions.

### Architecture

```python
# Intent Classification Pipeline

User Input → Preprocessor → Intent Classifier → Entity Extractor → Action Mapper → Execution Plan

Example Flow:
"Create me an email address for john@suhlabs.io"
  ↓
Preprocessor: Normalize, tokenize
  ↓
Intent Classifier: "provision_email" (confidence: 0.95)
  ↓
Entity Extractor: {
    "action": "create",
    "resource_type": "email",
    "username": "john",
    "domain": "suhlabs.io"
}
  ↓
Action Mapper: {
    "playbook": "ansible/playbooks/provision-email.yml",
    "vars": {"email": "john@suhlabs.io", "quota": "10GB"}
}
  ↓
Execution Plan: [
    "Run Ansible playbook",
    "Update DNS records",
    "Configure mail routing",
    "Store credentials in Vault"
]
```

### Intent Categories

| Intent Type | Natural Language Examples | Mapped Actions |
|-------------|---------------------------|----------------|
| **Provisioning** | "create email", "spin up cluster", "deploy website" | Terraform apply, Ansible playbook |
| **Security** | "rotate secrets", "issue cert", "enable mTLS" | Vault operations, cert-manager |
| **Identity** | "add user", "grant access", "create service account" | K8s RBAC, Vault policy |
| **Observability** | "show logs", "check metrics", "summarize incidents" | Query Loki, Prometheus |
| **Compliance** | "scan for CVEs", "generate SBOM", "audit access" | Trivy, Syft, audit logs |

### Implementation Components

#### 1.1 Intent Parser (`ai_ops_agent/intent/parser.py`)

```python
from typing import Dict, List, Tuple
from pydantic import BaseModel
import ollama

class Intent(BaseModel):
    """Structured intent representation"""
    category: str  # provision, security, identity, observability, compliance
    action: str    # create, update, delete, rotate, issue, query, etc.
    resource_type: str  # email, cluster, website, cert, user, etc.
    entities: Dict[str, str]  # Extracted parameters
    confidence: float

class IntentParser:
    """Parse natural language to structured intent"""

    def __init__(self, ollama_host: str):
        self.client = ollama.Client(host=ollama_host)
        self.model = "mistral"  # Or phi3, llama3

    async def parse(self, user_input: str) -> Intent:
        """Extract intent from natural language"""

        # Use Ollama with structured output
        prompt = f"""
        Parse this infrastructure request into structured format:

        User: {user_input}

        Extract:
        1. Category: [provision|security|identity|observability|compliance]
        2. Action: [create|update|delete|rotate|issue|query|scan]
        3. Resource Type: [email|cluster|website|cert|user|secret|etc]
        4. Entities: Key-value pairs of parameters

        Respond in JSON format.
        """

        response = await self.client.generate(
            model=self.model,
            prompt=prompt,
            format="json"
        )

        # Parse and validate
        intent_data = response['response']
        return Intent(**intent_data)
```

#### 1.2 Action Mapper (`ai_ops_agent/intent/mapper.py`)

```python
from typing import Dict, Optional
from pathlib import Path
import yaml

class ActionMapper:
    """Map intents to Terraform/Ansible actions"""

    def __init__(self, mappings_path: Path):
        self.mappings = self._load_mappings(mappings_path)

    def _load_mappings(self, path: Path) -> Dict:
        """Load intent → action mappings from YAML"""
        with open(path) as f:
            return yaml.safe_load(f)

    def map(self, intent: Intent) -> ExecutionPlan:
        """Map intent to execution plan"""

        # Lookup mapping
        key = f"{intent.category}.{intent.action}.{intent.resource_type}"
        mapping = self.mappings.get(key)

        if not mapping:
            raise ValueError(f"No mapping found for: {key}")

        # Build execution plan
        return ExecutionPlan(
            playbook=mapping['playbook'],
            terraform_module=mapping.get('terraform_module'),
            variables=self._merge_vars(mapping['default_vars'], intent.entities),
            requires_approval=mapping.get('requires_approval', True)
        )
```

#### 1.3 Intent Mapping Configuration (`config/intent-mappings.yaml`)

```yaml
# Natural Language → Infrastructure Actions

provision:
  create:
    email:
      playbook: "ansible/playbooks/provision-email.yml"
      default_vars:
        quota: "10GB"
        backup: true
      requires_approval: true

    website:
      terraform_module: "infra/modules/static-website"
      playbook: "ansible/playbooks/deploy-website.yml"
      default_vars:
        tls_enabled: true
        cdn_enabled: false
      requires_approval: true

    cluster:
      terraform_module: "infra/modules/k8s-cluster"
      default_vars:
        node_count: 3
        instance_type: "t3.medium"
      requires_approval: true

security:
  rotate:
    secrets:
      playbook: "ansible/playbooks/rotate-vault-secrets.yml"
      requires_approval: true

  issue:
    cert:
      playbook: "ansible/playbooks/issue-certificate.yml"
      default_vars:
        ttl: "30d"
        auto_renew: true
      requires_approval: false  # Automated

identity:
  create:
    user:
      playbook: "ansible/playbooks/create-user.yml"
      terraform_module: "infra/modules/user-account"
      default_vars:
        mfa_enabled: true
      requires_approval: true

observability:
  query:
    logs:
      api_endpoint: "/api/v1/logs/query"
      requires_approval: false

compliance:
  scan:
    vulnerabilities:
      playbook: "ansible/playbooks/scan-vulnerabilities.yml"
      requires_approval: false
```

---

## Component 2: RAG Pipeline (Retrieval-Augmented Generation)

### Purpose
Provide context-aware responses by retrieving relevant configs, logs, and documentation from a vector database.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    RAG Pipeline Flow                             │
└─────────────────────────────────────────────────────────────────┘

1. Indexing Phase (Offline)
   ┌──────────────┐
   │  Data Source │ → Configs, Logs, Docs, Playbooks
   └──────┬───────┘
          │
   ┌──────▼───────┐
   │  Chunker     │ → Split into 512-token chunks
   └──────┬───────┘
          │
   ┌──────▼───────┐
   │  Embeddings  │ → Ollama (nomic-embed-text)
   └──────┬───────┘
          │
   ┌──────▼───────┐
   │   Qdrant     │ → Store vectors + metadata
   └──────────────┘

2. Query Phase (Online)
   ┌──────────────┐
   │  User Query  │ → "How do I rotate Vault secrets?"
   └──────┬───────┘
          │
   ┌──────▼───────┐
   │  Embeddings  │ → Convert query to vector
   └──────┬───────┘
          │
   ┌──────▼───────┐
   │  Vector      │ → Find top-k similar chunks
   │  Search      │
   └──────┬───────┘
          │
   ┌──────▼───────┐
   │  Reranker    │ → Score by relevance
   └──────┬───────┘
          │
   ┌──────▼───────┐
   │  Context     │ → Augment LLM prompt
   │  Builder     │
   └──────┬───────┘
          │
   ┌──────▼───────┐
   │  LLM         │ → Generate context-aware response
   │  Generation  │
   └──────────────┘
```

### Data Sources for Indexing

| Source Type | Location | Update Frequency | Metadata |
|-------------|----------|------------------|----------|
| **Documentation** | `docs/*.md` | On commit | `{type: "doc", category: "guide"}` |
| **Terraform** | `infra/**/*.tf` | On commit | `{type: "terraform", module: "..."}` |
| **Ansible** | `ansible/**/*.yml` | On commit | `{type: "ansible", role: "..."}` |
| **Kubernetes** | `cluster/**/*.yaml` | On commit | `{type: "k8s", kind: "..."}` |
| **Logs** | Loki queries | Every 5 min | `{type: "log", level: "error"}` |
| **Vault Configs** | Vault API | Every 10 min | `{type: "vault", secret_path: "..."}` |

### Implementation Components

#### 2.1 Document Indexer (`ai_ops_agent/rag/indexer.py`)

```python
from pathlib import Path
from typing import List, Dict
import ollama
from qdrant_client import QdrantClient
from qdrant_client.models import PointStruct, VectorParams, Distance

class DocumentIndexer:
    """Index documents into Qdrant vector database"""

    def __init__(self, ollama_host: str, qdrant_host: str):
        self.ollama = ollama.Client(host=ollama_host)
        self.qdrant = QdrantClient(url=qdrant_host)
        self.embedding_model = "nomic-embed-text"
        self.collection_name = "suhlabs-knowledge"

    async def initialize_collection(self):
        """Create Qdrant collection if not exists"""
        collections = await self.qdrant.get_collections()

        if self.collection_name not in [c.name for c in collections.collections]:
            await self.qdrant.create_collection(
                collection_name=self.collection_name,
                vectors_config=VectorParams(
                    size=768,  # nomic-embed-text dimension
                    distance=Distance.COSINE
                )
            )

    async def index_directory(self, directory: Path, doc_type: str):
        """Index all files in a directory"""

        for file_path in directory.rglob("*"):
            if file_path.is_file():
                await self.index_file(file_path, doc_type)

    async def index_file(self, file_path: Path, doc_type: str):
        """Index a single file"""

        # Read content
        content = file_path.read_text()

        # Chunk content (512 tokens per chunk)
        chunks = self._chunk_text(content, max_tokens=512)

        # Generate embeddings
        points = []
        for i, chunk in enumerate(chunks):
            embedding = await self._embed(chunk)

            point = PointStruct(
                id=f"{file_path}_{i}",
                vector=embedding,
                payload={
                    "type": doc_type,
                    "file_path": str(file_path),
                    "chunk_index": i,
                    "content": chunk,
                    "metadata": self._extract_metadata(file_path, chunk)
                }
            )
            points.append(point)

        # Upload to Qdrant
        await self.qdrant.upsert(
            collection_name=self.collection_name,
            points=points
        )

    async def _embed(self, text: str) -> List[float]:
        """Generate embedding vector for text"""
        response = await self.ollama.embeddings(
            model=self.embedding_model,
            prompt=text
        )
        return response['embedding']

    def _chunk_text(self, text: str, max_tokens: int) -> List[str]:
        """Split text into chunks"""
        # Simple sentence-based chunking
        sentences = text.split('. ')
        chunks = []
        current_chunk = []
        current_length = 0

        for sentence in sentences:
            sentence_length = len(sentence.split())

            if current_length + sentence_length > max_tokens:
                chunks.append('. '.join(current_chunk))
                current_chunk = [sentence]
                current_length = sentence_length
            else:
                current_chunk.append(sentence)
                current_length += sentence_length

        if current_chunk:
            chunks.append('. '.join(current_chunk))

        return chunks
```

#### 2.2 RAG Retriever (`ai_ops_agent/rag/retriever.py`)

```python
from typing import List, Dict
from qdrant_client import QdrantClient
from qdrant_client.models import Filter, FieldCondition, MatchValue

class RAGRetriever:
    """Retrieve relevant context for queries"""

    def __init__(self, ollama_host: str, qdrant_host: str):
        self.ollama = ollama.Client(host=ollama_host)
        self.qdrant = QdrantClient(url=qdrant_host)
        self.embedding_model = "nomic-embed-text"
        self.collection_name = "suhlabs-knowledge"

    async def retrieve(
        self,
        query: str,
        top_k: int = 5,
        filter_type: Optional[str] = None
    ) -> List[Dict]:
        """Retrieve top-k relevant chunks"""

        # Generate query embedding
        query_vector = await self._embed(query)

        # Build filter
        query_filter = None
        if filter_type:
            query_filter = Filter(
                must=[
                    FieldCondition(
                        key="type",
                        match=MatchValue(value=filter_type)
                    )
                ]
            )

        # Search Qdrant
        results = await self.qdrant.search(
            collection_name=self.collection_name,
            query_vector=query_vector,
            limit=top_k,
            query_filter=query_filter
        )

        # Extract context
        contexts = []
        for result in results:
            contexts.append({
                "content": result.payload["content"],
                "score": result.score,
                "metadata": result.payload["metadata"]
            })

        return contexts

    async def build_context(
        self,
        query: str,
        retrieved_chunks: List[Dict]
    ) -> str:
        """Build augmented context for LLM"""

        context_parts = ["# Relevant Context\n"]

        for i, chunk in enumerate(retrieved_chunks, 1):
            context_parts.append(f"## Source {i} (relevance: {chunk['score']:.2f})")
            context_parts.append(chunk['content'])
            context_parts.append("")

        context_parts.append(f"# User Query\n{query}")

        return "\n".join(context_parts)
```

#### 2.3 Indexing Cron Job (`cluster/ai-ops-agent/cronjobs/indexer.yaml`)

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: rag-indexer
  namespace: ai-ops
spec:
  schedule: "*/10 * * * *"  # Every 10 minutes
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: indexer
            image: ghcr.io/johnyoungsuh/ai-ops-agent:latest
            command:
            - python
            - -m
            - ai_ops_agent.rag.indexer
            env:
            - name: OLLAMA_HOST
              value: "http://ollama:11434"
            - name: QDRANT_HOST
              value: "http://qdrant:6333"
            - name: INDEX_PATHS
              value: "/workspace/docs,/workspace/infra,/workspace/ansible"
            volumeMounts:
            - name: workspace
              mountPath: /workspace
              readOnly: true
          volumes:
          - name: workspace
            persistentVolumeClaim:
              claimName: suhlabs-workspace
          restartPolicy: OnFailure
```

---

## Component 3: MCP Enforcement (Model Control Protocol)

### Purpose
Ensure the AI agent respects compliance, security, and operational guardrails before executing infrastructure changes.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    MCP Enforcement Flow                          │
└─────────────────────────────────────────────────────────────────┘

User Request → Intent Parser → MCP Validator → Execution (if allowed)
                                     ↓
                            ┌────────┴────────┐
                            │   Policy Check   │
                            └────────┬────────┘
                                     │
                    ┌────────────────┼────────────────┐
                    │                │                │
            ┌───────▼──────┐  ┌──────▼──────┐  ┌─────▼──────┐
            │   Security   │  │ Compliance  │  │ Operational│
            │   Policies   │  │   Policies  │  │  Policies  │
            └───────┬──────┘  └──────┬──────┘  └─────┬──────┘
                    │                │                │
                    └────────────────┼────────────────┘
                                     │
                            ┌────────▼────────┐
                            │  Decision Engine │
                            └────────┬────────┘
                                     │
                    ┌────────────────┼────────────────┐
                    │                │                │
            ┌───────▼──────┐  ┌──────▼──────┐  ┌─────▼──────┐
            │   ALLOW      │  │   DENY      │  │  REQUIRE   │
            │   Execute    │  │   Reject    │  │  APPROVAL  │
            └──────────────┘  └─────────────┘  └────────────┘
```

### Policy Categories

#### 3.1 Security Policies

| Policy | Description | Enforcement |
|--------|-------------|-------------|
| **No Production Deletion** | Block deletion of production resources | DENY |
| **Require MFA** | User must have MFA enabled | ALLOW with MFA |
| **Secrets Encryption** | All secrets must be Vault-backed | DENY if plain text |
| **TLS Required** | All services must use TLS | DENY if HTTP |
| **RBAC Least Privilege** | Users get minimal permissions | REQUIRE APPROVAL |

#### 3.2 Compliance Policies

| Policy | Description | Enforcement |
|--------|-------------|-------------|
| **Audit Logging** | All actions must be logged | REQUIRE APPROVAL |
| **Data Residency** | Data must stay in allowed regions | DENY if wrong region |
| **Resource Tagging** | All resources must have owner tag | DENY if untagged |
| **Cost Limits** | Respect budget constraints | DENY if over budget |

#### 3.3 Operational Policies

| Policy | Description | Enforcement |
|--------|-------------|-------------|
| **Change Windows** | Infrastructure changes only during windows | DENY outside window |
| **Rollback Required** | All changes must be reversible | REQUIRE APPROVAL |
| **Testing Required** | Changes tested in staging first | DENY if not tested |
| **Rate Limiting** | Max N operations per hour | DENY if exceeded |

### Implementation Components

#### 3.1 Policy Engine (`ai_ops_agent/mcp/policy_engine.py`)

```python
from typing import List, Optional, Dict
from enum import Enum
from pydantic import BaseModel
import yaml

class PolicyDecision(str, Enum):
    ALLOW = "allow"
    DENY = "deny"
    REQUIRE_APPROVAL = "require_approval"

class PolicyResult(BaseModel):
    decision: PolicyDecision
    policy_name: str
    reason: str
    metadata: Dict = {}

class PolicyEngine:
    """Evaluate execution plans against policies"""

    def __init__(self, policies_path: Path):
        self.policies = self._load_policies(policies_path)

    def _load_policies(self, path: Path) -> Dict:
        """Load policies from YAML"""
        with open(path) as f:
            return yaml.safe_load(f)

    async def evaluate(
        self,
        execution_plan: ExecutionPlan,
        user_context: UserContext
    ) -> List[PolicyResult]:
        """Evaluate plan against all applicable policies"""

        results = []

        # Security policies
        results.extend(await self._check_security_policies(execution_plan, user_context))

        # Compliance policies
        results.extend(await self._check_compliance_policies(execution_plan, user_context))

        # Operational policies
        results.extend(await self._check_operational_policies(execution_plan, user_context))

        return results

    async def _check_security_policies(
        self,
        plan: ExecutionPlan,
        user: UserContext
    ) -> List[PolicyResult]:
        """Check security-related policies"""

        results = []

        # Example: No production deletion
        if plan.action == "delete" and plan.environment == "production":
            results.append(PolicyResult(
                decision=PolicyDecision.DENY,
                policy_name="no_production_deletion",
                reason="Direct deletion of production resources is not allowed"
            ))

        # Example: Require MFA
        if not user.mfa_enabled and plan.requires_approval:
            results.append(PolicyResult(
                decision=PolicyDecision.DENY,
                policy_name="require_mfa",
                reason="MFA is required for privileged operations"
            ))

        # Example: TLS required
        if plan.resource_type == "website" and not plan.variables.get("tls_enabled"):
            results.append(PolicyResult(
                decision=PolicyDecision.DENY,
                policy_name="tls_required",
                reason="All websites must have TLS enabled"
            ))

        return results

    async def _check_compliance_policies(
        self,
        plan: ExecutionPlan,
        user: UserContext
    ) -> List[PolicyResult]:
        """Check compliance-related policies"""

        results = []

        # Example: Resource tagging
        required_tags = ["owner", "project", "environment"]
        missing_tags = [
            tag for tag in required_tags
            if tag not in plan.variables.get("tags", {})
        ]

        if missing_tags:
            results.append(PolicyResult(
                decision=PolicyDecision.DENY,
                policy_name="resource_tagging",
                reason=f"Missing required tags: {', '.join(missing_tags)}",
                metadata={"missing_tags": missing_tags}
            ))

        return results

    def make_final_decision(self, results: List[PolicyResult]) -> PolicyDecision:
        """Aggregate policy results into final decision"""

        # If any policy says DENY, final decision is DENY
        if any(r.decision == PolicyDecision.DENY for r in results):
            return PolicyDecision.DENY

        # If any policy says REQUIRE_APPROVAL, final decision is REQUIRE_APPROVAL
        if any(r.decision == PolicyDecision.REQUIRE_APPROVAL for r in results):
            return PolicyDecision.REQUIRE_APPROVAL

        # Otherwise, ALLOW
        return PolicyDecision.ALLOW
```

#### 3.2 Policy Configuration (`config/mcp-policies.yaml`)

```yaml
# Model Control Protocol Policies

security:
  no_production_deletion:
    enabled: true
    severity: critical
    rule: |
      action == "delete" AND environment == "production"
    decision: deny
    message: "Direct deletion of production resources is not allowed. Use blue-green deployment."

  require_mfa:
    enabled: true
    severity: high
    rule: |
      user.mfa_enabled == false AND plan.requires_approval == true
    decision: deny
    message: "MFA is required for privileged operations"

  tls_required:
    enabled: true
    severity: high
    rule: |
      resource_type == "website" AND variables.tls_enabled != true
    decision: deny
    message: "All websites must have TLS enabled"

  secrets_encryption:
    enabled: true
    severity: critical
    rule: |
      variables contains plain_text_secret
    decision: deny
    message: "Secrets must be stored in Vault, not plain text"

compliance:
  resource_tagging:
    enabled: true
    severity: medium
    required_tags:
      - owner
      - project
      - environment
      - cost_center
    decision: deny
    message: "All resources must be properly tagged"

  audit_logging:
    enabled: true
    severity: high
    rule: |
      plan.requires_approval == true
    decision: require_approval
    message: "High-privilege operations require approval and audit"

  data_residency:
    enabled: true
    severity: critical
    allowed_regions:
      - us-east-1
      - eu-west-1
    rule: |
      variables.region NOT IN allowed_regions
    decision: deny
    message: "Data must reside in compliant regions"

operational:
  change_windows:
    enabled: true
    severity: medium
    allowed_windows:
      - day: monday
        start: "09:00"
        end: "17:00"
      - day: wednesday
        start: "09:00"
        end: "17:00"
    rule: |
      current_time NOT IN allowed_windows AND environment == "production"
    decision: deny
    message: "Production changes only allowed during change windows"

  rate_limiting:
    enabled: true
    severity: medium
    limits:
      provision: 10  # per hour
      delete: 5      # per hour
      rotate: 20     # per hour
    decision: deny
    message: "Rate limit exceeded. Contact admin for increase."

  rollback_required:
    enabled: true
    severity: high
    rule: |
      plan.has_rollback_plan == false AND environment == "production"
    decision: require_approval
    message: "Production changes require rollback plan"
```

#### 3.3 Approval Workflow (`ai_ops_agent/mcp/approval.py`)

```python
from typing import Optional
from datetime import datetime, timedelta
import asyncio

class ApprovalWorkflow:
    """Manage approval workflow for high-risk operations"""

    def __init__(self, notification_service):
        self.notification = notification_service
        self.pending_approvals = {}

    async def request_approval(
        self,
        execution_plan: ExecutionPlan,
        user_context: UserContext,
        policy_results: List[PolicyResult]
    ) -> str:
        """Request approval from authorized approvers"""

        # Generate approval request ID
        approval_id = f"APR-{datetime.now().strftime('%Y%m%d-%H%M%S')}"

        # Find approvers
        approvers = await self._get_approvers(execution_plan.environment)

        # Send notifications
        for approver in approvers:
            await self.notification.send(
                to=approver.email,
                subject=f"Approval Required: {execution_plan.description}",
                body=self._format_approval_request(
                    approval_id,
                    execution_plan,
                    user_context,
                    policy_results
                )
            )

        # Store pending approval
        self.pending_approvals[approval_id] = {
            "plan": execution_plan,
            "user": user_context,
            "approvers": approvers,
            "created_at": datetime.now(),
            "expires_at": datetime.now() + timedelta(hours=24),
            "status": "pending"
        }

        return approval_id

    async def check_approval(self, approval_id: str) -> Optional[bool]:
        """Check if approval has been granted"""

        if approval_id not in self.pending_approvals:
            return None

        approval = self.pending_approvals[approval_id]

        # Check expiration
        if datetime.now() > approval["expires_at"]:
            approval["status"] = "expired"
            return False

        return approval["status"] == "approved"

    async def grant_approval(
        self,
        approval_id: str,
        approver: UserContext
    ) -> bool:
        """Grant approval (called by approver)"""

        if approval_id not in self.pending_approvals:
            return False

        approval = self.pending_approvals[approval_id]

        # Verify approver is authorized
        if approver.email not in [a.email for a in approval["approvers"]]:
            return False

        # Grant approval
        approval["status"] = "approved"
        approval["approved_by"] = approver.email
        approval["approved_at"] = datetime.now()

        # Notify requester
        await self.notification.send(
            to=approval["user"].email,
            subject=f"Approval Granted: {approval_id}",
            body=f"Your request has been approved by {approver.email}"
        )

        return True
```

---

## Component 4: Continuous ML Logging

### Purpose
Capture all queries, outcomes, and errors to create a feedback loop for fine-tuning the LLM.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                  Continuous ML Logging Flow                      │
└─────────────────────────────────────────────────────────────────┘

User Query → Agent Processing → Execution → Outcome
     │               │              │          │
     ▼               ▼              ▼          ▼
┌────────────────────────────────────────────────┐
│            PostgreSQL ML Logs DB                │
│                                                 │
│  Tables:                                        │
│  - queries (user input, intent, timestamp)      │
│  - executions (plan, terraform/ansible output)  │
│  - outcomes (success/failure, errors)           │
│  - feedback (user satisfaction, corrections)    │
└────────────────┬───────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────────┐
│         Analytics & Fine-Tuning Pipeline        │
│                                                 │
│  1. Error Pattern Analysis                      │
│  2. Intent Classification Accuracy              │
│  3. Policy Violation Trends                     │
│  4. User Satisfaction Metrics                   │
│  5. Dataset Generation for Fine-Tuning          │
└────────────────┬───────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────────┐
│        LLM Fine-Tuning (Periodic)               │
│                                                 │
│  Input: Historical query/intent pairs           │
│  Output: Fine-tuned model for better accuracy   │
└─────────────────────────────────────────────────┘
```

### Data Model

#### 4.1 Database Schema (`ai_ops_agent/ml/schema.sql`)

```sql
-- User queries
CREATE TABLE queries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(255) NOT NULL,
    query_text TEXT NOT NULL,
    parsed_intent JSONB,
    confidence FLOAT,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    session_id UUID,
    INDEX idx_user_id (user_id),
    INDEX idx_timestamp (timestamp)
);

-- Execution plans
CREATE TABLE executions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    query_id UUID REFERENCES queries(id),
    execution_plan JSONB NOT NULL,
    terraform_output TEXT,
    ansible_output TEXT,
    status VARCHAR(50),  -- pending, running, success, failed
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    INDEX idx_query_id (query_id),
    INDEX idx_status (status)
);

-- Outcomes and errors
CREATE TABLE outcomes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    execution_id UUID REFERENCES executions(id),
    success BOOLEAN NOT NULL,
    error_message TEXT,
    error_type VARCHAR(100),
    stack_trace TEXT,
    resource_changes JSONB,  -- Created, updated, deleted resources
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    INDEX idx_execution_id (execution_id),
    INDEX idx_success (success)
);

-- User feedback
CREATE TABLE feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    query_id UUID REFERENCES queries(id),
    execution_id UUID REFERENCES executions(id),
    user_id VARCHAR(255) NOT NULL,
    satisfaction_score INT CHECK (satisfaction_score BETWEEN 1 AND 5),
    feedback_text TEXT,
    intent_was_correct BOOLEAN,
    corrected_intent JSONB,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    INDEX idx_query_id (query_id),
    INDEX idx_user_id (user_id)
);

-- Policy violations
CREATE TABLE policy_violations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    execution_id UUID REFERENCES executions(id),
    policy_name VARCHAR(255) NOT NULL,
    severity VARCHAR(50),
    decision VARCHAR(50),  -- allow, deny, require_approval
    reason TEXT,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    INDEX idx_execution_id (execution_id),
    INDEX idx_policy_name (policy_name)
);

-- Fine-tuning datasets
CREATE TABLE finetuning_datasets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    query_id UUID REFERENCES queries(id),
    input_text TEXT NOT NULL,
    expected_intent JSONB NOT NULL,
    actual_intent JSONB,
    was_corrected BOOLEAN DEFAULT FALSE,
    quality_score FLOAT,  -- 0-1 confidence in this training example
    created_at TIMESTAMPTZ DEFAULT NOW(),
    used_in_training BOOLEAN DEFAULT FALSE,
    INDEX idx_quality_score (quality_score),
    INDEX idx_used_in_training (used_in_training)
);
```

### Implementation Components

#### 4.2 ML Logger (`ai_ops_agent/ml/logger.py`)

```python
from typing import Optional, Dict
from uuid import UUID, uuid4
from datetime import datetime
import asyncpg
from pydantic import BaseModel

class MLLogger:
    """Log all queries, executions, and outcomes for ML"""

    def __init__(self, db_url: str):
        self.db_url = db_url
        self.pool = None

    async def initialize(self):
        """Initialize database connection pool"""
        self.pool = await asyncpg.create_pool(self.db_url)

    async def log_query(
        self,
        user_id: str,
        query_text: str,
        parsed_intent: Dict,
        confidence: float,
        session_id: Optional[UUID] = None
    ) -> UUID:
        """Log user query"""

        query_id = uuid4()

        async with self.pool.acquire() as conn:
            await conn.execute("""
                INSERT INTO queries (id, user_id, query_text, parsed_intent, confidence, session_id)
                VALUES ($1, $2, $3, $4, $5, $6)
            """, query_id, user_id, query_text, parsed_intent, confidence, session_id)

        return query_id

    async def log_execution(
        self,
        query_id: UUID,
        execution_plan: Dict,
        status: str = "pending"
    ) -> UUID:
        """Log execution plan"""

        execution_id = uuid4()

        async with self.pool.acquire() as conn:
            await conn.execute("""
                INSERT INTO executions (id, query_id, execution_plan, status, started_at)
                VALUES ($1, $2, $3, $4, $5)
            """, execution_id, query_id, execution_plan, status, datetime.now())

        return execution_id

    async def log_outcome(
        self,
        execution_id: UUID,
        success: bool,
        error_message: Optional[str] = None,
        error_type: Optional[str] = None,
        resource_changes: Optional[Dict] = None
    ):
        """Log execution outcome"""

        async with self.pool.acquire() as conn:
            await conn.execute("""
                INSERT INTO outcomes (execution_id, success, error_message, error_type, resource_changes)
                VALUES ($1, $2, $3, $4, $5)
            """, execution_id, success, error_message, error_type, resource_changes)

            # Update execution status
            await conn.execute("""
                UPDATE executions
                SET status = $1, completed_at = $2
                WHERE id = $3
            """, "success" if success else "failed", datetime.now(), execution_id)

    async def log_policy_violation(
        self,
        execution_id: UUID,
        policy_name: str,
        severity: str,
        decision: str,
        reason: str
    ):
        """Log policy violation"""

        async with self.pool.acquire() as conn:
            await conn.execute("""
                INSERT INTO policy_violations (execution_id, policy_name, severity, decision, reason)
                VALUES ($1, $2, $3, $4, $5)
            """, execution_id, policy_name, severity, decision, reason)

    async def log_feedback(
        self,
        query_id: UUID,
        execution_id: UUID,
        user_id: str,
        satisfaction_score: int,
        feedback_text: Optional[str] = None,
        intent_was_correct: Optional[bool] = None,
        corrected_intent: Optional[Dict] = None
    ):
        """Log user feedback"""

        async with self.pool.acquire() as conn:
            await conn.execute("""
                INSERT INTO feedback (
                    query_id, execution_id, user_id, satisfaction_score,
                    feedback_text, intent_was_correct, corrected_intent
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7)
            """, query_id, execution_id, user_id, satisfaction_score,
                feedback_text, intent_was_correct, corrected_intent)

            # If user corrected the intent, create fine-tuning example
            if corrected_intent:
                await self._create_finetuning_example(query_id, corrected_intent)

    async def _create_finetuning_example(
        self,
        query_id: UUID,
        corrected_intent: Dict
    ):
        """Create fine-tuning training example from corrected intent"""

        async with self.pool.acquire() as conn:
            # Get original query
            query = await conn.fetchrow("""
                SELECT query_text, parsed_intent
                FROM queries
                WHERE id = $1
            """, query_id)

            # Create training example
            await conn.execute("""
                INSERT INTO finetuning_datasets (
                    query_id, input_text, expected_intent, actual_intent, was_corrected, quality_score
                )
                VALUES ($1, $2, $3, $4, $5, $6)
            """, query_id, query['query_text'], corrected_intent,
                query['parsed_intent'], True, 1.0)  # High quality since user-corrected
```

#### 4.3 Analytics Dashboard (`ai_ops_agent/ml/analytics.py`)

```python
from typing import List, Dict
from datetime import datetime, timedelta
import asyncpg

class MLAnalytics:
    """Analyze ML logs for insights"""

    def __init__(self, db_url: str):
        self.db_url = db_url
        self.pool = None

    async def initialize(self):
        """Initialize database connection pool"""
        self.pool = await asyncpg.create_pool(self.db_url)

    async def get_intent_accuracy(self, days: int = 7) -> Dict:
        """Calculate intent classification accuracy"""

        async with self.pool.acquire() as conn:
            # Get feedback on intent correctness
            results = await conn.fetch("""
                SELECT
                    COUNT(*) as total,
                    SUM(CASE WHEN intent_was_correct THEN 1 ELSE 0 END) as correct
                FROM feedback
                WHERE timestamp > NOW() - INTERVAL '%s days'
                  AND intent_was_correct IS NOT NULL
            """, days)

            row = results[0]
            total = row['total']
            correct = row['correct']

            return {
                "accuracy": correct / total if total > 0 else 0,
                "total_samples": total,
                "correct_predictions": correct,
                "incorrect_predictions": total - correct
            }

    async def get_error_patterns(self, limit: int = 10) -> List[Dict]:
        """Identify most common error patterns"""

        async with self.pool.acquire() as conn:
            results = await conn.fetch("""
                SELECT
                    error_type,
                    COUNT(*) as count,
                    ARRAY_AGG(DISTINCT error_message) as sample_messages
                FROM outcomes
                WHERE success = FALSE
                  AND timestamp > NOW() - INTERVAL '30 days'
                GROUP BY error_type
                ORDER BY count DESC
                LIMIT $1
            """, limit)

            return [dict(row) for row in results]

    async def get_policy_violation_trends(self) -> List[Dict]:
        """Analyze policy violation trends"""

        async with self.pool.acquire() as conn:
            results = await conn.fetch("""
                SELECT
                    policy_name,
                    severity,
                    decision,
                    COUNT(*) as violations,
                    DATE_TRUNC('day', timestamp) as date
                FROM policy_violations
                WHERE timestamp > NOW() - INTERVAL '30 days'
                GROUP BY policy_name, severity, decision, DATE_TRUNC('day', timestamp)
                ORDER BY date DESC, violations DESC
            """)

            return [dict(row) for row in results]

    async def get_user_satisfaction(self, days: int = 7) -> Dict:
        """Calculate user satisfaction metrics"""

        async with self.pool.acquire() as conn:
            results = await conn.fetch("""
                SELECT
                    AVG(satisfaction_score) as avg_score,
                    COUNT(*) as total_feedback,
                    COUNT(CASE WHEN satisfaction_score >= 4 THEN 1 END) as satisfied,
                    COUNT(CASE WHEN satisfaction_score <= 2 THEN 1 END) as dissatisfied
                FROM feedback
                WHERE timestamp > NOW() - INTERVAL '%s days'
            """, days)

            row = results[0]

            return {
                "average_score": float(row['avg_score']) if row['avg_score'] else 0,
                "total_feedback": row['total_feedback'],
                "satisfied_users": row['satisfied'],
                "dissatisfied_users": row['dissatisfied'],
                "satisfaction_rate": row['satisfied'] / row['total_feedback']
                    if row['total_feedback'] > 0 else 0
            }

    async def generate_finetuning_dataset(
        self,
        min_quality_score: float = 0.8,
        limit: int = 1000
    ) -> List[Dict]:
        """Generate dataset for LLM fine-tuning"""

        async with self.pool.acquire() as conn:
            results = await conn.fetch("""
                SELECT
                    input_text,
                    expected_intent,
                    quality_score
                FROM finetuning_datasets
                WHERE quality_score >= $1
                  AND used_in_training = FALSE
                ORDER BY quality_score DESC
                LIMIT $2
            """, min_quality_score, limit)

            # Mark as used
            await conn.execute("""
                UPDATE finetuning_datasets
                SET used_in_training = TRUE
                WHERE id IN (
                    SELECT id
                    FROM finetuning_datasets
                    WHERE quality_score >= $1
                      AND used_in_training = FALSE
                    ORDER BY quality_score DESC
                    LIMIT $2
                )
            """, min_quality_score, limit)

            return [dict(row) for row in results]
```

---

## Component 5: Integration Layer

### Purpose
Connect all components into a cohesive API.

### Implementation (`ai_ops_agent/main.py`)

```python
from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional, List, Dict
import ollama
from .intent.parser import IntentParser, Intent
from .intent.mapper import ActionMapper
from .rag.retriever import RAGRetriever
from .mcp.policy_engine import PolicyEngine, PolicyDecision
from .mcp.approval import ApprovalWorkflow
from .ml.logger import MLLogger
from .execution.runner import ExecutionRunner

app = FastAPI(
    title="AI Ops/Sec Agent",
    version="2.0.0",
    description="Natural language infrastructure automation with RAG and MCP"
)

# Initialize components
intent_parser = IntentParser(ollama_host=os.getenv("OLLAMA_HOST"))
action_mapper = ActionMapper(mappings_path=Path("config/intent-mappings.yaml"))
rag_retriever = RAGRetriever(
    ollama_host=os.getenv("OLLAMA_HOST"),
    qdrant_host=os.getenv("QDRANT_HOST")
)
policy_engine = PolicyEngine(policies_path=Path("config/mcp-policies.yaml"))
approval_workflow = ApprovalWorkflow(notification_service=notification)
ml_logger = MLLogger(db_url=os.getenv("DATABASE_URL"))
execution_runner = ExecutionRunner()

class ChatRequest(BaseModel):
    query: str
    user_id: str
    session_id: Optional[str] = None

class ChatResponse(BaseModel):
    response: str
    intent: Optional[Intent] = None
    execution_plan: Optional[Dict] = None
    policy_decision: Optional[str] = None
    approval_required: bool = False
    approval_id: Optional[str] = None

@app.post("/api/v1/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """Main conversational endpoint"""

    # 1. Parse intent
    intent = await intent_parser.parse(request.query)

    # 2. Retrieve context with RAG
    rag_context = await rag_retriever.retrieve(request.query, top_k=5)
    augmented_prompt = await rag_retriever.build_context(request.query, rag_context)

    # 3. Map to execution plan
    try:
        execution_plan = action_mapper.map(intent)
    except ValueError as e:
        # No direct mapping - use RAG to generate response
        response = await _generate_informational_response(augmented_prompt)
        return ChatResponse(response=response, intent=intent)

    # 4. Log query
    query_id = await ml_logger.log_query(
        user_id=request.user_id,
        query_text=request.query,
        parsed_intent=intent.dict(),
        confidence=intent.confidence,
        session_id=request.session_id
    )

    # 5. Evaluate against MCP policies
    user_context = await _get_user_context(request.user_id)
    policy_results = await policy_engine.evaluate(execution_plan, user_context)
    final_decision = policy_engine.make_final_decision(policy_results)

    # 6. Log policy checks
    execution_id = await ml_logger.log_execution(query_id, execution_plan.dict())
    for result in policy_results:
        await ml_logger.log_policy_violation(
            execution_id,
            result.policy_name,
            result.severity,
            result.decision,
            result.reason
        )

    # 7. Handle decision
    if final_decision == PolicyDecision.DENY:
        # Denied by policy
        deny_reasons = [r.reason for r in policy_results if r.decision == PolicyDecision.DENY]
        return ChatResponse(
            response=f"❌ Request denied:\n" + "\n".join(f"- {r}" for r in deny_reasons),
            intent=intent,
            execution_plan=execution_plan.dict(),
            policy_decision="denied"
        )

    elif final_decision == PolicyDecision.REQUIRE_APPROVAL:
        # Requires approval
        approval_id = await approval_workflow.request_approval(
            execution_plan, user_context, policy_results
        )

        return ChatResponse(
            response=f"⏳ Approval required. Request ID: {approval_id}\n"
                    f"Your request has been sent to approvers. You'll be notified when approved.",
            intent=intent,
            execution_plan=execution_plan.dict(),
            policy_decision="requires_approval",
            approval_required=True,
            approval_id=approval_id
        )

    else:  # ALLOW
        # Execute immediately
        result = await execution_runner.execute(execution_plan)

        # Log outcome
        await ml_logger.log_outcome(
            execution_id,
            success=result.success,
            error_message=result.error_message,
            resource_changes=result.resource_changes
        )

        if result.success:
            return ChatResponse(
                response=f"✅ Successfully executed!\n\n{result.summary}",
                intent=intent,
                execution_plan=execution_plan.dict(),
                policy_decision="allowed"
            )
        else:
            return ChatResponse(
                response=f"❌ Execution failed:\n{result.error_message}",
                intent=intent,
                execution_plan=execution_plan.dict(),
                policy_decision="allowed"
            )

@app.post("/api/v1/feedback")
async def submit_feedback(
    query_id: str,
    execution_id: str,
    user_id: str,
    satisfaction_score: int,
    feedback_text: Optional[str] = None,
    intent_was_correct: Optional[bool] = None,
    corrected_intent: Optional[Dict] = None
):
    """Submit user feedback for ML improvement"""

    await ml_logger.log_feedback(
        query_id=query_id,
        execution_id=execution_id,
        user_id=user_id,
        satisfaction_score=satisfaction_score,
        feedback_text=feedback_text,
        intent_was_correct=intent_was_correct,
        corrected_intent=corrected_intent
    )

    return {"status": "success", "message": "Thank you for your feedback!"}

@app.get("/api/v1/analytics/accuracy")
async def get_accuracy():
    """Get intent classification accuracy"""
    return await ml_analytics.get_intent_accuracy(days=7)

@app.get("/api/v1/analytics/errors")
async def get_error_patterns():
    """Get common error patterns"""
    return await ml_analytics.get_error_patterns(limit=10)

@app.get("/health")
async def health():
    """Health check"""
    return {"status": "healthy", "version": "2.0.0"}
```

---

## Deployment Architecture

### Kubernetes Resources

```yaml
# cluster/ai-ops-agent/deployment.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: ai-ops-agent
  namespace: ai-ops
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ai-ops-agent
  template:
    metadata:
      labels:
        app: ai-ops-agent
    spec:
      serviceAccountName: ai-ops-agent
      containers:
      - name: agent
        image: ghcr.io/johnyoungsuh/ai-ops-agent:2.0.0
        ports:
        - containerPort: 8000
        env:
        - name: OLLAMA_HOST
          value: "http://ollama:11434"
        - name: QDRANT_HOST
          value: "http://qdrant:6333"
        - name: VAULT_ADDR
          value: "http://vault.vault.svc:8200"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: connection-string
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 2000m
            memory: 4Gi
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: ai-ops-agent
  namespace: ai-ops
spec:
  selector:
    app: ai-ops-agent
  ports:
  - port: 80
    targetPort: 8000
  type: ClusterIP
---
# Ollama deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ollama
  namespace: ai-ops
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ollama
  template:
    metadata:
      labels:
        app: ollama
    spec:
      containers:
      - name: ollama
        image: ollama/ollama:latest
        ports:
        - containerPort: 11434
        resources:
          requests:
            cpu: 2000m
            memory: 8Gi
          limits:
            cpu: 4000m
            memory: 16Gi
        volumeMounts:
        - name: models
          mountPath: /root/.ollama
      volumes:
      - name: models
        persistentVolumeClaim:
          claimName: ollama-models
---
# Qdrant deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: qdrant
  namespace: ai-ops
spec:
  replicas: 1
  selector:
    matchLabels:
      app: qdrant
  template:
    metadata:
      labels:
        app: qdrant
    spec:
      containers:
      - name: qdrant
        image: qdrant/qdrant:latest
        ports:
        - containerPort: 6333
        - containerPort: 6334
        resources:
          requests:
            cpu: 1000m
            memory: 2Gi
          limits:
            cpu: 2000m
            memory: 4Gi
        volumeMounts:
        - name: storage
          mountPath: /qdrant/storage
      volumes:
      - name: storage
        persistentVolumeClaim:
          claimName: qdrant-storage
---
# PostgreSQL for ML logs
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: ai-ops
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:16
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: "ai_ops_ml"
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: password
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 50Gi
```

---

## Summary

This architecture implements a complete AI Ops/Sec automation system with:

1. **Conversational Triggers**: Natural language → Infrastructure actions via intent parsing and action mapping
2. **RAG Pipeline**: Context-aware responses using Qdrant vector DB and Ollama embeddings
3. **MCP Enforcement**: Security, compliance, and operational guardrails with approval workflows
4. **Continuous ML Loop**: Query logging, analytics, and fine-tuning dataset generation

The system integrates seamlessly with existing suhlabs infrastructure (Terraform, Ansible, Vault, Kubernetes) and provides a production-ready foundation for AI-powered infrastructure automation.

**Next Steps**:
1. Implement each component
2. Create example playbooks and mappings
3. Deploy to Kubernetes
4. Test end-to-end workflows
5. Set up monitoring and observability
