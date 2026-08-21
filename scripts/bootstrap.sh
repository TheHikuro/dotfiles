#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — Loan CLERIS | Dotfiles Setup
# Usage: curl -fsSL https://raw.githubusercontent.com/TheHikuro/dotfiles/main/scripts/bootstrap.sh | bash
# Options:
#   ANSIBLE_TAGS="nvim,nushell" ./bootstrap.sh   → install specific roles only
#   CHECK=1 ./bootstrap.sh                        → dry-run, no changes made
# =============================================================================

set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
RESET="\033[0m"
BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"

# ─── Config ───────────────────────────────────────────────────────────────────
DOTFILES_REPO="git@github.com:TheHikuro/dotfiles.git"
DOTFILES_DIR="${HOME}/dotfiles"
LOG_FILE="${HOME}/.dotfiles_bootstrap.log"
ANSIBLE_TAGS="${ANSIBLE_TAGS:-"all"}"

# ─── Helpers ──────────────────────────────────────────────────────────────────
log() { echo -e "${BOLD}${BLUE}[bootstrap]${RESET} $*" | tee -a "$LOG_FILE"; }
success() { echo -e "${BOLD}${GREEN}  ✓ $*${RESET}" | tee -a "$LOG_FILE"; }
warn() { echo -e "${BOLD}${YELLOW}  ⚠ $*${RESET}" | tee -a "$LOG_FILE"; }
error() {
  echo -e "${BOLD}${RED}  ✗ $*${RESET}" | tee -a "$LOG_FILE"
  exit 1
}
step() { echo -e "\n${BOLD}${CYAN}━━━ $* ━━━${RESET}" | tee -a "$LOG_FILE"; }
command_exists() { command -v "$1" &>/dev/null; }

# ─── Secrets ──────────────────────────────────────────────────────────────────
# Format: "KEYCHAIN_SERVICE_NAME:Description shown to the user"
# Add new secrets here — they will be prompted before installation begins
REQUIRED_SECRETS=(
  "JIRA_API_TOKEN:Jira Token Api"
  "ANTHROPIC_API_KEY:Claude api key"
  "SOPS_AGE_KEY:Age private key for sops (decrypts project .env.encrypted files)"
  # "GITHUB_TOKEN:GitHub Personal Access Token"  ← add more secrets here
)

collect_secrets() {
  step "Secrets — Keychain check"

  local dry_run=${CHECK:-0}
  local all_present=true

  for entry in "${REQUIRED_SECRETS[@]}"; do
    local service="${entry%%:*}"
    local description="${entry#*:}"

    if security find-generic-password -a "$USER" -s "$service" -w &>/dev/null; then
      success "${service} → already in Keychain"
    else
      all_present=false
      if [[ "$dry_run" == "1" ]]; then
        warn "${service} → MISSING (will be prompted on real bootstrap)"
      else
        echo -e "\n  ${BOLD}${YELLOW}Missing secret: ${service}${RESET}"
        echo -e "  ${description}"
        echo -ne "  ${CYAN}Value:${RESET} "
        read -rs secret_value # -s hides input
        echo ""

        if [[ -n "$secret_value" ]]; then
          security add-generic-password \
            -a "$USER" \
            -s "$service" \
            -w "$secret_value" \
            -U 2>/dev/null
          success "${service} → stored in Keychain"
        else
          warn "${service} → skipped (empty value)"
        fi
      fi
    fi
  done

  if [[ "$all_present" == "true" ]]; then
    success "All secrets are present"
  fi
}

# ─── Preflight ────────────────────────────────────────────────────────────────
preflight() {
  step "Preflight checks"
  [[ "$(uname)" == "Darwin" ]] || error "This script is designed for macOS only."
  success "macOS $(sw_vers -productVersion)"

  if ! xcode-select -p &>/dev/null; then
    log "Installing Xcode Command Line Tools..."
    xcode-select --install
    until xcode-select -p &>/dev/null; do sleep 5; done
  fi
  success "Xcode Command Line Tools OK"
}

