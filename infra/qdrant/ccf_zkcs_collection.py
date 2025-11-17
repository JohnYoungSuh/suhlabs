"""Qdrant collection schema for CCF-ZKCS metadata.

Stores merkle DAG node metadata in Qdrant for distributed coordination.
"""

from qdrant_client import QdrantClient
from qdrant_client.models import (
    Distance,
    VectorParams,
    PointStruct,
    FieldCondition,
    Filter,
    MatchValue,
)
from typing import Optional
import sys
sys.path.append("/home/user/suhlabs")

from ml.common.tls_context import TLSContext
from ml.features.ccf_zkcs.config import (
    QDRANT_COLLECTION_NAME,
    QDRANT_HOST,
    QDRANT_PORT,
)


class QdrantCCFZKCSClient:
    """Qdrant client for CCF-ZKCS metadata storage.

    Stores merkle DAG node metadata including:
    - cache_key (primary ID)
    - parent_key
    - children_keys
    - refcount
    - access_timestamp
    - size_bytes

    Uses batched writes to prevent antipattern #5 (non-transactional upserts).
    """

    def __init__(self, tls_context: TLSContext):
        """Initialize Qdrant client with mTLS.

        Args:
            tls_context: TLS context for mTLS
        """
        self.tls_context = tls_context

        # Create Qdrant client with TLS
        # Note: qdrant-client doesn't natively support custom SSL contexts
        # In production, configure Qdrant with mTLS at server level
        self.client = QdrantClient(
            host=QDRANT_HOST,
            port=QDRANT_PORT,
            https=True,  # Enforce HTTPS
            # TODO: Add cert/key when qdrant-client supports it
        )

        # Ensure collection exists
        self._ensure_collection()

    def _ensure_collection(self) -> None:
        """Create collection if it doesn't exist (idempotent)."""
        collections = self.client.get_collections().collections
        collection_names = [c.name for c in collections]

        if QDRANT_COLLECTION_NAME not in collection_names:
            # Create collection with dummy vector for metadata storage
            # We don't use actual vectors, just Qdrant's metadata capabilities
            self.client.create_collection(
                collection_name=QDRANT_COLLECTION_NAME,
                vectors_config=VectorParams(
                    size=1,  # Dummy vector
                    distance=Distance.DOT,
                ),
            )

    def upsert_node_batch(self, nodes: list[dict]) -> None:
        """Upsert merkle nodes in batch (prevents antipattern #5).

        Args:
            nodes: List of node dictionaries with keys:
                - cache_key: bytes (hex encoded for storage)
                - parent_key: Optional[bytes]
                - children_keys: list[bytes]
                - refcount: int
                - access_timestamp: float
                - size_bytes: int
        """
        if not nodes:
            return

        points = []
        for node in nodes:
            cache_key_hex = node["cache_key"].hex()

            # Convert bytes to hex for JSON serialization
            parent_key_hex = (
                node["parent_key"].hex() if node.get("parent_key") else None
            )
            children_keys_hex = [
                k.hex() for k in node.get("children_keys", [])
            ]

            point = PointStruct(
                id=cache_key_hex,  # Use cache_key as point ID
                vector=[0.0],  # Dummy vector
                payload={
                    "cache_key": cache_key_hex,
                    "parent_key": parent_key_hex,
                    "children_keys": children_keys_hex,
                    "refcount": node.get("refcount", 0),
                    "access_timestamp": node.get("access_timestamp", 0.0),
                    "size_bytes": node.get("size_bytes", 0),
                },
            )
            points.append(point)

        # Batch upsert (transactional)
        self.client.upsert(
            collection_name=QDRANT_COLLECTION_NAME,
            points=points,
        )

    def get_node(self, cache_key: bytes) -> Optional[dict]:
        """Retrieve node metadata by cache_key.

        Args:
            cache_key: BLAKE3 cache key

        Returns:
            Node metadata dictionary or None if not found
        """
        cache_key_hex = cache_key.hex()

        try:
            point = self.client.retrieve(
                collection_name=QDRANT_COLLECTION_NAME,
                ids=[cache_key_hex],
            )

            if not point:
                return None

            payload = point[0].payload
            return {
                "cache_key": bytes.fromhex(payload["cache_key"]),
                "parent_key": (
                    bytes.fromhex(payload["parent_key"])
                    if payload.get("parent_key")
                    else None
                ),
                "children_keys": [
                    bytes.fromhex(k) for k in payload.get("children_keys", [])
                ],
                "refcount": payload.get("refcount", 0),
                "access_timestamp": payload.get("access_timestamp", 0.0),
                "size_bytes": payload.get("size_bytes", 0),
            }

        except Exception:
            return None

    def delete_nodes_batch(self, cache_keys: list[bytes]) -> None:
        """Delete nodes in batch.

        Args:
            cache_keys: List of BLAKE3 cache keys to delete
        """
        if not cache_keys:
            return

        cache_keys_hex = [k.hex() for k in cache_keys]

        self.client.delete(
            collection_name=QDRANT_COLLECTION_NAME,
            points_selector=cache_keys_hex,
        )

    def get_lru_nodes(self, limit: int = 100) -> list[dict]:
        """Get least recently used nodes.

        Args:
            limit: Maximum number of nodes to return

        Returns:
            List of node metadata dictionaries sorted by access_timestamp
        """
        # Scroll through all points and sort by access_timestamp
        # Note: This is inefficient for large collections; in production
        # consider using a dedicated LRU index or time-series DB

        points, _ = self.client.scroll(
            collection_name=QDRANT_COLLECTION_NAME,
            limit=limit * 10,  # Fetch extra for filtering
        )

        # Filter to refcount=0 (evictable)
        evictable = [
            p for p in points
            if p.payload.get("refcount", 0) == 0
        ]

        # Sort by access_timestamp
        evictable.sort(key=lambda p: p.payload.get("access_timestamp", 0.0))

        # Convert to node dicts
        nodes = []
        for p in evictable[:limit]:
            payload = p.payload
            nodes.append({
                "cache_key": bytes.fromhex(payload["cache_key"]),
                "parent_key": (
                    bytes.fromhex(payload["parent_key"])
                    if payload.get("parent_key")
                    else None
                ),
                "children_keys": [
                    bytes.fromhex(k) for k in payload.get("children_keys", [])
                ],
                "refcount": payload.get("refcount", 0),
                "access_timestamp": payload.get("access_timestamp", 0.0),
                "size_bytes": payload.get("size_bytes", 0),
            })

        return nodes


def setup_ccf_zkcs_collection():
    """Setup CCF-ZKCS Qdrant collection (run once during deployment)."""
    from ml.common.tls_context import TLSContext

    tls_context = TLSContext()
    client = QdrantCCFZKCSClient(tls_context)
    print(f"✓ Created Qdrant collection: {QDRANT_COLLECTION_NAME}")


if __name__ == "__main__":
    setup_ccf_zkcs_collection()
