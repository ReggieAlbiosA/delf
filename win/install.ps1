#Requires -Version 5.1
<#
.SYNOPSIS
    DELF Installer for Windows

.DESCRIPTION
    Installs DELF (Delete Files) command-line tool for Windows.
    Supports user-level and system-wide installation.

.EXAMPLE
    irm https://raw.githubusercontent.com/ReggieAlbiosA/delf/main/win/install.ps1 | iex

.EXAMPLE
    .\install.ps1
#>

$ErrorActionPreference = "Stop"

# GitHub repository details
$GitHubUser = "ReggieAlbiosA"
$GitHubRepo = "delf"
$GitHubBranch = "main"
$ScriptUrl = "https://raw.githubusercontent.com/$GitHubUser/$GitHubRepo/refs/heads/$GitHubBranch/win/delf.ps1"

# Log file location
$LogDir = Join-Path $env:USERPROFILE ".delf"
$LogFile = Join-Path $LogDir "install.log"

# Enable ANSI colors
if ($PSVersionTable.PSVersion.Major -ge 7 -or $env:WT_SESSION) {
    $PSStyle.OutputRendering = 'Ansi'
}

# Color codes
$script:Colors = @{
    Red     = "`e[0;31m"
    Green   = "`e[0;32m"
    Yellow  = "`e[1;33m"
    Blue    = "`e[0;34m"
    Cyan    = "`e[0;36m"
    Bold    = "`e[1m"
    Dim     = "`e[2m"
    NC      = "`e[0m"
}

# Fallback for older PowerShell
if ($PSVersionTable.PSVersion.Major -lt 7 -and -not $env:WT_SESSION) {
    $script:Colors = @{
        Red     = ""
        Green   = ""
        Yellow  = ""
        Blue    = ""
        Cyan    = ""
        Bold    = ""
        Dim     = ""
        NC      = ""
    }
}

# Create log directory
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$timestamp] $Message" | Out-File -FilePath $LogFile -Append -Encoding UTF8
}

function Write-Status {
    param(
        [ValidateSet("ok", "info", "warn", "error", "step")]
        [string]$Status,
        [string]$Message
    )

    $c = $script:Colors

    switch ($Status) {
        "ok" {
            Write-Host "$($c.Green)[$($c.Bold)OK$($c.NC)$($c.Green)]$($c.NC) $Message"
            Write-Log "[OK] $Message"
        }
        "info" {
            Write-Host "$($c.Cyan)[$($c.Bold)*$($c.NC)$($c.Cyan)]$($c.NC) $Message"
            Write-Log "[INFO] $Message"
        }
        "warn" {
            Write-Host "$($c.Yellow)[$($c.Bold)!$($c.NC)$($c.Yellow)]$($c.NC) $Message"
            Write-Log "[WARN] $Message"
        }
        "error" {
            Write-Host "$($c.Red)[$($c.Bold)X$($c.NC)$($c.Red)]$($c.NC) $Message"
            Write-Log "[ERROR] $Message"
        }
        "step" {
            Write-Host "$($c.Blue)$($c.Bold)==>$($c.NC) $Message"
            Write-Log "[STEP] $Message"
        }
    }
}

function Write-Progress-Custom {
    param([string]$Message)
    Write-Host -NoNewline "$Message..."
    Write-Log $Message
}

function Write-ProgressDone {
    $c = $script:Colors
    Write-Host " $($c.Green)Done$($c.NC)"
    Write-Log "Done"
}

function Write-Step {
    param([string]$Message)
    $c = $script:Colors
    Write-Host "$($c.Bold)$($c.Blue)> $Message$($c.NC)"
}

function Test-FdInstalled {
    $null -ne (Get-Command fd -ErrorAction SilentlyContinue)
}

function Get-PackageManager {
    $managers = @()

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $managers += "winget"
    }
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        $managers += "choco"
    }
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        $managers += "scoop"
    }

    return $managers
}

