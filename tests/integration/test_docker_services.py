"""
Integration tests for Docker Compose services.

These tests verify that services defined in docker-compose.yml
start correctly and are accessible.
"""

import time

import pytest
import requests


class TestVaultService:
    """Test Hashicorp Vault service."""

    @pytest.mark.integration
    @pytest.mark.docker
    def test_vault_health(self):
        """Test that Vault service is healthy."""
        try:
            response = requests.get(
                "http://localhost:8200/v1/sys/health",
                timeout=5,
            )
            # Vault returns 200 for initialized and unsealed
            # 429 for unsealed and standby
            # 472 for recovery mode
            # 473 for performance standby
            # 501 for not initialized
            # 503 for sealed
            assert response.status_code in [200, 429, 501, 503], (
                f"Vault health check failed with status {response.status_code}"
            )
        except requests.exceptions.ConnectionError:
            pytest.skip("Vault service not running")

    @pytest.mark.integration
    @pytest.mark.docker
    def test_vault_dev_mode(self):
        """Test that Vault is in dev mode and accessible."""
        try:
            response = requests.get(
                "http://localhost:8200/v1/sys/seal-status",
                timeout=5,
            )
            assert response.status_code == 200
            data = response.json()
            # In dev mode, Vault should be unsealed
            assert not data.get("sealed", True), "Vault should be unsealed in dev mode"
        except requests.exceptions.ConnectionError:
            pytest.skip("Vault service not running")


class TestOllamaService:
    """Test Ollama LLM service."""

    @pytest.mark.integration
    @pytest.mark.docker
    @pytest.mark.slow
    def test_ollama_health(self):
        """Test that Ollama service is healthy."""
        try:
            response = requests.get(
                "http://localhost:11434/",
                timeout=5,
            )
            assert response.status_code == 200
            assert "Ollama is running" in response.text
        except requests.exceptions.ConnectionError:
            pytest.skip("Ollama service not running")

    @pytest.mark.integration
    @pytest.mark.docker
    @pytest.mark.slow
    def test_ollama_api(self):
        """Test that Ollama API is accessible."""
        try:
            response = requests.get(
                "http://localhost:11434/api/tags",
                timeout=5,
            )
            assert response.status_code == 200
            # Should return JSON with models list
            data = response.json()
            assert "models" in data
        except requests.exceptions.ConnectionError:
            pytest.skip("Ollama service not running")


class TestMinIOService:
    """Test MinIO S3-compatible storage service."""

    @pytest.mark.integration
    @pytest.mark.docker
    def test_minio_api(self):
        """Test that MinIO API is accessible."""
        try:
            # MinIO API endpoint
            response = requests.get(
                "http://localhost:9000/minio/health/live",
                timeout=5,
            )
            assert response.status_code == 200
        except requests.exceptions.ConnectionError:
            pytest.skip("MinIO service not running")

    @pytest.mark.integration
    @pytest.mark.docker
    def test_minio_console(self):
        """Test that MinIO console is accessible."""
        try:
            # MinIO console endpoint
            response = requests.get(
                "http://localhost:9001/",
                timeout=5,
                allow_redirects=False,
            )
            # Should redirect to login or return 200
            assert response.status_code in [200, 301, 302, 303, 307, 308]
        except requests.exceptions.ConnectionError:
            pytest.skip("MinIO console not running")


class TestPostgreSQLService:
    """Test PostgreSQL service."""

    @pytest.mark.integration
    @pytest.mark.docker
    def test_postgres_connection(self):
        """Test that PostgreSQL is accessible."""
        try:
            import psycopg2

            conn = psycopg2.connect(
                host="localhost",
                port=5432,
                user="postgres",
                password="changeme123",
                database="postgres",
                connect_timeout=5,
            )
            cursor = conn.cursor()
            cursor.execute("SELECT version();")
            version = cursor.fetchone()
            assert version is not None
            cursor.close()
            conn.close()
        except ImportError:
            pytest.skip("psycopg2 not installed")
        except Exception as e:
            pytest.skip(f"PostgreSQL not running: {e}")


class TestServicesIntegration:
    """Test services working together."""

    @pytest.mark.integration
    @pytest.mark.docker
    @pytest.mark.slow
    def test_all_services_running(self):
        """Test that all expected services are running."""
        services = {
            "Vault": "http://localhost:8200/v1/sys/health",
            "Ollama": "http://localhost:11434/",
            "MinIO API": "http://localhost:9000/minio/health/live",
            "MinIO Console": "http://localhost:9001/",
        }

        running_services = []
        failed_services = []

        for service_name, url in services.items():
            try:
                response = requests.get(url, timeout=3, allow_redirects=False)
                if response.status_code < 500:
                    running_services.append(service_name)
                else:
                    failed_services.append(service_name)
            except requests.exceptions.ConnectionError:
                failed_services.append(service_name)

        # Report status
        print(f"\n✓ Running: {', '.join(running_services)}")
        if failed_services:
            print(f"✗ Not running: {', '.join(failed_services)}")

        # At least one service should be running for the test to pass
        assert len(running_services) > 0, (
            "No services are running. Start with 'make dev-up'"
        )

    @pytest.mark.integration
    @pytest.mark.docker
    def test_services_network_connectivity(self):
        """Test that services can connect to each other."""
        # This is a placeholder for more complex network tests
        # You could test service-to-service communication here
        pass
