# Ansible Learning Guide - Day 4

## What is Ansible Doing Here?

Ansible is AUTOMATING the verification of your foundation services. Instead of running manual commands, you write playbooks that:
1. Check if services are running
2. Test DNS resolution
3. Verify Vault PKI
4. Ensure everything is healthy

## The Two Playbooks You Built

### 1. verify-foundation.yml (500+ lines)
**Purpose:** Bootstrap verification - checks if foundation services are up
**Sections:**
- DNS checks (CoreDNS pods, resolution)
- Vault checks (pods, service, seal status)
- SoftHSM checks (token, slots)
- Integration tests (DNS→Vault connectivity)

### 2. verify-vault-pki.yml (600+ lines)
**Purpose:** PKI verification - checks if certificates work
**Sections:**
- PKI engine checks
- Root CA verification
- Intermediate CA verification
- Role testing
- Certificate issuance testing
- CRL checks

## Key Ansible Concepts in These Playbooks

### 1. Tasks (What to do)
```yaml
- name: Check CoreDNS pods
  shell: kubectl get pods -n kube-system -l k8s-app=coredns
  register: coredns_pods
  changed_when: false
```

**Breaking it down:**
- `name`: Human-readable description
- `shell`: Module to use (runs command)
- `register`: Save output to variable
- `changed_when: false`: This is READ-ONLY (idempotent!)

### 2. Variables (Storing data)
```yaml
- name: Count CoreDNS pods
  set_fact:
    coredns_pod_count: "{{ coredns_pods.stdout_lines | length }}"
```

**Breaking it down:**
- `set_fact`: Creates a variable
- `coredns_pod_count`: Variable name
- `{{ ... }}`: Jinja2 template syntax
- `| length`: Filter to count items

### 3. Assertions (Testing conditions)
```yaml
- name: Verify CoreDNS pods are running
  assert:
    that:
      - coredns_pod_count | int >= 1
    fail_msg: "Expected at least 1 CoreDNS pod, found 0"
    success_msg: "CoreDNS is running ({{ coredns_pod_count }} pods)"
```

**Breaking it down:**
- `assert`: Test condition
- `that`: Condition to check
- `fail_msg`: Error message if fails
- `success_msg`: Success message if passes

### 4. Tags (Selective execution)
```yaml
- name: Verify Vault is running
  shell: kubectl get pods -n vault
  tags:
    - vault
    - pki
```

**How to use:**
```bash
# Run only vault-tagged tasks
ansible-playbook verify-foundation.yml --tags vault

# Run everything except pki tasks
ansible-playbook verify-foundation.yml --skip-tags pki
```

## Idempotency - The Most Important Concept

**Definition:** Running the playbook twice produces the same result.

**Why it matters:**
- Safe to re-run
- No side effects
- Predictable behavior

**How to achieve it:**
```yaml
# ❌ BAD - Not idempotent
- name: Add line to file
  shell: echo "setting=value" >> /etc/config

# ✅ GOOD - Idempotent
- name: Ensure line in file
  lineinfile:
    path: /etc/config
    line: "setting=value"

# ✅ GOOD - Read-only command
- name: Check status
  shell: kubectl get pods
  changed_when: false  # ← This tells Ansible "no changes made"
```

## The Verification Workflow

```
1. Run playbook
   └─ Check prerequisites
       └─ Verify DNS
           └─ Verify Vault
               └─ Verify PKI
                   └─ Test integration
                       └─ Report results

2. If something fails:
   └─ Playbook stops
   └─ Shows error message
   └─ You fix the issue
   └─ Re-run playbook (idempotent!)
```

## How to Study the Playbooks

### Step 1: Look at the structure
```bash
# Count tasks in foundation playbook
grep -c "^  - name:" ansible/playbooks/verify-foundation.yml

# See all task names
grep "^  - name:" ansible/playbooks/verify-foundation.yml
```

### Step 2: Understand a single section
Pick ONE section (e.g., DNS verification) and trace through:
1. What commands does it run?
2. What does it store in variables?
3. What conditions does it check?
4. What happens if it fails?

### Step 3: See how sections connect
Notice how variables from early tasks are used in later tasks:
- DNS check stores `coredns_pod_count`
- Later task uses `coredns_pod_count` to verify ≥1 pod

## Common Ansible Modules Used

### shell / command
```yaml
- shell: kubectl get pods
```
Runs shell commands (use `command` for more security)

### set_fact
```yaml
- set_fact:
    my_var: "{{ some_value }}"
```
Creates/updates variables

### assert
```yaml
- assert:
    that:
      - condition_is_true
```
Tests conditions, fails if false

### debug
```yaml
- debug:
    msg: "Value is {{ my_var }}"
```
Prints information (helpful for debugging)

## Practice Exercises

1. **Read one section:** Pick the DNS verification section and understand every task

2. **Trace a variable:** Follow `coredns_pod_count` through the playbook

3. **Find assertions:** Count how many `assert` tasks exist

4. **Understand tags:** List all unique tags used

## Key Files to Review

```
ansible/
├── README.md               # Concepts guide (750+ lines)
├── ansible.cfg             # Configuration
├── inventory/local.yml     # Inventory definition
└── playbooks/
    ├── verify-foundation.yml    # Foundation checks
    └── verify-vault-pki.yml     # PKI checks
```

## Next Steps After Learning

When you have a real cluster:
1. Set environment variables (VAULT_TOKEN, etc.)
2. Run: `ansible-playbook playbooks/verify-foundation.yml`
3. Watch it check everything automatically
4. If failures, fix and re-run (idempotent!)

---

**Remember:** Ansible is about AUTOMATION. Instead of typing commands manually, you write playbooks that do it for you. Every time. The same way.
