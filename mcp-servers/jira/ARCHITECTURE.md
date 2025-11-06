# MCP Jira Server Architecture

## Overview

The MCP Jira Server provides a Model Context Protocol interface for the AI Ops Agent to interact with Jira programmatically. It enables natural language requests to be translated into Jira API operations.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                          User Input                              │
│            "Create a task for fixing DNS issue"                  │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                  AI Ops Agent (FastAPI)                          │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │         NL Interface Engine                               │   │
│  │  - Intent Recognition                                     │   │
│  │  - Permission Checking                                    │   │
│  │  - Context Management                                     │   │
│  └─────────────────────┬────────────────────────────────────┘   │
└────────────────────────┼─────────────────────────────────────────┘
                         │ MCP Protocol
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                     MCP Jira Server                              │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              MCP Server Core                              │   │
│  │  - Tool Registration                                      │   │
│  │  - Request/Response Handling                              │   │
│  │  - Error Management                                       │   │
│  └─────────────────────┬────────────────────────────────────┘   │
│                        │                                          │
│  ┌─────────────────────┴────────────────────────────────────┐   │
│  │              Jira Tool Handlers                           │   │
│  │  - create_issue      - search_issues                      │   │
│  │  - update_issue      - add_comment                        │   │
│  │  - transition_issue  - get_issue                          │   │
│  │  - link_issues       - add_attachment                     │   │
│  └─────────────────────┬────────────────────────────────────┘   │
│                        │                                          │
│  ┌─────────────────────┴────────────────────────────────────┐   │
│  │           Jira REST API Client                            │   │
│  │  - Authentication (API Token/OAuth)                       │   │
│  │  - Request Builder                                        │   │
│  │  - Response Parser                                        │   │
│  │  - Rate Limiting                                          │   │
│  │  - Retry Logic                                            │   │
│  └─────────────────────┬────────────────────────────────────┘   │
└────────────────────────┼─────────────────────────────────────────┘
                         │ HTTPS
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Jira REST API                                 │
│              (Cloud/Server/Data Center)                          │
└─────────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. MCP Server Core

**Technology:** Python with `mcp` package (Model Context Protocol SDK)

**Responsibilities:**
- Implement MCP protocol handlers
- Register available tools
- Route requests to appropriate handlers
- Manage server lifecycle
- Handle errors and validation

**Key Files:**
- `src/server.py` - Main MCP server entry point
- `src/config.py` - Configuration management

### 2. Jira Tool Handlers

**Tool Definitions:**

#### `create_issue`
Creates a new Jira issue (story, task, bug, epic)

**Input Schema:**
```json
{
  "project_key": "string",
  "issue_type": "Story|Task|Bug|Epic",
  "summary": "string",
  "description": "string (optional)",
  "priority": "Highest|High|Medium|Low|Lowest (optional)",
  "labels": "array<string> (optional)",
  "story_points": "number (optional)",
  "epic_link": "string (optional)",
  "assignee": "string (optional)",
  "sprint_id": "number (optional)"
}
```

**Output:**
```json
{
  "issue_key": "PROJ-123",
  "issue_id": "10234",
  "url": "https://your-domain.atlassian.net/browse/PROJ-123"
}
```

#### `search_issues`
Search for issues using JQL (Jira Query Language)

**Input Schema:**
```json
{
  "jql": "string",
  "max_results": "number (optional, default 50)",
  "fields": "array<string> (optional)"
}
```

**Output:**
```json
{
  "total": 10,
  "issues": [
    {
      "key": "PROJ-123",
      "summary": "Fix DNS issue",
      "status": "In Progress",
      "assignee": "john@example.com"
    }
  ]
}
```

#### `update_issue`
Update an existing issue

**Input Schema:**
```json
{
  "issue_key": "string",
  "fields": {
    "summary": "string (optional)",
    "description": "string (optional)",
    "priority": "string (optional)",
    "labels": "array<string> (optional)",
    "story_points": "number (optional)",
    "assignee": "string (optional)"
  }
}
```

#### `transition_issue`
Change issue status (To Do → In Progress → Done)

**Input Schema:**
```json
{
  "issue_key": "string",
  "transition_name": "In Progress|Done|To Do|etc."
}
```

#### `add_comment`
Add a comment to an issue

**Input Schema:**
```json
{
  "issue_key": "string",
  "comment": "string"
}
```

#### `get_issue`
Get detailed information about a specific issue