# ─── Homebrew ─────────────────────────────────────────────────────────────────
install_homebrew() {
  step "Homebrew"
  if command_exists brew; then
    warn "Homebrew already installed — updating..."
    # GIT_TERMINAL_PROMPT=0 prevents git from blocking on credential prompts
    # grep -v filters out noise from the deprecated cask-fonts tap and git errors
    GIT_TERMINAL_PROMPT=0 brew update --quiet 2>&1 | grep -v "cask-fonts" | grep -v "fatal:" || true

    # Remove deprecated homebrew/cask-fonts tap if still present
    if brew tap | grep -q "homebrew/cask-fonts"; then
      warn "Removing deprecated tap: homebrew/cask-fonts..."
      brew untap homebrew/homebrew-cask-fonts 2>/dev/null || true
    fi
  else
    log "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>"${HOME}/.zprofile"
    else
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi
  success "Homebrew $(brew --version | head -1)"
}

# ─── Git ──────────────────────────────────────────────────────────────────────
install_git() {
  step "Git"
  command_exists git || brew install git
  success "Git $(git --version | awk '{print $3}')"

  step "Git CLI"
  command_exists gh || brew install gh
  success "GitHub CLI $(gh --version | head -1 | awk '{print $3}')"

  step "Gitlab CLI"
  command_exists glab || brew install glab
  success "GitLab CLI $(glab --version | head -1 | awk '{print $3}')"
}

# ─── MISE ─────────────────────────────────────────────────────────────────────
install_mise() {
  step "MISE (universal version manager)"
  if command_exists mise; then
    warn "MISE already installed ($(mise --version)) — skipping"
  else
    log "Installing MISE..."
    brew install mise
    eval "$(mise activate bash)"
    grep -q "mise activate" "${HOME}/.zshrc" 2>/dev/null ||
      echo 'eval "$(mise activate zsh)"' >>"${HOME}/.zshrc"
  fi
  success "MISE $(mise --version)"
}

# ─── Ansible ──────────────────────────────────────────────────────────────────
install_ansible() {
  step "Ansible"
  if command_exists ansible; then
    warn "Ansible already installed — skipping"
  else
    brew install ansible
    # community.general required for git_config module
    ansible-galaxy collection install community.general
  fi
  success "Ansible $(ansible --version | head -1 | awk '{print $NF}')"
}

# ─── Clone dotfiles ───────────────────────────────────────────────────────────
clone_dotfiles() {
  step "Dotfiles"
  if [[ -d "${DOTFILES_DIR}/.git" ]]; then
    warn "Repo already cloned — syncing..."
    local current_branch
    current_branch=$(git -C "${DOTFILES_DIR}" rev-parse --abbrev-ref HEAD)
    log "Current branch: ${current_branch}"

    # Check if branch has a configured upstream
    if git -C "${DOTFILES_DIR}" rev-parse --abbrev-ref "@{upstream}" &>/dev/null; then
      GIT_TERMINAL_PROMPT=0 git -C "${DOTFILES_DIR}" pull --rebase --autostash
    else
      # No tracking → fetch and set upstream if branch exists on remote
      warn "No upstream tracking for '${current_branch}' — fetching from origin..."
      GIT_TERMINAL_PROMPT=0 git -C "${DOTFILES_DIR}" fetch origin
      if git -C "${DOTFILES_DIR}" ls-remote --heads origin "${current_branch}" | grep -q "${current_branch}"; then
        git -C "${DOTFILES_DIR}" branch --set-upstream-to="origin/${current_branch}" "${current_branch}"
        git -C "${DOTFILES_DIR}" pull --rebase --autostash
      else
        warn "Branch '${current_branch}' does not exist on origin — staying on local commit."
      fi
    fi
  else
    log "Cloning ${DOTFILES_REPO}..."
    GIT_TERMINAL_PROMPT=0 git clone "${DOTFILES_REPO}" "${DOTFILES_DIR}"
  fi
  success "Dotfiles → ${DOTFILES_DIR}"
}

