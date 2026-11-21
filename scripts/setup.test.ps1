# Run with pwsh -NoProfile -File scripts/setup.test.ps1.
$ErrorActionPreference = 'Stop'
$fixture = Join-Path ([IO.Path]::GetTempPath()) "dotfiles-test-$([guid]::NewGuid())"

function Assert($Condition, $Message) {
    if (-not $Condition) { throw $Message }
}

try {
    $repository = Join-Path $fixture 'repo with spaces'
    $env:USERPROFILE = Join-Path $fixture 'home'
    $env:LOCALAPPDATA = Join-Path $fixture 'local'
    $env:APPDATA = Join-Path $fixture 'roaming'
    $PROFILE = [pscustomobject]@{ CurrentUserCurrentHost = Join-Path $fixture 'documents/profile.ps1' }
    $claude = Join-Path $env:USERPROFILE '.claude/skills'
    $codex = Join-Path $env:USERPROFILE '.agents/skills'
    $shared = Join-Path $repository '.skills/shared'
    $config = Join-Path $repository 'config'
    $setup = Join-Path $repository 'scripts/setup.ps1'
    $nvim = Join-Path $env:LOCALAPPDATA 'nvim'

    foreach ($dir in @($shared, "$claude/local", $codex, "$config/nvim", "$config/powershell", "$repository/scripts", $env:LOCALAPPDATA)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    Assert (Test-Path -LiteralPath "$PSScriptRoot/setup.ps1") 'Missing installer'
    Copy-Item -LiteralPath "$PSScriptRoot/setup.ps1" -Destination $setup
    Set-Content -LiteralPath "$shared/SKILL.md" -Value 'shared skill'
    Set-Content -LiteralPath "$claude/local/SKILL.md" -Value 'local skill'
    Set-Content -LiteralPath "$config/powershell/profile.ps1" -Value '# new profile'
    Set-Content -LiteralPath "$config/powershell/.env" -Value 'DOTFILES_PA_SSH_HOST="encrypted:test"'
    New-Item -ItemType Directory -Path (Split-Path $PROFILE.CurrentUserCurrentHost) | Out-Null
    Set-Content -LiteralPath $PROFILE.CurrentUserCurrentHost -Value '# old profile'

    $oldNvim = Join-Path $repository 'LazyVim'
    New-Item -ItemType Directory -Path $oldNvim | Out-Null
    New-Item -ItemType Junction -Path $nvim -Target $oldNvim | Out-Null
    Rename-Item -LiteralPath $oldNvim -NewName 'old-target-moved'

    New-Item -ItemType Directory -Path "$codex/shared" | Out-Null
    $collision = try { & $setup; $null } catch { $_ }
    Assert ($collision -and $collision.Exception.Message -like '*skill*shared*') 'Expected a skill collision'
    Assert (-not (Test-Path -LiteralPath "$claude/shared")) 'Collision was detected after setup made changes'
    [IO.Directory]::Delete("$codex/shared")

    & $setup -WhatIf
    Assert (-not (Test-Path -LiteralPath "$claude/shared")) 'WhatIf created a skill link'
    Assert ((Get-Content -LiteralPath $PROFILE.CurrentUserCurrentHost) -eq '# old profile') 'WhatIf changed the profile'

    New-Item -ItemType Directory -Path "$config/zed" | Out-Null
    Set-Content -LiteralPath "$config/zed/keymap.json" -Value '[]'
    Set-Content -LiteralPath "$config/zed/settings.json" -Value '{"vim_mode": true}'
    Set-Content -LiteralPath $env:APPDATA -Value 'blocks creation of the Zed directory'
    $failure = try { & $setup; $null } catch { $_ }
    Assert ($failure) 'Expected setup to fail on the blocked Zed path'
    Assert ((Get-Item -LiteralPath $nvim -Force).Target -eq $oldNvim) 'Failed setup did not restore the old Neovim junction'
    Assert ((Get-Content -LiteralPath $PROFILE.CurrentUserCurrentHost) -eq '# old profile') 'Failed setup did not restore the original profile'
    [IO.File]::Delete($env:APPDATA)

    & $setup
    $zedSettings = Join-Path $env:APPDATA 'Zed/settings.json'
    Assert ((Test-Path -LiteralPath $zedSettings) -and ((Get-Item -LiteralPath $zedSettings).LinkType -in 'SymbolicLink', 'HardLink')) 'Zed settings were not linked'
    Assert ((Get-Content -LiteralPath "$claude/shared/SKILL.md") -eq 'shared skill') 'Claude skill was not linked'
    Assert ((Get-Content -LiteralPath "$codex/shared/SKILL.md") -eq 'shared skill') 'Codex skill was not linked'
    Assert ((Get-Content -LiteralPath "$claude/local/SKILL.md") -eq 'local skill') 'Unrelated local skill changed'
    Assert ((Get-Item -LiteralPath $nvim).Target -eq (Join-Path $config 'nvim')) 'Old Neovim junction was not repaired'
    Assert ((Get-Content -LiteralPath $PROFILE.CurrentUserCurrentHost) -eq '# new profile') 'PowerShell profile was not linked'
    Assert ((Test-Path -LiteralPath (Join-Path $env:LOCALAPPDATA 'dotfiles/.env') -PathType Leaf)) 'PowerShell encrypted env file was not linked'

    $backup = @(Get-ChildItem -LiteralPath (Split-Path $PROFILE.CurrentUserCurrentHost) -Filter '*.dotfiles-backup-*')
    Assert ($backup.Count -eq 1 -and (Get-Content -LiteralPath $backup[0].FullName) -eq '# old profile') 'Original profile was not backed up'
    & $setup
    Assert (@(Get-ChildItem -LiteralPath (Split-Path $PROFILE.CurrentUserCurrentHost) -Filter '*.dotfiles-backup-*').Count -eq 1) 'Rerun created an unnecessary backup'
} finally {
    if (Test-Path -LiteralPath $fixture) {
        $resolvedFixture = (Resolve-Path -LiteralPath $fixture).ProviderPath
        if ($resolvedFixture -ne $fixture) { throw "Unexpected fixture path: $resolvedFixture" }
        Get-ChildItem -LiteralPath $resolvedFixture -Recurse -Force -Attributes ReparsePoint |
            ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }
        Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
    }
}
Write-Output 'Setup smoke test passed.'