**Input Schema:**
```json
{
  "issue_key": "string",
  "fields": "array<string> (optional)"
}
```

#### `link_issues`
Create a link between two issues

**Input Schema:**
```json
{
  "inward_issue": "string",
  "outward_issue": "string",
  "link_type": "Blocks|Relates to|Duplicates|etc."
}
```

#### `add_attachment`
Attach a file to an issue

**Input Schema:**
```json
{
  "issue_key": "string",
  "file_path": "string",
  "file_name": "string (optional)"
}
```

### 3. Jira REST API Client

**Class:** `JiraClient`

**Key Methods:**
- `authenticate()` - Authenticate with API token or OAuth
- `create_issue(data)` - POST /rest/api/3/issue
- `search_issues(jql, fields)` - GET /rest/api/3/search
- `update_issue(key, fields)` - PUT /rest/api/3/issue/{key}
- `get_transitions(key)` - GET /rest/api/3/issue/{key}/transitions
- `transition_issue(key, transition_id)` - POST /rest/api/3/issue/{key}/transitions
- `add_comment(key, body)` - POST /rest/api/3/issue/{key}/comment
- `get_issue(key, fields)` - GET /rest/api/3/issue/{key}

**Features:**
- Automatic retry with exponential backoff
- Rate limiting (respects Jira API limits)
- Request/response logging
- Error handling with meaningful messages

### 4. Configuration

**Environment Variables:**
```bash
# Jira Connection
JIRA_URL=https://your-domain.atlassian.net
JIRA_USER_EMAIL=your-email@example.com
JIRA_API_TOKEN=your-api-token

# Optional: For OAuth
JIRA_OAUTH_CLIENT_ID=
JIRA_OAUTH_CLIENT_SECRET=

# MCP Server
MCP_SERVER_HOST=0.0.0.0
MCP_SERVER_PORT=8001

# Logging
LOG_LEVEL=INFO
```

**Configuration File:** `config/jira.yaml`
```yaml
jira:
  default_project: HOMELAB
  default_issue_type: Task
  max_results: 100
  timeout: 30
  retry_attempts: 3

custom_fields:
  story_points: customfield_10016
  epic_link: customfield_10014
  sprint: customfield_10020

issue_types:
  story: 10001
  task: 10002
  bug: 10003
  epic: 10000
```

## Integration with AI Ops Agent

### Natural Language Interface Updates

Add new intent patterns to `cluster/ai-ops-agent/src/nl_interface.py`:

```python
class Intent(Enum):
    # ... existing intents ...
    CREATE_JIRA_ISSUE = "create_jira_issue"
    UPDATE_JIRA_ISSUE = "update_jira_issue"
    SEARCH_JIRA_ISSUES = "search_jira_issues"
    COMMENT_JIRA_ISSUE = "comment_jira_issue"

INTENT_PATTERNS = {
    Intent.CREATE_JIRA_ISSUE: [
        r"create.*(?:task|story|bug|issue).*(?:for|about|to)",
        r"(?:track|log).*(?:in jira|as (?:task|issue))",
        r"need.*jira.*(?:task|issue|story)",
        r"make.*jira.*(?:ticket|issue)",
    ],
    Intent.UPDATE_JIRA_ISSUE: [
        r"update.*(?:task|issue|ticket).*(?:PROJ-\d+|\w+-\d+)",
        r"change.*(?:status|priority|assignee).*(?:PROJ-\d+)",
        r"move.*(?:PROJ-\d+).*(?:to do|in progress|done)",
    ],
    Intent.SEARCH_JIRA_ISSUES: [
        r"(?:find|search|show|list).*(?:tasks?|issues?|tickets?)",
        r"what.*(?:tasks?|issues?).*(?:assigned|open|in progress)",
        r"show.*(?:my|all).*(?:jira|tasks?|issues?)",
    ],
    Intent.COMMENT_JIRA_ISSUE: [
        r"(?:add|post).*comment.*(?:PROJ-\d+)",
        r"comment.*(?:on|to).*(?:PROJ-\d+)",
    ],
}
```

### MCP Client Integration

Add MCP client to AI Ops Agent:

