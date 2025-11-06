# Micro LLM Strategy for Deterministic Issues

**Goal:** Create a small, fast, specialized LLM for common/deterministic infrastructure tasks
**Why:** Lower cost, faster response, higher accuracy than general-purpose LLMs
**Target:** DNS, Samba, user management - predictable, repetitive tasks

---

## 🎯 Problem Statement

### Current Approach (General LLM):
- **Model:** Llama 3.2 3B or Llama 3.1 8B
- **Size:** 2-8 GB
- **Speed:** 1-5 seconds per query
- **Accuracy:** 70-90% (general knowledge, inconsistent on specific tasks)
- **Cost:** High inference cost at scale

### Target Approach (Micro LLM):
- **Model:** Fine-tuned Llama 3.2 1B or custom small model
- **Size:** 500 MB - 1 GB
- **Speed:** 0.1-0.5 seconds per query
- **Accuracy:** 95-99% (domain-specific, deterministic tasks)
- **Cost:** 10x cheaper inference

---

## 🔬 Micro LLM Design

### What is a Micro LLM?

A **micro LLM** is a small language model fine-tuned for a specific, narrow domain:

1. **Start with small base model** (Llama 3.2 1B, Phi-3 Mini, TinyLlama)
2. **Fine-tune on domain-specific data** (DNS commands, Samba config, user management)
3. **Optimize for deterministic outputs** (structured JSON, not creative text)
4. **Quantize to 4-bit** (reduce size, increase speed)
5. **Deploy locally** (no API costs, low latency)

### Advantages:

| Metric | General LLM (3B-8B) | Micro LLM (1B fine-tuned) |
|--------|---------------------|---------------------------|
| Model Size | 2-8 GB | 500 MB - 1 GB |
| Inference Time | 1-5 seconds | 0.1-0.5 seconds |
| RAM Usage | 4-10 GB | 1-2 GB |
| Accuracy (domain) | 70-90% | 95-99% |
| Cost per 1M queries | $50-200 | $5-20 |
| Works offline | Yes | Yes |
| Hallucinations | Common | Rare (trained on facts) |

---

## 📊 Use Cases for Micro LLM

### Tier 1: Deterministic Infrastructure Tasks (Best Fit)

**DNS Management:**
```
Input: "Add DNS record api.local to 10.0.0.5"
Output: {"action": "add", "zone": "api.local", "ip": "10.0.0.5", "type": "A"}

Input: "Remove DNS entry for old.example.com"
Output: {"action": "remove", "zone": "old.example.com"}

Input: "Create CNAME from www.local to server.local"
Output: {"action": "add", "zone": "www.local", "target": "server.local", "type": "CNAME"}
```

**User Management:**
```
Input: "Create user john with password abc123"
Output: {"action": "add_user", "username": "john", "password": "abc123"}

Input: "Add john to samba group"
Output: {"action": "add_to_group", "username": "john", "group": "samba"}

Input: "Remove user jane"
Output: {"action": "remove_user", "username": "jane"}
```

**Samba/File Sharing:**
```
Input: "Create share called 'family' at /srv/shares/family"
Output: {"action": "create_share", "name": "family", "path": "/srv/shares/family"}

Input: "Give john access to family share"
Output: {"action": "grant_access", "username": "john", "share": "family"}
```

### Tier 2: Semi-Deterministic (Good Fit)

- Mail relay configuration
- PKI certificate generation
- Firewall rules
- Network interface configuration

### Tier 3: Non-Deterministic (Poor Fit - Use General LLM)

- Troubleshooting unknown errors
- Answering "why" questions
- Creative problem solving
- Free-form conversation

---

## 🏗️ Implementation Strategy

### Phase 1: Data Collection (Week 1)

**Goal:** Collect 1,000-5,000 examples of real infrastructure commands

**Sources:**
1. **Synthetic Data Generation:**
   ```python
   # Generate training data programmatically
   templates = [
       "Add DNS record {zone} to {ip}",
       "Create DNS entry for {zone} pointing to {ip}",
       "Add A record {zone} → {ip}",
       "Set up DNS for {zone} at {ip}",
   ]

   zones = ["test.local", "api.local", "db.local", ...]
   ips = ["192.168.1.100", "10.0.0.5", ...]

   for template in templates:
       for zone, ip in zip(zones, ips):
           query = template.format(zone=zone, ip=ip)
           intent = {"action": "add", "zone": zone, "ip": ip, "type": "A"}
           training_data.append((query, intent))
   ```

