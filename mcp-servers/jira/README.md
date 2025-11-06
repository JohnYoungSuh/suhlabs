# MCP Jira Server

Model Context Protocol (MCP) server for Jira integration with AI Ops Agent.

## Overview

The MCP Jira Server enables natural language interaction with Jira through the AI Ops Agent. Users can create, update, search, and manage Jira issues using plain English commands.

**Example user interactions:**
- "Create a task for fixing the DNS issue"
- "Show me all my open tasks"
- "Move HOMELAB-123 to Done"
- "Add a comment to HOMELAB-456: Deployed to production"

## Architecture

```
User Input (Natural Language)
    ↓
AI Ops Agent (NL Interface)
    ↓
MCP Jira Client (MCP Protocol)
    ↓
MCP Jira Server (This component)
    ↓
Jira REST API
    ↓
Jira Cloud/Server
```

## Features

### Supported Operations

1. **Create Issues**
   - Create stories, tasks, bugs, epics
   - Set priority, labels, story points
   - Link to epics and sprints
   - Assign to users

2. **Search Issues**
   - Search using JQL (Jira Query Language)
   - Filter by status, assignee, project
   - Retrieve specific fields

3. **Update Issues**
   - Update summary, description, priority
   - Change labels and story points
   - Reassign issues

4. **Transition Issues**
   - Move issues between statuses
   - "To Do" → "In Progress" → "Done"

5. **Comments**
   - Add comments to issues
   - Automated updates from AI agent

6. **Link Issues**
   - Create relationships between issues
   - Blocks, Relates, Duplicates, etc.

## Prerequisites

- **Jira Instance**: Cloud, Server, or Data Center
- **Jira API Token**: For authentication
- **Python 3.11+**: For running the server
- **Kubernetes Cluster**: For deployment (optional)
- **Docker**: For containerization (optional)

## Setup Instructions

### 1. Get Jira API Token

#### For Jira Cloud:

