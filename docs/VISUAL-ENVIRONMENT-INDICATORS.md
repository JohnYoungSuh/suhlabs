# Visual Environment Indicators - POC vs Validation

**Goal**: Make it IMPOSSIBLE to confuse which environment you're working in

**Strategy**: Multi-layered visual cues (tmux + starship + terminal + shell)

---

## Layer 1: Starship Prompt (Always Visible)

### Starship K8s Context with Color Coding

**Installation**:
```bash
# Install starship (if not already)
curl -sS https://starship.rs/install.sh | sh

# Create starship config
mkdir -p ~/.config
touch ~/.config/starship.toml
```

**Configuration** (`~/.config/starship.toml`):
```toml
# Starship Configuration for Environment Clarity

# Kubernetes context with color coding
[kubernetes]
format = '[$symbol$context( \($namespace\))]($style) '
disabled = false
detect_files = ['k8s']
detect_folders = []

# POC environment = GREEN
[kubernetes.context_aliases]
"aiops-poc" = "🏗️  POC"
"aiops-poc-kind" = "🏗️  POC-Kind"

# Validation environment = YELLOW
"aiops-validation" = "🧪 VALIDATION"
"kind-aiops-validation" = "🧪 VAL"

# Production = RED (when you deploy to prod later)
"aiops-prod" = "🚀 PROD"

# Style based on context name
[kubernetes.style]
# This doesn't work directly, use custom module below

# Custom Kubernetes context with conditional styling
[[custom.k8s_env]]
command = """
ctx=$(kubectl config current-context 2>/dev/null)
case "$ctx" in
  *poc*) echo "🏗️  POC" ;;
  *validation*) echo "🧪 VALIDATION" ;;
  *prod*) echo "🚀 PROD" ;;
  *) echo "⚠️  $ctx" ;;
esac
"""
when = 'kubectl config current-context &>/dev/null'
shell = ["bash", "--noprofile", "--norc"]
format = '[$output]($style) '
style = "bold green"  # Default, but we'll override with colors below

# Alternative: Show context + namespace with colors
[kubernetes]
format = 'on [$symbol$context( \($namespace\))]($style) '
style = "bold cyan"
symbol = "⎈ "
disabled = false

[kubernetes.context_aliases]
"aiops-poc" = "POC"
"aiops-poc-kind" = "POC"
"aiops-validation" = "VALIDATION"
"kind-aiops-validation" = "VAL"

# Show current directory
[directory]
truncation_length = 3
truncate_to_repo = true
format = "[$path]($style)[$read_only]($read_only_style) "
style = "bold cyan"

# Git branch
[git_branch]
symbol = " "
format = "on [$symbol$branch]($style) "
style = "bold purple"

# Command duration (useful for long kubectl commands)
[cmd_duration]
min_time = 2000
format = "took [$duration]($style) "
style = "bold yellow"
```

### Better: Custom Script for Color-Coded Context

Create `~/.config/starship-k8s.sh`:
```bash
#!/bin/bash
# Starship Kubernetes context with color coding

ctx=$(kubectl config current-context 2>/dev/null)
ns=$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)
ns=${ns:-default}

case "$ctx" in
  *poc*)
    # Green for POC
    echo -e "\033[1;32m🏗️  POC\033[0m:\033[0;32m$ns\033[0m"
    ;;
  *validation*)
    # Yellow for Validation
    echo -e "\033[1;33m🧪 VAL\033[0m:\033[0;33m$ns\033[0m"
    ;;
  *prod*)
    # Red for Production
    echo -e "\033[1;31m🚀 PROD\033[0m:\033[0;31m$ns\033[0m"
    ;;
  *)
    # Gray for unknown
    echo -e "\033[1;90m⚠️  $ctx\033[0m:\033[0;90m$ns\033[0m"
    ;;
esac
```

Make executable:
```bash
chmod +x ~/.config/starship-k8s.sh
```

Update `~/.config/starship.toml`:
```toml
[custom.k8s_env]
command = "~/.config/starship-k8s.sh"
when = "kubectl config current-context &>/dev/null"
shell = ["bash", "--noprofile", "--norc"]
format = "[$output]($style) "
```

**Result**:
```
~/projects/aiops-substrate 🏗️  POC:vault main ✗
```

---

## Layer 2: Tmux Status Bar (Always Visible When Using Tmux)

### Tmux Configuration with Environment Colors

