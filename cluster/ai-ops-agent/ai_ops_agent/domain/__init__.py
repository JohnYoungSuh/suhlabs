"""
Domain Management Module

Handles domain availability checks, registration, and DNS configuration
for automated PhotoPrism family onboarding.
"""

from typing import List, Dict, Optional, Tuple
from enum import Enum
import httpx
import logging
from pydantic import BaseModel

logger = logging.getLogger(__name__)


class DomainStatus(str, Enum):
    """Domain availability status"""
    AVAILABLE = "available"
    UNAVAILABLE = "unavailable"
    PREMIUM = "premium"
    RESERVED = "reserved"
    ERROR = "error"


class DomainRegistrar(str, Enum):
    """Supported domain registrars"""
    NAMECHEAP = "namecheap"
    CLOUDFLARE = "cloudflare"
    GODADDY = "godaddy"
    ROUTE53 = "route53"  # AWS


class DomainCheckResult(BaseModel):
    """Result of domain availability check"""
    domain: str
    status: DomainStatus
    price: Optional[float] = None
    currency: str = "USD"
    registrar: DomainRegistrar
    error: Optional[str] = None


class DomainSuggestion(BaseModel):
    """Domain name suggestion"""
    domain: str
    available: bool
    score: float  # 0-1, relevance to original query
    price: Optional[float] = None


