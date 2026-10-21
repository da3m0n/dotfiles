<#
.SYNOPSIS
    One-step setup of the PowerShell 7 + Oh My Posh + Windows Terminal config on a new PC.

.DESCRIPTION
    Run this from the folder it lives in (the cloned dotfiles\powershell folder).
    It installs the programs, the font and the PowerShell modules, then copies the
    profile, theme, README and Windows Terminal settings into the right places.
    Existing files that differ are backed up first (name.bak-yyyyMMdd-HHmmss).
    It is safe to run more than once.

.PARAMETER SkipInstall
    Don't install programs, the font or PowerShell modules; only copy the config files.

.PARAMETER SkipSettings
    Don't touch Windows Terminal's settings.json.

.PARAMETER DryRun
    Show what would be done without changing anything.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Install-ShellConfig.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Install-ShellConfig.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [switch]$SkipInstall,
    [switch]$SkipSettings,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
$isWin = ($env:OS -eq 'Windows_NT')

function Write-Step([string]$Text) { Write-Host "`n==> $Text" -ForegroundColor Cyan }

function Invoke-Action([string]$Description, [scriptblock]$Action) {
    if ($DryRun) { Write-Host "[dry run] $Description" -ForegroundColor Yellow }
    else { Write-Host $Description; & $Action }
}

function Get-PwshPath {
    $cmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $p = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
    if (Test-Path $p) { return $p }
    return $null
}

function Copy-WithBackup([string]$Source, [string]$DestDir) {
    $name = Split-Path $Source -Leaf
    $dest = Join-Path $DestDir $name
    if (Test-Path $dest) {
        if ((Get-FileHash $Source).Hash -eq (Get-FileHash $dest).Hash) {
            Write-Host "Already up to date: $dest"
            return
        }
        $bak = "$dest.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Invoke-Action "Backing up existing $name to $bak" { Copy-Item $dest $bak -Force }
    }
    Invoke-Action "Copying $name to $DestDir" { Copy-Item $Source $dest -Force }
}

# --- Check the files this script needs are next to it ---
$profileSrc  = Join-Path $repo 'Microsoft.PowerShell_profile.ps1'
$themeSrc    = Join-Path $repo 'agnosterplus.omp.json'
$readmeSrc   = Join-Path $repo 'README.md'
$iconsSrc    = Join-Path $repo 'rowan_light.psd1'
$settingsSrc = Join-Path $repo 'settings.json'

foreach ($f in @($profileSrc, $themeSrc)) {
    if (-not (Test-Path $f)) { throw "Missing required file next to this script: $f" }
}

# ============================================================
# 1. Programs, modules, font
# ============================================================
if (-not $SkipInstall) {
    Write-Step 'Installing programs with winget'
    $hasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
    if (-not $hasWinget -and -not $DryRun) {
        throw "winget was not found. Install 'App Installer' from the Microsoft Store, or re-run with -SkipInstall and install the programs manually (see README)."
    }

    $packages = @(
        @{ Id = 'Microsoft.PowerShell';       Name = 'PowerShell 7' },
        @{ Id = 'Microsoft.WindowsTerminal';  Name = 'Windows Terminal' },
        @{ Id = 'JanDeDobbeleer.OhMyPosh';    Name = 'Oh My Posh' },
        @{ Id = 'Git.Git';                    Name = 'Git' },
        @{ Id = 'ajeetdsouza.zoxide';         Name = 'zoxide' },
        @{ Id = 'junegunn.fzf';               Name = 'fzf' }
    )
    foreach ($p in $packages) {
        $installed = $false
        if ($hasWinget) {
            winget list --id $p.Id -e --accept-source-agreements 2>$null | Out-Null
            $installed = ($LASTEXITCODE -eq 0)
        }
        if ($installed) { Write-Host "$($p.Name): already installed" }
        else {
            Invoke-Action "Installing $($p.Name)" {
                winget install --id $p.Id -e --silent --accept-package-agreements --accept-source-agreements
            }
        }
    }

    # Make newly installed programs visible to this window
    if ($isWin -and -not $DryRun) {
        $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                    [Environment]::GetEnvironmentVariable('Path', 'User')
    }

    Write-Step 'Installing PowerShell modules (Terminal-Icons, PSFzf)'
    $pwsh = Get-PwshPath
    if ($pwsh -or $DryRun) {
        foreach ($m in @('Terminal-Icons', 'PSFzf')) {
            Invoke-Action "Installing module $m (if missing)" {
                & $pwsh -NoProfile -Command "if (-not (Get-Module -ListAvailable -Name '$m')) { Install-Module '$m' -Scope CurrentUser -Force }"
            }
        }
    }
    else {
        Write-Warning 'PowerShell 7 (pwsh) was not found, so the modules were not installed. Open a new window and run this script again.'
    }

    Write-Step 'Installing the FiraCode Nerd Font'
    $hasFont = $false
    try {
        Add-Type -AssemblyName System.Drawing
        $families = (New-Object System.Drawing.Text.InstalledFontCollection).Families
        $hasFont = [bool]($families | Where-Object { $_.Name -like 'FiraCode Nerd Font*' })
    }
    catch { }
    if ($hasFont) { Write-Host 'FiraCode Nerd Font: already installed' }
    elseif ((Get-Command oh-my-posh -ErrorAction SilentlyContinue) -or $DryRun) {
        Invoke-Action 'Installing FiraCode Nerd Font' { oh-my-posh font install FiraCode }
    }
    else {
        Write-Warning "oh-my-posh isn't available in this window yet. Open a new window and run: oh-my-posh font install FiraCode"
    }

    if ($isWin) {
        Write-Step 'Allowing profile scripts to run (CurrentUser, RemoteSigned)'
        Invoke-Action 'Set-ExecutionPolicy CurrentUser RemoteSigned' {
            Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
        }
    }
}