**Add to `~/.tmux.conf`**:
```bash
# Tmux Status Bar with Kubernetes Context

# Function to get K8s context with color
set -g status-interval 5
set -g status-left-length 100
set -g status-right-length 100

# Status bar colors based on K8s context
# This requires a script to detect context and set colors

# Left side: Session name
set -g status-left '#[fg=black,bg=green,bold] #S #[default] '

# Right side: K8s context + time
set -g status-right '#(~/.config/tmux-k8s-status.sh) #[fg=white,bg=black] %H:%M '

# Status bar styling
set -g status-bg black
set -g status-fg white

# Window status
setw -g window-status-current-format '#[fg=black,bg=cyan,bold] #I:#W '
setw -g window-status-format '#[fg=white,bg=black] #I:#W '
```

**Create `~/.config/tmux-k8s-status.sh`**:
```bash
#!/bin/bash
# Tmux Kubernetes status with color coding

ctx=$(kubectl config current-context 2>/dev/null)
ns=$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)
ns=${ns:-default}

case "$ctx" in
  *poc*)
    # Green background for POC
    echo "#[fg=black,bg=green,bold] 🏗️  POC:$ns "
    ;;
  *validation*)
    # Yellow background for Validation
    echo "#[fg=black,bg=yellow,bold] 🧪 VAL:$ns "
    ;;
  *prod*)
    # Red background for Production
    echo "#[fg=white,bg=red,bold] 🚀 PROD:$ns "
    ;;
  *)
    # Gray for unknown
    echo "#[fg=white,bg=brightblack] ⚠️  $ctx:$ns "
    ;;
esac
```

Make executable:
```bash
chmod +x ~/.config/tmux-k8s-status.sh
```

Reload tmux:
```bash
tmux source-file ~/.tmux.conf
```

**Result**: Tmux status bar shows:
```
┌─────────────────────────────────────────────────────────────────┐
│ [ main ]              [ 🏗️  POC:vault ]  [ 14:32 ] │  ← Green for POC
└─────────────────────────────────────────────────────────────────┘
```

---

## Layer 3: Terminal Window Title (Per-Window Clarity)

### Automatic Terminal Title Based on Context

**Add to `~/.bashrc` or `~/.zshrc`**:
```bash
# Set terminal title based on K8s context
set_k8s_title() {
  local ctx=$(kubectl config current-context 2>/dev/null)
  local ns=$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)
  ns=${ns:-default}

  case "$ctx" in
    *poc*)
      echo -ne "\033]0;🏗️  POC:$ns - ${PWD##*/}\007"
      ;;
    *validation*)
      echo -ne "\033]0;🧪 VALIDATION:$ns - ${PWD##*/}\007"
      ;;
    *prod*)
      echo -ne "\033]0;🚀 PROD:$ns - ${PWD##*/}\007"
      ;;
    *)
      echo -ne "\033]0;⚠️  $ctx:$ns - ${PWD##*/}\007"
      ;;
  esac
}

# Update title on prompt
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }set_k8s_title"

# Also update title when changing context
alias kctx='kubectl config use-context'
alias kpoc='kubectl config use-context aiops-poc && set_k8s_title'
alias kval='kubectl config use-context aiops-validation && set_k8s_title'
```

**Result**: Terminal/tab title shows: `🏗️  POC:vault - aiops-substrate`

---

## Layer 4: Shell Aliases with Visual Confirmation

### Kubectl Wrapper with Environment Warning