2. **Observability Data:**
   - Export queries from `ai_decisions` table (see observability doc)
   - Filter for high-confidence, successful executions
   - Human verify a sample (100-200 examples)

3. **Ansible Playbook Reverse Engineering:**
   - Take existing playbooks
   - Generate natural language descriptions
   - Create (NL → Playbook parameters) pairs

4. **Crowdsourcing:**
   - Ask beta users to phrase commands naturally
   - Collect 100+ real user queries
   - Manually label with correct intents

**Target Dataset:**
```json
[
  {
    "input": "Add DNS record test.local to 192.168.1.100",
    "output": {
      "action": "dns_add",
      "zone": "test.local",
      "ip": "192.168.1.100",
      "record_type": "A"
    },
    "confidence": 1.0,
    "verified": true
  },
  ...
]
```

**Dataset Size Goals:**
- DNS: 1,000 examples
- Users: 500 examples
- Samba: 500 examples
- Total: 2,000-3,000 examples

---

### Phase 2: Model Selection & Fine-tuning (Week 2-3)

**Base Model Options:**

| Model | Size | Speed | Accuracy (Base) | Fine-tune Difficulty |
|-------|------|-------|-----------------|---------------------|
| **TinyLlama 1.1B** | 550 MB | Very Fast | Low | Easy |
| **Phi-3 Mini (3.8B)** | 2 GB | Fast | High | Medium |
| **Llama 3.2 1B** | 700 MB | Very Fast | Medium | Easy |
| **Qwen2 0.5B** | 300 MB | Ultra Fast | Low | Easy |

**Recommendation:** Start with **Llama 3.2 1B**
- Good balance of size, speed, accuracy
- Easy to fine-tune with Ollama or Hugging Face
- Compatible with existing infrastructure

**Fine-tuning Approach:**

**Option A: Ollama Modelfile (Simple)**
```dockerfile
# Modelfile for micro-aiops-llm
FROM llama3.2:1b

# Set system prompt
SYSTEM """
You are an AI assistant specialized in infrastructure management.
Parse user commands related to DNS, users, and file sharing.
Always respond with valid JSON containing the action and parameters.
"""

# Add training examples
TEMPLATE """
{{ if .System }}### System:
{{ .System }}{{ end }}
### User:
{{ .Prompt }}
### Assistant:
{{ .Response }}
"""

PARAMETER temperature 0.1
PARAMETER top_p 0.9
PARAMETER stop "###"
```

**Option B: Hugging Face Fine-tuning (Advanced)**
```python
from transformers import AutoModelForCausalLM, AutoTokenizer, Trainer

# Load base model
model = AutoModelForCausalLM.from_pretrained("meta-llama/Llama-3.2-1B")
tokenizer = AutoTokenizer.from_pretrained("meta-llama/Llama-3.2-1B")

# Prepare dataset
train_dataset = load_dataset("json", data_files="training_data.json")

# Fine-tune
trainer = Trainer(
    model=model,
    train_dataset=train_dataset,
    args=TrainingArguments(
        per_device_train_batch_size=4,
        num_train_epochs=3,
        learning_rate=2e-5,
        output_dir="./micro-aiops-llm"
    )
)

trainer.train()
model.save_pretrained("./micro-aiops-llm-finetuned")
```

**Option C: LoRA Fine-tuning (Efficient)**
```python
from peft import LoraConfig, get_peft_model

# Add LoRA adapters (trains only 1% of parameters)
lora_config = LoraConfig(
    r=16,
    lora_alpha=32,
    target_modules=["q_proj", "v_proj"],
    lora_dropout=0.05,
    bias="none",
    task_type="CAUSAL_LM"
)

model = get_peft_model(model, lora_config)
# Fine-tune as above, but much faster and smaller
```

**Fine-tuning Time:**
- Dataset: 2,000 examples
- GPU: RTX 4090 or A100
- Time: 2-6 hours
- Cost (cloud GPU): $10-30

---

### Phase 3: Quantization & Optimization (Week 3)

**Goal:** Reduce model size from 1 GB → 500 MB for faster inference

**Quantization Methods:**

**4-bit Quantization (Recommended):**
```python
from transformers import BitsAndBytesConfig

bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.float16
)

model = AutoModelForCausalLM.from_pretrained(
    "./micro-aiops-llm-finetuned",
    quantization_config=bnb_config
)

# Size: 1 GB → 500 MB
# Speed: 2x faster
# Accuracy: ~99% of original
```

