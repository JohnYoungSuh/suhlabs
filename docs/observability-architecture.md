# Observability Architecture for AI Ops Bot

**Goal:** Full visibility into AI agent decisions, Ansible execution, and system health
**Audience:** Developers, SREs, AI researchers
**Use Case:** Debug failures, improve LLM accuracy, monitor system performance

---

## 🎯 Observability Requirements

### 1. **AI Agent Decision Tracking**
- What did the LLM see? (input query)
- What did it understand? (parsed intent)
- How confident was it? (confidence score)
- What action did it take? (generated playbook)
- Did it succeed? (execution result)

### 2. **Ansible Execution Monitoring**
- Which playbooks are running?
- How long do they take?
- What tasks succeeded/failed?
- What changed on the appliance?
- Any errors or warnings?

### 3. **System Health Monitoring**
- Is the backend API responsive?
- Is Ollama LLM responding?
- Are appliances online?
- What's the resource usage? (CPU, RAM, disk)
- Any alerts or anomalies?

### 4. **User Experience Metrics**
- Response time (query → result)
- Success rate (% of queries handled correctly)
- User satisfaction (feedback)
- Error rate by query type

---

## 🏗️ Architecture

### Observability Stack

```
┌─────────────────────────────────────────────────────┐
│  Data Collection                                    │
├─────────────────────────────────────────────────────┤
│  ┌────────────┐  ┌────────────┐  ┌────────────┐   │
│  │ Logs       │  │ Metrics    │  │ Traces     │   │
│  │ (JSON)     │  │ (Prom)     │  │ (OTLP)     │   │
│  └────────────┘  └────────────┘  └────────────┘   │
│         │                │                │        │
│         ▼                ▼                ▼        │
├─────────────────────────────────────────────────────┤
│  Storage & Processing                               │
├─────────────────────────────────────────────────────┤
│  ┌────────────┐  ┌────────────┐  ┌────────────┐   │
│  │ Loki       │  │ Prometheus │  │ Tempo      │   │
│  │ (Logs)     │  │ (Metrics)  │  │ (Traces)   │   │
│  └────────────┘  └────────────┘  └────────────┘   │
│         │                │                │        │
│         ▼                ▼                ▼        │
├─────────────────────────────────────────────────────┤
│  Visualization & Alerting                           │
├─────────────────────────────────────────────────────┤
│  ┌────────────────────────────────────────────┐    │
│  │            Grafana                         │    │
│  │  - AI Decision Dashboard                   │    │
│  │  - Ansible Execution Dashboard             │    │
│  │  - System Health Dashboard                 │    │
│  │  - Alerts (PagerDuty, Slack)              │    │
│  └────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘
```

---

## 📊 Component Details

### 1. Structured Logging (Loki)

**Goal:** Capture every decision and action with full context

**Log Format:**
```python
# backend/api/main.py
import structlog

logger = structlog.get_logger()

@app.post("/api/v1/dns/add")
async def add_dns_record(request: DNSRequest):
    request_id = generate_id()

    logger.info(
        "dns.request.received",
        request_id=request_id,
        appliance_id=request.appliance_id,
        query=request.query,
        timestamp=datetime.utcnow().isoformat()
    )

    # Parse intent
    intent = await llm_parser.parse(request.query)

    logger.info(
        "llm.intent.parsed",
        request_id=request_id,
        action=intent.action,
        zone=intent.zone,
        ip=intent.ip,
        confidence=intent.confidence,
        llm_model="llama3.2:3b",
        duration_ms=intent.parse_time_ms
    )

    # Generate playbook
    playbook = generator.generate(intent)

    logger.info(
        "ansible.playbook.generated",
        request_id=request_id,
        playbook_path=playbook.path,
        playbook_hash=playbook.sha256,
        tasks_count=len(playbook.tasks)
    )

    # Execute
    result = await executor.execute(playbook, request.appliance_id)

    logger.info(
        "ansible.execution.completed",
        request_id=request_id,
        status=result.status,
        changed=result.changed,
        duration_seconds=result.duration,
        tasks_ok=result.tasks_ok,
        tasks_failed=result.tasks_failed,
        errors=result.errors
    )

    return result
```

