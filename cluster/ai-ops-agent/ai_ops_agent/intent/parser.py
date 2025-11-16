"""
Intent Parser: Natural language → Structured intent
"""

from typing import Dict, Optional
import json
import logging
import httpx
from ..models import Intent, IntentCategory, ActionType

logger = logging.getLogger(__name__)


class IntentParser:
    """Parse natural language requests into structured intents"""

    def __init__(self, ollama_host: str, model: str = "mistral"):
        self.ollama_host = ollama_host.rstrip('/')
        self.model = model
        self.client = httpx.AsyncClient(timeout=60.0)

    async def parse(self, user_input: str) -> Intent:
        """
        Extract intent from natural language

        Args:
            user_input: Natural language request

        Returns:
            Structured Intent object
        """
        logger.info(f"Parsing intent from: {user_input}")

        # Build prompt for Ollama
        prompt = self._build_prompt(user_input)

        # Call Ollama API
        try:
            response = await self._call_ollama(prompt)
            intent_data = self._parse_response(response)

            # Validate and create Intent
            intent = Intent(
                category=IntentCategory(intent_data.get("category", "query")),
                action=ActionType(intent_data.get("action", "query")),
                resource_type=intent_data.get("resource_type", "unknown"),
                entities=intent_data.get("entities", {}),
                confidence=intent_data.get("confidence", 0.5),
                raw_query=user_input
            )

            logger.info(f"Parsed intent: {intent.category}.{intent.action}.{intent.resource_type}")
            return intent

        except Exception as e:
            logger.error(f"Failed to parse intent: {e}")
            # Return default query intent
            return Intent(
                category=IntentCategory.QUERY,
                action=ActionType.QUERY,
                resource_type="general",
                entities={},
                confidence=0.3,
                raw_query=user_input
            )

    def _build_prompt(self, user_input: str) -> str:
        """Build prompt for intent extraction"""

        return f"""You are an infrastructure automation intent parser. Parse this request into structured format.

User Request: "{user_input}"

Extract the following information:

1. Category (choose one):
   - provision: Creating/deploying infrastructure (email, cluster, website, database, etc.)
   - security: Security operations (rotate secrets, issue certs, enable mTLS, etc.)
   - identity: User/access management (create user, grant access, manage permissions, etc.)
   - observability: Monitoring/logging (query logs, check metrics, view dashboards, etc.)
   - compliance: Compliance operations (scan CVEs, generate SBOM, audit access, etc.)
   - query: Information request (no action, just asking a question)

2. Action (choose one):
   - create: Create new resource
   - update: Update existing resource
   - delete: Delete resource
   - rotate: Rotate secrets/credentials
   - issue: Issue certificates/tokens
   - query: Query information
   - scan: Run security scan
   - list: List resources

3. Resource Type:
   - Specific resource being operated on (email, cluster, website, user, cert, secret, logs, etc.)

4. Entities:
   - Key-value pairs of parameters extracted from the request
   - Examples: {{"email": "john@suhlabs.io"}}, {{"domain": "example.com"}}, {{"username": "jsmith"}}

5. Confidence:
   - Float between 0.0 and 1.0 indicating confidence in the parse

Respond ONLY with valid JSON in this exact format:
{{
  "category": "provision|security|identity|observability|compliance|query",
  "action": "create|update|delete|rotate|issue|query|scan|list",
  "resource_type": "specific_resource_type",
  "entities": {{}},
  "confidence": 0.0-1.0
}}

Examples:

User: "Create me an email address for john@suhlabs.io"
Response: {{"category": "provision", "action": "create", "resource_type": "email", "entities": {{"email": "john@suhlabs.io", "username": "john", "domain": "suhlabs.io"}}, "confidence": 0.95}}

User: "Rotate the Vault secrets"
Response: {{"category": "security", "action": "rotate", "resource_type": "secrets", "entities": {{"service": "vault"}}, "confidence": 0.9}}

User: "Deploy a website for my family at family.suhlabs.io"
Response: {{"category": "provision", "action": "create", "resource_type": "website", "entities": {{"domain": "family.suhlabs.io", "type": "personal"}}, "confidence": 0.92}}

User: "How do I check the logs?"
Response: {{"category": "query", "action": "query", "resource_type": "logs", "entities": {{}}, "confidence": 0.85}}

Now parse this request:
User: "{user_input}"
Response:"""

    async def _call_ollama(self, prompt: str) -> str:
        """Call Ollama API for generation"""

        url = f"{self.ollama_host}/api/generate"

        payload = {
            "model": self.model,
            "prompt": prompt,
            "stream": False,
            "format": "json",
            "options": {
                "temperature": 0.1,  # Low temperature for more deterministic output
                "top_p": 0.9
            }
        }

        response = await self.client.post(url, json=payload)
        response.raise_for_status()

        data = response.json()
        return data.get("response", "{}")

    def _parse_response(self, response: str) -> Dict:
        """Parse JSON response from Ollama"""

        try:
            # Clean response (sometimes has markdown or extra text)
            response = response.strip()
            if response.startswith("```json"):
                response = response[7:]
            if response.startswith("```"):
                response = response[3:]
            if response.endswith("```"):
                response = response[:-3]
            response = response.strip()

            # Parse JSON
            data = json.loads(response)
            return data

        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse JSON response: {e}")
            logger.error(f"Response was: {response}")
            # Return default
            return {
                "category": "query",
                "action": "query",
                "resource_type": "general",
                "entities": {},
                "confidence": 0.3
            }

    async def close(self):
        """Close HTTP client"""
        await self.client.aclose()