**GGUF Format (For Ollama):**
```bash
# Convert to GGUF for Ollama
python convert-hf-to-gguf.py ./micro-aiops-llm-finetuned \
  --outfile micro-aiops-llm.gguf \
  --outtype q4_0

# Import to Ollama
ollama create micro-aiops:latest -f Modelfile
```

---

### Phase 4: Deployment & Testing (Week 4)

**Deployment Architecture:**

```
┌─────────────────────────────────────────┐
│  Backend API                            │
│  ┌─────────────────────────────────┐   │
│  │  Router                         │   │
│  │  ┌─────────────┬──────────────┐ │   │
│  │  │ Deterministic│ Non-Deterministic│   │
│  │  │ (DNS, Users,│ (Troubleshoot,│ │   │
│  │  │  Samba)     │  Questions)   │ │   │
│  │  └──────┬──────┴──────┬────────┘ │   │
│  │         │             │          │   │
│  │         ▼             ▼          │   │
│  │  ┌─────────────┬──────────────┐ │   │
│  │  │ Micro LLM   │ General LLM  │ │   │
│  │  │ (1B, 500MB) │ (3B, 2GB)    │ │   │
│  │  │ 0.2s        │ 2s           │ │   │
│  │  │ 95%+ acc    │ 80%+ acc     │ │   │
│  │  └─────────────┴──────────────┘ │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

**Router Logic:**

```python
# backend/llm/router.py
class LLMRouter:
    def __init__(self):
        self.micro_llm = MicroLLM("micro-aiops:latest")
        self.general_llm = GeneralLLM("llama3.2:3b")

    async def parse(self, query: str) -> ParsedIntent:
        # Classify query type
        query_type = self.classify(query)

        if query_type in ["dns", "user", "samba", "mail"]:
            # Use fast, specialized micro LLM
            return await self.micro_llm.parse(query)
        else:
            # Use general LLM for complex/unknown queries
            return await self.general_llm.parse(query)

    def classify(self, query: str) -> str:
        # Simple keyword-based classification
        query_lower = query.lower()

        if any(k in query_lower for k in ["dns", "record", "domain", "dig"]):
            return "dns"
        elif any(k in query_lower for k in ["user", "username", "password", "account"]):
            return "user"
        elif any(k in query_lower for k in ["share", "samba", "smb", "folder"]):
            return "samba"
        elif any(k in query_lower for k in ["mail", "email", "smtp", "postfix"]):
            return "mail"
        else:
            return "unknown"  # Use general LLM
```

**A/B Testing:**

```python
# Test micro LLM vs general LLM
test_queries = [
    "Add DNS record test.local to 192.168.1.100",
    "Create user john with password abc123",
    "Why is my DNS not working?",  # Non-deterministic
    ...
]

for query in test_queries:
    # Micro LLM
    start = time.time()
    micro_result = micro_llm.parse(query)
    micro_time = time.time() - start

    # General LLM
    start = time.time()
    general_result = general_llm.parse(query)
    general_time = time.time() - start

    # Compare
    print(f"Query: {query}")
    print(f"Micro: {micro_result} ({micro_time:.2f}s)")
    print(f"General: {general_result} ({general_time:.2f}s)")
```

**Expected Results:**
- Micro LLM: 95%+ accuracy on deterministic tasks, 5-10x faster
- General LLM: Better on open-ended questions, but slower
- Router: Best of both worlds

---

### Phase 5: Continuous Improvement (Ongoing)

**Feedback Loop:**

```
User Query
    │
    ▼
Micro LLM Parse
    │
    ▼
Execute Ansible
    │
    ▼
Success/Failure
    │
    ├─> If confidence < 0.9 or failed → Flag for review
    │
    ▼
Human Verification
    │
    ▼
Add to Training Data
    │
    ▼
Re-train Weekly
    │
    ▼
Deploy Updated Model
```

**Automated Retraining:**

```python
# scripts/retrain_micro_llm.py
def weekly_retrain():
    # 1. Export new verified data from database
    new_data = export_verified_decisions(since=last_week)

    # 2. Combine with existing training data
    all_data = load_training_data() + new_data

    # 3. Fine-tune model
    fine_tune(all_data, epochs=1)  # Incremental training

    # 4. Evaluate on test set
    accuracy = evaluate(test_set)

    # 5. If improved, deploy new model
    if accuracy > current_accuracy + 0.02:
        deploy_model()
        notify_team(f"New model deployed: {accuracy:.2%} accuracy")
