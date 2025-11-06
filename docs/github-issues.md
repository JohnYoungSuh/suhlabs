# GitHub Issues & Milestones - Ansible POC

**Repository:** JohnYoungSuh/suhlabs
**Milestone:** Ansible POC v0.1
**Target Date:** 1 week from start

---

## Milestone: Ansible POC v0.1

**Description:**
Prove LLM → Ansible → Config pipeline works end-to-end.

**Goals:**
- [x] Project restructured for backend + appliance
- [ ] LLM parses DNS commands
- [ ] Ansible playbooks generated dynamically
- [ ] Playbooks execute on Docker containers
- [ ] DNS configuration applied successfully
- [ ] Demo video created

**Success Criteria:**
- Demo shows natural language → DNS config working
- All tests passing
- Documentation complete

**Due Date:** [Set to 1 week from now]

---

## Issue #1: LLM Intent Parser for DNS Commands

**Title:** Implement LLM intent parser for DNS operations
**Labels:** `enhancement`, `llm`, `backend`, `poc`, `priority-high`
**Milestone:** Ansible POC v0.1
**Assignees:** @yourusername

### Description

Create LLM-based parser that converts natural language DNS commands into structured data.

### Requirements

Parse queries like:
- "Add DNS record test.local to 192.168.1.100"
- "Create A record for api.local pointing to 10.0.0.5"
- "Remove DNS entry for old.local"

Output structured data:
```json
{
  "action": "add|remove|update",
  "zone": "test.local",
  "ip": "192.168.1.100",
  "record_type": "A",
  "confidence": 0.95
}
```

### Acceptance Criteria

- [ ] Parse 10+ variations of DNS commands
- [ ] Return confidence score
- [ ] Handle invalid input gracefully
- [ ] Unit tests with 80%+ coverage
- [ ] Integration test with Ollama

### Technical Details

**File:** `backend/llm/intent_parser.py`

**Dependencies:**
- Ollama running locally or via Docker
- Llama 3.2 3B model pulled

**Testing:**
```python
# tests/test_intent_parser.py
def test_parse_add_dns():
    parser = DNSIntentParser()
    result = parser.parse("Add DNS record test.local to 192.168.1.100")
    assert result.action == "add"
    assert result.zone == "test.local"
    assert result.ip == "192.168.1.100"
    assert result.confidence > 0.8
```

### Time Estimate
2 hours

---

## Issue #2: Ansible Playbook Generator

**Title:** Create dynamic Ansible playbook generator for DNS
**Labels:** `enhancement`, `ansible`, `backend`, `poc`, `priority-high`
**Milestone:** Ansible POC v0.1
**Assignees:** @yourusername

### Description

Generate Ansible playbook YAML files from structured intent data.

### Requirements

Take structured data and generate valid Ansible YAML:

**Input:**
```json
{
  "action": "add",
  "zone": "test.local",
  "ip": "192.168.1.100"
}
```

**Output:** `playbook_12345.yml`
```yaml
---
- name: Add DNS record
  hosts: "{{ target_appliance }}"
  tasks:
    - name: Add A record to dnsmasq
      lineinfile:
        path: /etc/dnsmasq.d/custom.conf
        line: "address=/test.local/192.168.1.100"
        create: yes
      notify: restart dnsmasq

  handlers:
    - name: restart dnsmasq
      systemd:
        name: dnsmasq
        state: restarted
```

### Acceptance Criteria

- [ ] Generate valid Ansible YAML
- [ ] Support add/remove operations
- [ ] Playbooks are idempotent
- [ ] Save to temp directory
- [ ] Return playbook file path
- [ ] Unit tests validate YAML syntax

### Technical Details

**File:** `backend/ansible/playbook_generator.py`

**Libraries:**
- `pyyaml` for YAML generation
- `tempfile` for temp file management

**Template:**
```python
class PlaybookGenerator:
    def generate(self, intent: ParsedIntent, appliance_id: str) -> str:
        playbook = {
            "name": f"{intent.action.capitalize()} DNS record",
            "hosts": appliance_id,
            "tasks": self._generate_tasks(intent),
            "handlers": self._generate_handlers(intent)
        }
        return self._save_to_file(playbook)
```

### Time Estimate
2 hours

---

## Issue #3: Ansible Execution Engine

**Title:** Implement Ansible playbook execution engine
**Labels:** `enhancement`, `ansible`, `backend`, `poc`, `priority-high`
**Milestone:** Ansible POC v0.1
**Assignees:** @yourusername

### Description

Execute generated Ansible playbooks on target appliances and capture results.

### Requirements

- Execute playbooks using `ansible-playbook` command
- Target Docker containers (simulated appliances)
- Capture stdout, stderr, exit code
- Parse Ansible JSON output
- Return structured results
- Handle errors and timeouts

