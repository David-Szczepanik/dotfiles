# Windows dotfiles

Keep this repo in a permanent location and put PowerShell 7 (`pwsh.exe`) on PATH. From the repo root, preview the setup and then apply it.

```powershell
.\setup.bat -WhatIf
.\setup.bat
```

## Layout

| Repo path | Where setup links it |
| --- | --- |
| `config/nvim/` | LazyVim config at `%LOCALAPPDATA%\nvim` |
| `config/powershell/` | PowerShell 7 profile and encrypted settings for `pa` |
| `config/zed/` | Settings and keymap at `%APPDATA%\Zed` |
| `config/ideavim/` and `config/vsvim/` | `.ideavimrc` and `.vsvimrc` in your user profile |
| `config/claude/` | Managed settings, instructions, hooks, and status line under `~/.claude` |
| `.skills/` | Shared skills under `~/.claude/skills` and `~/.agents/skills` |
| `scripts/setup.ps1` | Installer called by `setup.bat` |

Setup backs up items it replaces beside their original paths with a `.dotfiles-backup-<timestamp>` suffix. It reuses correct links on subsequent runs. Directories use junctions. Files use symbolic links when available, with hard links as a same-drive fallback. Rerun setup if a Git operation replaces a hard-linked file.

## Shared skills

Add `.skills/<name>/SKILL.md` and rerun setup to make the skill available in every Claude Code and Codex project. Setup links each skill individually and stops before making changes if a skill name is already in use by a local copy or a different link.

## PowerShell tools and encrypted settings

Install the apps you use separately. The profile initializes zoxide when it is on PATH. To install zoxide and fzf, run `winget install ajeetdsouza.zoxide` and `winget install junegunn.fzf`.

The `pa` SSH shortcut requires `dotenvx` on PATH. Include `config/powershell/.env` in Git. It holds the encrypted host and its public key. Git ignores `.env.keys`, which holds the private decryption key. Setup links the encrypted file to `%LOCALAPPDATA%\dotfiles\.env`. On a new machine, restore the matching private key from a secure backup to `%LOCALAPPDATA%\dotfiles\.env.keys`.