```

**Metrics to Track:**
- Accuracy (% correct parses)
- Speed (average inference time)
- Confidence distribution
- User feedback (thumbs up/down)
- Fallback rate (% using general LLM)

---

## 🧪 Evaluation & Benchmarks

### Test Dataset (200 examples)

**DNS (50 examples):**
- Add/remove A records
- Add/remove CNAME records
- Variations in phrasing
- Edge cases (IPv6, wildcards)

**Users (50 examples):**
- Create/delete users
- Add to groups
- Password changes
- Permissions

**Samba (50 examples):**
- Create shares
- Grant/revoke access
- Set permissions

**Complex (50 examples):**
- Multi-step commands
- Ambiguous queries
- Error cases

### Success Criteria

| Metric | Target | Stretch Goal |
|--------|--------|--------------|
| Accuracy | 95% | 98% |
| Speed | <0.5s | <0.2s |
| Model Size | <1 GB | <500 MB |
| Confidence (correct) | >0.9 | >0.95 |
| Confidence (wrong) | <0.7 | <0.5 |

---

## 💰 Cost Analysis

### Inference Cost Comparison (1 Million Queries)

| Approach | Cost | Notes |
|----------|------|-------|
| **GPT-4 API** | $15,000 | $0.015/query |
| **GPT-3.5 Turbo API** | $1,500 | $0.0015/query |
| **Llama 3.1 8B (self-hosted)** | $200 | GPU server costs |
| **Llama 3.2 3B (self-hosted)** | $100 | Smaller GPU |
| **Micro LLM 1B (self-hosted)** | $20 | CPU inference possible |

**Savings:** 50-750x cheaper than API-based LLMs

---

## 🔧 Implementation Checklist

### Week 1: Data Collection
- [ ] Generate 1,000 synthetic DNS examples
- [ ] Generate 500 synthetic user examples
- [ ] Generate 500 synthetic Samba examples
- [ ] Export 100+ real queries from observability DB
- [ ] Human verify 50+ examples
- [ ] Create train/test split (80/20)

### Week 2: Model Training
- [ ] Setup training environment (GPU)
- [ ] Download Llama 3.2 1B base model
- [ ] Fine-tune on training data (2-6 hours)
- [ ] Evaluate on test set
- [ ] Target: >90% accuracy

### Week 3: Optimization
- [ ] Quantize to 4-bit
- [ ] Convert to GGUF format
- [ ] Import to Ollama
- [ ] Benchmark speed and accuracy
- [ ] Compare to general LLM

### Week 4: Deployment
- [ ] Create LLM router
- [ ] Deploy micro LLM alongside general LLM
- [ ] A/B test with 10% of traffic
- [ ] Monitor metrics
- [ ] Rollout to 100% if successful

### Ongoing: Improvement
- [ ] Collect feedback
- [ ] Add verified examples to training data
- [ ] Retrain weekly
- [ ] Monitor accuracy drift
- [ ] Expand to new domains (mail, PKI, firewall)

---

## 📈 Success Metrics

After deploying micro LLM:

1. **50%+ faster response time** (0.5s → 0.2s)
2. **95%+ accuracy** on deterministic tasks
3. **10x lower inference cost** vs general LLM
4. **Higher user satisfaction** (faster, more accurate)
5. **Training data for future improvements**

---

## 🔗 Related Documents

- [Observability Architecture](./observability-architecture.md) - How to collect training data
- [Ansible POC JIRA](./ansible-poc-jira.md) - Initial implementation
- [Integration Gaps](./integration-gaps.md) - What's needed for production

---

## 🚀 Quick Start (Once POC is Done)

```bash
# 1. Export training data
python scripts/export_training_data.py > training_data.json

# 2. Fine-tune model
python scripts/finetune_micro_llm.py --data training_data.json

# 3. Deploy
ollama create micro-aiops:latest -f Modelfile

# 4. Test
curl -X POST http://localhost:8000/api/v1/dns/add \
  -d '{"query": "Add DNS test.local to 192.168.1.100"}' \
  --header "X-Use-Micro-LLM: true"
```

That's it! You now have a fast, specialized LLM for infrastructure automation. 🎉