**Log Aggregation:**
- All logs → Loki
- Queryable by request_id, appliance_id, user_id
- Retention: 30 days
- Indexed fields: request_id, status, error

**Example Queries:**
```logql
# All failed requests in last hour
{app="aiops-backend"} | json | status="failed" | __timestamp__ > 1h

# LLM confidence < 0.7
{app="aiops-backend"} | json | confidence < 0.7

# Slow Ansible executions (> 10s)
{app="aiops-backend", event="ansible.execution.completed"} | json | duration_seconds > 10
```

---

### 2. Metrics (Prometheus)

**Goal:** Track performance and resource usage

**Metrics to Collect:**

```python
# backend/api/metrics.py
from prometheus_client import Counter, Histogram, Gauge, Info

# Request metrics
dns_requests_total = Counter(
    'aiops_dns_requests_total',
    'Total DNS requests',
    ['appliance_id', 'status']
)

# LLM metrics
llm_parse_duration_seconds = Histogram(
    'aiops_llm_parse_duration_seconds',
    'Time to parse intent with LLM',
    buckets=[0.1, 0.5, 1.0, 2.0, 5.0, 10.0]
)

llm_confidence_score = Histogram(
    'aiops_llm_confidence_score',
    'LLM confidence scores',
    buckets=[0.0, 0.5, 0.6, 0.7, 0.8, 0.9, 0.95, 1.0]
)

# Ansible metrics
ansible_execution_duration_seconds = Histogram(
    'aiops_ansible_execution_duration_seconds',
    'Ansible playbook execution time',
    ['appliance_id', 'playbook_type', 'status'],
    buckets=[1, 5, 10, 30, 60, 120]
)

ansible_tasks_total = Counter(
    'aiops_ansible_tasks_total',
    'Total Ansible tasks executed',
    ['appliance_id', 'task_name', 'status']
)

# Appliance metrics
appliance_online = Gauge(
    'aiops_appliance_online',
    'Appliance online status (1=online, 0=offline)',
    ['appliance_id', 'customer_id']
)

appliance_last_heartbeat_timestamp = Gauge(
    'aiops_appliance_last_heartbeat_timestamp',
    'Timestamp of last heartbeat',
    ['appliance_id']
)

# System metrics
api_response_time_seconds = Histogram(
    'aiops_api_response_time_seconds',
    'API endpoint response time',
    ['endpoint', 'method', 'status_code']
)
```

**Prometheus Scrape Config:**
```yaml
# monitoring/prometheus.yml
scrape_configs:
  - job_name: 'aiops-backend'
    static_configs:
      - targets: ['backend-api:8000']
    metrics_path: '/metrics'
    scrape_interval: 15s

  - job_name: 'aiops-appliances'
    static_configs:
      - targets: ['appliance-001:9100', 'appliance-002:9100']
    scrape_interval: 30s
```

**Key Dashboards:**

1. **AI Decision Dashboard**
   - Queries per minute
   - LLM confidence distribution
   - Parse time p50, p95, p99
   - Success rate by confidence threshold

2. **Ansible Execution Dashboard**
   - Playbooks executed per hour
   - Execution time p50, p95, p99
   - Success/failure rate
   - Most common errors

3. **Appliance Health Dashboard**
   - Online/offline count
   - Last heartbeat time
   - Resource usage (CPU, RAM, disk)
   - Service status (DNS, Samba, etc.)

---

### 3. Distributed Tracing (Tempo/Jaeger)

**Goal:** Trace requests across services

