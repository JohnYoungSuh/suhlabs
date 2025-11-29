# tmux Mastery Guide — Expert-Level DevOps Workflows

**Goal:** Achieve expert-level proficiency with tmux, Starship, and bash for routine Kubernetes/DevOps tasks through repeatable exercises.

---

## Table of Contents

1. [Quick Reference Card](#quick-reference-card)
2. [Level 1: Foundation (Days 1-3)](#level-1-foundation)
3. [Level 2: Navigation Mastery (Days 4-7)](#level-2-navigation-mastery)
4. [Level 3: Advanced Workflows (Days 8-14)](#level-3-advanced-workflows)
5. [Level 4: Expert Automation (Days 15+)](#level-4-expert-automation)
6. [Daily Drills](#daily-drills)
7. [Real-World Scenarios](#real-world-scenarios)
8. [Troubleshooting Patterns](#troubleshooting-patterns)

---

## Quick Reference Card

### Your Custom tmux Keybindings

| Action | Keybinding | Notes |
|--------|-----------|-------|
| **Prefix** | `Ctrl+a` | All commands start with this |
| Send prefix literal | `Ctrl+a Ctrl+a` | If app needs Ctrl+a |
| **Splitting** |
| Vertical split | `Ctrl+a \|` | Creates left/right panes |
| Horizontal split | `Ctrl+a -` | Creates top/bottom panes |
| **Navigation (No Prefix)** |
| Switch panes | `Alt+Arrow` | **Most used - no prefix!** |
| Resize panes | `Shift+Arrow` | **No prefix!** |
| **Navigation (With Prefix)** |
| Vim-style left | `Ctrl+a h` | Alternative to Alt+Left |
| Vim-style down | `Ctrl+a j` | Alternative to Alt+Down |
| Vim-style up | `Ctrl+a k` | Alternative to Alt+Up |
| Vim-style right | `Ctrl+a l` | Alternative to Alt+Right |
| **Windows** |
| Create new window | `Ctrl+a c` | New workspace |
| Next window | `Ctrl+a n` | Or `Ctrl+a 1-9` |
| Previous window | `Ctrl+a p` | Go back |
| Switch to window # | `Ctrl+a 0-9` | Direct access |
| Rename window | `Ctrl+a ,` | Give it a name |
| **Session Management** |
| Detach session | `Ctrl+a d` | **Critical!** Keeps running |
| List sessions | `tmux ls` | In bash, not inside tmux |
| Attach to session | `tmux attach -t <name>` | Resume work |
| Kill session | `tmux kill-session -t <name>` | Clean up |
| **Utilities** |
| Reload config | `Ctrl+a r` | After editing ~/.tmux.conf |
| Command mode | `Ctrl+a :` | Advanced commands |
| Copy mode | `Ctrl+a [` | Scroll/search history |
| Exit copy mode | `q` | Return to normal |

---

## Level 1: Foundation (Days 1-3)

### Exercise 1.1: Basic Session Management (5 minutes)

**Goal:** Learn to create, detach, and attach sessions without losing work.

```bash
# 1. Create a new session named "practice"
tmux new-session -s practice

# You're now inside tmux! Notice your status bar at the top.
# 2. Run a long-running command
ping google.com

# 3. Detach from session (keep it running)
# Press: Ctrl+a d

# You're back to your normal shell, but ping is still running!

# 4. List all sessions
tmux ls

# 5. Reattach to your session
tmux attach -t practice

# The ping command is still running! Press Ctrl+C to stop it.

# 6. Kill the session
# Press: Ctrl+a :
# Type: kill-session
# Press: Enter
```

**Practice drill:** Repeat this 3 times until it feels automatic.

**Real-world use:** You start a long deployment, need to leave for a meeting, detach the session, come back 30 minutes later and check the results.

---

### Exercise 1.2: Window Management (10 minutes)

**Goal:** Master creating and switching between different workspaces (windows).

```bash
# 1. Create a new session
tmux new-session -s windows-practice

# 2. You're in window 0. Rename it to "vault"
# Press: Ctrl+a ,
# Type: vault
# Press: Enter

# 3. Create a new window
# Press: Ctrl+a c

# 4. Rename this window to "cert-manager"
# Press: Ctrl+a ,
# Type: cert-manager
# Press: Enter

# 5. Create one more window named "default"
# Press: Ctrl+a c
# Press: Ctrl+a ,
# Type: default
# Press: Enter

# 6. Switch between windows using numbers
# Press: Ctrl+a 1  (goes to window 1 - vault)
# Press: Ctrl+a 2  (goes to window 2 - cert-manager)
# Press: Ctrl+a 3  (goes to window 3 - default)

# 7. Switch using next/previous
# Press: Ctrl+a n  (next window)
# Press: Ctrl+a p  (previous window)

# 8. Clean up
# Press: Ctrl+a :
# Type: kill-session
```

**Practice drill:** Create 5 windows, name them (vault, cert-manager, default, watch, scratch), switch between them using both numbers and n/p. Repeat until you can do it without thinking.

**Real-world use:** Each window represents a Kubernetes namespace or service you're monitoring.

---

### Exercise 1.3: Pane Splitting (10 minutes)

**Goal:** Create side-by-side and stacked panes for multi-tasking.

```bash
# 1. Create a new session
tmux new-session -s panes-practice

# 2. Split the window vertically (side by side)
# Press: Ctrl+a |

# You now have 2 panes side by side!

# 3. Move to the right pane
# Press: Alt+Right  (NO PREFIX NEEDED!)

# 4. Split this pane horizontally (top/bottom)
# Press: Ctrl+a -

# 5. You now have 3 panes! Navigate between them:
# Press: Alt+Left
# Press: Alt+Right
# Press: Alt+Up
# Press: Alt+Down

# 6. Practice navigating WITHOUT using your mouse
# Spend 2 minutes just moving between panes using Alt+Arrows
```

**Layout you created:**
```
┌─────────────┬─────────────┐
│             │   Pane 2    │
│   Pane 1    │             │
│             ├─────────────┤
│             │   Pane 3    │
└─────────────┴─────────────┘
```

**Practice drill:**
1. Create the layout above
2. Delete it (`Ctrl+a :` then `kill-session`)
3. Repeat 5 times
4. Each time, try to do it faster

**Real-world use:** Left pane = logs, top-right = kubectl commands, bottom-right = watch pods.

---

## Level 2: Navigation Mastery (Days 4-7)

### Exercise 2.1: Keyboard-Only Navigation Challenge (15 minutes)

**Goal:** Navigate complex layouts without touching the mouse.

**Setup:**
```bash
# Create this exact layout:
tmux new-session -s nav-challenge

# Split into 4 panes:
# Press: Ctrl+a |     (vertical split)
# Press: Alt+Right    (move to right pane)
# Press: Ctrl+a -     (horizontal split on right)
# Press: Alt+Left     (back to left)
# Press: Ctrl+a -     (horizontal split on left)
```

**Your layout:**
```
┌──────────────┬──────────────┐
│   Pane 1     │   Pane 3     │
│              │              │
├──────────────┼──────────────┤
│   Pane 2     │   Pane 4     │
│              │              │
└──────────────┴──────────────┘
```

**Challenge:** Start in Pane 1, touch each pane in this order as fast as possible:
1. Pane 1 → Pane 3 (Alt+Right)
2. Pane 3 → Pane 4 (Alt+Down)
3. Pane 4 → Pane 2 (Alt+Left)
4. Pane 2 → Pane 1 (Alt+Up)
5. Repeat this circuit 10 times

**Goal time:** < 10 seconds for one full circuit

**Why this matters:** In production incidents, every second counts. You need muscle memory to navigate quickly.

---

### Exercise 2.2: Resize Panes Like a Pro (10 minutes)

**Goal:** Master pane resizing for optimal screen real estate.

```bash
# Start with 2 vertical panes
tmux new-session -s resize-practice
# Press: Ctrl+a |

# Scenario: Left pane has logs (needs more space), right pane has commands (needs less)

# Make left pane wider (NO PREFIX NEEDED):
# Press: Shift+Right (hold and press multiple times)

# Make left pane narrower:
# Press: Shift+Left (hold and press multiple times)

# Create a horizontal split
# Press: Ctrl+a -

# Make top pane taller:
# Press: Shift+Up (in the bottom pane)

# Make bottom pane taller:
# Press: Shift+Down (in the top pane)
```

**Practice drill:**
1. Create a 2x2 grid (4 panes)
2. Make top-left pane take up 60% of screen width
3. Make bottom-right pane take up 70% of screen height
4. Reset and repeat 3 times

**Real-world use:** Logs streaming in one pane need more space, command pane can be smaller.

---

### Exercise 2.3: Vim-Style Navigation (Optional but Cool)

If you're a Vim user, use the Vim-style keybindings:

```bash
# Instead of Alt+Arrows, use Ctrl+a then h/j/k/l
Ctrl+a h  # Left  (same as Alt+Left)
Ctrl+a j  # Down  (same as Alt+Down)
Ctrl+a k  # Up    (same as Alt+Up)
Ctrl+a l  # Right (same as Alt+Right)
```

**Practice:** Do Exercise 2.1 using only Vim keys instead of Alt+Arrows.

---

## Level 3: Advanced Workflows (Days 8-14)

### Exercise 3.1: The Kubernetes Debugging Layout (20 minutes)

**Goal:** Create a production-ready K8s troubleshooting workspace.

**Scenario:** You need to debug a pod that's crashing in the `vault` namespace.

```bash
# 1. Create session
tmux new-session -s k8s-debug

# 2. Rename window to "vault"
# Press: Ctrl+a ,
# Type: vault
# Press: Enter

# 3. Create the layout:
# ┌────────────────────┬─────────────┐
# │  Pod logs (tail)   │  kubectl    │
# │                    │  commands   │
# ├────────────────────┼─────────────┤
# │  Watch pods        │  Vault CLI  │
# └────────────────────┴─────────────┘

# Press: Ctrl+a |     (split vertical)
# Press: Alt+Left     (go to left pane)
# Press: Ctrl+a -     (split left pane horizontal)
# Press: Alt+Right    (go to right pane)
# Press: Ctrl+a -     (split right pane horizontal)

# 4. Populate each pane with actual commands:

# Top-left pane (logs):
# Press: Alt+Up then Alt+Left
kubectl logs -n vault vault-0 -f --tail=50

# Top-right pane (kubectl commands):
# Press: Alt+Right
# Leave this as your command pane

# Bottom-left pane (watch pods):
# Press: Alt+Down then Alt+Left
watch -n 2 'kubectl get pods -n vault'

# Bottom-right pane (vault CLI):
# Press: Alt+Right
export VAULT_ADDR="http://localhost:8200"
vault status

# 5. Practice navigating this layout
# Spend 5 minutes moving between panes and running different commands
```

**Practice drill:** Create this layout from scratch 3 times, timing yourself each time. Goal: < 60 seconds.

---

### Exercise 3.2: Multi-Namespace Monitoring (25 minutes)

**Goal:** Monitor multiple Kubernetes namespaces simultaneously.

```bash
# Use the automated script:
cd /home/suhlabs/projects/suhlabs/aiops-substrate
./scripts/tmux-k8s-session.sh poc

# This creates a session with:
# - Window 1: vault namespace
# - Window 2: cert-manager namespace
# - Window 3: default namespace
# - Window 4: watch all pods
# - Window 5: scratch workspace

# Practice switching between windows:
# Press: Ctrl+a 1  (vault)
# Press: Ctrl+a 2  (cert-manager)
# Press: Ctrl+a 3  (default)
# Press: Ctrl+a 4  (watch all)
# Press: Ctrl+a 5  (scratch)

# Practice workflow:
# 1. Check vault logs (window 1, bottom pane)
# 2. Run vault command (window 1, top pane)
# 3. Switch to cert-manager (window 2)
# 4. Check certificate status (window 2, top pane)
# 5. Watch all pods (window 4)
# 6. Run ad-hoc commands in scratch (window 5)
```

**Real-world scenario:** You're investigating why certificates aren't being issued. You need to:
1. Check Vault logs for errors
2. Verify Vault is unsealed
3. Check cert-manager logs
4. Verify certificate resources exist
5. Watch for pod status changes

**Practice drill:** Simulate this investigation 3 times using only keyboard shortcuts.

---

### Exercise 3.3: Copy Mode & Scrollback (15 minutes)

**Goal:** Search logs and copy output without using a mouse.

```bash
# 1. Create a session with some output
tmux new-session -s copy-practice
kubectl get pods -A

# 2. Enter copy mode to scroll up
# Press: Ctrl+a [

# You're now in copy mode! Notice the cursor.

# 3. Navigation in copy mode:
# Up/Down arrows: scroll line by line
# Page Up/Down: scroll page by page
# g: go to top
# G: go to bottom (capital G)

# 4. Search in copy mode:
# /: search forward (like vim)
# ?: search backward
# n: next match
# N: previous match

# Example: Search for "Running"
# Press: /
# Type: Running
# Press: Enter
# Press: n  (goes to next match)
# Press: n  (goes to next match)

# 5. Copy text (Vim-style):
# Press: v  (start selection)
# Use arrows to select text
# Press: y  (yank/copy)
# Press: q  (exit copy mode)

# 6. Paste what you copied:
# Press: Ctrl+a ]
```

**Practice drill:**
1. Generate 100 lines of output: `for i in {1..100}; do echo "Line $i"; done`
2. Enter copy mode
3. Search for "Line 50"
4. Copy "Line 50" to "Line 55"
5. Exit copy mode
6. Paste the copied text
7. Repeat 5 times

**Real-world use:** Copying error messages from logs to paste into Slack/tickets.

---

## Level 4: Expert Automation (Days 15+)

### Exercise 4.1: Custom Layouts with Shell Scripts

**Goal:** Automate your most common tmux layouts.

Create a custom script for incident response:

```bash
# Create a new script
cat > ~/scripts/tmux-incident.sh << 'EOF'
#!/bin/bash
SESSION="incident-response"

# Create session
tmux new-session -d -s "$SESSION" -n "logs"

# Window 1: Application logs
tmux send-keys -t "$SESSION:1" "kubectl logs -n production app-deployment -f --tail=100" C-m
tmux split-window -t "$SESSION:1" -v
tmux send-keys -t "$SESSION:1.2" "kubectl get pods -n production -w" C-m

# Window 2: Metrics
tmux new-window -t "$SESSION" -n "metrics"
tmux send-keys -t "$SESSION:2" "kubectl top pods -n production" C-m
tmux split-window -t "$SESSION:2" -h
tmux send-keys -t "$SESSION:2.2" "kubectl top nodes" C-m

# Window 3: Commands
tmux new-window -t "$SESSION" -n "commands"
tmux send-keys -t "$SESSION:3" "kubectl config current-context" C-m

# Attach
tmux attach-session -t "$SESSION"
EOF

chmod +x ~/scripts/tmux-incident.sh
```

**Practice:** Run your script, verify the layout, modify it to match your needs.

---

### Exercise 4.2: The 10-Second Deployment Check

**Goal:** Check deployment health across all namespaces in under 10 seconds.

```bash
# Create this alias in ~/.bashrc:
alias k8s-health='tmux new-session -d -s health \; \
  send-keys "kubectl get pods -A | grep -v Running" C-m \; \
  split-window -h \; \
  send-keys "kubectl get events --all-namespaces --sort-by=.lastTimestamp | tail -20" C-m \; \
  split-window -v \; \
  send-keys "kubectl top nodes" C-m \; \
  select-pane -t 0 \; \
  attach-session -t health'

# Run it:
k8s-health
```

**Practice:** Create 3 custom aliases for your most common debugging patterns.

---

## Daily Drills

### Morning Warm-up (5 minutes)

Do this every morning before starting work:

```bash
# 1. Create a session
tmux new-session -s warmup

# 2. Create 4 windows as fast as possible
# Ctrl+a c (create)
# Ctrl+a c (create)
# Ctrl+a c (create)

# 3. Name them: logs, commands, watch, scratch
# Ctrl+a 1, Ctrl+a ,, type "logs"
# Ctrl+a 2, Ctrl+a ,, type "commands"
# Ctrl+a 3, Ctrl+a ,, type "watch"
# Ctrl+a 4, Ctrl+a ,, type "scratch"

# 4. In window 1, create a 2x2 grid
# Ctrl+a 1
# Ctrl+a |
# Ctrl+a -
# Alt+Left
# Ctrl+a -

# 5. Navigate the grid 10 times using only Alt+Arrows

# 6. Kill the session
# Ctrl+a :, kill-session
```

**Goal:** Complete in under 90 seconds.

---

### Muscle Memory Drill (3 minutes)

Practice these sequences 10 times each:

```bash
# Sequence 1: Create, split, navigate, resize
Ctrl+a c → Ctrl+a | → Alt+Right → Shift+Left (x5)

# Sequence 2: Window switching circuit
Ctrl+a 1 → Ctrl+a 2 → Ctrl+a 3 → Ctrl+a 1

# Sequence 3: Pane navigation circuit
Alt+Right → Alt+Down → Alt+Left → Alt+Up

# Sequence 4: Copy mode search
Ctrl+a [ → /error → Enter → n → n → q

# Sequence 5: Detach and reattach
Ctrl+a d → tmux attach -t practice
```

---

## Real-World Scenarios

### Scenario 1: Certificate Renewal Issue (Medium Difficulty)

**Problem:** Certificates aren't renewing in production. Debug using tmux.

**Solution:**
```bash
# 1. Create debugging session
./scripts/tmux-k8s-session.sh prod

# 2. Window 1 (vault): Check Vault status
# Ctrl+a 1
vault status
vault read pki_int/cert/ca_chain

# 3. Window 2 (cert-manager): Check certificate status
# Ctrl+a 2
kubectl get certificates -A
kubectl describe certificate <failing-cert>

# 4. Check cert-manager logs (already streaming in bottom pane)
# Alt+Down
# Look for errors

# 5. Check Vault logs (window 1, bottom pane)
# Ctrl+a 1, Alt+Down

# 6. Window 5: Run fix commands
# Ctrl+a 5
kubectl delete pod -n cert-manager <cert-manager-pod>
# Watch window 2 for certificate to be issued
```

**Practice:** Simulate this scenario 3 times, each time trying to complete the investigation faster.

---

### Scenario 2: Pod CrashLoopBackOff (High Difficulty)

**Problem:** AI Ops Agent pod is crash looping. Find root cause in under 5 minutes.

**Solution:**
```bash
# 1. Create session with crash layout
tmux new-session -s crash-debug

# 2. Create 3-pane layout:
# Top: Current logs
# Bottom-left: Previous logs (--previous)
# Bottom-right: Pod description

# Ctrl+a -
# Alt+Down
# Ctrl+a |

# 3. Populate panes:
# Top pane:
kubectl logs -n default ai-ops-agent-<pod> -f --tail=100

# Bottom-left:
# Alt+Down, Alt+Left
kubectl logs -n default ai-ops-agent-<pod> --previous

# Bottom-right:
# Alt+Right
kubectl describe pod -n default ai-ops-agent-<pod>

# 4. Analyze:
# Use Alt+Arrows to quickly switch between views
# Use Ctrl+a [ to enter copy mode and search logs
# Search for "error", "fail", "exception"
```

**Practice:** Set up this layout in under 45 seconds.

---

### Scenario 3: Multi-Environment Comparison

**Problem:** Feature works in dev but not prod. Compare environments.

**Solution:**
```bash
# Create 2 sessions side-by-side using separate terminal tabs/windows:

# Terminal 1:
./scripts/tmux-k8s-session.sh dev

# Terminal 2:
./scripts/tmux-k8s-session.sh prod

# Or use tmux windows:
tmux new-session -s compare -n dev
./scripts/switch-context.sh dev default
kubectl get all

# Ctrl+a c (new window)
# Ctrl+a , (rename to "prod")
./scripts/switch-context.sh prod default
kubectl get all

# Quickly switch between:
# Ctrl+a 1 (dev)
# Ctrl+a 2 (prod)
```

---

## Troubleshooting Patterns

### Pattern 1: "Something is broken" Generic Debug

```bash
# 1. Create debugging session
tmux new-session -s debug

# 2. Create 4-pane layout (described above)

# 3. Run these in each pane:
# Pane 1: Recent events
kubectl get events --all-namespaces --sort-by=.lastTimestamp | tail -30

# Pane 2: Non-running pods
kubectl get pods -A | grep -v Running

# Pane 3: Resource usage
kubectl top nodes
kubectl top pods -A

# Pane 4: Service status
kubectl get svc -A
```

### Pattern 2: Slow Response Time Investigation

```bash
# 1. Create performance session
tmux new-session -s perf

# 2. Setup:
# Top-left: Response time monitoring
# Top-right: Resource usage
# Bottom: Logs

# Ctrl+a |
# Alt+Left
# Ctrl+a -

# 3. Populate:
# Top-left:
while true; do curl -w "%{time_total}\n" -o /dev/null -s http://service-url; sleep 1; done

# Top-right:
# Alt+Right
watch -n 2 'kubectl top pods -n default'

# Bottom:
# Alt+Down (from either pane)
kubectl logs -n default service-pod -f
```

---

## Advanced Tips & Tricks

### Tip 1: Session Naming Convention

Use emojis and prefixes for visual identification:

```bash
tmux new-session -s "🏗️-dev-debugging"
tmux new-session -s "🧪-val-testing"
tmux new-session -s "🚀-prod-monitoring"

# List sessions:
tmux ls
# Output:
# 🏗️-dev-debugging: 3 windows
# 🧪-val-testing: 2 windows
# 🚀-prod-monitoring: 5 windows
```

### Tip 2: Synchronized Panes

Run the same command in all panes simultaneously:

```bash
# Enable synchronized panes
# Press: Ctrl+a :
# Type: setw synchronize-panes on

# Now typing in one pane types in all panes!
# Useful for: Running same kubectl command across multiple namespaces

# Disable:
# Press: Ctrl+a :
# Type: setw synchronize-panes off
```

### Tip 3: Save and Restore Sessions

Install `tmux-resurrect` to save sessions:

```bash
# Save session
# Press: Ctrl+a Ctrl+s

# Restore session
# Press: Ctrl+a Ctrl+r
```

### Tip 4: Mouse Mode for Beginners

Your config already has mouse mode enabled! You can:
- Click to switch panes
- Drag borders to resize
- Scroll with mouse wheel

But try to wean yourself off the mouse for speed.

---

## Starship Prompt Integration

Your Starship prompt shows:

- **Current Kubernetes context**: `☸️ poc(default)`
- **Current namespace**: Shown in prompt
- **Git status**: Branch, changes, commits ahead/behind
- **Command duration**: How long last command took
- **Directory**: Current location with nice icons

### Reading Your Prompt

```
🌍 EST 14:23 on suhlabs-dev ☸️ poc(vault) in ~/projects/aiops-substrate
 main ✏️ 2 ❓1
❯
```

Breaking it down:
- `🌍 EST 14:23`: Current timezone and time
- `on suhlabs-dev`: Hostname
- `☸️ poc(vault)`: K8s context and namespace
- `in ~/projects/aiops-substrate`: Current directory
- ` main`: Git branch
- `✏️ 2 ❓1`: 2 modified files, 1 untracked file
- `❯`: Prompt character (green = success, red = last command failed)

### Prompt Commands

```bash
# Switch Kubernetes context - prompt updates automatically!
kubectl config use-context prod

# Change namespace - prompt updates!
kubectl config set-context --current --namespace=cert-manager

# Git operations - prompt shows status
git status
git add .
# Notice the prompt changes from ✏️ to ➕
```

---

## Bash Profile Enhancements

### Useful Aliases to Add

Add these to `~/.bashrc`:

```bash
# tmux aliases
alias ta='tmux attach -t'
alias tls='tmux ls'
alias tn='tmux new-session -s'
alias tk='tmux kill-session -t'

# Kubernetes + tmux shortcuts
alias kpoc='~/projects/suhlabs/aiops-substrate/scripts/tmux-k8s-session.sh poc'
alias kval='~/projects/suhlabs/aiops-substrate/scripts/tmux-k8s-session.sh val'
alias kprod='~/projects/suhlabs/aiops-substrate/scripts/tmux-k8s-session.sh prod'

# Quick debugging
alias kdebug='tmux new-session -s debug \; \
  send-keys "kubectl get pods -A | grep -v Running" C-m \; \
  split-window -v \; \
  send-keys "kubectl get events --all-namespaces --sort-by=.lastTimestamp | tail -20" C-m'

# Kubernetes shortcuts
alias k='kubectl'
alias kg='kubectl get'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'

# Watch shortcuts
alias kwatch='watch -n 2 kubectl get pods -A'
alias kwatchn='watch -n 2 kubectl get nodes'
```

### Custom Functions

Add these to `~/.bashrc`:

```bash
# Quick pod logs in tmux
klogs() {
    POD=$1
    NAMESPACE=${2:-default}
    tmux new-session -s "logs-$POD" \; \
        send-keys "kubectl logs -n $NAMESPACE $POD -f --tail=100" C-m \; \
        split-window -v \; \
        send-keys "kubectl describe pod -n $NAMESPACE $POD" C-m
}

# Usage: klogs vault-0 vault

# Pod shell with logs
kshell() {
    POD=$1
    NAMESPACE=${2:-default}
    tmux new-session -s "shell-$POD" \; \
        send-keys "kubectl logs -n $NAMESPACE $POD -f --tail=50" C-m \; \
        split-window -h \; \
        send-keys "kubectl exec -it -n $NAMESPACE $POD -- /bin/sh" C-m
}

# Usage: kshell vault-0 vault
```

---

## 30-Day Mastery Plan

### Week 1: Foundation
- **Day 1-2**: Exercise 1.1, 1.2, 1.3 (Basic session, window, pane management)
- **Day 3-4**: Exercise 2.1 (Navigation challenge) - 10 reps each day
- **Day 5-7**: Exercise 2.2, 2.3 (Resizing, Vim navigation)

### Week 2: Real-World Practice
- **Day 8-10**: Exercise 3.1 (K8s debugging layout) - create from scratch daily
- **Day 11-13**: Exercise 3.2 (Multi-namespace monitoring) - practice daily workflows
- **Day 14**: Exercise 3.3 (Copy mode) - log searching drills

### Week 3: Automation
- **Day 15-18**: Exercise 4.1 (Custom layouts) - create 3 custom scripts
- **Day 19-21**: Exercise 4.2 (Quick checks) - create 5 custom aliases

### Week 4: Mastery
- **Day 22-25**: Real-world scenarios - practice incident response
- **Day 26-28**: Troubleshooting patterns - simulate 10 different issues
- **Day 29-30**: Speed drills - can you create any layout in under 30 seconds?

---

## Success Metrics

You've achieved mastery when you can:

- [ ] Create a 4-window, 8-pane session from scratch in under 60 seconds
- [ ] Navigate any tmux layout without looking at the keyboard
- [ ] Debug a Kubernetes issue without using your mouse
- [ ] Create custom tmux layouts for any debugging scenario
- [ ] Switch contexts, namespaces, and check pod status in under 10 seconds
- [ ] Use copy mode to search logs and extract error messages
- [ ] Create a reusable tmux script for your most common workflow
- [ ] Explain every symbol in your Starship prompt
- [ ] Detach and reattach from sessions instinctively

---

## Cheat Sheet for Printing

```
┌──────────────────────────────────────────────────────────────┐
│                    tmux Mastery Cheat Sheet                  │
├──────────────────────────────────────────────────────────────┤
│ PREFIX: Ctrl+a                                               │
├──────────────────────────────────────────────────────────────┤
│ SPLITTING:                                                   │
│   Ctrl+a |          Vertical split (side-by-side)            │
│   Ctrl+a -          Horizontal split (top/bottom)            │
├──────────────────────────────────────────────────────────────┤
│ NAVIGATION (NO PREFIX):                                      │
│   Alt+Arrows        Switch panes ⭐ MOST IMPORTANT           │
│   Shift+Arrows      Resize panes                             │
├──────────────────────────────────────────────────────────────┤
│ WINDOWS:                                                     │
│   Ctrl+a c          Create new window                        │
│   Ctrl+a 1-9        Switch to window number                  │
│   Ctrl+a ,          Rename window                            │
│   Ctrl+a n          Next window                              │
│   Ctrl+a p          Previous window                          │
├──────────────────────────────────────────────────────────────┤
│ SESSIONS:                                                    │
│   Ctrl+a d          Detach session (CRITICAL!)               │
│   tmux ls           List sessions (from bash)                │
│   tmux attach -t    Reattach to session                      │
├──────────────────────────────────────────────────────────────┤
│ COPY MODE:                                                   │
│   Ctrl+a [          Enter copy mode                          │
│   /text             Search forward                           │
│   n                 Next search result                       │
│   v                 Start selection                          │
│   y                 Copy selection                           │
│   q                 Exit copy mode                           │
│   Ctrl+a ]          Paste                                    │
├──────────────────────────────────────────────────────────────┤
│ UTILITIES:                                                   │
│   Ctrl+a r          Reload config                            │
│   Ctrl+a :          Command mode                             │
│   Ctrl+a ?          List all keybindings                     │
└──────────────────────────────────────────────────────────────┘
```

---

## Next Steps

1. **Print the cheat sheet** and keep it visible at your desk
2. **Do the morning warmup** for 7 days straight
3. **Practice one scenario per day** from the Real-World Scenarios section
4. **Create your own custom layout** for your most common task
5. **Challenge yourself**: Can you go a full day without using the mouse in the terminal?

---

## Resources

- Your tmux config: `~/.tmux.conf`
- Your Starship config: `~/.config/starship.toml`
- Project tmux scripts: `~/projects/suhlabs/aiops-substrate/scripts/`
- tmux manual: `man tmux`
- This guide: `~/projects/suhlabs/aiops-substrate/docs/TMUX-MASTERY-GUIDE.md`

---

**Remember:** Expert-level proficiency comes from repetition, not memorization. Practice these exercises daily for 30 days and tmux will become second nature.

Good luck! 🚀
