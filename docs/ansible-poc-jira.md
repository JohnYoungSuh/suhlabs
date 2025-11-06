# Ansible POC - JIRA Epic & Stories

**Epic:** LLM → Ansible Automation Pipeline (8-Hour POC)
**Goal:** Prove natural language can trigger Ansible playbooks on appliances
**Success Metric:** Demo video showing "Add DNS record" → executed on container

---

## Epic: Ansible Automation POC
**Epic Key:** AIOPS-100
**Story Points:** 13
**Priority:** P0 (Critical)
**Labels:** `mvp`, `ansible`, `llm`, `poc`, `p0`
**Sprint:** Sprint 1

---

## Story 1: LLM Intent Parser
**Story Key:** AIOPS-101
**Story Points:** 3
**Priority:** P0
**Assignee:** [Your Name]
**Labels:** `llm`, `backend`, `poc`

### Description:
Parse natural language DNS commands into structured data.

### Acceptance Criteria:
- [ ] Parse "Add DNS record test.local to 192.168.1.100" → `{zone: "test.local", ip: "192.168.1.100", action: "add"}`
- [ ] Handle variations: "Create DNS entry", "Add A record", etc.
- [ ] Return confidence score (0.0-1.0)
- [ ] Handle invalid input gracefully
- [ ] Unit tests with 80%+ coverage

### Technical Notes:
```python
# backend/llm/intent_parser.py
class DNSIntentParser:
    def parse(self, query: str) -> ParsedIntent:
        # Use Ollama LLM to extract:
        # - action (add, remove, update)
        # - zone (domain name)
        # - ip (IP address)
        # - confidence score
```

### Test Cases:
```python
assert parse("Add DNS test.local to 192.168.1.100") == {
    "action": "add",
    "zone": "test.local",
    "ip": "192.168.1.100",
    "confidence": 0.95
}
```

### Time Estimate: 2 hours

---

## Story 2: Ansible Playbook Generator
**Story Key:** AIOPS-102
**Story Points:** 3
**Priority:** P0
**Assignee:** [Your Name]
**Labels:** `ansible`, `backend`, `poc`

### Description:
Generate Ansible playbook YAML from structured intent data.

### Acceptance Criteria:
- [ ] Take structured data → generate valid Ansible YAML
- [ ] Support DNS add/remove operations
- [ ] Playbooks are idempotent (safe to run multiple times)
- [ ] Save to temp file with unique name
- [ ] Return playbook path
- [ ] Unit tests with valid YAML output

### Technical Notes:
```python
# backend/ansible/playbook_generator.py
class PlaybookGenerator:
    def generate_dns_playbook(self, zone: str, ip: str, action: str) -> str:
        # Generate YAML playbook
        # Return path to temp file
```

### Example Output:
```yaml
---
- name: Add DNS record
  hosts: "{{ appliance_id }}"
  tasks:
    - name: Add A record
      lineinfile:
        path: /etc/dnsmasq.d/custom.conf
        line: "address=/{{ zone }}/{{ ip }}"
        create: yes
      notify: restart dnsmasq
  handlers:
    - name: restart dnsmasq
      systemd:
        name: dnsmasq
        state: restarted
```

### Time Estimate: 2 hours

---

## Story 3: Ansible Execution Engine
**Story Key:** AIOPS-103
**Story Points:** 3
**Priority:** P0
**Assignee:** [Your Name]
**Labels:** `ansible`, `backend`, `poc`

### Description:
Execute Ansible playbooks on target appliances and capture results.

### Acceptance Criteria:
- [ ] Execute playbook using `ansible-playbook` command
- [ ] Target Docker container (simulated appliance)
- [ ] Capture stdout, stderr, exit code
- [ ] Parse Ansible JSON output
- [ ] Return structured results (success, changed, failed tasks)
- [ ] Handle execution errors gracefully
- [ ] Timeout after 60 seconds

### Technical Notes:
```python
# backend/ansible/executor.py
class AnsibleExecutor:
    def execute(self, playbook_path: str, appliance_id: str) -> ExecutionResult:
        # Run: ansible-playbook -i inventory playbook.yml
        # Capture output
        # Parse JSON results
        # Return structured data
```

### Example Result:
```python
{
    "status": "success",
    "changed": True,
    "tasks": [
        {"name": "Add A record", "status": "ok", "changed": True}
    ],
    "duration": 2.3,
    "output": "...",
    "errors": []
}
```

### Time Estimate: 2 hours

---

## Story 4: API Integration
**Story Key:** AIOPS-104
**Story Points:** 2
**Priority:** P0
**Assignee:** [Your Name]
**Labels:** `backend`, `api`, `poc`

### Description:
Connect LLM → Generator → Executor in API endpoint.

### Acceptance Criteria:
- [ ] Create POST `/api/v1/dns/add` endpoint
- [ ] Take natural language input
- [ ] Call LLM parser
- [ ] Generate playbook
- [ ] Execute playbook
- [ ] Return results
- [ ] Log all steps for debugging
- [ ] Handle errors at each stage

