$ErrorActionPreference = 'Stop'

$skillFile = "C:/DEV/_DOTFILES/claude-plugins/andrej-karpathy-skills-main/skills/karpathy-guidelines/SKILL.md"

if (-not (Test-Path $skillFile)) { exit 0 }

$content = Get-Content -Raw -Path $skillFile

$payload = @{
    hookSpecificOutput = @{
        hookEventName     = 'SessionStart'
        additionalContext = "The following behavioral guidelines (karpathy-guidelines skill) apply to this session:`n`n$content"
    }
}

$payload | ConvertTo-Json -Depth 5 -Compress
