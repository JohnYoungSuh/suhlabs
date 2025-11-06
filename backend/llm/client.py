"""
Ollama LLM Client for AIOps Backend

Handles natural language processing for:
- Customer support queries
- Intent parsing (converting NL to Ansible tasks)
- Answer generation
"""
import httpx
import json
from typing import Optional, Dict, List
from enum import Enum
from pydantic import BaseModel


class IntentType(str, Enum):
    """Types of customer intents"""
    ADD_USER = "add_user"
    REMOVE_USER = "remove_user"
    ADD_DNS_RECORD = "add_dns_record"
    ADD_SAMBA_SHARE = "add_samba_share"
    QUESTION = "question"
    UNKNOWN = "unknown"


class ParsedIntent(BaseModel):
    """Parsed customer intent from LLM"""
    intent_type: IntentType
    confidence: float  # 0.0 to 1.0
    parameters: Dict
    ansible_task: Optional[str] = None
    natural_response: str


class OllamaClient:
    """Client for interacting with Ollama LLM"""

    def __init__(
        self,
        base_url: str = "http://localhost:11434",
        model: str = "llama3.2:3b",
        timeout: int = 30
    ):
        self.base_url = base_url
        self.model = model
        self.timeout = timeout
        self.client = httpx.AsyncClient(timeout=timeout)

    async def generate(
        self,
        prompt: str,
        system_prompt: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 500
    ) -> str:
        """
        Generate text completion from Ollama

        Args:
            prompt: User prompt
            system_prompt: System instructions
            temperature: Randomness (0.0 = deterministic, 1.0 = creative)
            max_tokens: Maximum response length

        Returns:
            Generated text
        """
        payload = {
            "model": self.model,
            "prompt": prompt,
            "stream": False,
            "options": {
                "temperature": temperature,
                "num_predict": max_tokens
            }
        }

        if system_prompt:
            payload["system"] = system_prompt

        try:
            response = await self.client.post(
                f"{self.base_url}/api/generate",
                json=payload
            )
            response.raise_for_status()
            data = response.json()
            return data.get("response", "")

        except httpx.HTTPError as e:
            print(f"Ollama API error: {e}")
            raise

    async def parse_intent(self, query: str, context: Optional[Dict] = None) -> ParsedIntent:
        """
        Parse customer query into actionable intent

        Examples:
            "Add user John" → ADD_USER intent with username parameter
            "Create DNS record for test.local" → ADD_DNS_RECORD
            "How do I access files?" → QUESTION intent
        """
        system_prompt = """You are an AI assistant for a home server appliance that provides DNS, file sharing (Samba), mail, and PKI services.

Parse user queries into one of these intents:
- add_user: User wants to create a new user account
- remove_user: User wants to delete a user
- add_dns_record: User wants to add a DNS record
- add_samba_share: User wants to create a file share
- question: User is asking a question (not requesting an action)
- unknown: Cannot determine intent

Respond in JSON format:
{
  "intent_type": "add_user",
  "confidence": 0.95,
  "parameters": {"username": "john", "groups": ["users", "samba"]},
  "ansible_task": "user",
  "natural_response": "I'll create user 'john' with access to file sharing."
}"""

        prompt = f"User query: {query}"
        if context:
            prompt += f"\nContext: {json.dumps(context)}"

        response_text = await self.generate(
            prompt=prompt,
            system_prompt=system_prompt,
            temperature=0.3,  # Lower temperature for more deterministic parsing
            max_tokens=300
        )

        # Parse JSON response from LLM
        try:
            # Extract JSON from response (LLM might add explanation text)
            json_start = response_text.find("{")
            json_end = response_text.rfind("}") + 1
            if json_start >= 0 and json_end > json_start:
                json_str = response_text[json_start:json_end]
                data = json.loads(json_str)
                return ParsedIntent(**data)
            else:
                # Fallback if no JSON found
                return ParsedIntent(
                    intent_type=IntentType.UNKNOWN,
                    confidence=0.0,
                    parameters={},
                    natural_response=response_text
                )

        except (json.JSONDecodeError, ValueError) as e:
            print(f"Failed to parse LLM response as JSON: {e}")
            print(f"Response: {response_text}")

            # Return unknown intent with raw response
            return ParsedIntent(
                intent_type=IntentType.UNKNOWN,
                confidence=0.0,
                parameters={},
                natural_response=response_text
            )

    async def answer_question(
        self,
        question: str,
        context: Optional[Dict] = None
    ) -> str:
        """
        Answer customer support question

        Examples:
            "How do I access my files from Windows?" → Instructions
            "What port does DNS run on?" → Technical info
        """
        system_prompt = """You are a helpful technical support assistant for a home server appliance.

The appliance provides:
- DNS server (dnsmasq on port 53)
- File sharing (Samba/SMB on ports 139, 445)
- Mail relay (Postfix on port 25)
- PKI/Certificates (Step-CA)

Provide clear, concise answers to user questions. Include:
- Step-by-step instructions if needed
- Relevant IP addresses, ports, or URLs
- Troubleshooting tips

Keep answers under 200 words."""

        prompt = f"Question: {question}"
        if context:
            prompt += f"\nAppliance info: {json.dumps(context)}"

        response = await self.generate(
            prompt=prompt,
            system_prompt=system_prompt,
            temperature=0.5,
            max_tokens=400
        )

        return response

    async def health_check(self) -> bool:
        """Check if Ollama service is healthy"""
        try:
            response = await self.client.get(f"{self.base_url}/api/tags")
            response.raise_for_status()
            return True
        except httpx.HTTPError:
            return False

    async def close(self):
        """Close HTTP client"""
        await self.client.aclose()


# =============================================================================
# Example Usage
# =============================================================================

async def main():
    """Example usage of Ollama client"""
    client = OllamaClient(
        base_url="http://localhost:11434",
        model="llama3.2:3b"
    )

    try:
        # Check health
        is_healthy = await client.health_check()
        print(f"Ollama healthy: {is_healthy}")

        if not is_healthy:
            print("Ollama is not running. Start with: ollama serve")
            return

        # Parse intent
        print("\n=== Intent Parsing ===")
        intent = await client.parse_intent("Add user John to the file share")
        print(f"Intent: {intent.intent_type}")
        print(f"Confidence: {intent.confidence}")
        print(f"Parameters: {intent.parameters}")
        print(f"Response: {intent.natural_response}")

        # Answer question
        print("\n=== Question Answering ===")
        answer = await client.answer_question(
            "How do I access my files from Windows?"
        )
        print(f"Answer: {answer}")

    finally:
        await client.close()


if __name__ == "__main__":
    import asyncio
    asyncio.run(main())
