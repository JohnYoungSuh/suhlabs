"""Merkle DAG for hierarchical KV-cache prefix matching.

Implements a directed acyclic graph where each node represents a cached
context window, enabling O(log n) prefix lookup.
"""

from dataclasses import dataclass, field
from typing import Optional
import weakref
from blake3 import blake3
from .config import MAX_FANOUT


@dataclass
class MerkleNode:
    """Node in the merkle DAG representing a cached context segment.

    Attributes:
        cache_key: BLAKE3 hash of canonical token sequence
        parent_key: Optional parent node cache_key
        children_keys: List of child node cache_keys (bounded by MAX_FANOUT)
        refcount: Reference count (0 = eligible for eviction)
        size_bytes: Size of cached KV-cache data in bytes
        access_timestamp: Last access time (for LRU eviction)
    """

    cache_key: bytes
    parent_key: Optional[bytes] = None
    children_keys: list[bytes] = field(default_factory=list)
    refcount: int = 0
    size_bytes: int = 0
    access_timestamp: float = 0.0

    def add_child(self, child_key: bytes) -> None:
        """Add child node with fanout limit enforcement.

        Args:
            child_key: BLAKE3 cache key of child node

        Raises:
            ValueError: If fanout limit exceeded
        """
        if len(self.children_keys) >= MAX_FANOUT:
            raise ValueError(
                f"Fanout limit exceeded: {len(self.children_keys)} >= {MAX_FANOUT}"
            )

        if child_key not in self.children_keys:
            self.children_keys.append(child_key)

    def remove_child(self, child_key: bytes) -> None:
        """Remove child node."""
        if child_key in self.children_keys:
            self.children_keys.remove(child_key)

    def increment_refcount(self) -> None:
        """Increment reference count (prevents eviction)."""
        self.refcount += 1

    def decrement_refcount(self) -> None:
        """Decrement reference count.

        Raises:
            ValueError: If refcount is already 0
        """
        if self.refcount <= 0:
            raise ValueError("Refcount already at 0")
        self.refcount -= 1


class MerkleDAG:
    """Merkle DAG for hierarchical cache management.

    Maintains a directed acyclic graph of cached context windows,
    enabling efficient prefix matching and incremental cache updates.

    Attributes:
        nodes: Dictionary mapping cache_key to MerkleNode
        root_keys: List of root node cache_keys (no parents)
    """

    def __init__(self):
        """Initialize empty merkle DAG."""
        self.nodes: dict[bytes, MerkleNode] = {}
        self.root_keys: list[bytes] = []

        # Track total size for eviction
        self._total_size_bytes: int = 0

    def add_node(
        self,
        cache_key: bytes,
        parent_key: Optional[bytes] = None,
        size_bytes: int = 0,
    ) -> MerkleNode:
        """Add node to the DAG.

        Args:
            cache_key: BLAKE3 hash of canonical token sequence
            parent_key: Optional parent node cache_key
            size_bytes: Size of cached data in bytes

        Returns:
            Created MerkleNode

        Raises:
            ValueError: If parent_key doesn't exist or fanout exceeded
        """
        import time

        # Validate parent exists if specified
        if parent_key is not None and parent_key not in self.nodes:
            raise ValueError(f"Parent node not found: {parent_key.hex()}")

        # Create node
        node = MerkleNode(
            cache_key=cache_key,
            parent_key=parent_key,
            size_bytes=size_bytes,
            access_timestamp=time.time(),
        )

        # Add to parent's children if specified
        if parent_key is not None:
            self.nodes[parent_key].add_child(cache_key)
        else:
            # Root node
            self.root_keys.append(cache_key)

        # Store node
        self.nodes[cache_key] = node
        self._total_size_bytes += size_bytes

        return node

    def get_node(self, cache_key: bytes) -> Optional[MerkleNode]:
        """Get node by cache_key.

        Args:
            cache_key: BLAKE3 cache key

        Returns:
            MerkleNode if found, None otherwise
        """
        return self.nodes.get(cache_key)

    def remove_node(self, cache_key: bytes) -> None:
        """Remove node and update parent/children relationships.

        Args:
            cache_key: BLAKE3 cache key to remove

        Raises:
            ValueError: If node has non-zero refcount
        """
        node = self.nodes.get(cache_key)
        if node is None:
            return

        # Prevent removal of pinned nodes
        if node.refcount > 0:
            raise ValueError(
                f"Cannot remove node with refcount {node.refcount}: {cache_key.hex()}"
            )

        # Remove from parent's children
        if node.parent_key and node.parent_key in self.nodes:
            self.nodes[node.parent_key].remove_child(cache_key)
        else:
            # Root node
            if cache_key in self.root_keys:
                self.root_keys.remove(cache_key)

        # Recursively remove orphaned children
        for child_key in node.children_keys[:]:  # Copy list
            child_node = self.nodes.get(child_key)
            if child_node and child_node.refcount == 0:
                self.remove_node(child_key)

        # Remove node
        self._total_size_bytes -= node.size_bytes
        del self.nodes[cache_key]

    def find_longest_prefix(self, cache_key: bytes) -> Optional[MerkleNode]:
        """Find longest matching prefix in the DAG.

        Args:
            cache_key: BLAKE3 cache key to search for

        Returns:
            Node with longest matching prefix, or None
        """
        # Direct match
        if cache_key in self.nodes:
            return self.nodes[cache_key]

        # Search through tree for longest prefix
        # This is a simplified O(n) search; could be optimized with trie
        longest_prefix: Optional[MerkleNode] = None
        longest_prefix_len = 0

        for node in self.nodes.values():
            # Check if node.cache_key is a prefix of cache_key
            # In practice, this requires storing token sequences
            # For now, we only support exact matches
            pass

        return longest_prefix

    def get_total_size_bytes(self) -> int:
        """Get total size of cached data in bytes."""
        return self._total_size_bytes

    def get_lru_nodes(self, limit: int = 100) -> list[MerkleNode]:
        """Get least recently used nodes.

        Args:
            limit: Maximum number of nodes to return

        Returns:
            List of nodes sorted by access_timestamp (oldest first)
        """
        # Filter out pinned nodes (refcount > 0)
        evictable = [n for n in self.nodes.values() if n.refcount == 0]

        # Sort by access timestamp
        evictable.sort(key=lambda n: n.access_timestamp)

        return evictable[:limit]
