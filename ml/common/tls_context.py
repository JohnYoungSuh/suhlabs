"""TLS Context wrapper for mTLS enforcement in SuhLabs infrastructure.

Ensures all HTTP communications are wrapped in cert-manager issued certificates.
"""

import ssl
from pathlib import Path
from typing import Optional
import certifi


class TLSContext:
    """Enforces mTLS for all network operations.

    Attributes:
        cert_path: Path to client certificate (issued by cert-manager)
        key_path: Path to private key
        ca_bundle: Path to CA bundle for verification
        verify_mode: SSL verification mode (CERT_REQUIRED by default)
    """

    def __init__(
        self,
        cert_path: str = "/etc/suhlabs/certs/tls.crt",
        key_path: str = "/etc/suhlabs/certs/tls.key",
        ca_bundle: Optional[str] = None,
    ):
        """Initialize TLS context with certificate paths.

        Args:
            cert_path: Path to client certificate
            key_path: Path to private key
            ca_bundle: Optional CA bundle path (defaults to certifi)

        Raises:
            FileNotFoundError: If certificate or key files don't exist
        """
        self.cert_path = Path(cert_path)
        self.key_path = Path(key_path)
        self.ca_bundle = ca_bundle or certifi.where()

        # Validate certificate files exist
        if not self.cert_path.exists():
            raise FileNotFoundError(f"Certificate not found: {self.cert_path}")
        if not self.key_path.exists():
            raise FileNotFoundError(f"Private key not found: {self.key_path}")

    def create_ssl_context(self) -> ssl.SSLContext:
        """Create SSL context with mTLS configuration.

        Returns:
            Configured SSL context enforcing mTLS
        """
        context = ssl.create_default_context(
            purpose=ssl.Purpose.SERVER_AUTH,
            cafile=self.ca_bundle
        )

        # Enforce certificate verification
        context.verify_mode = ssl.CERT_REQUIRED
        context.check_hostname = True

        # Load client certificate for mTLS
        context.load_cert_chain(
            certfile=str(self.cert_path),
            keyfile=str(self.key_path)
        )

        # Disable insecure protocols
        context.minimum_version = ssl.TLSVersion.TLSv1_3
        context.options |= ssl.OP_NO_TLSv1 | ssl.OP_NO_TLSv1_1 | ssl.OP_NO_TLSv1_2

        return context

    def get_requests_cert_tuple(self) -> tuple[str, str]:
        """Get certificate tuple for requests library.

        Returns:
            Tuple of (cert_path, key_path) for requests library
        """
        return (str(self.cert_path), str(self.key_path))
