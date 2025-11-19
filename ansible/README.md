# Ansible Automation

Infrastructure automation for the AI Ops Substrate project using Ansible.

## What is Ansible?

**Ansible** is an agentless automation tool that configures systems, deploys applications, and orchestrates workflows.

**Key Concepts:**

1. **Declarative** - Describe what you want, not how to get there
2. **Idempotent** - Running twice produces the same result (safe to re-run)
3. **Agentless** - No software to install on managed systems
4. **YAML-based** - Human-readable configuration

**Why We Use Ansible:**

- Verify foundation services are running correctly
- Automate deployment steps
- Test idempotency (no changes on second run)
- Document infrastructure as code
- Enable repeatable deployments

## Quick Start

```bash
cd ansible

# Install Ansible
./install-ansible.sh

# Test connection
ansible -i inventory/local.yml localhost -m ping

# Run ad-hoc command
ansible -i inventory/local.yml localhost -m shell -a 'uptime'

# Run playbook
ansible-playbook playbooks/verify-foundation.yml

# Lint playbooks
ansible-lint playbooks/*.yml
```

## Directory Structure

```
ansible/
├── ansible.cfg              # Ansible configuration
├── install-ansible.sh       # Installation script
├── README.md                # This file
│
├── inventory/               # Inventory files (what hosts exist)
│   ├── local.yml            # Local development inventory
│   ├── staging.yml          # Staging environment (future)
│   └── production.yml       # Production environment (future)
│
├── playbooks/               # Playbooks (what to do)
│   ├── verify-foundation.yml    # Verify foundation services
│   ├── verify-vault-pki.yml     # Verify Vault PKI
│   └── bootstrap.yml            # Bootstrap infrastructure
│
└── roles/                   # Reusable roles
    ├── coredns/             # CoreDNS role
    ├── vault/               # Vault role
    └── common/              # Common tasks
```

## Ansible Concepts

### 1. Inventory

**What:** Defines what hosts exist and how to connect to them.

**Example (`inventory/local.yml`):**
```yaml
all:
  children:
    local:
      hosts:
        localhost:
          ansible_connection: local
          ansible_python_interpreter: /usr/bin/python3
      vars:
        environment: development
        cluster_name: kind-suh-labs
```

**Key Points:**
- **Groups**: Organize hosts (e.g., `local`, `production`)
- **Host Variables**: Specific to one host
- **Group Variables**: Shared across a group
- **Connection Settings**: How to connect (local, SSH, etc.)

**View Inventory:**
```bash
# List all hosts
ansible-inventory -i inventory/local.yml --list

# Graph inventory structure
ansible-inventory -i inventory/local.yml --graph
```

### 2. Modules

**What:** Units of work that Ansible executes (e.g., copy file, install package).
Here is the way to read Ansible task Structure
  - name: <label>               # 🏷️ Human-readable description (optional but recommended)
    <module_name>:              # 🧩 The action module (e.g. shell, copy, assert, k8s)
      <parameter1>: <value>     # 🔧 Parameters specific to that module
      <parameter2>: <value>
    register: <var_name>        # 📦 (Optional) Save output for later use
    when: <condition>           # 🧠 (Optional) Conditional execution
    tags: [<tag1>, <tag2>]      # 🏷️ (Optional) For selective runs

**Common Modules:**

**System:**
- `ping` - Test connectivity
- `shell` - Run shell commands
- `command` - Run commands (more secure, no shell expansion)
- `file` - Manage files/directories
- `copy` - Copy files to remote systems
- `template` - Render Jinja2 templates

**Package Management:**
- `apt` - Manage apt packages (Debian/Ubuntu)
- `yum` - Manage yum packages (RHEL/CentOS)
- `pip` - Manage Python packages

**Kubernetes:**
- `k8s` - Manage Kubernetes resources
- `k8s_info` - Query Kubernetes resources
- `helm` - Manage Helm charts

**Examples:**
```bash
# Test connectivity
ansible localhost -m ping

# Get system uptime
ansible localhost -m shell -a 'uptime'

# Check if file exists
ansible localhost -m stat -a 'path=/etc/hosts'

# Create directory
ansible localhost -m file -a 'path=/tmp/test state=directory'
```

### 3. Playbooks

**What:** YAML files that define a series of tasks to execute.

**Structure:**
```yaml
---
- name: Verify Foundation Services
  hosts: localhost
  gather_facts: yes

  tasks:
    - name: Check CoreDNS pods
      k8s_info:
        kind: Pod
        namespace: kube-system
        label_selectors:
          - k8s-app=coredns
      register: coredns_pods

    - name: Display pod count
      debug:
        msg: "CoreDNS pods: {{ coredns_pods.resources | length }}"
```