**Trace Flow:**
```
User Request
  │
  ├─> API Endpoint (span: api.dns.add)
  │     │
  │     ├─> LLM Parser (span: llm.parse_intent)
  │     │     │
  │     │     └─> Ollama API (span: ollama.generate)
  │     │
  │     ├─> Playbook Generator (span: ansible.generate_playbook)
  │     │
  │     └─> Ansible Executor (span: ansible.execute)
  │           │
  │           └─> SSH to Appliance (span: ssh.execute)
  │                 │
  │                 └─> dnsmasq restart (span: systemd.restart)
  │
  └─> Response
```

**Implementation (OpenTelemetry):**

```python
# backend/api/main.py
from opentelemetry import trace
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

tracer = trace.get_tracer(__name__)

@app.post("/api/v1/dns/add")
async def add_dns_record(request: DNSRequest):
    with tracer.start_as_current_span("api.dns.add") as span:
        span.set_attribute("appliance_id", request.appliance_id)
        span.set_attribute("query", request.query)

        # Parse intent
        with tracer.start_as_current_span("llm.parse_intent"):
            intent = await llm_parser.parse(request.query)
            span.set_attribute("confidence", intent.confidence)

        # Generate playbook
        with tracer.start_as_current_span("ansible.generate_playbook"):
            playbook = generator.generate(intent)

        # Execute
        with tracer.start_as_current_span("ansible.execute"):
            result = await executor.execute(playbook, request.appliance_id)
            span.set_attribute("success", result.success)

        return result

# Auto-instrument
FastAPIInstrumentor.instrument_app(app)
```

**Benefits:**
- See exact bottlenecks (is LLM or Ansible slow?)
- Debug failures (where did it fail?)
- Optimize performance (where to cache?)

---

### 4. AI Decision Tracking Database

**Goal:** Store every AI decision for analysis and training

**Schema:**
```sql
CREATE TABLE ai_decisions (
    id UUID PRIMARY KEY,
    timestamp TIMESTAMP NOT NULL,
    appliance_id VARCHAR(255) NOT NULL,
    customer_id VARCHAR(255),

    -- Input
    query TEXT NOT NULL,
    query_hash VARCHAR(64),

    -- LLM Output
    parsed_intent JSONB,
    confidence FLOAT,
    llm_model VARCHAR(50),
    llm_tokens_used INTEGER,
    llm_duration_ms INTEGER,

    -- Generated Playbook
    playbook_yaml TEXT,
    playbook_hash VARCHAR(64),

    -- Execution Result
    execution_status VARCHAR(20), -- success, failed, timeout
    execution_duration_seconds FLOAT,
    tasks_executed INTEGER,
    tasks_ok INTEGER,
    tasks_changed INTEGER,
    tasks_failed INTEGER,
    execution_output TEXT,
    execution_errors TEXT[],

    -- Feedback
    user_feedback VARCHAR(20), -- thumbs_up, thumbs_down, null
    user_comment TEXT,

    -- For ML training
    is_training_data BOOLEAN DEFAULT false,
    human_verified BOOLEAN DEFAULT false,
    correct_intent JSONB -- if LLM was wrong
);

-- Indexes
CREATE INDEX idx_timestamp ON ai_decisions(timestamp DESC);
CREATE INDEX idx_appliance ON ai_decisions(appliance_id);
CREATE INDEX idx_query_hash ON ai_decisions(query_hash);
CREATE INDEX idx_confidence ON ai_decisions(confidence);
CREATE INDEX idx_execution_status ON ai_decisions(execution_status);
```

**Use Cases:**

1. **Debug Failures:**
   ```sql
   SELECT * FROM ai_decisions
   WHERE execution_status = 'failed'
   ORDER BY timestamp DESC
   LIMIT 10;
   ```

2. **Find Low Confidence Queries:**
   ```sql
   SELECT query, confidence, execution_status
   FROM ai_decisions
   WHERE confidence < 0.7
   ORDER BY confidence ASC;
   ```

