"""Vault client wrapper with mTLS support for SuhLabs infrastructure.

Provides secure access to Vault secrets with automatic certificate rotation.
"""

import asyncio
import weakref
from typing import Any, Optional
import hvac
from .tls_context import TLSContext


class VaultClient:
    """Vault client with mTLS enforcement and async cert rotation.

    Attributes:
        vault_addr: Vault server address
        tls_context: TLS context for mTLS
        client: HVAC client instance
    """

    def __init__(
        self,
        tls_context: TLSContext,
        vault_addr: str = "https://vault.corp.local:8200",
        namespace: Optional[str] = None,
    ):
        """Initialize Vault client with mTLS.

        Args:
            tls_context: TLS context for certificate-based auth
            vault_addr: Vault server address (must be HTTPS)
            namespace: Optional Vault namespace

        Raises:
            ValueError: If vault_addr is not HTTPS
        """
        if not vault_addr.startswith("https://"):
            raise ValueError(f"Vault address must use HTTPS: {vault_addr}")

        self.vault_addr = vault_addr
        self.tls_context = tls_context
        self.namespace = namespace

        # Create HVAC client with mTLS
        cert_tuple = self.tls_context.get_requests_cert_tuple()
        self.client = hvac.Client(
            url=self.vault_addr,
            cert=cert_tuple,
            verify=self.tls_context.ca_bundle,
            namespace=self.namespace,
        )

        # Authenticate using Kubernetes service account
        self._authenticate_kubernetes()

        # Start async certificate rotation monitor
        self._rotation_task = None
        self._start_cert_rotation_monitor()

    def _authenticate_kubernetes(self) -> None:
        """Authenticate to Vault using Kubernetes service account token."""
        try:
            with open("/var/run/secrets/kubernetes.io/serviceaccount/token") as f:
                jwt_token = f.read().strip()

            # Authenticate with Kubernetes auth method
            self.client.auth.kubernetes.login(
                role="ccf-zkcs",
                jwt=jwt_token,
            )
        except FileNotFoundError:
            # Fallback for local development - use token from environment
            import os
            token = os.getenv("VAULT_TOKEN")
            if not token:
                raise ValueError(
                    "Not running in Kubernetes and VAULT_TOKEN not set"
                )
            self.client.token = token

    def read(self, path: str) -> dict[str, Any]:
        """Read secret from Vault.

        Args:
            path: Secret path (e.g., 'secret/suhlabs/ccf_zkcs/hmac_keys')

        Returns:
            Secret data dictionary

        Raises:
            hvac.exceptions.Forbidden: If not authorized
            hvac.exceptions.InvalidPath: If path doesn't exist
        """
        response = self.client.secrets.kv.v2.read_secret_version(
            path=path.removeprefix("secret/data/").removeprefix("secret/"),
            mount_point="secret",
        )
        return response["data"]

    def write(self, path: str, data: dict[str, Any]) -> None:
        """Write secret to Vault.

        Args:
            path: Secret path
            data: Secret data to write
        """
        self.client.secrets.kv.v2.create_or_update_secret(
            path=path.removeprefix("secret/data/").removeprefix("secret/"),
            secret=data,
            mount_point="secret",
        )

    def _start_cert_rotation_monitor(self) -> None:
        """Start async background task to monitor cert rotation.

        This prevents cert deadlock (antipattern #9) by refreshing
        the TLS context asynchronously when certificates are rotated.
        """
        async def monitor_cert_rotation():
            """Background task to detect and handle cert rotation."""
            while True:
                try:
                    # Check every 60 seconds
                    await asyncio.sleep(60)

                    # Detect cert rotation by checking file modification time
                    current_mtime = self.tls_context.cert_path.stat().st_mtime

                    if not hasattr(self, "_last_cert_mtime"):
                        self._last_cert_mtime = current_mtime
                        continue

                    if current_mtime > self._last_cert_mtime:
                        # Certificate rotated - recreate client
                        cert_tuple = self.tls_context.get_requests_cert_tuple()
                        self.client = hvac.Client(
                            url=self.vault_addr,
                            cert=cert_tuple,
                            verify=self.tls_context.ca_bundle,
                            namespace=self.namespace,
                        )
                        self._authenticate_kubernetes()
                        self._last_cert_mtime = current_mtime

                except Exception:
                    # Swallow errors to prevent task crash
                    pass

        # Start background task
        try:
            loop = asyncio.get_running_loop()
            self._rotation_task = loop.create_task(monitor_cert_rotation())

            # Use weakref to prevent circular reference
            weakref.finalize(self, lambda task: task.cancel(), self._rotation_task)
        except RuntimeError:
            # No event loop running - skip async rotation
            pass

    def close(self) -> None:
        """Clean up resources."""
        if self._rotation_task:
            self._rotation_task.cancel()