**Key Elements:**
- **hosts** - Which systems to run on
- **gather_facts** - Collect system information
- **tasks** - What to do (in order)
- **register** - Save output to variable
- **debug** - Display information

**Run Playbook:**
```bash
ansible-playbook playbooks/verify-foundation.yml

# With extra verbosity
ansible-playbook playbooks/verify-foundation.yml -v
ansible-playbook playbooks/verify-foundation.yml -vv
ansible-playbook playbooks/verify-foundation.yml -vvv

# Dry run (check mode)
ansible-playbook playbooks/verify-foundation.yml --check

# Step-by-step (prompt before each task)
ansible-playbook playbooks/verify-foundation.yml --step
```

### 4. Roles

**What:** Reusable collections of tasks, handlers, and variables.

**Why Use Roles:**
- Organize playbooks into logical units
- Share code across playbooks
- Follow best practices (directory structure)
- Easier testing and maintenance

**Role Structure:**
```
roles/
└── vault/
    ├── tasks/          # Main tasks
    │   └── main.yml
    ├── handlers/       # Event handlers (e.g., restart service)
    │   └── main.yml
    ├── vars/           # Variables
    │   └── main.yml
    ├── defaults/       # Default variables (lowest precedence)
    │   └── main.yml
    ├── files/          # Static files to copy
    ├── templates/      # Jinja2 templates
    └── meta/           # Role metadata (dependencies)
        └── main.yml
```

**Use Role in Playbook:**
```yaml
---
- name: Configure Vault
  hosts: localhost
  roles:
    - vault
```

### 5. Variables

**What:** Data that varies between hosts, environments, or tasks.

**Variable Precedence (lowest to highest):**
1. Role defaults (`roles/*/defaults/main.yml`)
2. Inventory file vars (`inventory/local.yml`)
3. Playbook vars
4. Extra vars (`-e` flag on command line)

**Example:**
```yaml
# inventory/local.yml
vars:
  vault_addr: http://localhost:8200
  vault_namespace: vault

# playbooks/verify.yml
- name: Check Vault
  shell: "curl {{ vault_addr }}/v1/sys/health"
```

**Use Variables:**
```bash
# Override on command line
ansible-playbook playbooks/verify.yml -e "vault_addr=https://vault.example.com:8200"
```

### 6. Idempotency

**What:** Running the same playbook multiple times produces the same result.

**Why It Matters:**
- Safe to re-run playbooks
- Only makes changes when needed
- Prevents configuration drift

**Example:**
```yaml
- name: Ensure directory exists
  file:
    path: /opt/myapp
    state: directory
    owner: root
    group: root
    mode: '0755'
```

**First run:** Creates directory (CHANGED)
**Second run:** Directory exists with correct permissions (OK, no change)

**Test Idempotency:**
```bash
# Run twice, observe output
ansible-playbook playbooks/verify.yml
ansible-playbook playbooks/verify.yml

# Second run should show:
# changed=0  (no changes made)
```

## Ad-Hoc Commands

**What:** One-line commands for quick tasks (no playbook needed).

**Syntax:**
```bash
ansible <hosts> -i <inventory> -m <module> -a <arguments>
```

### System Information

```bash
# Test connectivity
ansible -i inventory/local.yml localhost -m ping

# Get system facts
ansible -i inventory/local.yml localhost -m setup

# Get specific fact
ansible -i inventory/local.yml localhost -m setup -a 'filter=ansible_distribution*'

# System uptime
ansible -i inventory/local.yml localhost -m shell -a 'uptime'

# Disk usage
ansible -i inventory/local.yml localhost -m shell -a 'df -h'

# Memory usage
ansible -i inventory/local.yml localhost -m shell -a 'free -h'
```

### Kubernetes Operations

```bash
# Get pods in namespace
ansible -i inventory/local.yml localhost -m shell -a 'kubectl get pods -n vault'

# Check Vault status
ansible -i inventory/local.yml localhost -m shell -a 'kubectl exec -n vault vault-0 -- vault status'

# Get CoreDNS pods
ansible -i inventory/local.yml localhost -m shell -a 'kubectl get pods -n kube-system -l k8s-app=coredns'

# Check services
ansible -i inventory/local.yml localhost -m shell -a 'kubectl get svc -A'
```

### File Operations

```bash
# Check if file exists
ansible -i inventory/local.yml localhost -m stat -a 'path=/etc/hosts'

# Create directory
ansible -i inventory/local.yml localhost -m file -a 'path=/tmp/test state=directory'

# Remove file
ansible -i inventory/local.yml localhost -m file -a 'path=/tmp/test.txt state=absent'

# Copy file
ansible -i inventory/local.yml localhost -m copy -a 'src=./test.txt dest=/tmp/test.txt'
```

