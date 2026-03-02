# Infra & Server Tools

A collection of scripts and tools for infrastructure, servers, and development tooling. Use them to set up and maintain your machines in a repeatable way.

---

## Collection

### 1. LazyVim (Neovim) installer

One-command install of [LazyVim](https://www.lazyvim.org/) and Neovim. Backs up existing config if present and installs Neovim under `~/.local` when possible.

| Platform | Script |
|----------|--------|
| **macOS** (Apple Silicon & Intel) | [Mac/install_lazyvim.sh](Mac/install_lazyvim.sh) |
| **Ubuntu** | [Ubuntu/install_lazyvim.sh](Ubuntu/install_lazyvim.sh) |

You can install LazyVim with:

```bash
# macOS
curl https://raw.githubusercontent.com/clasen/Infra/refs/heads/main/Mac/install_lazyvim.sh | bash

# Ubuntu
curl https://raw.githubusercontent.com/clasen/Infra/refs/heads/main/Ubuntu/install_lazyvim.sh | bash
```

Or run the script locally after cloning:

```bash
# macOS
bash Mac/install_lazyvim.sh

# Ubuntu
bash Ubuntu/install_lazyvim.sh
```

---

*More tools will be added over time.*