3. **Training Data for Fine-tuning:**
   ```sql
   SELECT query, parsed_intent, user_feedback
   FROM ai_decisions
   WHERE user_feedback = 'thumbs_up'
   AND confidence > 0.8
   AND execution_status = 'success';
   ```

4. **Performance Analytics:**
   ```sql
   SELECT
       DATE_TRUNC('hour', timestamp) as hour,
       COUNT(*) as total_requests,
       AVG(confidence) as avg_confidence,
       AVG(execution_duration_seconds) as avg_duration,
       SUM(CASE WHEN execution_status = 'success' THEN 1 ELSE 0 END)::FLOAT / COUNT(*) as success_rate
   FROM ai_decisions
   WHERE timestamp > NOW() - INTERVAL '7 days'
   GROUP BY hour
   ORDER BY hour DESC;
   ```

---

## 📈 Grafana Dashboards

### Dashboard 1: AI Decision Quality

**Panels:**
1. **Queries per minute** (graph)
2. **Success rate** (gauge) - target: >95%
3. **Confidence distribution** (histogram)
4. **Low confidence queries** (table)
5. **User feedback** (pie chart: thumbs up/down)
6. **Most common queries** (bar chart)

**Alerts:**
- Success rate < 90% for 5 minutes
- >10 queries with confidence < 0.5 in last hour
- >5 failed executions in last 10 minutes

### Dashboard 2: Ansible Execution

**Panels:**
1. **Playbooks executed** (counter)
2. **Execution time p50/p95/p99** (graph)
3. **Success vs Failed** (pie chart)
4. **Tasks by status** (stacked bar: ok, changed, failed)
5. **Execution errors** (table with error messages)
6. **Slowest playbooks** (table)

**Alerts:**
- Playbook execution time > 60s
- Execution failure rate > 10%
- Any playbook failed 3 times in a row

### Dashboard 3: Appliance Health

**Panels:**
1. **Online appliances** (gauge)
2. **Offline appliances** (list)
3. **Last heartbeat time** (table)
4. **CPU usage** (graph per appliance)
5. **Memory usage** (graph per appliance)
6. **Disk usage** (graph per appliance)
7. **Service status** (table: DNS, Samba, Mail, PKI)

**Alerts:**
- Appliance offline for >10 minutes
- CPU > 90% for >5 minutes
- Memory > 90% for >5 minutes
- Disk > 85%
- Any service down

### Dashboard 4: System Overview

**Panels:**
1. **API requests per second** (graph)
2. **API response time p50/p95/p99** (graph)
3. **Active connections** (gauge)
4. **Database connections** (gauge)
5. **LLM queue depth** (gauge)
6. **Ansible queue depth** (gauge)
7. **Error rate** (graph)

**Alerts:**
- API response time p95 > 5s
- Error rate > 5%
- Database connection pool exhausted
- LLM queue depth > 50

---

## 🔍 Query Examples

### Find Patterns in Failed Requests

```promql
# Prometheus query
rate(aiops_dns_requests_total{status="failed"}[5m])
```

```logql
# Loki query
{app="aiops-backend"} | json | status="failed"
| pattern `<_> error: <error>`
| count by error
```

### Identify Slow LLM Responses

```promql
histogram_quantile(0.95,
  rate(aiops_llm_parse_duration_seconds_bucket[5m])
) > 2
```

### Track Appliance Health

```promql
# Appliances online
sum(aiops_appliance_online)

# Appliances offline > 5 minutes
(time() - aiops_appliance_last_heartbeat_timestamp) > 300
```

---

## 🚨 Alerting Rules

**Prometheus Alerting:**