**Add to `~/.bashrc` or `~/.zshrc`**:
```bash
# Kubectl wrapper with environment confirmation
kubectl() {
  local ctx=$(command kubectl config current-context 2>/dev/null)
  local ns=$(command kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)
  ns=${ns:-default}

  # Show banner for destructive operations
  case "$1" in
    delete|apply|create|patch|edit)
      case "$ctx" in
        *poc*)
          echo -e "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
          echo -e "\033[1;32m🏗️  POC Environment: $ns\033[0m"
          echo -e "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
          ;;
        *validation*)
          echo -e "\033[1;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
          echo -e "\033[1;33m🧪 VALIDATION Environment: $ns\033[0m"
          echo -e "\033[1;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
          ;;
        *prod*)
          echo -e "\033[1;31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
          echo -e "\033[1;31m🚀 PRODUCTION Environment: $ns\033[0m"
          echo -e "\033[1;31m⚠️  WARNING: You are modifying PRODUCTION!\033[0m"
          echo -e "\033[1;31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

          # Require confirmation for prod
          read -p "Type 'yes' to confirm: " confirm
          if [ "$confirm" != "yes" ]; then
            echo "Aborted."
            return 1
          fi
          ;;
      esac
      ;;
  esac

  # Execute actual kubectl command
  command kubectl "$@"
}

# Context switching with visual feedback
kctx() {
  local ctx=$(kubectl config current-context 2>/dev/null)
  echo -e "\n\033[1;36mCurrent context:\033[0m"

  case "$ctx" in
    *poc*)
      echo -e "  \033[1;32m🏗️  POC\033[0m"
      ;;
    *validation*)
      echo -e "  \033[1;33m🧪 VALIDATION\033[0m"
      ;;
    *prod*)
      echo -e "  \033[1;31m🚀 PRODUCTION\033[0m"
      ;;
    *)
      echo -e "  \033[1;90m⚠️  $ctx\033[0m"
      ;;
  esac
  echo ""
}

# Switch to POC with confirmation
kpoc() {
  kubectl config use-context aiops-poc >/dev/null 2>&1 || \
  kubectl config use-context aiops-poc-kind >/dev/null 2>&1

  echo -e "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
  echo -e "\033[1;32m🏗️  Switched to POC environment\033[0m"
  echo -e "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
  kctx
}

# Switch to Validation with confirmation
kval() {
  kubectl config use-context aiops-validation >/dev/null 2>&1 || \
  kubectl config use-context kind-aiops-validation >/dev/null 2>&1

  echo -e "\033[1;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
  echo -e "\033[1;33m🧪 Switched to VALIDATION environment\033[0m"
  echo -e "\033[1;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
  kctx
}

# List all contexts with color coding
kls() {
  echo -e "\n\033[1;36mAvailable Kubernetes contexts:\033[0m\n"

  kubectl config get-contexts -o name | while read ctx; do
    current=$(kubectl config current-context 2>/dev/null)
    marker=""
    [ "$ctx" = "$current" ] && marker="→ "

    case "$ctx" in
      *poc*)
        echo -e "  ${marker}\033[1;32m🏗️  $ctx\033[0m"
        ;;
      *validation*)
        echo -e "  ${marker}\033[1;33m🧪 $ctx\033[0m"
        ;;
      *prod*)
        echo -e "  ${marker}\033[1;31m🚀 $ctx\033[0m"
        ;;
      *)
        echo -e "  ${marker}\033[1;90m⚠️  $ctx\033[0m"
        ;;
    esac
  done
  echo ""
}
```

**Usage Examples**:

```bash
# Switch to POC
$ kpoc
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🏗️  Switched to POC environment
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Delete pod (shows confirmation)
$ kubectl delete pod vault-0 -n vault
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🏗️  POC Environment: vault
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
pod "vault-0" deleted

# List contexts
$ kls
Available Kubernetes contexts:

  → 🏗️  aiops-poc
    🧪 aiops-validation
```

---

## Layer 5: Terminal Color Scheme (Full Window)

### iTerm2 / Alacritty / Windows Terminal Profiles

**iTerm2 (macOS)**:
```bash
# Create iTerm2 profiles with different background colors

# POC profile: Light green tint
# Edit → Preferences → Profiles → POC
# Colors → Background: RGB(230, 255, 230)  # Very light green

# Validation profile: Light yellow tint
# Edit → Preferences → Profiles → Validation
# Colors → Background: RGB(255, 255, 230)  # Very light yellow

# Production profile: Light red tint
# Edit → Preferences → Profiles → Production
# Colors → Background: RGB(255, 230, 230)  # Very light red
```

**Alacritty** (`~/.config/alacritty/alacritty.yml`):
```yaml
# Create separate configs and symlink based on environment

# ~/.config/alacritty/poc.yml
colors:
  primary:
    background: '0xe6ffe6'  # Light green
    foreground: '0x000000'

# ~/.config/alacritty/validation.yml
colors:
  primary:
    background: '0xffffe6'  # Light yellow
    foreground: '0x000000'

# Script to switch:
# ln -sf ~/.config/alacritty/poc.yml ~/.config/alacritty/alacritty.yml
```