### Acceptance Criteria

- [ ] Execute playbook successfully on Docker container
- [ ] Capture and parse Ansible output
- [ ] Return structured execution results
- [ ] Handle SSH connectivity issues
- [ ] Timeout after 60 seconds
- [ ] Integration tests with real playbook

### Technical Details

**File:** `backend/ansible/executor.py`

**Dependencies:**
- ansible-core installed
- SSH access to appliances
- Inventory file configured

**Execution:**
```python
class AnsibleExecutor:
    async def execute(
        self,
        playbook_path: str,
        appliance_id: str
    ) -> ExecutionResult:
        # Build command
        cmd = [
            "ansible-playbook",
            "-i", "inventory/appliances.yml",
            playbook_path,
            "-e", f"target_appliance={appliance_id}",
            "--timeout=60"
        ]

        # Execute async
        result = await asyncio.create_subprocess_exec(...)

        # Parse output
        return self._parse_result(stdout, stderr, returncode)
```

**Result Format:**
```python
{
    "status": "success|failed",
    "changed": True,
    "tasks": [
        {"name": "Add A record", "status": "ok", "changed": True}
    ],
    "duration_seconds": 2.3,
    "output": "...",
    "errors": []
}
```

### Time Estimate
2-3 hours

---

## Issue #4: API Endpoint for DNS Operations

**Title:** Create API endpoint integrating LLM → Ansible pipeline
**Labels:** `enhancement`, `api`, `backend`, `poc`, `priority-high`
**Milestone:** Ansible POC v0.1
**Assignees:** @yourusername

### Description

Create FastAPI endpoint that orchestrates LLM parsing → Playbook generation → Ansible execution.

### Requirements

**Endpoint:** `POST /api/v1/dns/add`

**Request:**
```json
{
  "appliance_id": "appliance-001",
  "query": "Add DNS record test.local to 192.168.1.100"
}
```

**Response:**
```json
{
  "task_id": "task-abc123",
  "status": "success",
  "intent": {
    "action": "add",
    "zone": "test.local",
    "ip": "192.168.1.100"
  },
  "execution": {
    "changed": true,
    "duration": 2.3
  },
  "message": "DNS record added successfully"
}
```

### Acceptance Criteria

- [ ] POST endpoint accepts natural language
- [ ] Calls LLM parser
- [ ] Generates Ansible playbook
- [ ] Executes playbook
- [ ] Returns structured results
- [ ] Logs all steps
- [ ] Handles errors at each stage
- [ ] OpenAPI documentation auto-generated

### Technical Details

**File:** `backend/api/main.py`

**Workflow:**
```python
@app.post("/api/v1/dns/add")
async def add_dns_record(request: DNSRequest):
    # 1. Parse intent
    intent = await llm_parser.parse(request.query)
    if intent.confidence < 0.7:
        raise HTTPException(400, "Could not parse query")

    # 2. Generate playbook
    playbook = generator.generate_dns_playbook(intent)

    # 3. Execute
    result = await executor.execute(playbook, request.appliance_id)

    # 4. Return
    return {
        "status": "success" if result.success else "failed",
        "intent": intent,
        "execution": result
    }
```

### Testing

```bash
# Test endpoint
curl -X POST http://localhost:8000/api/v1/dns/add \
  -H "Content-Type: application/json" \
  -d '{
    "appliance_id": "appliance-001",
    "query": "Add DNS record test.local to 192.168.1.100"
  }'
```

### Time Estimate
1.5 hours

---

## Issue #5: Appliance DNS Configuration

**Title:** Configure appliance to accept and apply DNS changes
**Labels:** `enhancement`, `appliance`, `infrastructure`, `poc`, `priority-high`
**Milestone:** Ansible POC v0.1
**Assignees:** @yourusername

### Description

Setup Docker container (simulated appliance) to:
- Accept SSH connections
- Have dnsmasq installed
- Apply DNS configuration from Ansible
- Verify DNS resolution works

### Requirements

**Container Setup:**
- SSH server running
- dnsmasq installed and configured
- `/etc/dnsmasq.d/` directory writable
- Ansible can connect via SSH
- DNS queries work on port 53

### Acceptance Criteria

- [ ] Docker container accepts SSH from Ansible
- [ ] dnsmasq installed and running
- [ ] Ansible playbook execution succeeds
- [ ] Config file `/etc/dnsmasq.d/custom.conf` created
- [ ] dnsmasq restarts after config change
- [ ] DNS resolution works: `dig @localhost test.local` returns correct IP
- [ ] Document setup in README

### Technical Details