function Install-Fd {
    param([string]$PackageManager)

    Write-Status "step" "Installing fd (fast file finder)..."
    Write-Log "Installing fd using $PackageManager"

    try {
        switch ($PackageManager) {
            "winget" {
                winget install sharkdp.fd --accept-source-agreements --accept-package-agreements 2>$null
                return $true
            }
            "choco" {
                choco install fd -y 2>$null
                return $true
            }
            "scoop" {
                scoop install fd 2>$null
                return $true
            }
        }
    }
    catch {
        Write-Log "Failed to install fd: $_"
        return $false
    }

    return $false
}

function Add-ToProfile {
    param([string]$InstallPath)

    $profilePath = $PROFILE.CurrentUserAllHosts
    $profileDir = Split-Path $profilePath -Parent

    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    if (-not (Test-Path $profilePath)) {
        New-Item -ItemType File -Path $profilePath -Force | Out-Null
    }

    $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue

    if ($profileContent -notmatch "function delf") {
        $delfFunction = @"

# Added by DELF installer
function delf {
    & "$InstallPath" @args
}
"@
        Add-Content -Path $profilePath -Value $delfFunction
        Write-Log "Added delf function to PowerShell profile"
        return $true
    }
    else {
        Write-Log "delf function already exists in profile"
        return $false
    }
}

function Install-User {
    $c = $script:Colors
    $BinDir = Join-Path $env:USERPROFILE ".local\bin"
    $InstallPath = Join-Path $BinDir "delf.ps1"
    $IsUpdate = $false

    Write-Step "User Installation"
    Write-Host ""

    if (Test-Path $InstallPath) {
        $IsUpdate = $true
        Write-Status "info" "Package 'delf' is already installed"
        Write-Status "info" "Preparing to upgrade delf..."
        Write-Log "Action: UPDATE"
    }
    else {
        Write-Status "info" "Preparing to install delf..."
        Write-Log "Action: FRESH INSTALL"
    }

    Write-Log "Installation Location: $BinDir"

    Write-Progress-Custom "Creating directories"
    if (-not (Test-Path $BinDir)) {
        New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
    }
    Write-ProgressDone
    Write-Log "Created/Verified directory: $BinDir"

    Write-Status "step" "Fetching delf from repository..."
    Write-Progress-Custom "  Downloading $ScriptUrl"
    Write-Log "Downloading from: $ScriptUrl"

    try {
        Invoke-WebRequest -Uri $ScriptUrl -OutFile $InstallPath -UseBasicParsing
        Write-ProgressDone
        Write-Log "Download successful"
    }
    catch {
        Write-Host " $($c.Red)Failed$($c.NC)"
        Write-Status "error" "Download failed: $_"
        Write-Log "ERROR: Download failed - $_"
        throw
    }

    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -notlike "*$BinDir*") {
        Write-Progress-Custom "Configuring environment (PATH)"
        [Environment]::SetEnvironmentVariable("Path", "$BinDir;$currentPath", "User")
        Write-ProgressDone
        Write-Log "Added $BinDir to user PATH"
    }
    else {
        Write-Log "$BinDir already in PATH (skipped)"
    }

    Write-Progress-Custom "Configuring PowerShell profile"
    $null = Add-ToProfile -InstallPath $InstallPath
    Write-ProgressDone

    Write-Host ""
    if ($IsUpdate) {
        Write-Status "ok" "delf upgraded successfully"
        Write-Log "User upgrade completed successfully"
    }
    else {
        Write-Status "ok" "delf installed successfully"
        Write-Log "User installation completed successfully"
    }

    Write-Status "info" "Location: $InstallPath"
    Write-Host ""
    Write-Status "warn" "Please restart your PowerShell terminal or run: $($c.Bold). `$PROFILE$($c.NC)"
}