**Windows Terminal** (`settings.json`):
```json
{
  "profiles": {
    "list": [
      {
        "name": "POC Environment",
        "commandline": "wsl.exe -d Ubuntu -- bash -c 'kpoc && exec bash'",
        "colorScheme": "POC-Green"
      },
      {
        "name": "Validation Environment",
        "commandline": "wsl.exe -d Ubuntu -- bash -c 'kval && exec bash'",
        "colorScheme": "Validation-Yellow"
      }
    ]
  },
  "schemes": [
    {
      "name": "POC-Green",
      "background": "#e6ffe6",
      "foreground": "#000000"
    },
    {
      "name": "Validation-Yellow",
      "background": "#ffffe6",
      "foreground": "#000000"
    }
  ]
}
```

---

## Layer 6: ASCII Art Banner (Shell Login)

### Environment Banner on Shell Init

**Add to `~/.bashrc` or `~/.zshrc`**:
```bash
# Show environment banner on shell init (only for interactive shells)
if [[ $- == *i* ]]; then
  ctx=$(kubectl config current-context 2>/dev/null)

  case "$ctx" in
    *poc*)
      cat << 'EOF'

╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   🏗️   POC ENVIRONMENT                                   ║
║                                                           ║
║   Changes here are safe to experiment with               ║
║   Auto-unseal enabled, persistent storage                ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

EOF
      ;;
    *validation*)
      cat << 'EOF'

╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   🧪  VALIDATION ENVIRONMENT                             ║
║                                                           ║
║   Ephemeral test environment                             ║
║   Changes will be discarded after test                   ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

EOF
      ;;
    *prod*)
      cat << 'EOF'

╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   🚀  PRODUCTION ENVIRONMENT                             ║
║                                                           ║
║   ⚠️  WARNING: REAL USER DATA ⚠️                          ║
║   All changes require approval                           ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

EOF
      ;;
  esac
fi
```

---

## Layer 7: kubectx + fzf (Interactive Context Switcher)

### Visual Context Switching with Fuzzy Finder

**Install**:
```bash
# Install kubectx and fzf
brew install kubectx fzf  # macOS
# or
apt install fzf  # Linux
git clone https://github.com/ahmetb/kubectx ~/.kubectx
```

**Add to `~/.bashrc`**:
```bash
# kubectx with visual indicators
kctx() {
  if [ -z "$1" ]; then
    # Interactive mode with fzf and color coding
    kubectl config get-contexts -o name | \
    while read ctx; do
      case "$ctx" in
        *poc*) echo "🏗️  $ctx" ;;
        *validation*) echo "🧪 $ctx" ;;
        *prod*) echo "🚀 $ctx" ;;
        *) echo "⚠️  $ctx" ;;
      esac
    done | fzf --ansi --reverse --height 40% | \
    sed 's/^[^ ]* //' | \
    xargs -r kubectl config use-context
  else
    kubectl config use-context "$1"
  fi
}
```

**Usage**:
```bash
$ kctx
# Opens fuzzy finder with color-coded contexts:
> 🏗️  aiops-poc
  🧪 aiops-validation
  ⚠️  kind-old-cluster
```

---

## Complete Integration Example

### Full Setup Script

