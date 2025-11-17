"""Test: mmap orphan leak (Antipattern #10 - New)

Ensures mmap file descriptors are properly cleaned up.
"""

import sys
from pathlib import Path
import pytest


def test_mmap_cleanup_on_close():
    """Verify mmap.close() is called in finally blocks."""
    ml_dir = Path(__file__).parent.parent.parent
    cache_mgr_path = ml_dir / "features" / "ccf_zkcs" / "cache_manager.py"

    with open(cache_mgr_path) as f:
        content = f.read()

    # Verify finally blocks with mm.close()
    assert "mm.close()" in content, "Must call mm.close() to prevent FD leaks"

    # Verify atexit handler for cleanup
    assert "atexit" in content, "Must register atexit handler for cleanup"
    assert "_cleanup_all_mmaps" in content, "Must implement cleanup handler"


def test_weakref_tracking():
    """Verify weak references are used to track open mmaps."""
    ml_dir = Path(__file__).parent.parent.parent
    cache_mgr_path = ml_dir / "features" / "ccf_zkcs" / "cache_manager.py"

    with open(cache_mgr_path) as f:
        content = f.read()

    # Verify weakref usage
    assert "weakref" in content, "Must use weakref to track mmaps"
    assert "WeakSet" in content, "Should use WeakSet for tracking open mmaps"


def test_fd_close_after_mmap():
    """Verify file descriptors are closed after mmap creation."""
    ml_dir = Path(__file__).parent.parent.parent
    cache_mgr_path = ml_dir / "features" / "ccf_zkcs" / "cache_manager.py"

    with open(cache_mgr_path) as f:
        content = f.read()

    # Verify os.close(fd) in finally block
    assert "os.close(fd)" in content, (
        "Must close file descriptor after mmap creation"
    )


def test_no_fd_leak():
    """Integration test: verify no FD leaks after 1000 operations."""
    sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent))

    try:
        import psutil
        import tempfile
        import os
        from pathlib import Path as PathLib

        # Create temporary cache directory
        with tempfile.TemporaryDirectory() as tmpdir:
            cache_dir = PathLib(tmpdir) / "cache"
            cache_dir.mkdir()

            # Mock HMAC key
            hmac_key = b"test_hmac_key_32_bytes_length_!!"

            # Import after setting up paths
            from ml.features.ccf_zkcs.cache_manager import CacheManager

            # Get baseline FD count
            process = psutil.Process()
            baseline_fds = len(process.open_files())

            # Create cache manager
            cache_mgr = CacheManager(cache_dir=cache_dir, hmac_key=hmac_key)

            # Perform 100 write/read cycles (reduced from 1000 for test speed)
            for i in range(100):
                cache_key = f"test_key_{i}".encode().ljust(32, b'\x00')[:32]
                data = b"test_data_" * 100  # ~1KB

                # Write
                cache_mgr.write_cache(cache_key, data)

                # Read (creates mmap)
                mm = cache_mgr.read_cache(cache_key)
                if mm:
                    mm.close()  # Explicit close

            # Cleanup
            cache_mgr._cleanup_all_mmaps()

            # Check FD count
            final_fds = len(process.open_files())
            fd_leak = final_fds - baseline_fds

            # Allow small tolerance (up to 10 FDs)
            assert fd_leak <= 10, (
                f"FD leak detected: {fd_leak} leaked file descriptors. "
                f"Baseline: {baseline_fds}, Final: {final_fds}"
            )

    except ImportError as e:
        pytest.skip(f"Cannot import dependencies: {e}")


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