function Install-System {
    $c = $script:Colors
    $BinDir = Join-Path $env:ProgramFiles "delf"
    $InstallPath = Join-Path $BinDir "delf.ps1"
    $IsUpdate = $false

    Write-Step "System-Wide Installation"
    Write-Host ""

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Status "warn" "System-wide installation requires Administrator privileges"
        Write-Status "info" "Run PowerShell as Administrator to install system-wide"
        Write-Log "Skipped system-wide installation (not admin)"
        return
    }

    if (Test-Path $InstallPath) {
        $IsUpdate = $true
        Write-Status "info" "Package 'delf' is already installed (system-wide)"
        Write-Status "info" "Preparing to upgrade delf..."
        Write-Log "Action: UPDATE (SYSTEM-WIDE)"
    }
    else {
        Write-Status "info" "Preparing to install delf (system-wide)..."
        Write-Log "Action: FRESH INSTALL (SYSTEM-WIDE)"
    }

    Write-Log "Installation Location: $BinDir"

    Write-Progress-Custom "Creating directories"
    if (-not (Test-Path $BinDir)) {
        New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
    }
    Write-ProgressDone
    Write-Log "Created/Verified directory: $BinDir"

    Write-Status "step" "Fetching delf from repository..."
    Write-Progress-Custom "  Downloading $ScriptUrl"
    Write-Log "Downloading from: $ScriptUrl"

    try {
        Invoke-WebRequest -Uri $ScriptUrl -OutFile $InstallPath -UseBasicParsing
        Write-ProgressDone
        Write-Log "Download successful"
    }
    catch {
        Write-Host " $($c.Red)Failed$($c.NC)"
        Write-Status "error" "Download failed: $_"
        Write-Log "ERROR: Download failed - $_"
        throw
    }

    $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($currentPath -notlike "*$BinDir*") {
        Write-Progress-Custom "Configuring environment (PATH)"
        [Environment]::SetEnvironmentVariable("Path", "$BinDir;$currentPath", "Machine")
        Write-ProgressDone
        Write-Log "Added $BinDir to system PATH"
    }
    else {
        Write-Log "$BinDir already in system PATH (skipped)"
    }

    Write-Host ""
    if ($IsUpdate) {
        Write-Status "ok" "delf upgraded successfully (system-wide)"
        Write-Log "System-wide upgrade completed successfully"
    }
    else {
        Write-Status "ok" "delf installed successfully (system-wide)"
        Write-Log "System-wide installation completed successfully"
    }

    Write-Status "info" "Location: $InstallPath"
    Write-Status "info" "Available to all users"
}

# Main installation
Write-Log "========================================="
Write-Log "DELF Installation Started"
Write-Log "========================================="

$c = $script:Colors

Write-Host "$($c.Bold)$($c.Cyan)╔════════════════════════════════════════╗$($c.NC)"
Write-Host "$($c.Bold)$($c.Cyan)║$($c.NC)   $($c.Bold)DELF Installer$($c.NC)                     $($c.Bold)$($c.Cyan)║$($c.NC)"
Write-Host "$($c.Bold)$($c.Cyan)║$($c.NC)   $($c.Dim)Delete Files Tool$($c.NC)                   $($c.Bold)$($c.Cyan)║$($c.NC)"
Write-Host "$($c.Bold)$($c.Cyan)╚════════════════════════════════════════╝$($c.NC)"
Write-Host ""

Write-Step "Installing to User & System Locations"
Write-Host ""
Write-Log "Installing to both user and system directories"

Install-User
Write-Host ""

Install-System

# Check for fd
Write-Host ""
Write-Step "Checking Optional Dependencies"
Write-Host ""

