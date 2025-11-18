"""
Document Indexer: Index configs, docs, and logs into Qdrant
"""

from pathlib import Path
from typing import List, Dict, Optional
import logging
import hashlib
import httpx
from qdrant_client import QdrantClient
from qdrant_client.models import PointStruct, VectorParams, Distance, models

logger = logging.getLogger(__name__)


class DocumentIndexer:
    """Index documents into Qdrant vector database"""

    def __init__(self, ollama_host: str, qdrant_host: str):
        self.ollama_host = ollama_host.rstrip('/')
        self.qdrant_host = qdrant_host
        self.qdrant = QdrantClient(url=qdrant_host)
        self.ollama_client = httpx.AsyncClient(timeout=60.0)
        self.embedding_model = "nomic-embed-text"
        self.collection_name = "suhlabs-knowledge"
        self.embedding_dimension = 768  # nomic-embed-text dimension

    async def initialize_collection(self):
        """Create Qdrant collection if not exists"""

        try:
            collections = await self.qdrant.get_collections()
            existing_names = [c.name for c in collections.collections]

            if self.collection_name not in existing_names:
                logger.info(f"Creating collection: {self.collection_name}")

                await self.qdrant.create_collection(
                    collection_name=self.collection_name,
                    vectors_config=VectorParams(
                        size=self.embedding_dimension,
                        distance=Distance.COSINE
                    )
                )

                logger.info(f"Collection created: {self.collection_name}")
            else:
                logger.info(f"Collection already exists: {self.collection_name}")

        except Exception as e:
            logger.error(f"Failed to initialize collection: {e}")
            raise

    async def index_directory(
        self,
        directory: Path,
        doc_type: str,
        pattern: str = "**/*",
        exclude_patterns: Optional[List[str]] = None
    ):
        """
        Index all files in a directory

        Args:
            directory: Directory to index
            doc_type: Type of documents (doc, terraform, ansible, k8s, etc.)
            pattern: Glob pattern for files to include
            exclude_patterns: Patterns to exclude
        """
        logger.info(f"Indexing directory: {directory} (type: {doc_type})")

        exclude_patterns = exclude_patterns or [
            "*.pyc",
            "__pycache__",
            ".git",
            "node_modules",
            "*.tfstate",
            "*.tfstate.backup"
        ]

        indexed_count = 0

        for file_path in directory.glob(pattern):
            if not file_path.is_file():
                continue

            # Check exclusions
            if any(file_path.match(pat) for pat in exclude_patterns):
                logger.debug(f"Skipping excluded file: {file_path}")
                continue

            # Only index text files
            if not self._is_text_file(file_path):
                logger.debug(f"Skipping non-text file: {file_path}")
                continue

            try:
                await self.index_file(file_path, doc_type)
                indexed_count += 1
            except Exception as e:
                logger.warning(f"Failed to index {file_path}: {e}")

        logger.info(f"Indexed {indexed_count} files from {directory}")

    async def index_file(self, file_path: Path, doc_type: str):
        """Index a single file"""

        logger.debug(f"Indexing file: {file_path}")

        # Read content
        try:
            content = file_path.read_text(encoding='utf-8')
        except UnicodeDecodeError:
            logger.warning(f"Failed to decode {file_path} as UTF-8")
            return

        # Chunk content
        chunks = self._chunk_text(content, max_tokens=512)

        # Generate embeddings and create points
        points = []
        for i, chunk in enumerate(chunks):
            try:
                embedding = await self._embed(chunk)

                # Generate unique ID
                point_id = self._generate_id(str(file_path), i)

                point = PointStruct(
                    id=point_id,
                    vector=embedding,
                    payload={
                        "type": doc_type,
                        "file_path": str(file_path),
                        "chunk_index": i,
                        "total_chunks": len(chunks),
                        "content": chunk,
                        "metadata": self._extract_metadata(file_path, chunk)
                    }
                )
                points.append(point)

            except Exception as e:
                logger.warning(f"Failed to embed chunk {i} of {file_path}: {e}")

        # Upload to Qdrant
        if points:
            try:
                await self.qdrant.upsert(
                    collection_name=self.collection_name,
                    points=points
                )
                logger.debug(f"Uploaded {len(points)} points for {file_path}")
            except Exception as e:
                logger.error(f"Failed to upload points for {file_path}: {e}")

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
        embedding = data.get("embedding", [])

        if len(embedding) != self.embedding_dimension:
            raise ValueError(
                f"Expected embedding dimension {self.embedding_dimension}, "
                f"got {len(embedding)}"
            )

        return embedding

    def _chunk_text(self, text: str, max_tokens: int = 512) -> List[str]:
        """
        Split text into chunks

        Simple sentence-based chunking with token limit approximation.
        """
        # Split by sentences (simple approach)
        sentences = []
        current = []

        for line in text.split('\n'):
            line = line.strip()
            if not line:
                if current:
                    sentences.append(' '.join(current))
                    current = []
                continue

            # Split by '. ' for sentences
            parts = line.split('. ')
            for part in parts:
                current.append(part)

        if current:
            sentences.append(' '.join(current))

        # Group sentences into chunks
        chunks = []
        current_chunk = []
        current_length = 0

        for sentence in sentences:
            # Approximate token count (4 chars ≈ 1 token)
            sentence_tokens = len(sentence) // 4

            if current_length + sentence_tokens > max_tokens and current_chunk:
                chunks.append(' '.join(current_chunk))
                current_chunk = [sentence]
                current_length = sentence_tokens
            else:
                current_chunk.append(sentence)
                current_length += sentence_tokens

        if current_chunk:
            chunks.append(' '.join(current_chunk))

        return chunks if chunks else [text]  # At least one chunk

    def _extract_metadata(self, file_path: Path, chunk: str) -> Dict:
        """Extract metadata from file and chunk"""

        metadata = {
            "filename": file_path.name,
            "extension": file_path.suffix,
            "directory": str(file_path.parent),
        }

        # Add content-specific metadata
        if "apiVersion" in chunk and "kind" in chunk:
            metadata["k8s_detected"] = True

        if "resource " in chunk or "module " in chunk:
            metadata["terraform_detected"] = True

        if "tasks:" in chunk or "- name:" in chunk:
            metadata["ansible_detected"] = True

        return metadata

    def _is_text_file(self, file_path: Path) -> bool:
        """Check if file is a text file"""

        text_extensions = {
            '.md', '.txt', '.yaml', '.yml', '.json', '.tf', '.py',
            '.sh', '.bash', '.conf', '.cfg', '.ini', '.toml',
            '.hcl', '.nomad', '.j2', '.tmpl'
        }

        return file_path.suffix.lower() in text_extensions

    def _generate_id(self, file_path: str, chunk_index: int) -> str:
        """Generate unique ID for point"""

        # Use hash of file path + chunk index
        raw = f"{file_path}_{chunk_index}"
        return hashlib.md5(raw.encode()).hexdigest()

    async def close(self):
        """Close HTTP client"""
        await self.ollama_client.aclose()
