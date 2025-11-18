"""
RAG Retriever: Retrieve relevant context for queries
"""

from typing import List, Optional
import logging
import httpx
from qdrant_client import QdrantClient
from qdrant_client.models import Filter, FieldCondition, MatchValue
from ..models import RAGContext

logger = logging.getLogger(__name__)


class RAGRetriever:
    """Retrieve relevant context for queries"""

    def __init__(self, ollama_host: str, qdrant_host: str):
        self.ollama_host = ollama_host.rstrip('/')
        self.qdrant_host = qdrant_host
        self.qdrant = QdrantClient(url=qdrant_host)
        self.ollama_client = httpx.AsyncClient(timeout=60.0)
        self.embedding_model = "nomic-embed-text"
        self.collection_name = "suhlabs-knowledge"

    async def retrieve(
        self,
        query: str,
        top_k: int = 5,
        filter_type: Optional[str] = None,
        min_score: float = 0.5
    ) -> List[RAGContext]:
        """
        Retrieve top-k relevant chunks

        Args:
            query: User query
            top_k: Number of results to return
            filter_type: Filter by document type (doc, terraform, ansible, k8s, etc.)
            min_score: Minimum similarity score

        Returns:
            List of RAGContext objects
        """
        logger.info(f"Retrieving context for query: {query[:50]}...")

        try:
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
                query_filter=query_filter,
                score_threshold=min_score
            )

            # Convert to RAGContext
            contexts = []
            for result in results:
                context = RAGContext(
                    content=result.payload.get("content", ""),
                    score=result.score,
                    metadata=result.payload.get("metadata", {}),
                    source_type=result.payload.get("type", "unknown"),
                    file_path=result.payload.get("file_path")
                )
                contexts.append(context)

            logger.info(f"Retrieved {len(contexts)} relevant contexts")
            return contexts

        except Exception as e:
            logger.error(f"Failed to retrieve context: {e}")
            return []

    async def build_context(
        self,
        query: str,
        retrieved_chunks: List[RAGContext]
    ) -> str:
        """
        Build augmented context for LLM

        Args:
            query: User query
            retrieved_chunks: Retrieved context chunks

        Returns:
            Formatted context string
        """
        if not retrieved_chunks:
            return f"# User Query\n{query}\n\nNo relevant context found."

        context_parts = ["# Relevant Context from suhlabs Infrastructure\n"]

        for i, chunk in enumerate(retrieved_chunks, 1):
            context_parts.append(f"\n## Source {i} (relevance: {chunk.score:.2f})")
            context_parts.append(f"**Type**: {chunk.source_type}")

            if chunk.file_path:
                context_parts.append(f"**File**: {chunk.file_path}")

            context_parts.append(f"\n{chunk.content}\n")
            context_parts.append("---")

        context_parts.append(f"\n# User Query\n{query}")

        return "\n".join(context_parts)

    async def _embed(self, text: str) -> List[float]:
        """Generate embedding vector for text"""

        url = f"{self.ollama_host}/api/embeddings"

        payload = {
            "model": self.embedding_model,
            "prompt": text
        }

        response = await self.ollama_client.post(url, json=payload)
        response.raise_for_status()

        data = response.json()
        return data.get("embedding", [])

    async def close(self):
        """Close HTTP client"""
        await self.ollama_client.aclose()
