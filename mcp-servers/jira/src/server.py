"""MCP Jira Server - Model Context Protocol server for Jira integration."""

import asyncio
from typing import Any, Dict, List, Optional

import structlog
from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import (
    Tool,
    TextContent,
    ErrorData,
)

from .config import load_config
from .jira_client import JiraClient, JiraAPIError

logger = structlog.get_logger()


class MCPJiraServer:
    """MCP server for Jira integration."""

    def __init__(self, config_file: Optional[str] = None):
        """Initialize MCP Jira server."""
        self.config = load_config(config_file)
        self.jira_client = JiraClient(self.config)
        self.server = Server("jira-mcp-server")

        # Register tools
        self._register_tools()

        logger.info("mcp_jira_server_initialized")

    def _register_tools(self):
        """Register all Jira tools with the MCP server."""

        # Tool 1: Create Issue
        @self.server.list_tools()
        async def list_tools() -> List[Tool]:
            """List all available tools."""
            return [
                Tool(
                    name="create_issue",
                    description="Create a new Jira issue (story, task, bug, or epic)",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "project_key": {
                                "type": "string",
                                "description": "Project key (e.g., 'HOMELAB')",
                            },
                            "issue_type": {
                                "type": "string",
                                "enum": ["Story", "Task", "Bug", "Epic"],
                                "description": "Type of issue to create",
                            },
                            "summary": {
                                "type": "string",
                                "description": "Brief summary of the issue",
                            },
                            "description": {
                                "type": "string",
                                "description": "Detailed description (optional)",
                            },
                            "priority": {
                                "type": "string",
                                "enum": ["Highest", "High", "Medium", "Low", "Lowest"],
                                "description": "Priority level (optional, default: Medium)",
                            },
                            "labels": {
                                "type": "array",
                                "items": {"type": "string"},
                                "description": "Labels/tags (optional)",
                            },
                            "story_points": {
                                "type": "integer",
                                "description": "Story points (optional)",
                            },
                            "epic_link": {
                                "type": "string",
                                "description": "Epic key to link to (optional)",
                            },
                            "assignee": {
                                "type": "string",
                                "description": "Assignee email address (optional)",
                            },
                            "sprint_id": {
                                "type": "integer",
                                "description": "Sprint ID (optional)",
                            },
                        },
                        "required": ["project_key", "issue_type", "summary"],
                    },
                ),
                Tool(
                    name="search_issues",
                    description="Search for issues using JQL (Jira Query Language)",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "jql": {
                                "type": "string",
                                "description": "JQL query (e.g., 'project=HOMELAB AND status=Open')",
                            },
                            "max_results": {
                                "type": "integer",
                                "description": "Maximum number of results (default: 50)",
                                "default": 50,
                            },
                            "fields": {
                                "type": "array",
                                "items": {"type": "string"},
                                "description": "Fields to include (optional)",
                            },
                        },
                        "required": ["jql"],
                    },
                ),
                Tool(
                    name="get_issue",
                    description="Get detailed information about a specific issue",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "issue_key": {
                                "type": "string",
                                "description": "Issue key (e.g., 'HOMELAB-123')",
                            },
                            "fields": {
                                "type": "array",
                                "items": {"type": "string"},
                                "description": "Specific fields to retrieve (optional)",
                            },
                        },
                        "required": ["issue_key"],
                    },
                ),
                Tool(
                    name="update_issue",
                    description="Update an existing issue",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "issue_key": {
                                "type": "string",
                                "description": "Issue key to update",
                            },
                            "summary": {
                                "type": "string",
                                "description": "New summary (optional)",
                            },
                            "description": {
                                "type": "string",
                                "description": "New description (optional)",
                            },
                            "priority": {
                                "type": "string",
                                "enum": ["Highest", "High", "Medium", "Low", "Lowest"],
                                "description": "New priority (optional)",
                            },
                            "labels": {
                                "type": "array",
                                "items": {"type": "string"},
                                "description": "New labels (optional)",
                            },
                            "story_points": {
                                "type": "integer",
                                "description": "New story points (optional)",
                            },
                            "assignee": {
                                "type": "string",
                                "description": "New assignee email (optional)",
                            },
                        },
                        "required": ["issue_key"],
                    },
                ),
                Tool(
                    name="transition_issue",
                    description="Change the status of an issue (e.g., move to In Progress or Done)",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "issue_key": {
                                "type": "string",
                                "description": "Issue key to transition",
                            },
                            "transition_name": {
                                "type": "string",
                                "description": "Target status name (e.g., 'In Progress', 'Done')",
                            },
                        },
                        "required": ["issue_key", "transition_name"],
                    },
                ),
                Tool(
                    name="add_comment",
                    description="Add a comment to an issue",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "issue_key": {
                                "type": "string",
                                "description": "Issue key to comment on",
                            },
                            "comment": {
                                "type": "string",
                                "description": "Comment text",
                            },
                        },
                        "required": ["issue_key", "comment"],
                    },
                ),
                Tool(
                    name="link_issues",
                    description="Create a link between two issues",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "inward_issue": {
                                "type": "string",
                                "description": "Source issue key",
                            },
                            "outward_issue": {
                                "type": "string",
                                "description": "Target issue key",
                            },
                            "link_type": {
                                "type": "string",
                                "enum": ["Blocks", "Relates", "Duplicates", "Clones"],
                                "description": "Type of link (default: Relates)",
                                "default": "Relates",
                            },
                        },
                        "required": ["inward_issue", "outward_issue"],
                    },
                ),
                Tool(
                    name="get_projects",
                    description="Get all accessible Jira projects",
                    inputSchema={
                        "type": "object",
                        "properties": {},
                    },
                ),
                Tool(
                    name="get_issue_types",
                    description="Get available issue types for a project",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "project_key": {
                                "type": "string",
                                "description": "Project key",
                            },
                        },
                        "required": ["project_key"],
                    },
                ),
            ]

        @self.server.call_tool()
        async def call_tool(name: str, arguments: Dict[str, Any]) -> List[TextContent]:
            """Handle tool calls."""
            try:
                logger.info("tool_called", tool=name, arguments=arguments)

                if name == "create_issue":
                    result = await self._handle_create_issue(arguments)
                elif name == "search_issues":
                    result = await self._handle_search_issues(arguments)
                elif name == "get_issue":
                    result = await self._handle_get_issue(arguments)
                elif name == "update_issue":
                    result = await self._handle_update_issue(arguments)
                elif name == "transition_issue":
                    result = await self._handle_transition_issue(arguments)
                elif name == "add_comment":
                    result = await self._handle_add_comment(arguments)
                elif name == "link_issues":
                    result = await self._handle_link_issues(arguments)
                elif name == "get_projects":
                    result = await self._handle_get_projects(arguments)
                elif name == "get_issue_types":
                    result = await self._handle_get_issue_types(arguments)
                else:
                    raise ValueError(f"Unknown tool: {name}")

                logger.info("tool_completed", tool=name)

                return [TextContent(type="text", text=str(result))]

            except JiraAPIError as e:
                logger.error("jira_api_error", tool=name, error=str(e))
                return [
                    TextContent(
                        type="text",
                        text=f"Jira API Error: {e.message}",
                    )
                ]
            except Exception as e:
                logger.error("tool_error", tool=name, error=str(e))
                return [
                    TextContent(
                        type="text",
                        text=f"Error: {str(e)}",
                    )
                ]

    # ========== Tool Handlers ==========

    async def _handle_create_issue(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Handle create_issue tool call."""
        result = await self.jira_client.create_issue(
            project_key=args["project_key"],
            issue_type=args["issue_type"],
            summary=args["summary"],
            description=args.get("description"),
            priority=args.get("priority"),
            labels=args.get("labels"),
            story_points=args.get("story_points"),
            epic_link=args.get("epic_link"),
            assignee=args.get("assignee"),
            sprint_id=args.get("sprint_id"),
        )
        return {
            "status": "success",
            "message": f"Created {result['issue_key']}: {args['summary']}",
            "issue": result,
        }

    async def _handle_search_issues(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Handle search_issues tool call."""
        result = await self.jira_client.search_issues(
            jql=args["jql"],
            max_results=args.get("max_results", 50),
            fields=args.get("fields"),
        )

        # Simplify response
        issues = []
        for issue in result.get("issues", []):
            fields = issue.get("fields", {})
            issues.append({
                "key": issue["key"],
                "summary": fields.get("summary"),
                "status": fields.get("status", {}).get("name"),
                "assignee": fields.get("assignee", {}).get("displayName") if fields.get("assignee") else None,
                "priority": fields.get("priority", {}).get("name") if fields.get("priority") else None,
            })

        return {
            "status": "success",
            "total": result.get("total", 0),
            "issues": issues,
        }

    async def _handle_get_issue(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Handle get_issue tool call."""
        result = await self.jira_client.get_issue(
            issue_key=args["issue_key"],
            fields=args.get("fields"),
        )

        # Extract key information
        fields = result.get("fields", {})
        return {
            "status": "success",
            "issue": {
                "key": result["key"],
                "summary": fields.get("summary"),
                "description": self._extract_text_from_adf(fields.get("description", {})),
                "status": fields.get("status", {}).get("name"),
                "priority": fields.get("priority", {}).get("name") if fields.get("priority") else None,
                "assignee": fields.get("assignee", {}).get("displayName") if fields.get("assignee") else None,
                "labels": fields.get("labels", []),
                "created": fields.get("created"),
                "updated": fields.get("updated"),
            },
        }

    async def _handle_update_issue(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Handle update_issue tool call."""
        fields: Dict[str, Any] = {}

        if "summary" in args:
            fields["summary"] = args["summary"]

        if "description" in args:
            fields["description"] = {
                "type": "doc",
                "version": 1,
                "content": [
                    {
                        "type": "paragraph",
                        "content": [{"type": "text", "text": args["description"]}],
                    }
                ],
            }

        if "priority" in args:
            fields["priority"] = {"name": args["priority"]}

        if "labels" in args:
            fields["labels"] = args["labels"]

        if "assignee" in args:
            fields["assignee"] = {"emailAddress": args["assignee"]}

        if "story_points" in args:
            fields[self.config.custom_fields.story_points] = args["story_points"]

        await self.jira_client.update_issue(
            issue_key=args["issue_key"],
            fields=fields,
        )

        return {
            "status": "success",
            "message": f"Updated {args['issue_key']}",
        }

    async def _handle_transition_issue(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Handle transition_issue tool call."""
        await self.jira_client.transition_issue(
            issue_key=args["issue_key"],
            transition_name=args["transition_name"],
        )

        return {
            "status": "success",
            "message": f"Transitioned {args['issue_key']} to {args['transition_name']}",
        }

    async def _handle_add_comment(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Handle add_comment tool call."""
        result = await self.jira_client.add_comment(
            issue_key=args["issue_key"],
            comment=args["comment"],
        )

        return {
            "status": "success",
            "message": f"Added comment to {args['issue_key']}",
            "comment_id": result.get("id"),
        }

    async def _handle_link_issues(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Handle link_issues tool call."""
        await self.jira_client.link_issues(
            inward_issue=args["inward_issue"],
            outward_issue=args["outward_issue"],
            link_type=args.get("link_type", "Relates"),
        )

        return {
            "status": "success",
            "message": f"Linked {args['inward_issue']} to {args['outward_issue']}",
        }

    async def _handle_get_projects(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Handle get_projects tool call."""
        projects = await self.jira_client.get_projects()

        simplified = [
            {
                "key": p["key"],
                "name": p["name"],
                "project_type": p.get("projectTypeKey"),
            }
            for p in projects
        ]

        return {
            "status": "success",
            "projects": simplified,
        }

    async def _handle_get_issue_types(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Handle get_issue_types tool call."""
        issue_types = await self.jira_client.get_issue_types(
            project_key=args["project_key"]
        )

        simplified = [
            {
                "id": it["id"],
                "name": it["name"],
                "description": it.get("description", ""),
            }
            for it in issue_types
        ]

        return {
            "status": "success",
            "issue_types": simplified,
        }

    # ========== Utilities ==========

    @staticmethod
    def _extract_text_from_adf(adf: Dict) -> str:
        """Extract plain text from Atlassian Document Format."""
        if not adf or "content" not in adf:
            return ""

        text_parts = []
        for node in adf.get("content", []):
            if node.get("type") == "paragraph":
                for content in node.get("content", []):
                    if content.get("type") == "text":
                        text_parts.append(content.get("text", ""))

        return " ".join(text_parts)

    async def run(self):
        """Run the MCP server."""
        logger.info("starting_mcp_jira_server")

        try:
            async with stdio_server() as (read_stream, write_stream):
                await self.server.run(
                    read_stream,
                    write_stream,
                    self.server.create_initialization_options(),
                )
        finally:
            await self.jira_client.close()
            logger.info("mcp_jira_server_stopped")


async def main():
    """Main entry point."""
    # Setup logging
    structlog.configure(
        processors=[
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.add_log_level,
            structlog.processors.JSONRenderer(),
        ],
    )

    # Create and run server
    server = MCPJiraServer()
    await server.run()


if __name__ == "__main__":
    asyncio.run(main())
