"""
MCP Client for AI Ops Agent
Connects to MCP Jira Server via Model Context Protocol
"""

import asyncio
from typing import Dict, List, Optional, Any
import structlog

try:
    from mcp import ClientSession, StdioServerParameters
    from mcp.client.stdio import stdio_client
    MCP_AVAILABLE = True
except ImportError:
    MCP_AVAILABLE = False
    print("Warning: MCP package not installed. Jira integration will not be available.")

logger = structlog.get_logger()


class MCPJiraClient:
    """
    MCP client for communicating with Jira MCP server.

    This client wraps the MCP protocol and provides simple methods
    for the NL interface to call.
    """

    def __init__(self, server_script_path: str = "/app/mcp-servers/jira/src/server.py"):
        """
        Initialize MCP Jira client.

        Args:
            server_script_path: Path to the MCP Jira server script
        """
        self.server_script_path = server_script_path
        self.session: Optional[ClientSession] = None
        self.connected = False

        if not MCP_AVAILABLE:
            logger.warning("mcp_not_available", message="MCP package not installed")

    async def connect(self) -> bool:
        """
        Connect to the MCP Jira server.

        Returns:
            True if connected successfully, False otherwise
        """
        if not MCP_AVAILABLE:
            logger.error("mcp_connect_failed", reason="MCP package not available")
            return False

        try:
            server_params = StdioServerParameters(
                command="python",
                args=[self.server_script_path],
                env=None  # Inherit environment variables
            )

            # Note: This is a persistent connection that stays open
            self.read_stream, self.write_stream = await stdio_client(server_params).__aenter__()
            self.session = await ClientSession(self.read_stream, self.write_stream).__aenter__()

            # Initialize session
            await self.session.initialize()

            self.connected = True
            logger.info("mcp_jira_connected", server=self.server_script_path)
            return True

        except Exception as e:
            logger.error("mcp_connect_error", error=str(e))
            self.connected = False
            return False

    async def disconnect(self):
        """Disconnect from the MCP Jira server."""
        if self.session:
            try:
                await self.session.__aexit__(None, None, None)
                await stdio_client(None).__aexit__(None, None, None)
            except Exception as e:
                logger.error("mcp_disconnect_error", error=str(e))
            finally:
                self.connected = False
                self.session = None

    def _check_connection(self):
        """Check if connected to MCP server."""
        if not self.connected or not self.session:
            raise RuntimeError("Not connected to MCP Jira server. Call connect() first.")

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
        """
        Create a new Jira issue.

        Args:
            project_key: Project key (e.g., "HOMELAB")
            issue_type: Type of issue ("Story", "Task", "Bug", "Epic")
            summary: Issue summary/title
            description: Detailed description (optional)
            priority: Priority level (optional)
            labels: List of labels (optional)
            story_points: Story points estimate (optional)
            epic_link: Epic key to link to (optional)
            assignee: Assignee email (optional)
            sprint_id: Sprint ID (optional)

        Returns:
            Dictionary with issue details
        """
        self._check_connection()

        arguments = {
            "project_key": project_key,
            "issue_type": issue_type,
            "summary": summary,
        }

        if description:
            arguments["description"] = description
        if priority:
            arguments["priority"] = priority
        if labels:
            arguments["labels"] = labels
        if story_points is not None:
            arguments["story_points"] = story_points
        if epic_link:
            arguments["epic_link"] = epic_link
        if assignee:
            arguments["assignee"] = assignee
        if sprint_id is not None:
            arguments["sprint_id"] = sprint_id

        logger.info("mcp_create_issue", project=project_key, summary=summary)

        result = await self.session.call_tool("create_issue", arguments=arguments)

        # Parse result from MCP response
        response_text = result[0].text if result else "{}"
        import json
        response_data = json.loads(response_text)

        logger.info("mcp_issue_created", issue_key=response_data.get("issue", {}).get("issue_key"))

        return response_data

    async def search_issues(
        self,
        jql: str,
        max_results: int = 50,
        fields: Optional[List[str]] = None,
    ) -> Dict[str, Any]:
        """
        Search for issues using JQL.

        Args:
            jql: JQL query string
            max_results: Maximum number of results to return
            fields: Specific fields to retrieve (optional)

        Returns:
            Dictionary with search results
        """
        self._check_connection()

        arguments = {
            "jql": jql,
            "max_results": max_results,
        }

        if fields:
            arguments["fields"] = fields

        logger.info("mcp_search_issues", jql=jql)

        result = await self.session.call_tool("search_issues", arguments=arguments)

        response_text = result[0].text if result else "{}"
        import json
        response_data = json.loads(response_text)

        logger.info("mcp_search_complete", total=response_data.get("total", 0))

        return response_data

    async def get_issue(
        self,
        issue_key: str,
        fields: Optional[List[str]] = None,
    ) -> Dict[str, Any]:
        """
        Get detailed information about a specific issue.

        Args:
            issue_key: Issue key (e.g., "HOMELAB-123")
            fields: Specific fields to retrieve (optional)

        Returns:
            Dictionary with issue details
        """
        self._check_connection()

        arguments = {"issue_key": issue_key}
        if fields:
            arguments["fields"] = fields

        logger.info("mcp_get_issue", issue_key=issue_key)

        result = await self.session.call_tool("get_issue", arguments=arguments)

        response_text = result[0].text if result else "{}"
        import json
        response_data = json.loads(response_text)

        return response_data

    async def update_issue(
        self,
        issue_key: str,
        summary: Optional[str] = None,
        description: Optional[str] = None,
        priority: Optional[str] = None,
        labels: Optional[List[str]] = None,
        story_points: Optional[int] = None,
        assignee: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Update an existing issue.

        Args:
            issue_key: Issue key to update
            summary: New summary (optional)
            description: New description (optional)
            priority: New priority (optional)
            labels: New labels (optional)
            story_points: New story points (optional)
            assignee: New assignee email (optional)

        Returns:
            Dictionary with update result
        """
        self._check_connection()

        arguments = {"issue_key": issue_key}

        if summary:
            arguments["summary"] = summary
        if description:
            arguments["description"] = description
        if priority:
            arguments["priority"] = priority
        if labels:
            arguments["labels"] = labels
        if story_points is not None:
            arguments["story_points"] = story_points
        if assignee:
            arguments["assignee"] = assignee

        logger.info("mcp_update_issue", issue_key=issue_key)

        result = await self.session.call_tool("update_issue", arguments=arguments)

        response_text = result[0].text if result else "{}"
        import json
        response_data = json.loads(response_text)

        logger.info("mcp_issue_updated", issue_key=issue_key)

        return response_data

    async def transition_issue(
        self,
        issue_key: str,
        transition_name: str,
    ) -> Dict[str, Any]:
        """
        Transition an issue to a new status.

        Args:
            issue_key: Issue key to transition
            transition_name: Target status name (e.g., "In Progress", "Done")

        Returns:
            Dictionary with transition result
        """
        self._check_connection()

        arguments = {
            "issue_key": issue_key,
            "transition_name": transition_name,
        }

        logger.info("mcp_transition_issue", issue_key=issue_key, transition=transition_name)

        result = await self.session.call_tool("transition_issue", arguments=arguments)

        response_text = result[0].text if result else "{}"
        import json
        response_data = json.loads(response_text)

        logger.info("mcp_issue_transitioned", issue_key=issue_key)

        return response_data

    async def add_comment(
        self,
        issue_key: str,
        comment: str,
    ) -> Dict[str, Any]:
        """
        Add a comment to an issue.

        Args:
            issue_key: Issue key to comment on
            comment: Comment text

        Returns:
            Dictionary with comment result
        """
        self._check_connection()

        arguments = {
            "issue_key": issue_key,
            "comment": comment,
        }

        logger.info("mcp_add_comment", issue_key=issue_key)

        result = await self.session.call_tool("add_comment", arguments=arguments)

        response_text = result[0].text if result else "{}"
        import json
        response_data = json.loads(response_text)

        logger.info("mcp_comment_added", issue_key=issue_key)

        return response_data

    async def link_issues(
        self,
        inward_issue: str,
        outward_issue: str,
        link_type: str = "Relates",
    ) -> Dict[str, Any]:
        """
        Create a link between two issues.

        Args:
            inward_issue: Source issue key
            outward_issue: Target issue key
            link_type: Type of link ("Blocks", "Relates", "Duplicates", "Clones")

        Returns:
            Dictionary with link result
        """
        self._check_connection()

        arguments = {
            "inward_issue": inward_issue,
            "outward_issue": outward_issue,
            "link_type": link_type,
        }

        logger.info("mcp_link_issues", inward=inward_issue, outward=outward_issue)

        result = await self.session.call_tool("link_issues", arguments=arguments)

        response_text = result[0].text if result else "{}"
        import json
        response_data = json.loads(response_text)

        logger.info("mcp_issues_linked", inward=inward_issue, outward=outward_issue)

        return response_data


class SyncMCPJiraClient:
    """
    Synchronous wrapper around MCPJiraClient for non-async contexts.

    This is useful when the NL interface is called from synchronous code.
    """

    def __init__(self, server_script_path: str = "/app/mcp-servers/jira/src/server.py"):
        """Initialize sync MCP Jira client."""
        self.async_client = MCPJiraClient(server_script_path)
        self.loop = None

    def _run_async(self, coro):
        """Run an async coroutine in a sync context."""
        if self.loop is None:
            self.loop = asyncio.new_event_loop()
            asyncio.set_event_loop(self.loop)

        return self.loop.run_until_complete(coro)

    def connect(self) -> bool:
        """Connect to MCP Jira server (sync)."""
        return self._run_async(self.async_client.connect())

    def disconnect(self):
        """Disconnect from MCP Jira server (sync)."""
        return self._run_async(self.async_client.disconnect())

    def create_issue(self, **kwargs) -> Dict[str, Any]:
        """Create Jira issue (sync)."""
        return self._run_async(self.async_client.create_issue(**kwargs))

    def search_issues(self, jql: str, max_results: int = 50, fields: Optional[List[str]] = None) -> Dict[str, Any]:
        """Search Jira issues (sync)."""
        return self._run_async(self.async_client.search_issues(jql, max_results, fields))

    def get_issue(self, issue_key: str, fields: Optional[List[str]] = None) -> Dict[str, Any]:
        """Get Jira issue (sync)."""
        return self._run_async(self.async_client.get_issue(issue_key, fields))

    def update_issue(self, issue_key: str, **kwargs) -> Dict[str, Any]:
        """Update Jira issue (sync)."""
        return self._run_async(self.async_client.update_issue(issue_key, **kwargs))

    def transition_issue(self, issue_key: str, transition_name: str) -> Dict[str, Any]:
        """Transition Jira issue (sync)."""
        return self._run_async(self.async_client.transition_issue(issue_key, transition_name))

    def add_comment(self, issue_key: str, comment: str) -> Dict[str, Any]:
        """Add comment to Jira issue (sync)."""
        return self._run_async(self.async_client.add_comment(issue_key, comment))

    def link_issues(self, inward_issue: str, outward_issue: str, link_type: str = "Relates") -> Dict[str, Any]:
        """Link Jira issues (sync)."""
        return self._run_async(self.async_client.link_issues(inward_issue, outward_issue, link_type))