if (Test-FdInstalled) {
    Write-Status "ok" "fd is installed (fast parallel search enabled)"
    Write-Log "fd: already installed"
}
else {
    Write-Status "warn" "fd not found (delf will use slower Get-ChildItem)"
    Write-Log "fd: not installed"

    $packageManagers = Get-PackageManager

    if ($packageManagers.Count -gt 0) {
        Write-Host ""
        Write-Host "  $($c.Cyan)fd$($c.NC) enables $($c.Bold)5-10x faster$($c.NC) parallel file searching."
        Write-Host "  Available package managers: $($c.Green)$($packageManagers -join ', ')$($c.NC)"
        Write-Host ""

        $installChoice = Read-Host "  Install fd now? [Y/n]"

        if ($installChoice -match "^[Yy]?$") {
            $selectedManager = $packageManagers[0]

            if ($packageManagers.Count -gt 1) {
                Write-Host ""
                Write-Host "  Select package manager:"
                for ($i = 0; $i -lt $packageManagers.Count; $i++) {
                    Write-Host "    [$($i + 1)] $($packageManagers[$i])"
                }
                $managerChoice = Read-Host "  Choice (default: 1)"

                if ([string]::IsNullOrEmpty($managerChoice)) {
                    $managerChoice = "1"
                }

                $idx = [int]$managerChoice - 1
                if ($idx -ge 0 -and $idx -lt $packageManagers.Count) {
                    $selectedManager = $packageManagers[$idx]
                }
            }

            if (Install-Fd -PackageManager $selectedManager) {
                if (Test-FdInstalled) {
                    Write-Status "ok" "fd installed successfully"
                    Write-Log "fd: installed successfully"
                }
                else {
                    Write-Status "warn" "fd installation may require restart"
                    Write-Log "fd: installation completed, may need restart"
                }
            }
            else {
                Write-Status "warn" "Could not install fd automatically"
                Write-Status "info" "Install manually: $($c.Cyan)winget install sharkdp.fd$($c.NC)"
                Write-Log "fd: auto-install failed"
            }
        }
        else {
            Write-Status "info" "Skipped fd installation"
            Write-Status "info" "Install later: $($c.Cyan)winget install sharkdp.fd$($c.NC)"
            Write-Log "fd: user skipped installation"
        }
    }
    else {
        Write-Status "info" "No package manager found (winget, choco, scoop)"
        Write-Status "info" "Install fd manually from: $($c.Cyan)https://github.com/sharkdp/fd$($c.NC)"
        Write-Log "fd: no package manager available"
    }
}

# Summary
Write-Host ""
Write-Host "$($c.Bold)$($c.Cyan)╔════════════════════════════════════════╗$($c.NC)"
Write-Host "$($c.Bold)$($c.Cyan)║$($c.NC)   $($c.Green)$($c.Bold)Installation Complete!$($c.NC)             $($c.Bold)$($c.Cyan)║$($c.NC)"
Write-Host "$($c.Bold)$($c.Cyan)╚════════════════════════════════════════╝$($c.NC)"
Write-Host ""
Write-Status "info" "Usage: $($c.Bold)$($c.Green)delf$($c.NC) (run as user)"
Write-Status "info" "Usage: $($c.Bold)$($c.Green)delf `"*.log`"$($c.NC) (direct search)"
Write-Host ""

Write-Host "$($c.Bold)Features:$($c.NC)"
if (Test-FdInstalled) {
    Write-Host "  $($c.Green)OK$($c.NC) Fast parallel search (fd)"
}
else {
    Write-Host "  $($c.Yellow)--$($c.NC) Fast parallel search (install fd for boost)"
}
Write-Host "  $($c.Green)OK$($c.NC) Safety protection for system files"
Write-Host "  $($c.Green)OK$($c.NC) Dry-run mode for preview"
Write-Host "  $($c.Green)OK$($c.NC) Pattern matching and exclusions"
Write-Host ""

Write-Status "info" "Installation log: $($c.Cyan)$LogFile$($c.NC)"
Write-Host ""

Write-Log "========================================="
Write-Log "DELF Installation Finished Successfully"
Write-Log "========================================="
