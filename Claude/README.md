# Claude Code dotfiles

This directory contains only hand-authored Claude Code configuration. The
credential files, history, sessions, caches, and other runtime data remain
local under `~/.claude` and are ignored by Git.

From PowerShell, create the user-profile links with:

```powershell
& "C:\DEV\_DOTFILES\link_claude.ps1"
```

The script backs up existing configuration under `~/.claude/backups/` before
creating links. It prefers symbolic links. When Windows Developer Mode and an
administrator token are unavailable, it uses hard links for files and a
directory junction for folders, which provide the same live synchronization
with the repository without elevation.