**Dockerfile updates:**
```dockerfile
# appliance/Dockerfile
FROM debian:bookworm-slim

# Install SSH + dnsmasq
RUN apt-get update && apt-get install -y \
    openssh-server \
    dnsmasq \
    dnsutils \
    && mkdir /var/run/sshd

# Configure SSH
RUN echo 'root:aiops123' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Configure dnsmasq
COPY services/dns/dnsmasq.conf /etc/dnsmasq.conf
RUN mkdir -p /etc/dnsmasq.d

EXPOSE 22 53/udp

CMD service ssh start && dnsmasq --no-daemon
```

**Testing:**
```bash
# SSH into container
docker exec appliance-001 ssh root@localhost

# Check dnsmasq
docker exec appliance-001 systemctl status dnsmasq

# Test DNS
docker exec appliance-001 dig @localhost test.local +short
```

### Time Estimate
1.5 hours

---

## Issue #6: POC Demo Video & Documentation

**Title:** Create demo video and documentation for Ansible POC
**Labels:** `documentation`, `demo`, `poc`, `priority-medium`
**Milestone:** Ansible POC v0.1
**Assignees:** @yourusername

### Description

Record demo video showing end-to-end workflow and write comprehensive documentation.

### Requirements

**Demo Video (2-3 minutes):**
1. Show architecture diagram
2. Start services: `make dev-up`
3. Send natural language command via API
4. Show LLM parsing the intent
5. Show Ansible playbook generation
6. Show playbook execution
7. Verify DNS resolution works
8. Explain what was proved

**Documentation:**
- demo.md with step-by-step instructions
- architecture.md with updated diagrams
- README updated with POC results
- Next steps and limitations

### Acceptance Criteria

- [ ] 2-3 minute demo video recorded
- [ ] Video uploaded to YouTube (unlisted)
- [ ] demo.md written with reproduction steps
- [ ] Architecture diagram created (Mermaid or draw.io)
- [ ] README updated with POC section
- [ ] List limitations and future work
- [ ] Share link in project

### Demo Script

```bash
# Terminal 1: Start services
make dev-up
make dev-logs

# Terminal 2: Test API
curl -X POST http://localhost:8000/api/v1/dns/add \
  -H "Content-Type: application/json" \
  -d '{
    "appliance_id": "appliance-001",
    "query": "Add DNS record test.local to 192.168.1.100"
  }' | jq

# Terminal 3: Verify on appliance
docker exec appliance-001 dig @localhost test.local +short
# Should output: 192.168.1.100

# Show in browser
open http://localhost:8000/docs
```

### Architecture Diagram

```mermaid
graph LR
    User[User] -->|Natural Language| API[FastAPI]
    API -->|Parse| LLM[Ollama LLM]
    LLM -->|Structured Data| Gen[Playbook Generator]
    Gen -->|YAML| Exec[Ansible Executor]
    Exec -->|SSH| App[Appliance]
    App -->|Config Applied| DNS[dnsmasq]
```

### Time Estimate
1-2 hours

---

## How to Create Issues in GitHub

### Method 1: Web UI
1. Go to https://github.com/JohnYoungSuh/suhlabs/issues
2. Click "New Issue"
3. Copy/paste each issue template above
4. Set labels, milestone, assignee
5. Create issue

### Method 2: GitHub CLI
```bash
gh issue create \
  --title "Implement LLM intent parser for DNS operations" \
  --body "$(cat issue-01.md)" \
  --label "enhancement,llm,backend,poc,priority-high" \
  --milestone "Ansible POC v0.1" \
  --assignee @me
```

### Method 3: GitHub API
```bash
curl -X POST https://api.github.com/repos/JohnYoungSuh/suhlabs/issues \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Implement LLM intent parser",
    "body": "...",
    "labels": ["enhancement", "llm"],
    "milestone": 1
  }'
```

---

## Project Board Setup

**Columns:**
1. **Backlog** - Not started
2. **In Progress** - Currently working on
3. **Review** - Ready for review
4. **Done** - Completed

**Automation:**
- Move to "In Progress" when issue assigned
- Move to "Review" when PR created
- Move to "Done" when PR merged

---

## Labels to Create

```bash
# Priority
priority-high (red)
priority-medium (yellow)
priority-low (gray)

# Type
enhancement (green)
bug (red)
documentation (blue)
demo (purple)

# Component
backend (blue)
appliance (green)
llm (purple)
ansible (orange)
api (cyan)
infrastructure (gray)

# Status
poc (yellow)
mvp (red)
blocked (red)
help-wanted (green)
```

---

## Milestone Checklist

Before closing milestone:
- [ ] All 6 issues completed
- [ ] All tests passing
- [ ] Demo video created
- [ ] Documentation updated
- [ ] Code reviewed
- [ ] Tagged release: v0.1.0-poc
- [ ] Retrospective: What worked? What didn't?
- [ ] Decision: Continue to MVP or pivot?
