# PowerShell 7 Setup: Oh My Posh, light/dark profiles

A PowerShell 7 setup for Windows Terminal with two profiles, **PowerShell - Light** and **PowerShell - Dark**. One Oh My Posh theme file switches colours automatically, and syntax-highlighting colours stay readable on both backgrounds.

## What's in this folder

| File | Where it goes | Purpose |
|---|---|---|
| `Microsoft.PowerShell_profile.ps1` | the folder `$PROFILE` points at (normally `C:\Users\<you>\Documents\PowerShell\`) | Detects light/dark, starts Oh My Posh, sets PSReadLine colours, fzf, zoxide, helper functions, `Backup-ShellConfig` |
| `agnosterplus.omp.json` | **same folder as the profile** | Oh My Posh theme, one file with `light` and `dark` palettes and git-status colours |
| `settings.json` | Windows Terminal settings folder (see step 5) | Terminal profiles, colour schemes, font, starting folder |
| `Install-ShellConfig.ps1` | stays in the repo | One-step installer for a new PC (see "Quick install") |
| `README.md` | the profile folder (copied by the installer) | This file |

## How it works (read this once)

1. Windows Terminal starts a shell from either the Light or the Dark profile. Both use a plain `pwsh.exe -NoLogo` command line.
2. Terminal sets the environment variable `WT_PROFILE_ID` to that profile's **guid**.
3. The top of the PowerShell profile compares `WT_PROFILE_ID` with `$lightGuid`. It sets `$env:OMP_THEME` to `light` or `dark`, and `$isLight` to true or false.
4. The Oh My Posh theme reads `OMP_THEME` to choose its colour palette. The profile also uses `$isLight` to choose PSReadLine syntax colours and fzf colours.

**Important:** the guid in the profile (`$lightGuid`) must match the guid of the "PowerShell - Light" entry in Windows Terminal's `settings.json`. If you copy both files from this setup, they already match.

Current guids:

- PowerShell - Light: `{f63b4f74-c9bb-5718-9e33-467c2122f6a7}`
- PowerShell - Dark: `{f3c0b797-b2d6-550c-8bed-1d9ecc4785d4}`

## Quick install on a new PC (recommended)

One script does everything below: installs the programs, the font and the modules, then copies the profile, theme, README and Windows Terminal settings into the right folders. Run it in **Windows PowerShell** (it is already on every Windows PC).

```powershell
winget install --id Git.Git -e        # skip if Git is already installed; reopen the window afterwards
git clone https://github.com/<you>/dotfiles.git "$HOME\dotfiles\powershell"
cd "$HOME\dotfiles\powershell"
powershell -ExecutionPolicy Bypass -File .\Install-ShellConfig.ps1
```

**Clone into `$HOME\dotfiles\powershell` exactly as shown.** The GitHub repository's root is that folder's contents (the profile, theme, installer and so on sit at the top level), and `Backup-ShellConfig` expects the repo at `$HOME\dotfiles\powershell` on every PC. Cloning into any other folder means backups would create a second, separate repo.

Useful options:

| Option | Effect |
|---|---|
| `-DryRun` | Show what would happen without changing anything. Run this first if you're unsure. |
| `-SkipInstall` | Only copy the config files; don't install programs, font or modules. |
| `-SkipSettings` | Leave Windows Terminal's `settings.json` alone. |

What the script does for you:

- Skips programs that are already installed.
- Backs up any existing file that differs, as `name.bak-yyyyMMdd-HHmmss`, before replacing it.
- Finds the correct profile folder, including OneDrive-redirected Documents.
- Finds the right Windows Terminal settings folder. If Terminal has never been run, it creates the folder.
- Replaces the `H:\projects` starting folder with `~\projects` if the PC has no `H:` drive.
- Is safe to run more than once.

Afterwards, close **all** Terminal windows, reopen Terminal and follow "Check it works" below. Windows may ask for permission during the installs. The font step relies on `oh-my-posh` being found in the same window; if the script warns about that, open a new window and run `oh-my-posh font install FiraCode`.

On your main PC, put `Install-ShellConfig.ps1` in your dotfiles folder (`C:\Users\<you>\dotfiles\powershell`) once. The next `Backup-ShellConfig` run will commit it.

## Manual install (fallback)

Use these steps if the script can't be used. Open **Windows PowerShell** (or any terminal) and work through them in order.

### 1. Install the programs

```powershell
winget install --id Microsoft.PowerShell -e
winget install --id Microsoft.WindowsTerminal -e
winget install --id JanDeDobbeleer.OhMyPosh -e
winget install --id Git.Git -e
winget install --id ajeetdsouza.zoxide -e
winget install --id junegunn.fzf -e
```

Close and reopen your terminal afterwards so the new programs are on the PATH. Optional: JetBrains WebStorm, if you use the `ws` function.

### 2. Install the font

The settings use **FiraCode Nerd Font**. Without a Nerd Font the prompt shows empty boxes instead of icons.

```powershell
oh-my-posh font install FiraCode
```

Alternatively, download "FiraCode Nerd Font" from nerdfonts.com and install it by hand.

### 3. Install the PowerShell modules

Open **PowerShell 7** (`pwsh`), then:

```powershell
Install-Module Terminal-Icons -Scope CurrentUser
Install-Module PSFzf -Scope CurrentUser
```

Accept the prompt about the PowerShell Gallery. PSReadLine is already included with PowerShell 7.

### 4. Copy the profile and theme

In `pwsh`, find where your profile belongs:

```powershell
Split-Path $PROFILE
```

This is normally `C:\Users\<you>\Documents\PowerShell`. If your Documents folder is synced with OneDrive, it may be under `OneDrive\Documents\PowerShell`. **Always use the folder this command prints.** Create it if it doesn't exist, then copy both files into it:

```powershell
$dest = Split-Path $PROFILE
New-Item -ItemType Directory -Force $dest | Out-Null
Copy-Item .\Microsoft.PowerShell_profile.ps1 $dest -Force
Copy-Item .\agnosterplus.omp.json $dest -Force
```

(Run those from the folder containing this README's files.)

### 5. Copy the Windows Terminal settings

Find the live settings file. Pick the one that matches how Terminal was installed:

| Install type | Path |
|---|---|
| Microsoft Store / winget (normal) | `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json` |
| Terminal Preview | `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json` |
| Unpackaged | `%LOCALAPPDATA%\Microsoft\Windows Terminal\settings.json` |

Easiest way to find the right one: open Terminal and press **Ctrl+Shift+,**. That opens the live file in your editor.

Back up the existing file first, then replace it:

```powershell
$wt = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
Copy-Item $wt "$wt.bak" -ErrorAction SilentlyContinue
Copy-Item .\settings.json $wt -Force
```

**Then edit two things on the new PC:**

- `"startingDirectory": "H:\\projects"` (in `profiles.defaults` and on some profiles). If the new PC has no `H:` drive, change it to a folder that exists, for example `"C:\\Users\\<you>\\projects"`.
- `"defaultProfile"` is `{574e775e-4f2a-5b96-ac1e-a2962a402336}`, the standard PowerShell 7 profile, which is the same on every PC. If you'd rather open straight into Light or Dark, change it to one of the guids above.

The settings also contain a `Dracula` colour scheme, used by the Dark profile. The Light profile uses the built-in `One Half Light`.

### 6. Allow profile scripts to run

If PowerShell complains that scripts are disabled:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

### 7. Check it works

Close **all** Windows Terminal windows, reopen Terminal, and open a new tab from the dropdown for each of the Light and Dark profiles. In a Light tab, run:

```powershell
$env:OMP_THEME
(Get-PSReadLineOption).CommandColor -replace "`e", '<ESC>'
```

Expected results:

| Tab | `$env:OMP_THEME` | `CommandColor` |
|---|---|---|
| Light | `light` | `<ESC>[38;2;31;111;178m` |
| Dark | `dark` | `<ESC>[38;2;139;233;253m` |

Visual checks:

- **Light tab:** slate, blue and green prompt segments; dark readable text as you type.
- **Dark tab:** white, pale blue and pale green segments.
- In a git repository, the git segment turns amber when there are uncommitted changes.

## Everyday use

- **Back up your config:** run `Backup-ShellConfig "What you changed"`. The text becomes the git commit message, so your history explains each change. If you leave it out, you're asked for one (Enter uses a dated default). It copies the profile, theme and Terminal settings to `C:\Users\<you>\dotfiles\powershell` and makes a git commit. It pushes to GitHub only if you have set up a remote (see "Optional: push backups to GitHub" below); otherwise it stays local.
- **Change prompt colours:** edit `palettes.list.light` or `palettes.list.dark` in `agnosterplus.omp.json`. Only that one file needs changing.
- **Change typed-command colours:** edit the `$hex` tables in the profile (the `if ($isLight) {...} else {...}` block).
- **Add another look:** add a palette name to `palettes.list`, extend the `template` line in the theme, and add a Terminal profile with its own guid.
- **Open a folder in WebStorm:** `ws` (current folder) or `ws C:\path\to\project`. The function finds the newest install under `C:\Program Files\JetBrains\`. For a Toolbox install, the path in the function needs changing.
- **Reload the profile without restarting:** `. $PROFILE` (the guid-based theme choice still applies).

### Optional: push backups to GitHub

1. Create a **private** repository on GitHub with no README.
2. Run:

```powershell
Backup-ShellConfig
git -C "$HOME\dotfiles\powershell" branch -M main
git -C "$HOME\dotfiles\powershell" remote add origin https://github.com/<you>/dotfiles.git
git -C "$HOME\dotfiles\powershell" push -u origin main
```

3. After this one-time setup, every `Backup-ShellConfig` run pushes automatically. The function already contains the line `if (git -C $dest remote) { git -C $dest push -q -u origin HEAD }`, which only pushes when a remote exists. Until you add the remote in step 2, backups stay local and nothing is pushed.

Keep the repository private, and don't put passwords, API keys or tokens in the profile. `settings.json` contains your folder paths.

On a new PC you can then clone the repository into `$HOME\dotfiles\powershell` (see "Quick install") and copy the files in steps 4 and 5.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| Prompt says `Config Not Found` | Oh My Posh was given a path it can't open. Check the shell's real launch command: `(Get-CimInstance Win32_Process -Filter "ProcessId=$PID").CommandLine` should be just `pwsh.exe -NoLogo`. If it contains `-Command "oh-my-posh init ..."`, the Terminal profile still has the old command line. Edit the live `settings.json` (Ctrl+Shift+,) and restart all Terminal windows. |
| Warning: `Oh My Posh config not found: <path>` at startup | `agnosterplus.omp.json` isn't in the same folder as the profile. Compare `Split-Path $PROFILE` with where you copied the file. |
| `Error: flag needs an argument: --config` | The config path came out empty. This profile builds it from `$PROFILE`, so it shouldn't happen. If you edited the line, don't use `$PSScriptRoot` here: it can be empty inside a profile. |
| Boxes or question marks instead of icons | The Nerd Font isn't installed, or the Terminal profile isn't using "FiraCode Nerd Font". Repeat step 2 and restart Terminal. |
| Shell opens in `C:\Windows\System32` | The profile has no valid `startingDirectory`. Set one in `profiles.defaults` in `settings.json`, and check the folder exists. |
| Parts of typed commands are hard to read | PSReadLine colours aren't being applied. Run the check in step 7. If `CommandColor` shows a default such as `<ESC>[93m`, the colour block didn't run. Check for red errors when a tab opens, and that nothing later in the profile sets other `-Colors`. |
| Light tab shows dark-theme colours | `$lightGuid` doesn't match the Light profile's `guid` in `settings.json`. Check `$env:WT_PROFILE_ID` in the Light tab and compare. |
| Changed a colour scheme and text became hard to read | Prompt and syntax colours are fixed hex values chosen for a light or dark background. Keep the Light profile on a light scheme and the Dark profile on a dark one. |
| No file/folder icons in `ls` | Check `Get-Module Terminal-Icons`. If empty, the module isn't loaded: run `Install-Module Terminal-Icons -Scope CurrentUser` and check the profile has `Import-Module Terminal-Icons`. If you see boxes instead of icons, the Terminal profile isn't using the Nerd Font. |
| `ws` says WebStorm not found | WebStorm isn't under `C:\Program Files\JetBrains\`. Edit the path in the function. |
| `print primary` shows nothing, or `$env:POSH_THEME` is empty | Neither is a reliable test on this Oh My Posh version. Use `oh-my-posh debug --config "<path to agnosterplus.omp.json>" --shell pwsh` instead and check the `Config path:` line. |

### Useful diagnostic commands

```powershell
$PROFILE                       # where pwsh loads the profile from
$env:WT_PROFILE_ID             # guid of the Terminal profile in use
$env:OMP_THEME                 # light or dark
oh-my-posh --version
oh-my-posh debug --config (Join-Path (Split-Path $PROFILE) 'agnosterplus.omp.json') --shell pwsh
```

Print PSReadLine colours without the terminal swallowing the escape codes:

```powershell
(Get-PSReadLineOption).PSObject.Properties |
    Where-Object Name -like '*Color' |
    ForEach-Object { '{0,-26} {1}' -f $_.Name, ($_.Value -replace "`e", '<ESC>') }
```

## Notes

- Tested with PowerShell 7 and Oh My Posh 31.x. Oh My Posh's configuration format changes between major versions, so after a big upgrade, re-check the theme with the `debug` command above.
- The theme includes `"pwd": "osc99"`, which lets Windows Terminal's Duplicate Tab and Duplicate Pane open in the current folder.
- `adjustIndistinguishableColors` can be added to `profiles.defaults` in `settings.json` as a fallback if some text is still hard to read. This only works on newer Terminal versions.