### Technical Notes:
```python
# backend/api/main.py
@app.post("/api/v1/dns/add")
async def add_dns_record(request: DNSRequest):
    # 1. Parse intent
    intent = await llm_parser.parse(request.query)

    # 2. Generate playbook
    playbook = generator.generate_dns_playbook(intent)

    # 3. Execute
    result = await executor.execute(playbook, request.appliance_id)

    # 4. Return
    return result
```

### Test:
```bash
curl -X POST http://localhost:8000/api/v1/dns/add \
  -H "Content-Type: application/json" \
  -d '{
    "appliance_id": "appliance-001",
    "query": "Add DNS record test.local to 192.168.1.100"
  }'
```

### Time Estimate: 1.5 hours

---

## Story 5: Appliance Config Application
**Story Key:** AIOPS-105
**Story Points:** 2
**Priority:** P0
**Assignee:** [Your Name]
**Labels:** `appliance`, `agent`, `poc`

### Description:
Appliance agent applies DNS configuration when playbook runs.

### Acceptance Criteria:
- [ ] SSH access enabled in Docker container
- [ ] dnsmasq installed and configured
- [ ] Playbook execution creates /etc/dnsmasq.d/custom.conf
- [ ] dnsmasq restarts after config change
- [ ] DNS resolution works for added record
- [ ] Verify with `dig` command

### Technical Notes:
```bash
# Test on appliance:
docker exec appliance-001 cat /etc/dnsmasq.d/custom.conf
# Should show: address=/test.local/192.168.1.100

docker exec appliance-001 dig @localhost test.local +short
# Should return: 192.168.1.100
```

### Setup:
- Ensure Docker container has SSH server
- Add SSH key to authorized_keys
- Configure Ansible inventory with container IP

### Time Estimate: 1.5 hours

---

## Story 6: End-to-End Demo & Documentation
**Story Key:** AIOPS-106
**Story Points:** 1
**Priority:** P0
**Assignee:** [Your Name]
**Labels:** `docs`, `demo`, `poc`

### Description:
Create demo video and documentation showing working POC.

### Acceptance Criteria:
- [ ] Record 2-3 minute demo video
- [ ] Show: NL input → API call → Playbook exec → DNS working
- [ ] Write demo.md with step-by-step instructions
- [ ] Document architecture diagram
- [ ] List limitations and next steps
- [ ] Upload video to YouTube (unlisted)

### Demo Script:
```bash
# 1. Start services
make dev-up

# 2. Add DNS record via API
curl -X POST http://localhost:8000/api/v1/dns/add \
  -d '{"appliance_id": "appliance-001", "query": "Add DNS record test.local to 192.168.1.100"}'

# 3. Verify on appliance
docker exec appliance-001 dig @localhost test.local +short
# Output: 192.168.1.100

# 4. Show in browser
# Visit http://localhost:8000/docs
```

### Time Estimate: 1 hour

---

## Epic Summary

**Total Story Points:** 13
**Estimated Time:** 8-10 hours
**Sprint:** 1 week (with buffer)

### Dependencies:
- AIOPS-101 → AIOPS-102 → AIOPS-103 → AIOPS-104
- AIOPS-105 (parallel with 101-104)
- AIOPS-106 (after all others complete)

### Definition of Done:
- [ ] All acceptance criteria met
- [ ] Unit tests passing
- [ ] Integration test passing
- [ ] Demo video recorded
- [ ] Documentation complete
- [ ] Code reviewed and merged

### Success Metrics:
- Demo shows end-to-end flow working
- LLM accurately parses 90%+ of test queries
- Ansible execution succeeds on first try
- DNS resolution works after config applied
- Total time < 12 hours

---

## How to Import into JIRA

### Method 1: CSV Import
1. Export stories to CSV (see attached)
2. JIRA → Issues → Import from CSV
3. Map fields (Summary, Description, Story Points, etc.)
4. Create Epic link

### Method 2: Manual Creation
1. Create Epic: AIOPS-100
2. Create 6 Stories: AIOPS-101 to AIOPS-106
3. Link stories to epic
4. Set story points
5. Add to Sprint 1

### Method 3: JIRA API (Script)
```bash
# Use jira-cli or REST API to bulk create
curl -X POST https://your-jira.atlassian.net/rest/api/3/issue \
  -H "Authorization: Bearer $JIRA_TOKEN" \
  -d @story.json
```

---

## Recommended Labels

- `mvp` - Part of MVP
- `poc` - Proof of concept
- `ansible` - Ansible-related
- `llm` - LLM integration
- `backend` - Backend code
- `appliance` - Appliance code
- `p0` - Critical priority
- `demo` - For demo/showcase

---

## Next Steps After POC

If POC succeeds:
1. Add more services (Samba, Users, Mail)
2. Add database for persistence
3. Add task queue (Celery)
4. Add authentication
5. Build web UI
6. Deploy to Proxmox

If POC fails:
1. Identify blockers
2. Pivot or simplify
3. Document learnings
4. Decide: continue, pivot, or archive