```yaml
# monitoring/alerts.yml
groups:
  - name: aiops_alerts
    interval: 30s
    rules:
      - alert: HighErrorRate
        expr: |
          rate(aiops_dns_requests_total{status="failed"}[5m]) /
          rate(aiops_dns_requests_total[5m]) > 0.10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High error rate: {{ $value }}%"

      - alert: LowLLMConfidence
        expr: |
          aiops_llm_confidence_score < 0.5
        for: 1m
        labels:
          severity: info
        annotations:
          summary: "LLM confidence below 0.5"

      - alert: ApplianceOffline
        expr: |
          aiops_appliance_online == 0
        for: 10m
        labels:
          severity: critical
        annotations:
          summary: "Appliance {{ $labels.appliance_id }} offline"

      - alert: SlowAnsibleExecution
        expr: |
          histogram_quantile(0.95,
            rate(aiops_ansible_execution_duration_seconds_bucket[5m])
          ) > 60
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Ansible execution p95 > 60s"
```

**Alert Destinations:**
- Slack: #aiops-alerts
- PagerDuty: For critical alerts
- Email: For info/warning alerts

---

## 🔧 Implementation Checklist

### Phase 1: Basic Logging (POC)
- [ ] Add structured logging with structlog
- [ ] Log request_id for all operations
- [ ] Log LLM decisions with confidence
- [ ] Log Ansible execution results
- [ ] View logs with: `docker-compose logs -f`

### Phase 2: Metrics (Week 1-2)
- [ ] Add Prometheus client library
- [ ] Instrument API endpoints
- [ ] Instrument LLM parser
- [ ] Instrument Ansible executor
- [ ] Add `/metrics` endpoint
- [ ] Setup Prometheus server
- [ ] Create basic Grafana dashboard

### Phase 3: Tracing (Week 3-4)
- [ ] Add OpenTelemetry SDK
- [ ] Instrument FastAPI automatically
- [ ] Add manual spans for LLM and Ansible
- [ ] Setup Tempo/Jaeger
- [ ] Connect Grafana to Tempo
- [ ] View traces in Grafana

### Phase 4: AI Decision DB (Week 5-6)
- [ ] Create PostgreSQL schema
- [ ] Store every AI decision
- [ ] Add feedback mechanism (thumbs up/down)
- [ ] Create analytics queries
- [ ] Export training data

### Phase 5: Dashboards & Alerts (Week 7-8)
- [ ] Create 4 Grafana dashboards
- [ ] Setup alerting rules
- [ ] Connect to Slack/PagerDuty
- [ ] Test alerts
- [ ] Document runbooks

---

## 📦 Docker Compose Addition

```yaml
# docker-compose.yml additions

  # Prometheus
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./monitoring/alerts.yml:/etc/prometheus/alerts.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'

  # Grafana
  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_INSTALL_PLUGINS=grafana-piechart-panel
    volumes:
      - ./monitoring/grafana/dashboards:/etc/grafana/provisioning/dashboards
      - ./monitoring/grafana/datasources:/etc/grafana/provisioning/datasources
      - grafana_data:/var/lib/grafana
    depends_on:
      - prometheus
      - loki

  # Loki (logs)
  loki:
    image: grafana/loki:latest
    ports:
      - "3100:3100"
    volumes:
      - ./monitoring/loki.yml:/etc/loki/local-config.yaml
      - loki_data:/loki

  # Promtail (log shipper)
  promtail:
    image: grafana/promtail:latest
    volumes:
      - ./monitoring/promtail.yml:/etc/promtail/config.yml
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
    command: -config.file=/etc/promtail/config.yml

volumes:
  prometheus_data:
  grafana_data:
  loki_data:
```

---

## 🎯 Success Metrics

After implementing observability:

1. **Faster Debugging:** < 5 minutes to identify root cause
2. **Better LLM Accuracy:** Data to fine-tune model
3. **Proactive Alerts:** Issues detected before users report
4. **Performance Optimization:** Identify bottlenecks with data
5. **Training Data:** 1000+ verified decisions for fine-tuning

---

## 🔗 Related Documents

- [Micro LLM Strategy](./micro-llm-strategy.md)
- [Integration Gaps Analysis](./integration-gaps.md)
- [Ansible POC JIRA Plan](./ansible-poc-jira.md)