# ─── Run Ansible ──────────────────────────────────────────────────────────────
run_ansible() {
  step "Ansible Playbook"

  local playbook="${DOTFILES_DIR}/ansible/setup.yml"
  local inventory="${DOTFILES_DIR}/ansible/hosts.ini"

  [[ -f "$playbook" ]] || error "Playbook not found: ${playbook}"

  local cmd=(ansible-playbook "$playbook" -i "$inventory" --diff)

  [[ "$ANSIBLE_TAGS" != "all" ]] && cmd+=(--tags "$ANSIBLE_TAGS") &&
    log "Tags: ${ANSIBLE_TAGS}"

  [[ "${CHECK:-0}" == "1" ]] && cmd+=(--check) && warn "Dry-run mode (CHECK=1)"

  "${cmd[@]}"
  success "Playbook OK"
}

# ─── Shells ───────────────────────────────────────────────────────────────────
setup_shells() {
  step "Shells"

  local fish_bin="/opt/homebrew/bin/fish"

  # fish is the login shell; nushell stays installed as a fallback.
  if ! command_exists fish; then
    log "Installing fish..."
    brew install fish
  fi
  success "fish $(fish --version)"

  if ! command_exists nu; then
    log "Installing Nushell (fallback shell)..."
    brew install nushell
  fi
  success "Nushell $(nu --version)"

  # Ensure nushell config directory exists
  mkdir -p "${HOME}/.config/nushell"
  success "~/.config/nushell directory OK"

  # Add fish to /etc/shells if not already listed
  if ! grep -qF "$fish_bin" /etc/shells; then
    log "Adding ${fish_bin} to /etc/shells (requires sudo)..."
    echo "$fish_bin" | sudo tee -a /etc/shells >/dev/null
    success "${fish_bin} added to /etc/shells"
  fi

  # Set fish as default shell via dscl
  local current_shell
  current_shell=$(dscl . -read "/Users/${USER}" UserShell 2>/dev/null | awk '{print $2}')
  if [[ "$current_shell" != "$fish_bin" ]]; then
    log "Setting fish as default shell (requires sudo)..."
    sudo dscl . -create "/Users/${USER}" UserShell "$fish_bin"
    success "Default shell → ${fish_bin}"
  else
    success "Default shell already set to fish"
  fi
}

# ─── Post-install ─────────────────────────────────────────────────────────────
post_install() {
  step "Post-install"

  if [[ -f "${DOTFILES_DIR}/.mise.toml" ]]; then
    log "Installing tools via MISE..."
    mise install --yes
    success "MISE tools installed"
  fi

  echo -e "\n${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD}${GREEN}  ✓ Bootstrap complete!${RESET}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "\n  ${BOLD}Dotfiles:${RESET} ${DOTFILES_DIR}"
  echo -e "  ${BOLD}Logs:    ${RESET} ${LOG_FILE}"
  echo -e "\n  ${YELLOW}➜ Restart your terminal:${RESET}"
  echo -e "    ${CYAN}exec nu${RESET}   (NuShell)"
  echo -e "    ${CYAN}exec zsh${RESET}  (fallback)\n"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
  echo -e "\n${BOLD}${CYAN}"
  echo "  ██╗      ██████╗  █████╗ ███╗   ██╗     ██████╗██╗     ███████╗██████╗ ██╗███████╗"
  echo "  ██║     ██╔═══██╗██╔══██╗████╗  ██║    ██╔════╝██║     ██╔════╝██╔══██╗██║██╔════╝"
  echo "  ██║     ██║   ██║███████║██╔██╗ ██║    ██║     ██║     █████╗  ██████╔╝██║███████╗"
  echo "  ██║     ██║   ██║██╔══██║██║╚██╗██║    ██║     ██║     ██╔══╝  ██╔══██╗██║╚════██║"
  echo "  ███████╗╚██████╔╝██║  ██║██║ ╚████║    ╚██████╗███████╗███████╗██║  ██║██║███████║"
  echo "  ╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝    ╚═════╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝╚══════╝"
  echo -e "${RESET}"
  echo -e "  ${BOLD}Dotfiles Bootstrap${RESET}"
  echo -e "  Log: ${LOG_FILE}\n"

  mkdir -p "$(dirname "$LOG_FILE")"
  echo "Bootstrap started at $(date)" >"$LOG_FILE"

  preflight
  collect_secrets
  install_homebrew
  install_git
  install_mise
  install_ansible
  clone_dotfiles
  setup_shells
  run_ansible
  post_install
}

main "$@"