### Package Management

```bash
# Install package (Debian/Ubuntu)
ansible -i inventory/local.yml localhost -m apt -a 'name=curl state=present' --become

# Install Python package
ansible -i inventory/local.yml localhost -m pip -a 'name=requests state=present'

# Remove package
ansible -i inventory/local.yml localhost -m apt -a 'name=curl state=absent' --become
```

## Configuration (ansible.cfg)

**Location Priority:**
1. `ANSIBLE_CONFIG` environment variable
2. `ansible.cfg` in current directory (THIS PROJECT)
3. `~/.ansible.cfg` in user's home
4. `/etc/ansible/ansible.cfg` system-wide

**Key Settings (ansible.cfg):**

```ini
[defaults]
# Default inventory
inventory = ./inventory/local.yml

# Parallel processes
forks = 10

# Output format
stdout_callback = yaml

# Enable profiling
callbacks_enabled = profile_tasks, timer

# Fact caching (speed up subsequent runs)
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts_cache
fact_caching_timeout = 3600

[ssh_connection]
# Use connection multiplexing (faster)
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
pipelining = True
```

## Testing and Development

### Syntax Check

```bash
# Check playbook syntax
ansible-playbook playbooks/verify-foundation.yml --syntax-check
```

### Linting

```bash
# Install ansible-lint
pip3 install --user ansible-lint

# Lint all playbooks
ansible-lint playbooks/*.yml

# Lint specific playbook
ansible-lint playbooks/verify-foundation.yml

# Ignore specific rules
ansible-lint -x yaml[line-length] playbooks/verify.yml
```

### Dry Run (Check Mode)

```bash
# See what would change without making changes
ansible-playbook playbooks/verify-foundation.yml --check

# Combine with diff to see exact changes
ansible-playbook playbooks/verify-foundation.yml --check --diff
```

### Step-by-Step Execution

```bash
# Prompt before each task
ansible-playbook playbooks/verify-foundation.yml --step
```

### Debugging

```bash
# Increase verbosity
ansible-playbook playbooks/verify.yml -v    # Verbose
ansible-playbook playbooks/verify.yml -vv   # More verbose
ansible-playbook playbooks/verify.yml -vvv  # Debug
ansible-playbook playbooks/verify.yml -vvvv # Connection debug

# Start at specific task
ansible-playbook playbooks/verify.yml --start-at-task="Check Vault status"

# Run specific tags
ansible-playbook playbooks/verify.yml --tags "vault,pki"

# Skip specific tags
ansible-playbook playbooks/verify.yml --skip-tags "dns"
```

### Task Timing

```bash
# Profile task execution times
# Already enabled in ansible.cfg via:
# callbacks_enabled = profile_tasks, timer

ansible-playbook playbooks/verify-foundation.yml
# Output will show:
# - Time for each task
# - Total playbook execution time
```

## Best Practices

### 1. Always Test Idempotency

```bash
# Run twice, second run should show changed=0
ansible-playbook playbooks/verify.yml
ansible-playbook playbooks/verify.yml
```

**Good (Idempotent):**
```yaml
- name: Ensure config file exists
  copy:
    src: config.yml
    dest: /etc/app/config.yml
    owner: root
    group: root
    mode: '0644'
```

**Bad (Not Idempotent):**
```yaml
- name: Append to config file
  shell: "echo 'setting=value' >> /etc/app/config.yml"
```

### 2. Use Modules, Not Shell

**Good:**
```yaml
- name: Create directory
  file:
    path: /opt/myapp
    state: directory
    mode: '0755'
```

**Bad:**
```yaml
- name: Create directory
  shell: mkdir -p /opt/myapp && chmod 755 /opt/myapp
```

**Why:** Modules are:
- Idempotent by design
- Cross-platform
- Better error handling
- More secure (no shell injection)

### 3. Use Variables for Flexibility

**Good:**
```yaml
vars:
  vault_addr: http://localhost:8200
  vault_namespace: vault

tasks:
  - name: Check Vault health
    uri:
      url: "{{ vault_addr }}/v1/sys/health"
```

**Bad:**
```yaml
tasks:
  - name: Check Vault health
    uri:
      url: http://localhost:8200/v1/sys/health
```

### 4. Name All Tasks

**Good:**
```yaml
- name: Install kubectl
  apt:
    name: kubectl
    state: present
```

**Bad:**
```yaml
- apt:
    name: kubectl
    state: present
```

**Why:** Named tasks make output readable and debugging easier.

### 5. Use Tags for Selective Execution

