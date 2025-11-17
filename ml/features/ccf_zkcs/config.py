"""Configuration for CCF-ZKCS feature.

All configuration values with resource constraints and limits.
"""

from pathlib import Path
from typing import Final


# Resource constraints
MAX_SEGMENT_MB: Final[int] = 2048  # 2GB max per cache segment
MAX_TOTAL_CACHE_GB: Final[int] = 16  # 16GB total cache size
MAX_FANOUT: Final[int] = 256  # Max children per merkle node
MAX_TOKENS_PER_REQUEST: Final[int] = 32768  # 32K token limit

# Cache directory (tmpfs for zero-copy mmap)
CACHE_DIR: Final[Path] = Path("/dev/shm/suhlabs/kv_cache")

# Vault paths
VAULT_HMAC_KEY_PATH: Final[str] = "secret/suhlabs/ccf_zkcs/hmac_keys"

# Qdrant configuration
QDRANT_COLLECTION_NAME: Final[str] = "ccf_zkcs_metadata_v1"
QDRANT_HOST: Final[str] = "qdrant.corp.local"
QDRANT_PORT: Final[int] = 6333
QDRANT_GRPC_PORT: Final[int] = 6334

# Performance tuning
CACHE_LOOKUP_TIMEOUT_MS: Final[int] = 50  # 50ms timeout for cache lookups
MMAP_PREFETCH_DISABLED: Final[bool] = True  # Disable prefetch for determinism

# Security
MIN_TLS_VERSION: Final[str] = "TLSv1.3"
CERT_PATH: Final[str] = "/etc/suhlabs/certs/tls.crt"
KEY_PATH: Final[str] = "/etc/suhlabs/certs/tls.key"

# Monitoring
METRICS_ENABLED: Final[bool] = True
CACHE_HIT_RATE_THRESHOLD: Final[float] = 0.45  # 45% minimum hit rate
P95_LATENCY_TARGET_MS: Final[int] = 360  # Target P95 latency