```python
# cluster/ai-ops-agent/src/mcp_client.py
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

class MCPJiraClient:
    def __init__(self, server_path: str):
        self.server_path = server_path
        self.session = None

    async def connect(self):
        server_params = StdioServerParameters(
            command="python",
            args=[self.server_path],
        )

        async with stdio_client(server_params) as (read, write):
            async with ClientSession(read, write) as session:
                await session.initialize()
                self.session = session

    async def create_issue(self, **kwargs):
        result = await self.session.call_tool("create_issue", arguments=kwargs)
        return result

    async def search_issues(self, jql: str, max_results: int = 50):
        result = await self.session.call_tool("search_issues", arguments={
            "jql": jql,
            "max_results": max_results
        })
        return result
```

### Action Executors

Add Jira action executors:

```python
# cluster/ai-ops-agent/src/executors/jira_executor.py
async def execute_create_jira_issue(parsed: ParsedIntent, mcp_client: MCPJiraClient) -> Dict:
    result = await mcp_client.create_issue(
        project_key=parsed.parameters.get("project_key", "HOMELAB"),
        issue_type=parsed.parameters["issue_type"],
        summary=parsed.parameters["summary"],
        description=parsed.parameters.get("description"),
        priority=parsed.parameters.get("priority", "Medium"),
        labels=parsed.parameters.get("labels", [])
    )

    return {
        "status": "success",
        "message": f"Created {result['issue_key']}: {parsed.parameters['summary']}",
        "issue_url": result["url"]
    }
```

## Deployment

### Docker Container

**Dockerfile:**
```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY src/ ./src/
COPY config/ ./config/

# Run MCP server
CMD ["python", "src/server.py"]
```

### Kubernetes Deployment

**Service Type:** ClusterIP (internal only)
**Replicas:** 2 (for redundancy)
**Resources:**
- CPU: 200m request, 500m limit
- Memory: 256Mi request, 512Mi limit

**ConfigMap:** Jira configuration
**Secret:** API token/OAuth credentials

### Networking

- AI Ops Agent → MCP Jira Server: Internal service communication
- MCP Jira Server → Jira Cloud/Server: HTTPS egress (port 443)

## Security Considerations

1. **Authentication:**
   - Store API tokens in Kubernetes Secrets
   - Rotate tokens every 90 days
   - Use service accounts for Jira Server/Data Center

2. **Authorization:**
   - MCP server has minimal Jira permissions
   - Users inherit permissions from their Jira account
   - AI agent checks user permissions before executing actions

3. **Network Security:**
   - MCP server only accessible within cluster
   - TLS for Jira API communication
   - No direct external access

4. **Audit Logging:**
   - Log all Jira API calls
   - Track user actions through AI agent
   - Store logs in centralized logging system

## Testing Strategy

1. **Unit Tests:**
   - Test each tool handler in isolation
   - Mock Jira API responses
   - Validate input schemas

2. **Integration Tests:**
   - Test against Jira sandbox instance
   - Verify end-to-end workflows
   - Test error handling and retries

3. **User Acceptance Tests:**
   - Natural language to Jira issue creation
   - Search and query operations
   - Status transitions and updates

## Performance Considerations

- **Caching:** Cache Jira metadata (projects, issue types, fields)
- **Rate Limiting:** Respect Jira API rate limits (10 requests/second for Cloud)
- **Batch Operations:** Support bulk issue creation/updates
- **Async Operations:** Use asyncio for non-blocking I/O

## Monitoring and Observability

**Metrics:**
- `jira_api_requests_total` - Total API requests
- `jira_api_errors_total` - Total API errors
- `jira_api_request_duration_seconds` - Request latency
- `jira_issues_created_total` - Issues created via MCP
- `jira_issues_updated_total` - Issues updated via MCP

**Logs:**
- API request/response logging
- Error details with stack traces
- User action audit trail

## Future Enhancements

1. **Webhook Support:** Receive Jira events (issue created, updated)
2. **Advanced JQL Builder:** Natural language to JQL translation
3. **Bulk Operations:** Create/update multiple issues at once
4. **Jira Automation Integration:** Trigger Jira automation rules
5. **Custom Fields Mapping:** Automatic detection and mapping
6. **Multi-Project Support:** Manage multiple Jira projects
7. **Attachment Handling:** Upload files, screenshots to issues
8. **Smart Issue Linking:** Automatic relationship detection

## References

- [Jira REST API Documentation](https://developer.atlassian.com/cloud/jira/platform/rest/v3/)
- [Model Context Protocol Specification](https://modelcontextprotocol.io/)
- [MCP Python SDK](https://github.com/modelcontextprotocol/python-sdk)