```yaml
- name: Verify CoreDNS
  k8s_info:
    kind: Pod
    namespace: kube-system
  tags:
    - dns
    - coredns

- name: Verify Vault
  k8s_info:
    kind: Pod
    namespace: vault
  tags:
    - vault
    - pki
```

**Run:**
```bash
# Run only DNS tasks
ansible-playbook playbooks/verify.yml --tags dns

# Run everything except PKI tasks
ansible-playbook playbooks/verify.yml --skip-tags pki
```

## Common Patterns

### Check if Service is Running

```yaml
- name: Check if Vault is running
  k8s_info:
    kind: Pod
    namespace: vault
    label_selectors:
      - app=vault
    field_selectors:
      - status.phase=Running
  register: vault_pods

- name: Verify at least one pod running
  assert:
    that:
      - vault_pods.resources | length > 0
    fail_msg: "No Vault pods are running"
    success_msg: "Vault is running ({{ vault_pods.resources | length }} pods)"
```

### Retry on Failure

```yaml
- name: Wait for Vault to be ready
  uri:
    url: http://localhost:8200/v1/sys/health
    method: GET
  register: vault_health
  until: vault_health.status == 200
  retries: 10
  delay: 5
```

### Loop Over Items

```yaml
- name: Verify PKI roles exist
  shell: "vault read pki_int/roles/{{ item }}"
  loop:
    - ai-ops-agent
    - kubernetes
    - cert-manager
  environment:
    VAULT_ADDR: http://localhost:8200
    VAULT_TOKEN: "{{ vault_token }}"
```

### Conditional Execution

```yaml
- name: Get Vault seal status
  shell: vault status -format=json
  register: vault_status
  environment:
    VAULT_ADDR: http://localhost:8200

- name: Unseal Vault
  shell: vault operator unseal {{ unseal_key }}
  when: (vault_status.stdout | from_json).sealed == true
  environment:
    VAULT_ADDR: http://localhost:8200
```

## Integration with Foundation Services

### Verify CoreDNS

```yaml
- name: Verify CoreDNS
  hosts: localhost
  tasks:
    - name: Check CoreDNS pods
      k8s_info:
        kind: Pod
        namespace: kube-system
        label_selectors:
          - k8s-app=coredns
      register: coredns_pods

    - name: Test DNS resolution
      shell: |
        kubectl run dns-test --image=busybox:1.36 --rm -it --restart=Never \
          -- nslookup kubernetes.default.svc.cluster.local
      register: dns_test
      failed_when: "'Address 1:' not in dns_test.stdout"
```

### Verify Vault PKI

```yaml
- name: Verify Vault PKI
  hosts: localhost
  vars:
    vault_addr: http://localhost:8200
  tasks:
    - name: Check PKI engines enabled
      shell: vault secrets list -format=json
      register: secrets_engines
      environment:
        VAULT_ADDR: "{{ vault_addr }}"
        VAULT_TOKEN: "{{ vault_token }}"

    - name: Verify root PKI exists
      assert:
        that:
          - "'pki/' in (secrets_engines.stdout | from_json)"
        fail_msg: "Root PKI engine not found"
```

## Learning Outcomes

By completing Ansible automation (Hours 5-8), you learn:

### Conceptual Understanding
- ✅ Infrastructure as Code principles
- ✅ Idempotency and why it matters
- ✅ Declarative vs imperative configuration
- ✅ Inventory management
- ✅ Variable precedence

### Practical Skills
- ✅ Write Ansible playbooks
- ✅ Use Ansible modules
- ✅ Test idempotency
- ✅ Debug playbook issues
- ✅ Organize code with roles

### Best Practices
- ✅ Test before deploying
- ✅ Use modules over shell commands
- ✅ Name all tasks
- ✅ Use variables for flexibility
- ✅ Tag tasks for selective execution

## Next Steps

1. **Hour 6**: Create bootstrap playbook
   - Verify foundation services via Ansible
   - Test idempotency

2. **Hour 7**: Create Vault verification playbook
   - Automated PKI checks
   - Seal status verification

3. **Hour 8**: Documentation and testing
   - Run all playbooks
   - Verify idempotency
   - Document Day 4 complete

## Reference

- [Ansible Documentation](https://docs.ansible.com/ansible/latest/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html)
- [Module Index](https://docs.ansible.com/ansible/latest/modules/modules_by_category.html)
- [Kubernetes Module](https://docs.ansible.com/ansible/latest/collections/kubernetes/core/k8s_module.html)
- [Playbook Keywords](https://docs.ansible.com/ansible/latest/reference_appendices/playbooks_keywords.html)

---

**Status**: Day 4 (Hour 5) - Ansible Installation and Inventory

**Prerequisites**: Python 3.8+, pip3

**Next**: Hour 6 - Bootstrap Ansible playbook
