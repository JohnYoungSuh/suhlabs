"""Jira REST API client with authentication, retry, and rate limiting."""

import asyncio
import base64
from typing import Any, Dict, List, Optional
from urllib.parse import urljoin

import httpx
import structlog
from tenacity import (
    retry,
    retry_if_exception_type,
    stop_after_attempt,
    wait_exponential,
)

from .config import Config

logger = structlog.get_logger()


class JiraAPIError(Exception):
    """Base exception for Jira API errors."""

    def __init__(self, message: str, status_code: Optional[int] = None, response: Optional[Dict] = None):
        self.message = message
        self.status_code = status_code
        self.response = response
        super().__init__(self.message)


class JiraAuthenticationError(JiraAPIError):
    """Raised when authentication fails."""


class JiraNotFoundError(JiraAPIError):
    """Raised when resource is not found."""


class JiraRateLimitError(JiraAPIError):
    """Raised when rate limit is exceeded."""


class JiraClient:
    """Asynchronous Jira REST API client."""

    def __init__(self, config: Config):
        """Initialize Jira client."""
        self.config = config
        self.base_url = config.jira.url
        self.api_base = urljoin(self.base_url, "/rest/api/3/")

        # Create auth header
        auth_string = f"{config.jira.user_email}:{config.jira.api_token}"
        auth_bytes = auth_string.encode("utf-8")
        auth_b64 = base64.b64encode(auth_bytes).decode("utf-8")

        self.headers = {
            "Authorization": f"Basic {auth_b64}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        }

        self.client = httpx.AsyncClient(
            headers=self.headers,
            timeout=config.jira.timeout,
            follow_redirects=True,
        )

        # Rate limiting
        self._rate_limit_lock = asyncio.Lock()
        self._last_request_time = 0
        self._min_request_interval = 1.0 / config.jira.rate_limit  # seconds between requests

        logger.info("jira_client_initialized", base_url=self.base_url)

    async def close(self):
        """Close the HTTP client."""
        await self.client.aclose()

    async def _rate_limit(self):
        """Enforce rate limiting."""
        async with self._rate_limit_lock:
            now = asyncio.get_event_loop().time()
            time_since_last_request = now - self._last_request_time

            if time_since_last_request < self._min_request_interval:
                sleep_time = self._min_request_interval - time_since_last_request
                await asyncio.sleep(sleep_time)

            self._last_request_time = asyncio.get_event_loop().time()

    @retry(
        retry=retry_if_exception_type((httpx.TimeoutException, httpx.NetworkError)),
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=10),
    )
    async def _request(
        self,
        method: str,
        endpoint: str,
        json: Optional[Dict] = None,
        params: Optional[Dict] = None,
    ) -> Dict[str, Any]:
        """Make an HTTP request to Jira API with retry logic."""
        await self._rate_limit()

        url = urljoin(self.api_base, endpoint)

        try:
            logger.debug("jira_api_request", method=method, url=url, params=params)

            response = await self.client.request(
                method=method,
                url=url,
                json=json,
                params=params,
            )

            logger.debug("jira_api_response", status_code=response.status_code)

            # Handle error responses
            if response.status_code == 401:
                raise JiraAuthenticationError(
                    "Authentication failed. Check your credentials.",
                    status_code=response.status_code,
                )
            elif response.status_code == 404:
                raise JiraNotFoundError(
                    "Resource not found.",
                    status_code=response.status_code,
                )
            elif response.status_code == 429:
                raise JiraRateLimitError(
                    "Rate limit exceeded. Retry after some time.",
                    status_code=response.status_code,
                )
            elif response.status_code >= 400:
                error_data = response.json() if response.text else {}
                raise JiraAPIError(
                    f"Jira API error: {response.status_code}",
                    status_code=response.status_code,
                    response=error_data,
                )

            response.raise_for_status()

            # Return JSON response or empty dict
            return response.json() if response.text else {}

        except httpx.HTTPStatusError as e:
            logger.error("jira_api_error", error=str(e), status_code=e.response.status_code)
            raise JiraAPIError(
                f"HTTP error: {e.response.status_code}",
                status_code=e.response.status_code,
            )
        except httpx.TimeoutException as e:
            logger.error("jira_api_timeout", error=str(e))
            raise
        except httpx.NetworkError as e:
            logger.error("jira_network_error", error=str(e))
            raise

    # ========== Issue Operations ==========

    async def create_issue(
        self,
        project_key: str,
        issue_type: str,
        summary: str,
        description: Optional[str] = None,
        priority: Optional[str] = None,
        labels: Optional[List[str]] = None,
        story_points: Optional[int] = None,
        epic_link: Optional[str] = None,
        assignee: Optional[str] = None,
        sprint_id: Optional[int] = None,
    ) -> Dict[str, Any]:
        """Create a new Jira issue."""
        fields: Dict[str, Any] = {
            "project": {"key": project_key},
            "issuetype": {"name": issue_type},
            "summary": summary,
        }

        if description:
            fields["description"] = {
                "type": "doc",
                "version": 1,
                "content": [
                    {
                        "type": "paragraph",
                        "content": [{"type": "text", "text": description}],
                    }
                ],
            }

        if priority:
            fields["priority"] = {"name": priority}

        if labels:
            fields["labels"] = labels

        if assignee:
            fields["assignee"] = {"emailAddress": assignee}

        # Add custom fields
        if story_points is not None:
            fields[self.config.custom_fields.story_points] = story_points

        if epic_link:
            fields[self.config.custom_fields.epic_link] = epic_link

        if sprint_id is not None:
            fields[self.config.custom_fields.sprint] = sprint_id

        payload = {"fields": fields}

        logger.info("creating_issue", project=project_key, issue_type=issue_type, summary=summary)

        result = await self._request("POST", "issue", json=payload)

        issue_key = result.get("key")
        issue_id = result.get("id")

        logger.info("issue_created", issue_key=issue_key, issue_id=issue_id)

        return {
            "issue_key": issue_key,
            "issue_id": issue_id,
            "url": f"{self.base_url}/browse/{issue_key}",
        }

    async def get_issue(
        self,
        issue_key: str,
        fields: Optional[List[str]] = None,
    ) -> Dict[str, Any]:
        """Get detailed information about an issue."""
        params = {}
        if fields:
            params["fields"] = ",".join(fields)

        logger.info("getting_issue", issue_key=issue_key)

        result = await self._request("GET", f"issue/{issue_key}", params=params)

        return result

    async def update_issue(
        self,
        issue_key: str,
        fields: Dict[str, Any],
    ) -> None:
        """Update an existing issue."""
        payload = {"fields": fields}

        logger.info("updating_issue", issue_key=issue_key, fields=list(fields.keys()))

        await self._request("PUT", f"issue/{issue_key}", json=payload)

        logger.info("issue_updated", issue_key=issue_key)

    async def search_issues(
        self,
        jql: str,
        max_results: int = 50,
        fields: Optional[List[str]] = None,
        start_at: int = 0,
    ) -> Dict[str, Any]:
        """Search for issues using JQL."""
        params = {
            "jql": jql,
            "maxResults": max_results,
            "startAt": start_at,
        }

        if fields:
            params["fields"] = ",".join(fields)

        logger.info("searching_issues", jql=jql, max_results=max_results)

        result = await self._request("GET", "search", params=params)

        logger.info("search_complete", total=result.get("total", 0), returned=len(result.get("issues", [])))

        return result

    # ========== Transition Operations ==========

    async def get_transitions(self, issue_key: str) -> List[Dict[str, Any]]:
        """Get available transitions for an issue."""
        logger.info("getting_transitions", issue_key=issue_key)

        result = await self._request("GET", f"issue/{issue_key}/transitions")

        transitions = result.get("transitions", [])

        logger.info("transitions_retrieved", issue_key=issue_key, count=len(transitions))

        return transitions

    async def transition_issue(
        self,
        issue_key: str,
        transition_name: str,
    ) -> None:
        """Transition an issue to a new status."""
        # Get available transitions
        transitions = await self.get_transitions(issue_key)

        # Find matching transition
        transition_id = None
        for trans in transitions:
            if trans["name"].lower() == transition_name.lower():
                transition_id = trans["id"]
                break

        if not transition_id:
            available = [t["name"] for t in transitions]
            raise JiraAPIError(
                f"Transition '{transition_name}' not available. Available: {available}",
            )

        payload = {"transition": {"id": transition_id}}

        logger.info("transitioning_issue", issue_key=issue_key, transition=transition_name)

        await self._request("POST", f"issue/{issue_key}/transitions", json=payload)

        logger.info("issue_transitioned", issue_key=issue_key, transition=transition_name)

    # ========== Comment Operations ==========

    async def add_comment(
        self,
        issue_key: str,
        comment: str,
    ) -> Dict[str, Any]:
        """Add a comment to an issue."""
        payload = {
            "body": {
                "type": "doc",
                "version": 1,
                "content": [
                    {
                        "type": "paragraph",
                        "content": [{"type": "text", "text": comment}],
                    }
                ],
            }
        }

        logger.info("adding_comment", issue_key=issue_key)

        result = await self._request("POST", f"issue/{issue_key}/comment", json=payload)

        logger.info("comment_added", issue_key=issue_key, comment_id=result.get("id"))

        return result

    # ========== Link Operations ==========

    async def link_issues(
        self,
        inward_issue: str,
        outward_issue: str,
        link_type: str = "Relates",
    ) -> None:
        """Create a link between two issues."""
        payload = {
            "type": {"name": link_type},
            "inwardIssue": {"key": inward_issue},
            "outwardIssue": {"key": outward_issue},
        }

        logger.info("linking_issues", inward=inward_issue, outward=outward_issue, link_type=link_type)

        await self._request("POST", "issueLink", json=payload)

        logger.info("issues_linked", inward=inward_issue, outward=outward_issue)

    # ========== Metadata Operations ==========

    async def get_projects(self) -> List[Dict[str, Any]]:
        """Get all accessible projects."""
        logger.info("getting_projects")

        result = await self._request("GET", "project")

        logger.info("projects_retrieved", count=len(result))

        return result

    async def get_issue_types(self, project_key: str) -> List[Dict[str, Any]]:
        """Get issue types for a project."""
        logger.info("getting_issue_types", project=project_key)

        result = await self._request("GET", f"project/{project_key}")

        issue_types = result.get("issueTypes", [])

        logger.info("issue_types_retrieved", project=project_key, count=len(issue_types))

        return issue_types
