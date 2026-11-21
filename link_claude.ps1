[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ClaudeHome = (Join-Path $env:USERPROFILE '.claude')
)

$ErrorActionPreference = 'Stop'

$trackedRoot = Join-Path $PSScriptRoot 'Claude'
$trackedPaths = @(
    'CLAUDE.md'
    'RTK.md'
    'settings.json'
    'keybindings.json'
    'statusline.ps1'
    'hooks'
    'skills'
    'commands'
    'rules'
    'themes'
)

function Test-LinkTarget {
    param(
        [System.IO.FileSystemInfo]$Item,
        [string]$ExpectedTarget
    )

    $expected = [System.IO.Path]::GetFullPath($ExpectedTarget)

    if ($Item.LinkType -in @('SymbolicLink', 'Junction')) {
        foreach ($target in @($Item.Target)) {
            $targetText = [string]$target
            if ([System.IO.Path]::IsPathRooted($targetText)) {
                $resolvedTarget = [System.IO.Path]::GetFullPath($targetText)
            } else {
                $resolvedTarget = [System.IO.Path]::GetFullPath(
                    (Join-Path $Item.DirectoryName $targetText)
                )
            }

            if ($resolvedTarget -eq $expected) {
                return $true
            }
        }
    }

    if ($Item.LinkType -eq 'HardLink') {
        $volume = [System.IO.Path]::GetPathRoot($Item.FullName).TrimEnd('\')
        foreach ($hardLinkPath in @(& fsutil hardlink list $Item.FullName 2>$null)) {
            $candidate = if ($hardLinkPath.StartsWith('\')) {
                $volume + $hardLinkPath
            } else {
                $hardLinkPath
            }

            if ([System.IO.Path]::GetFullPath($candidate) -eq $expected) {
                return $true
            }
        }
    }

    return $false
}

if (-not (Test-Path -LiteralPath $trackedRoot -PathType Container)) {
    throw "Tracked Claude directory does not exist: $trackedRoot"
}

New-Item -ItemType Directory -Force -Path $ClaudeHome | Out-Null

# Prefer true symbolic links. If Windows does not permit them, use hard links
# for files and directory junctions for folders (both work without elevation).
$canCreateSymbolicLinks = $false
if (-not $WhatIfPreference) {
    $probeLink = Join-Path $ClaudeHome ".dotfiles-symlink-test-$PID"
    try {
        New-Item -ItemType SymbolicLink -Path $probeLink -Target (Join-Path $trackedRoot 'CLAUDE.md') | Out-Null
        $canCreateSymbolicLinks = $true
    } catch {
        Write-Host 'Symbolic links unavailable; using hard links and directory junctions.'
    } finally {
        if (Test-Path -LiteralPath $probeLink) {
            Remove-Item -LiteralPath $probeLink -Force
        }
    }
}

$backupRoot = Join-Path $ClaudeHome ('backups\dotfiles-link-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$createdBackup = $false

foreach ($relativePath in $trackedPaths) {
    $source = Join-Path $trackedRoot $relativePath
    if (-not (Test-Path -LiteralPath $source)) {
        continue
    }

    $destination = Join-Path $ClaudeHome $relativePath
    $existing = Get-Item -LiteralPath $destination -Force -ErrorAction SilentlyContinue

    if ($existing -and (Test-LinkTarget -Item $existing -ExpectedTarget $source)) {
        Write-Host "Already linked: $destination"
        continue
    }

    $backupPath = $null
    if ($existing) {
        $backupPath = Join-Path $backupRoot $relativePath
        $backupParent = Split-Path -Parent $backupPath

        if ($PSCmdlet.ShouldProcess($destination, "Move existing item to $backupPath")) {
            New-Item -ItemType Directory -Force -Path $backupParent | Out-Null
            Move-Item -LiteralPath $destination -Destination $backupPath
            $createdBackup = $true
        }
    }

    if ($PSCmdlet.ShouldProcess($destination, "Create link to $source")) {
        try {
            $sourceItem = Get-Item -LiteralPath $source
            $linkType = if ($canCreateSymbolicLinks) {
                'SymbolicLink'
            } elseif ($sourceItem.PSIsContainer) {
                'Junction'
            } else {
                'HardLink'
            }

            New-Item -ItemType $linkType -Path $destination -Target $source | Out-Null
            Write-Host "Linked ($linkType): $destination -> $source"
        } catch {
            if ($backupPath -and (Test-Path -LiteralPath $backupPath)) {
                Move-Item -LiteralPath $backupPath -Destination $destination
            }
            throw
        }
    }
}

if ($createdBackup) {
    Write-Host "Original files backed up to: $backupRoot"
}