class DomainManager:
    """Manage domain operations across multiple registrars"""

    def __init__(
        self,
        preferred_registrar: DomainRegistrar = DomainRegistrar.NAMECHEAP,
        api_credentials: Optional[Dict] = None
    ):
        self.preferred_registrar = preferred_registrar
        self.api_credentials = api_credentials or {}
        self.client = httpx.AsyncClient(timeout=30.0)

    async def check_availability(
        self,
        family_name: str,
        tld: str = "family"
    ) -> DomainCheckResult:
        """
        Check if domain is available

        Args:
            family_name: Family name (e.g., "smith")
            tld: Top-level domain (e.g., "family", "com", "io")

        Returns:
            DomainCheckResult with availability status
        """
        domain = f"{family_name.lower()}.{tld}"
        logger.info(f"Checking availability for: {domain}")

        try:
            # Route to appropriate registrar
            if self.preferred_registrar == DomainRegistrar.NAMECHEAP:
                return await self._check_namecheap(domain)
            elif self.preferred_registrar == DomainRegistrar.CLOUDFLARE:
                return await self._check_cloudflare(domain)
            elif self.preferred_registrar == DomainRegistrar.GODADDY:
                return await self._check_godaddy(domain)
            else:
                return DomainCheckResult(
                    domain=domain,
                    status=DomainStatus.ERROR,
                    registrar=self.preferred_registrar,
                    error=f"Registrar {self.preferred_registrar} not implemented"
                )

        except Exception as e:
            logger.error(f"Error checking domain {domain}: {e}")
            return DomainCheckResult(
                domain=domain,
                status=DomainStatus.ERROR,
                registrar=self.preferred_registrar,
                error=str(e)
            )

    async def suggest_alternatives(
        self,
        family_name: str,
        tld: str = "family",
        max_suggestions: int = 5
    ) -> List[DomainSuggestion]:
        """
        Suggest alternative domain names if primary is unavailable

        Args:
            family_name: Original family name
            tld: Top-level domain
            max_suggestions: Maximum number of suggestions

        Returns:
            List of DomainSuggestion objects
        """
        logger.info(f"Generating suggestions for: {family_name}.{tld}")

        suggestions = []
        base_name = family_name.lower().replace(" ", "")

        # Generate variations
        variations = [
            f"{base_name}family",  # smithfamily.family
            f"the{base_name}s",     # thesmiths.family
            f"{base_name}photos",   # smithphotos.family
            f"{base_name}-family",  # smith-family.family
            f"{base_name}-photos",  # smith-photos.family
            f"my{base_name}",       # mysmith.family
            f"{base_name}2024",     # smith2024.family
        ]

        # Check each variation
        for i, variation in enumerate(variations[:max_suggestions]):
            result = await self.check_availability(variation, tld)

            if result.status == DomainStatus.AVAILABLE:
                # Calculate relevance score (closer to original = higher score)
                score = 1.0 - (i * 0.15)  # Decrease by 15% for each position

                suggestions.append(DomainSuggestion(
                    domain=result.domain,
                    available=True,
                    score=score,
                    price=result.price
                ))

            if len(suggestions) >= max_suggestions:
                break

        # Sort by score (most relevant first)
        suggestions.sort(key=lambda x: x.score, reverse=True)

        return suggestions

    async def register_domain(
        self,
        domain: str,
        contact_info: Dict,
        dns_records: Optional[List[Dict]] = None
    ) -> Tuple[bool, Optional[str]]:
        """
        Register a domain with the registrar

        Args:
            domain: Domain to register (e.g., "smith.family")
            contact_info: Contact information for registration
            dns_records: Optional DNS records to configure

        Returns:
            Tuple of (success: bool, error_message: Optional[str])
        """
        logger.info(f"Registering domain: {domain}")

        try:
            if self.preferred_registrar == DomainRegistrar.NAMECHEAP:
                return await self._register_namecheap(domain, contact_info, dns_records)
            elif self.preferred_registrar == DomainRegistrar.CLOUDFLARE:
                return await self._register_cloudflare(domain, contact_info, dns_records)
            else:
                return False, f"Registrar {self.preferred_registrar} not implemented"

        except Exception as e:
            logger.error(f"Error registering domain {domain}: {e}")
            return False, str(e)

    async def configure_dns(
        self,
        domain: str,
        ingress_ip: str
    ) -> Tuple[bool, Optional[str]]:
        """
        Configure DNS records for PhotoPrism

        Args:
            domain: Domain (e.g., "smith.family")
            ingress_ip: Kubernetes ingress IP address

        Returns:
            Tuple of (success: bool, error_message: Optional[str])
        """
        logger.info(f"Configuring DNS for {domain} → {ingress_ip}")

        # DNS records needed for PhotoPrism
        dns_records = [
            {
                "type": "A",
                "name": f"photos.{domain}",
                "value": ingress_ip,
                "ttl": 300
            },
            {
                "type": "A",
                "name": f"minio.photos.{domain}",
                "value": ingress_ip,
                "ttl": 300
            },
            {
                "type": "A",
                "name": f"auth.{domain}",
                "value": ingress_ip,
                "ttl": 300
            }
        ]

        try:
            if self.preferred_registrar == DomainRegistrar.NAMECHEAP:
                return await self._configure_dns_namecheap(domain, dns_records)
            elif self.preferred_registrar == DomainRegistrar.CLOUDFLARE:
                return await self._configure_dns_cloudflare(domain, dns_records)
            else:
                return False, f"DNS configuration not implemented for {self.preferred_registrar}"

        except Exception as e:
            logger.error(f"Error configuring DNS for {domain}: {e}")
            return False, str(e)

    # ========================================================================
    # Namecheap API Implementation
    # ========================================================================

    async def _check_namecheap(self, domain: str) -> DomainCheckResult:
        """Check domain availability via Namecheap API"""

        # Namecheap API endpoint
        url = "https://api.namecheap.com/xml.response"

        # API credentials from config
        api_user = self.api_credentials.get("namecheap_api_user")
        api_key = self.api_credentials.get("namecheap_api_key")
        username = self.api_credentials.get("namecheap_username")
        client_ip = self.api_credentials.get("client_ip", "0.0.0.0")

        if not all([api_user, api_key, username]):
            return DomainCheckResult(
                domain=domain,
                status=DomainStatus.ERROR,
                registrar=DomainRegistrar.NAMECHEAP,
                error="Missing Namecheap API credentials"
            )

        params = {
            "ApiUser": api_user,
            "ApiKey": api_key,
            "UserName": username,
            "Command": "namecheap.domains.check",
            "ClientIp": client_ip,
            "DomainList": domain
        }

        try:
            response = await self.client.get(url, params=params)
            response.raise_for_status()

            # Parse XML response (simplified - real implementation needs XML parsing)
            # For MVP, assume JSON response or use xmltodict
            # This is a placeholder - real implementation would parse Namecheap XML

            # Example response parsing:
            # <DomainCheckResult Domain="smith.family" Available="true" Premium="false" />

            # Placeholder response
            available = "Available=\"true\"" in response.text
            premium = "Premium=\"true\"" in response.text

            if available and not premium:
                status = DomainStatus.AVAILABLE
                price = 25.0  # Typical .family price
            elif available and premium:
                status = DomainStatus.PREMIUM
                price = 100.0  # Premium pricing
            else:
                status = DomainStatus.UNAVAILABLE
                price = None

            return DomainCheckResult(
                domain=domain,
                status=status,
                price=price,
                registrar=DomainRegistrar.NAMECHEAP
            )

        except Exception as e:
            logger.error(f"Namecheap API error: {e}")
            return DomainCheckResult(
                domain=domain,
                status=DomainStatus.ERROR,
                registrar=DomainRegistrar.NAMECHEAP,
                error=str(e)
            )

    async def _register_namecheap(
        self,
        domain: str,
        contact_info: Dict,
        dns_records: Optional[List[Dict]]
    ) -> Tuple[bool, Optional[str]]:
        """Register domain via Namecheap API"""

        # TODO: Implement Namecheap domain registration
        # This requires:
        # 1. namecheap.domains.create API call
        # 2. Contact information (registrant, admin, tech, billing)
        # 3. Nameservers configuration
        # 4. Payment processing

        logger.warning("Namecheap domain registration not yet implemented")
        return False, "Namecheap registration requires manual implementation"

    async def _configure_dns_namecheap(
        self,
        domain: str,
        dns_records: List[Dict]
    ) -> Tuple[bool, Optional[str]]:
        """Configure DNS records via Namecheap API"""

        # TODO: Implement Namecheap DNS configuration
        # This uses namecheap.domains.dns.setHosts API

        logger.warning("Namecheap DNS configuration not yet implemented")
        return False, "Namecheap DNS requires manual configuration"

    # ========================================================================
    # Cloudflare API Implementation (More complete)
    # ========================================================================

    async def _check_cloudflare(self, domain: str) -> DomainCheckResult:
        """Check domain availability via Cloudflare Registrar API"""

        api_token = self.api_credentials.get("cloudflare_api_token")

        if not api_token:
            return DomainCheckResult(
                domain=domain,
                status=DomainStatus.ERROR,
                registrar=DomainRegistrar.CLOUDFLARE,
                error="Missing Cloudflare API token"
            )

        # Cloudflare Registrar API
        url = f"https://api.cloudflare.com/client/v4/accounts/{self.api_credentials.get('account_id')}/registrar/domains/{domain}"

        headers = {
            "Authorization": f"Bearer {api_token}",
            "Content-Type": "application/json"
        }

        try:
            response = await self.client.get(url, headers=headers)

            if response.status_code == 200:
                data = response.json()
                # Domain exists in account - unavailable
                return DomainCheckResult(
                    domain=domain,
                    status=DomainStatus.UNAVAILABLE,
                    registrar=DomainRegistrar.CLOUDFLARE
                )
            elif response.status_code == 404:
                # Domain not found - likely available
                return DomainCheckResult(
                    domain=domain,
                    status=DomainStatus.AVAILABLE,
                    price=20.0,  # Cloudflare at-cost pricing
                    registrar=DomainRegistrar.CLOUDFLARE
                )
            else:
                return DomainCheckResult(
                    domain=domain,
                    status=DomainStatus.ERROR,
                    registrar=DomainRegistrar.CLOUDFLARE,
                    error=f"Unexpected status code: {response.status_code}"
                )

        except Exception as e:
            logger.error(f"Cloudflare API error: {e}")
            return DomainCheckResult(
                domain=domain,
                status=DomainStatus.ERROR,
                registrar=DomainRegistrar.CLOUDFLARE,
                error=str(e)
            )

    async def _register_cloudflare(
        self,
        domain: str,
        contact_info: Dict,
        dns_records: Optional[List[Dict]]
    ) -> Tuple[bool, Optional[str]]:
        """Register domain via Cloudflare Registrar API"""

        # TODO: Implement Cloudflare domain registration
        # Cloudflare offers at-cost domain registration
        # API: POST /accounts/{account_id}/registrar/domains

        logger.warning("Cloudflare domain registration not yet implemented")
        return False, "Cloudflare registration requires implementation"

    async def _configure_dns_cloudflare(
        self,
        domain: str,
        dns_records: List[Dict]
    ) -> Tuple[bool, Optional[str]]:
        """Configure DNS records via Cloudflare API"""

        api_token = self.api_credentials.get("cloudflare_api_token")
        zone_id = self.api_credentials.get("zone_id")

        if not all([api_token, zone_id]):
            return False, "Missing Cloudflare API credentials"

        headers = {
            "Authorization": f"Bearer {api_token}",
            "Content-Type": "application/json"
        }

        # Create DNS records
        for record in dns_records:
            url = f"https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records"

            payload = {
                "type": record["type"],
                "name": record["name"],
                "content": record["value"],
                "ttl": record.get("ttl", 300),
                "proxied": record.get("proxied", False)
            }

            try:
                response = await self.client.post(url, headers=headers, json=payload)
                response.raise_for_status()
                logger.info(f"Created DNS record: {record['name']} → {record['value']}")

            except Exception as e:
                logger.error(f"Failed to create DNS record {record['name']}: {e}")
                return False, f"DNS record creation failed: {e}"

        return True, None

    # ========================================================================
    # GoDaddy API Implementation (Placeholder)
    # ========================================================================

    async def _check_godaddy(self, domain: str) -> DomainCheckResult:
        """Check domain availability via GoDaddy API"""

        # TODO: Implement GoDaddy domain check
        # API: GET https://api.godaddy.com/v1/domains/available?domain={domain}

        logger.warning("GoDaddy domain check not yet implemented")
        return DomainCheckResult(
            domain=domain,
            status=DomainStatus.ERROR,
            registrar=DomainRegistrar.GODADDY,
            error="GoDaddy integration not implemented"
        )

    async def close(self):
        """Close HTTP client"""
        await self.client.aclose()