1. Go to https://id.atlassian.com/manage-profile/security/api-tokens
2. Click **Create API token**
3. Give it a name (e.g., "MCP Jira Server")
4. Copy the token (you won't be able to see it again!)

#### For Jira Server/Data Center:

1. Generate a Personal Access Token in Jira
2. Or use username/password (not recommended)

### 2. Find Custom Field IDs

Your Jira instance has custom fields with unique IDs. You need to find these:

**Method 1: Via Jira UI**
1. Go to Jira Settings → Issues → Custom Fields
2. Click on a custom field (e.g., "Story Points")
3. Look at the URL: `/secure/admin/EditCustomField!default.jspa?id=10016`
4. The ID is `customfield_10016`

**Method 2: Via API**
```bash
curl -X GET \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  https://your-domain.atlassian.net/rest/api/3/field
```

Look for:
- `customfield_10016` - Story Points (usually)
- `customfield_10014` - Epic Link (usually)
- `customfield_10020` - Sprint (usually)

**Update `config/jira.yaml.example` with your field IDs**

### 3. Local Development Setup

```bash
# Clone repository
cd mcp-servers/jira

# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Copy environment file
cp .env.example .env

# Edit .env with your credentials
nano .env
```

**Edit `.env`:**
```bash
JIRA_URL=https://your-domain.atlassian.net
JIRA_USER_EMAIL=your-email@example.com
JIRA_API_TOKEN=your-api-token-here

JIRA_DEFAULT_PROJECT=HOMELAB
MCP_SERVER_LOG_LEVEL=INFO
```

**Copy and edit config:**
```bash
cp config/jira.yaml.example config/jira.yaml
nano config/jira.yaml
```

Update custom field IDs based on Step 2.

### 4. Run Locally

```bash
# Activate virtual environment
source venv/bin/activate

# Run server
python src/server.py
```

The server will start and listen for MCP protocol connections via stdio.

### 5. Test with MCP Client

```python
import asyncio
from mcp_client import MCPJiraClient

async def test():
    client = MCPJiraClient("src/server.py")
    await client.connect()

    # Create an issue
    result = await client.create_issue(
        project_key="HOMELAB",
        issue_type="Task",
        summary="Test issue from MCP",
        description="This is a test",
        priority="Medium"
    )

    print(f"Created: {result}")

    await client.disconnect()

asyncio.run(test())
```

## Kubernetes Deployment

### 1. Build Docker Image

```bash
# Build image
docker build -t mcp-jira-server:latest .

# Tag for your registry
docker tag mcp-jira-server:latest your-registry/mcp-jira-server:v1.0.0

# Push to registry
docker push your-registry/mcp-jira-server:v1.0.0
```

### 2. Create Jira Secret

**Important:** Do NOT commit secrets to Git!

```bash
# Create secret from command line
kubectl create secret generic mcp-jira-secret \
  --from-literal=JIRA_URL=https://your-domain.atlassian.net \
  --from-literal=JIRA_USER_EMAIL=your-email@example.com \
  --from-literal=JIRA_API_TOKEN=your-api-token \
  --namespace=default

# Or create from .env file
kubectl create secret generic mcp-jira-secret \
  --from-env-file=.env \
  --namespace=default
```

**For production, use:**
- HashiCorp Vault
- Sealed Secrets
- External Secrets Operator
- Cloud provider secret managers (AWS Secrets Manager, GCP Secret Manager, etc.)

### 3. Update Custom Field IDs

Edit `cluster/mcp-jira-server/configmap.yaml`:

```yaml
data:
  jira.yaml: |
    custom_fields:
      story_points: customfield_XXXXX  # Your actual field ID
      epic_link: customfield_YYYYY     # Your actual field ID
      sprint: customfield_ZZZZZ        # Your actual field ID
```

### 4. Update Image in Kustomization

Edit `cluster/mcp-jira-server/kustomization.yaml`:

```yaml
images:
  - name: mcp-jira-server
    newName: your-registry/mcp-jira-server
    newTag: v1.0.0
```

### 5. Deploy to Kubernetes

```bash
# Apply manifests
kubectl apply -k cluster/mcp-jira-server/

# Check deployment
kubectl get pods -l app=mcp-jira-server
kubectl logs -l app=mcp-jira-server --tail=50

# Check service
kubectl get svc mcp-jira-server
```

### 6. Integrate with AI Ops Agent

Update AI Ops Agent deployment to include MCP client:

```yaml
env:
- name: MCP_JIRA_SERVER_PATH
  value: "mcp-jira-server.default.svc.cluster.local:8001"
```

The AI Ops Agent will automatically connect to the MCP Jira Server.

## Configuration Reference

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `JIRA_URL` | Jira instance URL | - | Yes |
| `JIRA_USER_EMAIL` | User email for authentication | - | Yes |
| `JIRA_API_TOKEN` | API token for authentication | - | Yes |
| `JIRA_TIMEOUT` | API request timeout (seconds) | 30 | No |
| `JIRA_MAX_RETRIES` | Maximum retry attempts | 3 | No |
| `JIRA_RATE_LIMIT` | Requests per second limit | 10 | No |
| `JIRA_DEFAULT_PROJECT` | Default project key | HOMELAB | No |
| `JIRA_DEFAULT_ISSUE_TYPE` | Default issue type | Task | No |
| `MCP_SERVER_HOST` | Server host | 0.0.0.0 | No |
| `MCP_SERVER_PORT` | Server port | 8001 | No |
| `MCP_SERVER_LOG_LEVEL` | Logging level | INFO | No |

### Custom Fields Configuration

Located in `config/jira.yaml`:

```yaml
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

## Usage Examples

### Natural Language (via AI Ops Agent)

```
User: "Create a task for deploying the new API"
Agent: ✅ Created HOMELAB-789: Deploy new API

User: "Show me all my open tasks"
Agent: Found 5 open tasks:
- HOMELAB-123: Fix DNS configuration
- HOMELAB-456: Update Ollama model
...

User: "Move HOMELAB-123 to In Progress"
Agent: ✅ Moved HOMELAB-123 to In Progress

User: "Add comment to HOMELAB-123: Started working on this"
Agent: ✅ Added comment to HOMELAB-123
```

### Direct MCP Client Usage

```python
from mcp_client import SyncMCPJiraClient

# Create client
client = SyncMCPJiraClient()
client.connect()

# Create issue
result = client.create_issue(
    project_key="HOMELAB",
    issue_type="Bug",
    summary="Login page not loading",
    description="Users report login page is blank",
    priority="High",
    labels=["bug", "frontend", "urgent"]
)
print(f"Created: {result['issue']['issue_key']}")

# Search issues
results = client.search_issues(
    jql="project=HOMELAB AND status='In Progress'",
    max_results=10
)
print(f"Found {results['total']} issues")

# Update issue
client.update_issue(
    issue_key="HOMELAB-123",
    priority="Critical",
    labels=["hotfix"]
)

# Transition issue
client.transition_issue(
    issue_key="HOMELAB-123",
    transition_name="Done"
)

# Disconnect
client.disconnect()
```

## Troubleshooting

### Common Issues

#### 1. Authentication Failed (401)

**Cause:** Invalid API token or wrong email

**Solution:**
- Verify JIRA_URL is correct
- Regenerate API token
- Ensure JIRA_USER_EMAIL matches the token owner

#### 2. Resource Not Found (404)

**Cause:** Wrong issue key or project doesn't exist

**Solution:**
- Check project key exists: `GET /rest/api/3/project`
- Verify issue key format: `PROJ-123`

#### 3. Custom Field Not Found

**Cause:** Custom field ID doesn't exist in your Jira instance

**Solution:**
- Find correct field IDs (see Setup Step 2)
- Update `config/jira.yaml` with your field IDs

#### 4. Rate Limit Exceeded (429)

**Cause:** Too many API requests

**Solution:**
- Increase `JIRA_RATE_LIMIT` value
- Jira Cloud limit: 10 requests/second per user
- Add delays between requests

#### 5. MCP Connection Failed

**Cause:** MCP server not running or wrong path

**Solution:**
```bash
# Check server is running
kubectl get pods -l app=mcp-jira-server

# Check logs
kubectl logs -l app=mcp-jira-server --tail=100

# Verify service
kubectl get svc mcp-jira-server
```

### Debug Mode

Enable debug logging:

```bash
# Environment variable
export MCP_SERVER_LOG_LEVEL=DEBUG

# Or in .env
MCP_SERVER_LOG_LEVEL=DEBUG
```

View detailed logs:

```bash
# Local
python src/server.py 2>&1 | tee mcp-jira.log

# Kubernetes
kubectl logs -f -l app=mcp-jira-server --all-containers
```

## Security Best Practices

1. **Never commit secrets to Git**
   - Use `.env` for local development
   - Add `.env` to `.gitignore`

2. **Use Kubernetes Secrets**
   - Store credentials in Kubernetes Secrets
   - Or use external secret management (Vault, Sealed Secrets)

3. **Rotate API tokens regularly**
   - Rotate every 90 days
   - Generate new token before expiry

4. **Limit API token permissions**
   - Use service accounts with minimal permissions
   - Only grant required project access

5. **Enable audit logging**
   - Monitor all Jira API calls
   - Track issue creation/updates

6. **Network security**
   - Use ClusterIP service (internal only)
   - No external access to MCP server
   - TLS for Jira API communication

## Monitoring

### Metrics (Prometheus)

The server exposes metrics on `/metrics`:

- `jira_api_requests_total` - Total API requests
- `jira_api_errors_total` - Total API errors
- `jira_api_request_duration_seconds` - Request latency
- `jira_issues_created_total` - Issues created
- `jira_issues_updated_total` - Issues updated

### Health Checks

```bash
# Liveness
kubectl exec -it <pod-name> -- python -c "import sys; sys.exit(0)"

# Readiness
kubectl get pods -l app=mcp-jira-server
```

## Development

### Running Tests

```bash
# Install dev dependencies
pip install -r requirements.txt

# Run tests
pytest tests/ -v

# Run with coverage
pytest tests/ --cov=src --cov-report=html
```

### Code Quality

```bash
# Format code
black src/

# Lint
ruff check src/

# Type checking
mypy src/
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

MIT License

## Support

For issues and questions:
- GitHub Issues: https://github.com/JohnYoungSuh/suhlabs/issues
- Documentation: See `ARCHITECTURE.md`

## References

- [Jira REST API Documentation](https://developer.atlassian.com/cloud/jira/platform/rest/v3/)
- [Model Context Protocol](https://modelcontextprotocol.io/)
- [MCP Python SDK](https://github.com/modelcontextprotocol/python-sdk)
