# ============================================================
# PowerShell 7 profile  -  Oh My Posh + light/dark switching
# ============================================================

# --- Theme detection (keep this FIRST: everything below uses it) ---
# Windows Terminal sets WT_PROFILE_ID to the guid of the profile that launched this shell.
$lightGuid = '{f63b4f74-c9bb-5718-9e33-467c2122f6a7}'   # "PowerShell - Light"
$env:OMP_THEME = if ($env:WT_PROFILE_ID -eq $lightGuid) { 'light' } else { 'dark' }
$isLight = $env:OMP_THEME -eq 'light'

# --- Oh My Posh (one theme file, light/dark palettes inside it) ---
$ompConfig = Join-Path (Split-Path -Parent $PROFILE) 'agnosterplus.omp.json'
if (Test-Path $ompConfig) {
    oh-my-posh init pwsh --config $ompConfig | Invoke-Expression
}
else {
    Write-Warning "Oh My Posh config not found: $ompConfig"
}

# --- Terminal-Icons (loaded when the shell first goes idle, to speed up startup) ---
$null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
    Import-Module Terminal-Icons -Global
}

# --- zoxide (smart directory navigation) ---
Invoke-Expression (& { (zoxide init powershell | Out-String) })

# --- PSReadLine ---
Import-Module PSReadLine

# History search with arrow keys
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# Predictive command suggestions
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView

# Ctrl+Left / Ctrl+Right move between words
Set-PSReadLineKeyHandler -Key Ctrl+LeftArrow -Function BackwardWord
Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord

# Syntax-highlighting colours that stay readable on both backgrounds
function ConvertTo-Ansi([string]$Hex) {
    $r = [Convert]::ToInt32($Hex.Substring(1, 2), 16)
    $g = [Convert]::ToInt32($Hex.Substring(3, 2), 16)
    $b = [Convert]::ToInt32($Hex.Substring(5, 2), 16)
    "`e[38;2;${r};${g};${b}m"
}

$hex = if ($isLight) {
    @{ Command = '#1f6fb2'; Parameter = '#6d28d9'; Operator = '#4b5563'; Variable = '#237a4b'
       String  = '#b45309'; Number    = '#0e7490'; Type     = '#0e7490'; Member   = '#374151'
       Keyword = '#9d174d'; Comment   = '#6b7280'; Default  = '#1f2937'; Error    = '#b91c1c'
       Emphasis = '#b45309'; InlinePrediction = '#8a94a3'; ListPrediction = '#6b7280' }
}
else {
    @{ Command = '#8be9fd'; Parameter = '#ffb86c'; Operator = '#ff79c6'; Variable = '#50fa7b'
       String  = '#f1fa8c'; Number    = '#bd93f9'; Type     = '#8be9fd'; Member   = '#f8f8f2'
       Keyword = '#ff79c6'; Comment   = '#6272a4'; Default  = '#f8f8f2'; Error    = '#ff5555'
       Emphasis = '#ffb86c'; InlinePrediction = '#6272a4'; ListPrediction = '#9aa5ce' }
}

# Only set colour keys this PSReadLine version supports
$supported = (Get-PSReadLineOption).PSObject.Properties.Name
$colors = @{}
foreach ($k in $hex.Keys) {
    $prop = if ($k -eq 'Default') { 'DefaultTokenColor' } else { "${k}Color" }
    if ($supported -contains $prop) { $colors[$k] = ConvertTo-Ansi $hex[$k] }
}
Set-PSReadLineOption -Colors $colors

# --- fzf / PSFzf ---
$env:FZF_DEFAULT_OPTS = if ($isLight) { '--color=light' } else { '--color=dark' }
Import-Module PSFzf
Set-PsFzfOption -PSReadLineChordReverseHistory 'Ctrl+r'
Set-PsFzfOption -PSReadLineChordProvider 'Ctrl+t'

# --- Navigation helpers ---
function .. {
    Set-Location ..
}

function ... {
    Set-Location ../..
}

# --- Open a folder in WebStorm ---
function ws {
    param([string]$Path = ".")

    $exe = Get-ChildItem "C:\Program Files\JetBrains\WebStorm*\bin\webstorm64.exe" -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending |
        Select-Object -First 1

    if (-not $exe) {
        Write-Warning "WebStorm not found under C:\Program Files\JetBrains"
        return
    }

    Start-Process -FilePath $exe.FullName -ArgumentList "`"$((Resolve-Path $Path).Path)`""
}


# --- Open a folder in PyCharm ---
function pycharm {
    param([string]$Path = ".")

    $exe = Get-ChildItem "C:\Program Files\JetBrains\PyCharm*\bin\pycharm64.exe" -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending |
        Select-Object -First 1

    if (-not $exe) {
        Write-Warning "WebStorm not found under C:\Program Files\JetBrains"
        return
    }

    Start-Process -FilePath $exe.FullName -ArgumentList "`"$((Resolve-Path $Path).Path)`""
}

function which($name) {
    Get-Command $name | Select-Object -ExpandProperty Source
}

# --- Back up profile, theme and Windows Terminal settings into a local git repo ---
function Backup-ShellConfig {
    $dest = Join-Path $HOME 'dotfiles\powershell'
    New-Item -ItemType Directory -Force $dest | Out-Null

    $files = @(
        $PROFILE,
        (Join-Path (Split-Path -Parent $PROFILE) 'agnosterplus.omp.json'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json')
    )
    foreach ($f in $files) {
        if (Test-Path $f) { Copy-Item $f -Destination $dest -Force }
        else { Write-Warning "Not found, skipped: $f" }
    }

    if (Get-Command git -ErrorAction SilentlyContinue) {
        git -C $dest init -q
        git -C $dest add -A
        git -C $dest commit -q -m "Shell config backup $(Get-Date -Format 's')" 2>$null
        # Push to GitHub only if a remote has been set up (see README)
        if (git -C $dest remote) { git -C $dest push -q -u origin HEAD }
    }
    Write-Host "Backed up to $dest"
}