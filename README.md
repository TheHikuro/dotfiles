# 🛠️ Dotfiles — Loan CLERIS

Personal macOS setup, fully managed and deployed via Ansible + GNU Stow. Not intended for public use, but feel free to use it as a reference.

## ✨ Stack

| Tool                                                | Role                                                |
| --------------------------------------------------- | --------------------------------------------------- |
| [Ansible](https://www.ansible.com/)                 | Deployment & automation                             |
| [GNU Stow](https://www.gnu.org/software/stow/)      | Dotfiles symlink manager                            |
| [MISE](https://mise.jdx.dev/)                       | Universal version manager (Node, Rust, Ruby, Java…) |
| [NuShell](https://www.nushell.sh/)                  | Primary shell                                       |
| [Starship](https://starship.rs/)                    | Prompt                                              |
| [Ghostty](https://ghostty.org/)                     | Terminal emulator                                   |
| [Zellij](https://zellij.dev/)                       | Terminal multiplexer                                |
| [Oh My Pi (omp)](https://github.com/can1357/oh-my-pi)  | AI coding agent CLI                                 |
| [Terax](https://terax.app/)                          | AI-native terminal (secondary)                      |
| [Neovim](https://neovim.io/)                        | Editor (LazyVim-based)                              |
| [Carapace](https://github.com/rsteube/carapace-bin) | Multi-shell completion                              |
| [Zoxide](https://github.com/ajeetdsouza/zoxide)     | Smart directory navigation                          |

---

## 🚀 Fresh Install

One command to rule them all:

```bash
curl -fsSL https://raw.githubusercontent.com/TheHikuro/dotfiles/main/scripts/bootstrap.sh | bash
```

The script runs in order: Xcode CLI Tools → Homebrew → Git → MISE → Ansible → clone repo → **collect secrets** → run playbook → install language tools.

### Options

```bash
# Install only specific components
ANSIBLE_TAGS="nvim,nushell" bash ./scripts/bootstrap.sh

# Dry-run — shows what would change, modifies nothing
CHECK=1 bash ./scripts/bootstrap.sh
```

### MISE tasks (preferred if repo already cloned)

```bash
mise run install             # full install
mise run setup               # mise install deps
mise run bootstrap-dry-run   # dry-run (CHECK=1)
mise run ansible-run         # run playbook only
mise run ansible-check       # playbook dry-run
mise run ansible-nvim        # deploy nvim config only
mise run ansible-nushell     # deploy nushell config only
mise run status              # show installed tool versions
mise tasks                   # list all available tasks
```

---

## 🔐 Secrets & Environment Variables

Secrets are stored in the **macOS Keychain** — never in plaintext, never committed to git.

### How it works

`secrets.nu` (tracked in this repo) reads values from the Keychain at shell startup:

```nushell
# ~/.config/nushell/secrets.nu — safe to commit, contains no actual values
let akka_key = (keychain-get "AKKA_LICENSE_KEY")
if ($akka_key | is-not-empty) {
  $env.AKKA_LICENSE_KEY = $akka_key
}
```

Secrets are sourced in **`env.nu`** (not `config.nu`) so environment variables are available to all processes, including backend servers:

```nushell
# env.nu
source ~/.config/nushell/secrets.nu
```

### Automated provisioning

The bootstrap script collects missing secrets **interactively before installation begins**. For each missing secret, it prompts for the value and stores it in the Keychain silently (input is hidden):

```
━━━ Secrets — Keychain check ━━━
  ⚠ Secret missing: AKKA_LICENSE_KEY
  Akka License Key (Lightbend)
  Value: ████████              ← hidden input
  ✓ AKKA_LICENSE_KEY → stored in Keychain
```

On subsequent runs, already-stored secrets are skipped automatically.

### Adding a new secret

**1. Register it in `scripts/bootstrap.sh`:**

```bash
REQUIRED_SECRETS=(
  "AKKA_LICENSE_KEY:Akka License Key (Lightbend)"
  "MY_NEW_SECRET:Description shown to the user"   # ← add here
)
```

**2. Read it in `.config/nushell/secrets.nu`:**

```nushell
let my_secret = (keychain-get "MY_NEW_SECRET")
if ($my_secret | is-not-empty) {
  $env.MY_NEW_SECRET = $my_secret
}
```

**3. Add it to `ansible/roles/secrets/vars/main.yml`:**

```yaml
keychain_secrets:
  - service: "MY_NEW_SECRET"
    prompt: "My New Secret"
    description: "What this secret is used for"
```

### Manual Keychain management

```bash
# Store a secret
security add-generic-password -a "$USER" -s "MY_SECRET" -w "the_value"

# Read a secret
security find-generic-password -a "$USER" -s "MY_SECRET" -w

# Delete a secret
security delete-generic-password -a "$USER" -s "MY_SECRET"
```

> **Never commit secrets.** `.gitignore` also blocks `.mise.local.toml` which can hold local env overrides that don't belong in the Keychain.

---

## 🔗 Symlinks — GNU Stow

All config symlinks are managed by **GNU Stow** — no manual `ln -s` needed.

Stow maps `dotfiles/.config/` directly to `~/.config/`:

```
dotfiles/.config/nushell/  →  ~/.config/nushell
dotfiles/.config/nvim/     →  ~/.config/nvim
dotfiles/.config/mise/     →  ~/.config/mise
dotfiles/.config/starship/ →  ~/.config/starship
dotfiles/.config/tmux/     →  ~/.config/tmux
dotfiles/.config/zellij/   →  ~/.config/zellij
```

A few packages live under `dotfiles/.config/` for organization but are stowed to their **real** (non-XDG) config location instead of `~/.config/`, so they're excluded from the mapping above via `stow --ignore`:

```
dotfiles/.config/omp/agent/config.yml     →  ~/.omp/agent/config.yml
dotfiles/.config/terax/terax-settings.json → ~/Library/Application Support/app.crynta.terax/terax-settings.json
dotfiles/.claude/                          →  ~/.claude/
```

Only the tracked files/dirs get symlinked — untracked runtime state next to them (`~/.omp/agent/agent.db`, `~/.omp/agent/sessions/`, Terax's `terax-spaces.json`/`terax-ai-sessions.json`, etc.) is left as real files on disk, never pulled into git.

Stow is run automatically at the end of the Ansible playbook (`stow` role). To re-apply manually:

```bash
cd ~/dotfiles
stow --dir=. --target=~/.config --restow --ignore='^(omp|terax)$' .config
stow --dir=. --target=~/.claude --restow .claude
stow --dir=.config --target=~/.omp omp
stow --dir=.config --target="$HOME/Library/Application Support/app.crynta.terax" terax
```

> Ghostty is the exception — its config lives in `~/Library/Application Support/com.mitchellh.ghostty/config` and is handled separately by the `ghostty` Ansible role.

---

## 🔄 Ansible

### Structure

```
ansible/
├── ansible.cfg            # Roles path, inventory, callbacks config
├── setup.yml              # Main playbook
├── hosts.ini              # Local inventory
├── requirements.yml       # Galaxy collections (community.general)
├── group_vars/
│   └── all.yml            # Shared variables (packages, versions, paths)
└── roles/
    ├── base/              # macOS check, essential dirs, global .gitignore
    ├── homebrew/          # All Homebrew formulas and casks in one pass
    ├── mise/              # Universal version manager setup
    ├── secrets/           # Keychain provisioning
    ├── nushell/           # Shell install + init files (env.nu / config.nu)
    ├── ghostty/           # Terminal config symlink → Library/Application Support
    ├── fonts/             # Nerd Fonts directory check
    └── stow/              # GNU Stow — ~/.config, ~/.claude, ~/.omp/agent, Terax symlinks
```

### Running the playbook manually

```bash
# Full install
ansible-playbook ansible/setup.yml -i ansible/hosts.ini

# Specific roles only
ansible-playbook ansible/setup.yml -i ansible/hosts.ini --tags "nvim,nushell"

# Dry-run
ansible-playbook ansible/setup.yml -i ansible/hosts.ini --check --diff
```

### Available tags

`base` · `homebrew` · `mise` · `secrets` · `fonts` · `ghostty` · `nushell` · `stow`

### First run — install Galaxy dependencies

```bash
ansible-galaxy collection install -r ansible/requirements.yml
```

> This is handled automatically by `bootstrap.sh`.

---

## 🔧 MISE — Universal Version Manager

Replaces Volta, nvm, rbenv, sdkman and rustup. Config lives in `.config/mise/config.toml` (symlinked by Stow):

```toml
[tools]
node = "latest"
bun = "latest"
```

```bash
mise install          # install all tools
mise ls               # list installed versions
mise upgrade          # upgrade all tools to latest
mise use node@26      # switch a specific version
```

---

## 🐚 Shell: NuShell + Starship

- **Shell**: NuShell (set as default via `chsh`)
- **Prompt**: Starship
- **Completion**: Carapace (bridges zsh, fish, bash)
- **Navigation**: Zoxide

Config files (all symlinked via Stow):

- `~/.config/nushell/config.nu`
- `~/.config/nushell/env.nu`
- `~/.config/nushell/secrets.nu`
- `~/.config/starship/starship.toml`

NuShell on macOS loads its entry points from `~/Library/Application Support/nushell/` — these are generated by Ansible and source the real configs from dotfiles.

---

## 🖥️ Terminal: Ghostty

- Theme: `Solarized Dark - Patched`
- Font: `PlemolJP Console NF`
- Opacity: `0.9`
- Config: `~/Library/Application Support/com.mitchellh.ghostty/config`

The config is a **symlink** managed by the `ghostty` Ansible role — no manual `ln -s` needed.

---

## 🤖 Oh My Pi (omp) + Terax

- **omp** — AI coding agent CLI. Config: `~/.omp/agent/config.yml` (symlinked from `dotfiles/.config/omp/agent/config.yml`; `agent.db`, `sessions/`, `.env`, and other runtime state stay real, untracked files next to it).
  - Default model role: `anthropic/claude-sonnet-5:high` (`modelRoles.default` in `config.yml`).
  - `ANTHROPIC_API_KEY` is sourced from the Keychain by `secrets.nu` at shell startup (see [Secrets & Environment Variables](#-secrets--environment-variables)) — no manual `/login` or plaintext key on disk.
- **Terax** — secondary AI-native terminal. Config: `~/Library/Application Support/app.crynta.terax/terax-settings.json` (symlinked from `dotfiles/.config/terax/terax-settings.json`; spaces/sessions/snippets state stays untracked).

---

## 🧠 Neovim (LazyVim)

- Framework: [LazyVim](https://www.lazyvim.org/)
- Plugin manager: [lazy.nvim](https://github.com/folke/lazy.nvim)

| Plugin            | Role                                                    |
| ----------------- | ------------------------------------------------------- |
| `conform.nvim`    | Autoformat (eslint_d → biome → prettier, project-aware) |
| `nvim-treesitter` | Syntax highlighting                                     |
| `telescope.nvim`  | Fuzzy finder                                            |
| `mini.nvim`       | UI & utilities                                          |
| `lualine.nvim`    | Statusline                                              |

**Formatter logic (Conform):** detects project tooling at save time — `eslint_d` if `eslint.config.mjs` found, `biome` if `biome.json` found, `prettier` otherwise.

**ESLint fix on save:** `LspEslintFixAll` runs after formatting via a `BufWritePre` autocmd — handles import sorting, alphabetical rules, and all fixable ESLint rules.

---

## 🪟 Multiplexers

### Zellij (primary)

- Config: `~/.config/zellij/config.kdl`
- Theme: `catppuccin-mocha`

---

## 🧩 CLI Utilities

| Tool                                             | Purpose                               |
| ------------------------------------------------ | ------------------------------------- |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | Fast grep alternative                 |
| [fzf](https://github.com/junegunn/fzf)           | Fuzzy finder                          |
| [bat](https://github.com/sharkdp/bat)            | Better `cat` with syntax highlighting |
| [eza](https://github.com/eza-community/eza)      | Better `ls` with git integration      |
| [fd](https://github.com/sharkdp/fd)              | Better `find`                         |
| [watchman](https://facebook.github.io/watchman/) | File watcher                          |
