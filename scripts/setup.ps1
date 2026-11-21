#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess)]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$config = Join-Path $root 'config'
$skills = Join-Path $root '.skills'
$claudeHome = Join-Path $env:USERPROFILE '.claude'
$codexSkills = Join-Path $env:USERPROFILE '.agents/skills'

function Test-InstalledLink($Item, $Source) {
    if ($Item.LinkType -in 'Junction', 'SymbolicLink' -and $Item.Target) {
        $target = [IO.Path]::GetFullPath([string]$Item.Target, $Item.Parent?.FullName ?? $Item.DirectoryName)
        return $target.TrimEnd('\') -eq $Source
    }

    if ($Item.LinkType -eq 'HardLink') {
        $drive = [IO.Path]::GetPathRoot($Item.FullName).TrimEnd('\')
        $links = & fsutil.exe hardlink list $Item.FullName 2>$null
        return @($links | ForEach-Object { $drive + $_ }) -contains $Source
    }

    return $false
}

function Move-ConfigItem($From, $To, $IsDirectory) {
    if ($IsDirectory) {
        [IO.Directory]::Move($From, $To)
    } else {
        [IO.File]::Move($From, $To)
    }
}

function New-ConfigLink($Source, $Destination, $IsDirectory) {
    if ($IsDirectory) {
        New-Item -ItemType Junction -Path $Destination -Target $Source | Out-Null
    } else {
        try {
            New-Item -ItemType SymbolicLink -Path $Destination -Target $Source | Out-Null
        } catch {
            New-Item -ItemType HardLink -Path $Destination -Target $Source | Out-Null
        }
    }
}

$mappings = @(
    @{ Source = 'nvim'; Destination = Join-Path $env:LOCALAPPDATA 'nvim' }
    @{ Source = 'powershell/profile.ps1'; Destination = $PROFILE.CurrentUserCurrentHost }
    @{ Source = 'powershell/.env'; Destination = Join-Path $env:LOCALAPPDATA 'dotfiles/.env' }
    @{ Source = 'zed/keymap.json'; Destination = Join-Path $env:APPDATA 'Zed/keymap.json' }
    @{ Source = 'zed/settings.json'; Destination = Join-Path $env:APPDATA 'Zed/settings.json' }
    @{ Source = 'ideavim/.ideavimrc'; Destination = Join-Path $env:USERPROFILE '.ideavimrc' }
    @{ Source = 'vsvim/.vsvimrc'; Destination = Join-Path $env:USERPROFILE '.vsvimrc' }
)
foreach ($name in @('CLAUDE.md', 'RTK.md', 'settings.json', 'statusline.ps1', 'hooks')) {
    $mappings += @{ Source = "claude/$name"; Destination = Join-Path $claudeHome $name }
}
foreach ($mapping in $mappings) {
    $mapping.Source = Join-Path $config $mapping.Source
}

foreach ($skill in Get-ChildItem -LiteralPath $skills -Directory) {
    if (-not (Test-Path -LiteralPath (Join-Path $skill.FullName 'SKILL.md') -PathType Leaf)) {
        continue
    }
    foreach ($destinationRoot in @((Join-Path $claudeHome 'skills'), $codexSkills)) {
        $mappings += @{
            Source = $skill.FullName
            Destination = Join-Path $destinationRoot $skill.Name
            Skill = $true
        }
    }
}

$backupSuffix = '.dotfiles-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fffffff')
$changes = foreach ($mapping in $mappings) {
    $source = Get-Item -LiteralPath $mapping.Source -Force -ErrorAction SilentlyContinue
    if (-not $source) { continue }
    $destination = [IO.Path]::GetFullPath($mapping.Destination)
    $existing = Get-Item -LiteralPath $destination -Force -ErrorAction SilentlyContinue
    if ($existing -and (Test-InstalledLink $existing $source.FullName)) { continue }
    if ($existing -and $mapping.Skill) {
        throw "Shared skill conflicts with an existing item: $destination. Merge or rename it before running setup."
    }
    [pscustomobject]@{
        Source = $source
        Destination = $destination
        Existing = $existing
        Backup = "$destination$backupSuffix"
        BackedUp = $false
        Linked = $false
    }
}

$started = [System.Collections.Generic.List[object]]::new()
try {
    foreach ($change in $changes) {
        $action = "Link to $($change.Source.FullName)"
        if ($change.Existing) { $action += " after backing up to $($change.Backup)" }
        if (-not $PSCmdlet.ShouldProcess($change.Destination, $action)) { continue }

        $started.Add($change)
        New-Item -ItemType Directory -Path (Split-Path -Parent $change.Destination) -Force | Out-Null
        if ($change.Existing) {
            Move-ConfigItem $change.Destination $change.Backup $change.Existing.PSIsContainer
            $change.BackedUp = $true
        }
        New-ConfigLink $change.Source.FullName $change.Destination $change.Source.PSIsContainer
        $change.Linked = $true
    }
} catch {
    for ($index = $started.Count - 1; $index -ge 0; $index--) {
        $change = $started[$index]
        try {
            if ($change.Linked) {
                if ($change.Source.PSIsContainer) {
                    [IO.Directory]::Delete($change.Destination)
                } else {
                    [IO.File]::Delete($change.Destination)
                }
            }
            if ($change.BackedUp) {
                Move-ConfigItem $change.Backup $change.Destination $change.Existing.PSIsContainer
            }
        } catch {
            Write-Warning "Could not restore $($change.Destination). Check $($change.Backup). $_"
        }
    }
    throw
}

if (-not $WhatIfPreference) {
    foreach ($change in $started) {
        Write-Host "Linked $($change.Destination)"
        if ($change.BackedUp) { Write-Host "  Backup: $($change.Backup)" }
    }
    Write-Host 'Dotfiles setup complete.'
}
