if (Get-Command zoxide -ErrorAction SilentlyContinue) {
  Invoke-Expression (zoxide init powershell | Out-String)
}
  Set-PSReadLineKeyHandler -Chord "Ctrl+Delete" -Function DeleteWord

# Alias
  Set-Alias vim nvim
  Set-Alias lg lazygit
  Set-Alias cl claude

  Set-Alias -Name vimconf -Value open_vimconfig
  Set-Alias -Name vimconfpath -Value open_vimconfigpath

  function npmb { npm run build @args }
  function vimconf {
    nvim $env:LOCALAPPDATA\nvim
  }

function pa {
  if (-not (Get-Command dotenvx -ErrorAction SilentlyContinue)) {
    throw 'Install dotenvx to use pa.'
  }

  $envFile = Join-Path $env:LOCALAPPDATA 'dotfiles/.env'
  $sshHost = dotenvx get DOTFILES_PA_SSH_HOST -f $envFile --strict --overload --no-armor 2>$null
  if ($LASTEXITCODE -ne 0 -or $sshHost -isnot [string] -or -not [IPAddress]::TryParse($sshHost, [ref]$null)) {
    throw 'Could not decrypt the SSH host. Check .env and .env.keys in %LOCALAPPDATA%\dotfiles.'
  }
  ssh "root@$sshHost"
}

function open_vimconfig { nvim $HOME/AppData/Local/nvim/init.lua }
function open_vimconfigpath { cd $HOME/AppData/Local/nvim/ }
function open_profile { nvim $PROFILE.CurrentUserCurrentHost }