# ============================================================
# 2. Profile, theme, README
# ============================================================
Write-Step 'Copying profile, theme, README and Terminal-Icons light theme'
$profileDir = $null
$pwshPath = Get-PwshPath
if ($pwshPath) {
    try { $profileDir = Split-Path -Parent (& $pwshPath -NoProfile -Command '$PROFILE') } catch { }
}
if (-not $profileDir) {
    $profileDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell'
}
Write-Host "Profile folder: $profileDir"

if (-not (Test-Path $profileDir)) {
    Invoke-Action "Creating $profileDir" { New-Item -ItemType Directory -Force $profileDir | Out-Null }
}
Copy-WithBackup $profileSrc $profileDir
Copy-WithBackup $themeSrc   $profileDir
if (Test-Path $readmeSrc) { Copy-WithBackup $readmeSrc $profileDir }
if (Test-Path $iconsSrc)  { Copy-WithBackup $iconsSrc  $profileDir }

# ============================================================
# 3. Windows Terminal settings
# ============================================================
if (-not $SkipSettings -and (Test-Path $settingsSrc)) {
    Write-Step 'Installing Windows Terminal settings'
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal')
    )
    $wtDir = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $wtDir) {
        $wtDir = $candidates[0]
        Write-Host "Windows Terminal has not created its settings folder yet; creating $wtDir"
        Invoke-Action "Creating $wtDir" { New-Item -ItemType Directory -Force $wtDir | Out-Null }
    }
    Write-Host "Terminal settings folder: $wtDir"

    $raw = [IO.File]::ReadAllText($settingsSrc)

    # The saved settings start shells in H:\projects. Use ~\projects if this PC has no H: drive.
    if ($raw.Contains('H:\\projects') -and -not (Test-Path 'H:\')) {
        $fallback = Join-Path $HOME 'projects'
        $jsonPath = $fallback -replace '\\', '\\'
        $raw = $raw.Replace('H:\\projects', $jsonPath)
        Write-Host "No H: drive found, so the starting folder is set to $fallback"
        if (-not (Test-Path $fallback)) {
            Invoke-Action "Creating $fallback" { New-Item -ItemType Directory -Force $fallback | Out-Null }
        }
    }

    $wtDest = Join-Path $wtDir 'settings.json'
    if (Test-Path $wtDest) {
        $existing = [IO.File]::ReadAllText($wtDest)
        if ($existing -eq $raw) { Write-Host "Already up to date: $wtDest" }
        else {
            $bak = "$wtDest.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Invoke-Action "Backing up existing settings.json to $bak" { Copy-Item $wtDest $bak -Force }
            Invoke-Action "Writing $wtDest" { [IO.File]::WriteAllText($wtDest, $raw, (New-Object Text.UTF8Encoding($false))) }
        }
    }
    else {
        Invoke-Action "Writing $wtDest" { [IO.File]::WriteAllText($wtDest, $raw, (New-Object Text.UTF8Encoding($false))) }
    }
}
elseif (-not $SkipSettings) {
    Write-Warning "settings.json not found next to this script, so Windows Terminal settings were not installed."
}

# ============================================================
# Done
# ============================================================
Write-Host ''
if ($DryRun) { Write-Host 'Dry run finished. Nothing was changed.' -ForegroundColor Yellow }
else {
    Write-Host 'Done.' -ForegroundColor Green
    Write-Host 'Next: close ALL Windows Terminal windows, reopen Terminal, and open a tab from the "PowerShell - Light" and "PowerShell - Dark" entries in the dropdown.'
    Write-Host 'Then check the README section "Check it works".'
}
