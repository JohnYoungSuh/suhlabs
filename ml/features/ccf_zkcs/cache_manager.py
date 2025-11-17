"""Cache manager for zero-copy mmap-based KV-cache sharing.

Manages memory-mapped cache files with HMAC integrity verification
and LRU eviction.
"""

import atexit
import gc
import hmac
import mmap
import os
import weakref
from pathlib import Path
from typing import Optional
import psutil
from blake3 import blake3

from .config import (
    CACHE_DIR,
    MAX_SEGMENT_MB,
    MAX_TOTAL_CACHE_GB,
    MMAP_PREFETCH_DISABLED,
)
from .merkle_dag import MerkleDAG, MerkleNode


class CacheManager:
    """Manages memory-mapped KV-cache files with integrity verification.

    Attributes:
        cache_dir: Directory for cache files (tmpfs recommended)
        hmac_key: HMAC key for cache integrity verification
        merkle_dag: Merkle DAG for prefix tracking
        open_mmaps: Weak references to open mmap objects
    """

    def __init__(self, cache_dir: Path, hmac_key: bytes):
        """Initialize cache manager.

        Args:
            cache_dir: Cache directory path
            hmac_key: HMAC key for integrity verification (from Vault)

        Raises:
            ValueError: If cache_dir doesn't exist or isn't writable
        """
        self.cache_dir = cache_dir
        self.hmac_key = hmac_key
        self.merkle_dag = MerkleDAG()

        # Track open mmaps with weak references
        self.open_mmaps: weakref.WeakSet[mmap.mmap] = weakref.WeakSet()

        # Create cache directory if needed
        os.makedirs(self.cache_dir, mode=0o700, exist_ok=True)

        # Register cleanup handler
        atexit.register(self._cleanup_all_mmaps)

    def _get_cache_file_path(self, cache_key: bytes) -> Path:
        """Get cache file path for cache_key.

        Args:
            cache_key: BLAKE3 cache key

        Returns:
            Path to cache file
        """
        return self.cache_dir / f"{cache_key.hex()}.bin"

    def _compute_hmac(self, data: bytes) -> bytes:
        """Compute HMAC for cache integrity.

        Args:
            data: Cache data

        Returns:
            BLAKE3 HMAC digest (32 bytes)
        """
        return hmac.new(self.hmac_key, data, blake3).digest()

    def write_cache(
        self,
        cache_key: bytes,
        data: bytes,
        parent_key: Optional[bytes] = None,
    ) -> None:
        """Write cache data to mmap file with HMAC.

        Args:
            cache_key: BLAKE3 cache key
            data: KV-cache data to write
            parent_key: Optional parent node cache_key

        Raises:
            ValueError: If data exceeds MAX_SEGMENT_MB
            OSError: If disk space exhausted
        """
        # Enforce size limit
        size_mb = len(data) / (1024 ** 2)
        if size_mb > MAX_SEGMENT_MB:
            raise ValueError(
                f"Cache segment too large: {size_mb:.1f}MB > {MAX_SEGMENT_MB}MB"
            )

        # Check total cache size and evict if needed
        self._enforce_cache_limit()

        cache_file = self._get_cache_file_path(cache_key)

        try:
            # Compute HMAC
            data_hmac = self._compute_hmac(data)

            # Write file: [HMAC (32 bytes)][data]
            with open(cache_file, "wb") as f:
                f.write(data_hmac)
                f.write(data)

            # Ensure data is synced to disk
            os.sync()

            # Add to merkle DAG
            self.merkle_dag.add_node(
                cache_key=cache_key,
                parent_key=parent_key,
                size_bytes=len(data) + 32,  # Include HMAC size
            )

        except OSError as e:
            # Rollback: delete partial file
            if cache_file.exists():
                cache_file.unlink()
            raise e

    def read_cache(self, cache_key: bytes) -> Optional[mmap.mmap]:
        """Read cache data using zero-copy mmap.

        Args:
            cache_key: BLAKE3 cache key

        Returns:
            Memory-mapped cache data, or None if not found/corrupted

        Raises:
            ValueError: If HMAC verification fails
        """
        cache_file = self._get_cache_file_path(cache_key)

        if not cache_file.exists():
            return None

        # Get merkle node
        node = self.merkle_dag.get_node(cache_key)
        if node is None:
            return None

        try:
            # Read and verify HMAC
            with open(cache_file, "rb") as f:
                stored_hmac = f.read(32)
                max_read = min(
                    MAX_SEGMENT_MB * 1024 ** 2,
                    cache_file.stat().st_size - 32
                )
                data = f.read(max_read)

            expected_hmac = self._compute_hmac(data)
            if not hmac.compare_digest(expected_hmac, stored_hmac):
                # Corruption detected - delete cache file
                cache_file.unlink()
                self.merkle_dag.remove_node(cache_key)
                return None

            # Create memory-mapped file (zero-copy)
            fd = os.open(cache_file, os.O_RDONLY)

            try:
                mm = mmap.mmap(
                    fd,
                    length=0,  # Map entire file
                    access=mmap.ACCESS_READ,
                    flags=mmap.MAP_SHARED | mmap.MAP_LOCKED,
                )

                # Disable prefetch for determinism
                if MMAP_PREFETCH_DISABLED and hasattr(os, 'posix_fadvise'):
                    os.posix_fadvise(
                        fd,
                        0,
                        0,
                        os.POSIX_FADV_RANDOM  # Disable readahead
                    )

                # Track open mmap
                self.open_mmaps.add(mm)

                # Update access timestamp
                import time
                node.access_timestamp = time.time()

                return mm

            finally:
                # Close FD; mmap retains reference
                os.close(fd)

        except Exception as e:
            # Clean up on error
            if cache_file.exists():
                cache_file.unlink()
            if node:
                self.merkle_dag.remove_node(cache_key)
            return None

    def _enforce_cache_limit(self) -> None:
        """Enforce MAX_TOTAL_CACHE_GB limit using LRU eviction."""
        max_bytes = MAX_TOTAL_CACHE_GB * 1024 ** 3
        current_bytes = self.merkle_dag.get_total_size_bytes()

        if current_bytes <= max_bytes:
            return

        # Evict LRU nodes until under limit
        bytes_to_evict = current_bytes - max_bytes
        bytes_evicted = 0

        lru_nodes = self.merkle_dag.get_lru_nodes(limit=1000)

        for node in lru_nodes:
            if bytes_evicted >= bytes_to_evict:
                break

            # Skip pinned nodes
            if node.refcount > 0:
                continue

            # Delete cache file
            cache_file = self._get_cache_file_path(node.cache_key)
            if cache_file.exists():
                cache_file.unlink()

            # Remove from DAG
            bytes_evicted += node.size_bytes
            self.merkle_dag.remove_node(node.cache_key)

        # Force garbage collection
        gc.collect()

    def _cleanup_all_mmaps(self) -> None:
        """Clean up all open mmaps (called at exit)."""
        for mm in list(self.open_mmaps):
            try:
                mm.close()
            except Exception:
                pass

    def get_stats(self) -> dict:
        """Get cache statistics.

        Returns:
            Dictionary with cache stats
        """
        return {
            "total_size_bytes": self.merkle_dag.get_total_size_bytes(),
            "total_size_mb": self.merkle_dag.get_total_size_bytes() / (1024 ** 2),
            "num_nodes": len(self.merkle_dag.nodes),
            "num_root_nodes": len(self.merkle_dag.root_keys),
            "open_mmaps": len(self.open_mmaps),
            "open_file_descriptors": len(psutil.Process().open_files()),
        }
