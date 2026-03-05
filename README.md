# Infra & Server Tools

A collection of scripts and tools for infrastructure, servers, and development tooling. Use them to set up and maintain your machines in a repeatable way.

---

## Collection

### 1. Audit remote script (`audit_remote_script`)

**What it does:** Downloads the script from the given URL and sends it to **Codex** for a security audit. Codex returns a verdict (OK, REVIEW, or BLOCK); only the verdict is shown (the full report is saved in a temp file; use `--keep` to inspect it). With `--run-if-ok`, if the verdict is OK it prompts you to run the script; otherwise nothing is executed. This avoids blindly piping `curl … | bash`.

**Good practice:** Always audit scripts before you run them—especially those downloaded from the internet—before giving them access to your machine. This helper automates that review with Codex so it’s quick and consistent.

**Requirements:** `curl`, [Codex CLI](https://codex.dev/) in `PATH`.

**Usage:**

```bash
# Source the function (e.g. from the repo root)
source audit_remote_script.sh

# Audit only (no execution) — e.g. LazyVim macOS installer
audit_remote_script https://raw.githubusercontent.com/clasen/Infra/refs/heads/main/Mac/install_lazyvim.sh

# Audit and, if Codex says OK, offer to run the script
audit_remote_script --run-if-ok https://raw.githubusercontent.com/clasen/Infra/refs/heads/main/Mac/install_lazyvim.sh
```

| Option        | Description |
|---------------|-------------|
| `--run-if-ok` | If verdict is OK, prompt to execute the script. |
| `--keep`      | Do not delete temp dir; print its path. |
| `-h`, `--help`| Show usage. |

**Exit codes:** `0` = OK (and optionally ran), `1` = usage/download/audit error, `2` = REVIEW, `3` = BLOCK, `4` = unknown verdict.

---

### 2. LazyVim (Neovim) installer

One-command install of [LazyVim](https://www.lazyvim.org/) and Neovim. Backs up existing config if present and installs Neovim under `~/.local` when possible.

| Platform | Script |
|----------|--------|
| **macOS** (Apple Silicon & Intel) | [Mac/install_lazyvim.sh](Mac/install_lazyvim.sh) |
| **Ubuntu** | [Ubuntu/install_lazyvim.sh](Ubuntu/install_lazyvim.sh) |

**Theme:** [Catppuccin](https://github.com/catppuccin/nvim) is installed with flavour **Macchiato** by default. Set `NVIM_CATPPUCCIN_FLAVOUR` to use another: `latte`, `frappe`, `macchiato`, `mocha`.

**Font:** By default the script installs **Fira Code** Nerd Font. To use another font, set `NVIM_NERD_FONT` before running (e.g. `NVIM_NERD_FONT=JetBrainsMono bash Mac/install_lazyvim.sh`). Examples: `FiraCode`, `JetBrainsMono`, `Hack`, `CascadiaCode`, `Iosevka` ([full list](https://github.com/ryanoasis/nerd-fonts/releases)).

You can install LazyVim with:

#### macOS
```bash
curl https://raw.githubusercontent.com/clasen/Infra/refs/heads/main/Mac/install_lazyvim.sh | bash
```

#### Ubuntu
```bash
curl https://raw.githubusercontent.com/clasen/Infra/refs/heads/main/Ubuntu/install_lazyvim.sh | bash
```

---

*More tools will be added over time.*
