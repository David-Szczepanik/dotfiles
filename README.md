```
git clone https://github.com/David-Szczepanik/dotfiles.git C:\DEV\_DOTFILES
```

cmd /c mklink /D "C:\Users\dszczepanik\AppData\Roaming\Zed" "C:\DEV\_dotfiled\Zed"

# Install zoxide & fzf
winget install ajeetdsouza.zoxide
winget install junegunn.fzf

## nvim $PROFILE
Invoke-Expression (& { (zoxide init powershell | Out-String) })

z backend
zi backend