**Create `~/.config/setup-k8s-visual-indicators.sh`**:
```bash
#!/bin/bash
# Setup visual environment indicators for K8s

set -euo pipefail

echo "Setting up visual K8s environment indicators..."

# 1. Create starship config
cat > ~/.config/starship-k8s.sh << 'EOF'
#!/bin/bash
ctx=$(kubectl config current-context 2>/dev/null)
ns=$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)
ns=${ns:-default}

case "$ctx" in
  *poc*) echo -e "\033[1;32m🏗️  POC\033[0m:\033[0;32m$ns\033[0m" ;;
  *validation*) echo -e "\033[1;33m🧪 VAL\033[0m:\033[0;33m$ns\033[0m" ;;
  *prod*) echo -e "\033[1;31m🚀 PROD\033[0m:\033[0;31m$ns\033[0m" ;;
  *) echo -e "\033[1;90m⚠️  ${ctx:0:10}\033[0m:\033[0;90m$ns\033[0m" ;;
esac
EOF
chmod +x ~/.config/starship-k8s.sh

# 2. Create tmux status script
cat > ~/.config/tmux-k8s-status.sh << 'EOF'
#!/bin/bash
ctx=$(kubectl config current-context 2>/dev/null)
ns=$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)
ns=${ns:-default}

case "$ctx" in
  *poc*) echo "#[fg=black,bg=green,bold] 🏗️  POC:$ns " ;;
  *validation*) echo "#[fg=black,bg=yellow,bold] 🧪 VAL:$ns " ;;
  *prod*) echo "#[fg=white,bg=red,bold] 🚀 PROD:$ns " ;;
  *) echo "#[fg=white,bg=brightblack] ⚠️  ${ctx:0:8}:$ns " ;;
esac
EOF
chmod +x ~/.config/tmux-k8s-status.sh

# 3. Add to .bashrc
if ! grep -q "# K8s Visual Indicators" ~/.bashrc; then
  cat >> ~/.bashrc << 'EOF'

# K8s Visual Indicators
set_k8s_title() {
  ctx=$(kubectl config current-context 2>/dev/null)
  ns=$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)
  ns=${ns:-default}
  case "$ctx" in
    *poc*) echo -ne "\033]0;🏗️  POC:$ns - ${PWD##*/}\007" ;;
    *validation*) echo -ne "\033]0;🧪 VAL:$ns - ${PWD##*/}\007" ;;
    *prod*) echo -ne "\033]0;🚀 PROD:$ns - ${PWD##*/}\007" ;;
  esac
}
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }set_k8s_title"

# Aliases
alias kctx='kubectl config current-context'
alias kpoc='kubectl config use-context aiops-poc && set_k8s_title'
alias kval='kubectl config use-context aiops-validation && set_k8s_title'
EOF
fi

# 4. Add to .tmux.conf
if [ -f ~/.tmux.conf ]; then
  if ! grep -q "tmux-k8s-status" ~/.tmux.conf; then
    cat >> ~/.tmux.conf << 'EOF'

# K8s context in status bar
set -g status-right '#(~/.config/tmux-k8s-status.sh) #[fg=white,bg=black] %H:%M '
EOF
  fi
fi

echo "✓ Visual indicators configured!"
echo ""
echo "Next steps:"
echo "1. Restart your shell: exec bash"
echo "2. Reload tmux (if using): tmux source-file ~/.tmux.conf"
echo "3. Test: kpoc  # Should show green POC indicator"
echo "4. Test: kval  # Should show yellow VALIDATION indicator"
```

**Run it**:
```bash
chmod +x ~/.config/setup-k8s-visual-indicators.sh
~/.config/setup-k8s-visual-indicators.sh
exec bash  # Restart shell
```

---

## Visual Comparison

### Before (Confusing):
```
user@host:~/aiops-substrate$ kubectl get pods -n vault
# Which environment am I in? 🤔
```

### After (Crystal Clear):
```
╔═══════════════════════════════════════════════════════════╗
║   🏗️   POC ENVIRONMENT                                   ║
╚═══════════════════════════════════════════════════════════╝

~/aiops-substrate 🏗️  POC:vault main ✗                14:32
user@host$ kubectl get pods -n vault
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🏗️  POC Environment: vault
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
NAME      READY   STATUS    RESTARTS   AGE
vault-0   1/1     Running   0          10m

┌────────────────────────────────────────────────────┐
│ [ main ]       [ 🏗️  POC:vault ]    [ 14:32 ]     │
└────────────────────────────────────────────────────┘

Terminal title: 🏗️  POC:vault - aiops-substrate
```

---

## Recommendation: Multi-Layer Approach

**Must-Have (Layer 1-3)**:
1. ✅ Starship prompt (always visible)
2. ✅ Tmux status bar (if using tmux)
3. ✅ Shell aliases with banners (kubectl wrapper)

**Nice-to-Have (Layer 4-6)**:
4. Terminal title (extra confirmation)
5. ASCII art banner (on shell init)
6. Color schemes (full window tinting)

**Advanced (Layer 7)**:
7. kubectx + fzf (interactive switching)

---

## Testing Your Setup

```bash
# 1. Switch to POC
kpoc
# Should see: Green banner, green prompt, tmux shows green

# 2. Switch to Validation
kval
# Should see: Yellow banner, yellow prompt, tmux shows yellow

# 3. Try destructive command
kubectl delete pod vault-0 -n vault
# Should see: Environment confirmation banner

# 4. Check all indicators
# - Starship prompt: Should show 🏗️  POC or 🧪 VAL
# - Tmux status: Should show colored environment
# - Terminal title: Should show environment
# - Shell banner: Should match current environment
```

---

## Next Steps

1. **Run the setup script** (creates all configs)
2. **Restart shell** (`exec bash`)
3. **Test context switching** (`kpoc`, `kval`)
4. **Customize colors** (adjust to your preference)
5. **Add to README** (document for future you)

Want me to create the setup script and run it for you?
