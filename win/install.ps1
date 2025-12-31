#Requires -Version 5.1
<#
.SYNOPSIS
    DELF Installer for Windows

.DESCRIPTION
    Installs DELF (Delete Files/Folders) command-line tool for Windows.
    Downloads pre-built Go binary from GitHub Releases.
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
$ExeUrl = "https://github.com/$GitHubUser/$GitHubRepo/releases/latest/download/delf.exe"

# Log file location
$LogDir = Join-Path $env:USERPROFILE ".delf"
$LogFile = Join-Path $LogDir "install.log"

# Track if fd was installed during this session (for PATH refresh)
$script:FdWasInstalled = $false

# Enable ANSI colors (PSStyle only exists in PowerShell 7.2+)
if ($PSVersionTable.PSVersion.Major -ge 7 -and $null -ne (Get-Variable -Name PSStyle -ErrorAction SilentlyContinue)) {
    $PSStyle.OutputRendering = 'Ansi'
}

# ESC character for ANSI codes (works in PS 5.1+)
$ESC = [char]27

# Color codes - using $ESC for PS 5.1 compatibility
$script:Colors = @{
    Red     = "$ESC[0;31m"
    Green   = "$ESC[0;32m"
    Yellow  = "$ESC[1;33m"
    Blue    = "$ESC[0;34m"
    Cyan    = "$ESC[0;36m"
    Bold    = "$ESC[1m"
    Dim     = "$ESC[2m"
    NC      = "$ESC[0m"
}

# Fallback for older PowerShell without ANSI support (legacy console)
if ($PSVersionTable.PSVersion.Major -lt 7 -and -not $env:WT_SESSION -and -not $env:ConEmuANSI) {
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
    try {
        $null = fd --version 2>&1
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

function Get-InstalledVersion {
    param([string]$ExePath)

    if (-not (Test-Path $ExePath)) {
        return $null
    }

    try {
        $output = & $ExePath -h 2>&1 | Select-Object -First 1
        # Parse "delf - Delete Folder/File Command v2.0.0" -> "2.0.0"
        if ($output -match 'v(\d+\.\d+\.\d+)') {
            return $matches[1]
        }
    }
    catch {
        return $null
    }
    return $null
}

function Get-LatestVersion {
    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$GitHubUser/$GitHubRepo/releases/latest" -UseBasicParsing
        # Tag is like "v2.0.0" -> "2.0.0"
        return $release.tag_name -replace '^v', ''
    }
    catch {
        return $null
    }
}

function Install-Fd {
    Write-Status "step" "Installing fd (fast file finder)..."
    Write-Log "Installing fd using winget"

    try {
        winget install sharkdp.fd --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Log "winget install completed successfully"
            return $true
        }
        else {
            Write-Log "winget install failed with exit code: $LASTEXITCODE"
            return $false
        }
    }
    catch {
        Write-Log "Failed to install fd: $_"
        return $false
    }
}

function Remove-LegacyInstallation {
    param([string]$BinDir)

    # Check for legacy .ps1 script
    $LegacyPath = Join-Path $BinDir "delf.ps1"
    if (Test-Path $LegacyPath) {
        Write-Status "info" "Removing legacy delf.ps1 script..."
        Remove-Item $LegacyPath -Force -ErrorAction SilentlyContinue
        Write-Log "Removed legacy script: $LegacyPath"
        return $true
    }
    return $false
}

function Update-Profile {
    param([string]$InstallPath)

    # Get PowerShell profile path
    $profilePath = $PROFILE.CurrentUserAllHosts
    $profileDir = Split-Path $profilePath -Parent

    # Create profile directory if it doesn't exist
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    # Create profile if it doesn't exist
    if (-not (Test-Path $profilePath)) {
        New-Item -ItemType File -Path $profilePath -Force | Out-Null
    }

    $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
    if ($null -eq $profileContent) { $profileContent = "" }

    # Check if OLD delf function exists (points to .ps1) - needs upgrade
    if ($profileContent -match "function delf" -and $profileContent -match "delf\.ps1") {
        Write-Status "info" "Found legacy delf function in profile, upgrading..."
        Write-Log "Removing legacy delf function (was pointing to .ps1)"

        # Remove old function block using regex
        $profileContent = $profileContent -replace "(?m)# Added by DELF installer[^\n]*\nfunction delf \{[^}]+\}\s*", ""
        Set-Content -Path $profilePath -Value $profileContent.Trim() -Encoding UTF8

        # Re-read the cleaned content
        $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
        if ($null -eq $profileContent) { $profileContent = "" }
    }

    # Check if NEW delf function already exists (points to .exe)
    if ($profileContent -match "function delf" -and $profileContent -match "delf\.exe") {
        Write-Log "delf function already exists in profile (v2.0+)"
        return $false
    }

    # Check if any delf function exists but doesn't match our patterns
    if ($profileContent -match "function delf") {
        Write-Status "warn" "Custom delf function found in profile, skipping..."
        Write-Log "Custom delf function exists, not modifying"
        return $false
    }

    # Add new function (simple - no navigation needed for delete tool)
    $delfFunction = @"

# Added by DELF installer (v2.0+)
function delf {
    & "$InstallPath" @args
}
"@
    Add-Content -Path $profilePath -Value $delfFunction
    Write-Log "Added delf function to PowerShell profile"
    return $true
}

function Install-User {
    $c = $script:Colors
    $BinDir = Join-Path $env:USERPROFILE ".local\bin"
    $InstallPath = Join-Path $BinDir "delf.exe"
    $IsUpdate = $false

    Write-Step "User Installation"
    Write-Host ""

    # Remove legacy installation if exists
    $hadLegacy = Remove-LegacyInstallation -BinDir $BinDir

    # Check if already installed
    if (Test-Path $InstallPath) {
        $IsUpdate = $true
        Write-Status "info" "Package 'delf' is already installed"
        Write-Status "info" "Preparing to upgrade delf..."
        Write-Log "Action: UPDATE"
    }
    elseif ($hadLegacy) {
        Write-Log "Action: UPGRADE FROM PS1 TO EXE"
    }
    else {
        Write-Status "info" "Preparing to install delf..."
        Write-Log "Action: FRESH INSTALL"
    }

    Write-Log "Installation Location: $BinDir"

    # Create directory
    Write-Progress-Custom "Creating directories"
    if (-not (Test-Path $BinDir)) {
        New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
    }
    Write-ProgressDone
    Write-Log "Created/Verified directory: $BinDir"

    # Version check - skip download if already up to date
    $installedVersion = Get-InstalledVersion -ExePath $InstallPath
    $latestVersion = Get-LatestVersion
    $skipDownload = $false

    if ($installedVersion -and $latestVersion) {
        if ($installedVersion -eq $latestVersion) {
            Write-Status "ok" "delf is already up to date (v$installedVersion)"
            Write-Log "Skipped download - already at latest version $installedVersion"
            $skipDownload = $true
        }
        else {
            Write-Status "info" "Upgrading from v$installedVersion to v$latestVersion"
            Write-Log "Upgrading from $installedVersion to $latestVersion"
        }
    }

    if (-not $skipDownload) {
        # Download
        Write-Status "step" "Fetching delf from GitHub Releases..."
        Write-Progress-Custom "  Downloading delf.exe"
        Write-Log "Downloading from: $ExeUrl"

        try {
            Invoke-WebRequest -Uri $ExeUrl -OutFile $InstallPath -UseBasicParsing
            Write-ProgressDone
            Write-Log "Download successful"
        }
        catch {
            Write-Host " $($c.Red)Failed$($c.NC)"
            Write-Status "error" "Download failed: $_"
            Write-Status "info" "Make sure a release exists at: $ExeUrl"
            Write-Log "ERROR: Download failed - $_"
            throw
        }
    }

    # Add to PATH via environment variable
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

    # Add shell function to profile
    Write-Progress-Custom "Configuring PowerShell profile"
    $profileUpdated = Update-Profile -InstallPath $InstallPath
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
    $InstallPath = Join-Path $BinDir "delf.exe"
    $IsUpdate = $false

    Write-Step "System-Wide Installation"
    Write-Host ""

    # Check for admin privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Status "warn" "System-wide installation requires Administrator privileges"
        Write-Status "info" "Run PowerShell as Administrator to install system-wide"
        Write-Log "Skipped system-wide installation (not admin)"
        return
    }

    # Remove legacy installation if exists
    $hadLegacy = Remove-LegacyInstallation -BinDir $BinDir

    # Check if already installed
    if (Test-Path $InstallPath) {
        $IsUpdate = $true
        Write-Status "info" "Package 'delf' is already installed (system-wide)"
        Write-Status "info" "Preparing to upgrade delf..."
        Write-Log "Action: UPDATE (SYSTEM-WIDE)"
    }
    elseif ($hadLegacy) {
        Write-Log "Action: UPGRADE FROM PS1 TO EXE (SYSTEM-WIDE)"
    }
    else {
        Write-Status "info" "Preparing to install delf (system-wide)..."
        Write-Log "Action: FRESH INSTALL (SYSTEM-WIDE)"
    }

    Write-Log "Installation Location: $BinDir"

    # Create directory
    Write-Progress-Custom "Creating directories"
    if (-not (Test-Path $BinDir)) {
        New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
    }
    Write-ProgressDone
    Write-Log "Created/Verified directory: $BinDir"

    # Version check - skip download if already up to date
    $installedVersion = Get-InstalledVersion -ExePath $InstallPath
    $latestVersion = Get-LatestVersion
    $skipDownload = $false

    if ($installedVersion -and $latestVersion) {
        if ($installedVersion -eq $latestVersion) {
            Write-Status "ok" "delf is already up to date (v$installedVersion)"
            Write-Log "Skipped download - already at latest version $installedVersion"
            $skipDownload = $true
        }
        else {
            Write-Status "info" "Upgrading from v$installedVersion to v$latestVersion"
            Write-Log "Upgrading from $installedVersion to $latestVersion"
        }
    }

    if (-not $skipDownload) {
        # Download
        Write-Status "step" "Fetching delf from GitHub Releases..."
        Write-Progress-Custom "  Downloading delf.exe"
        Write-Log "Downloading from: $ExeUrl"

        try {
            Invoke-WebRequest -Uri $ExeUrl -OutFile $InstallPath -UseBasicParsing
            Write-ProgressDone
            Write-Log "Download successful"
        }
        catch {
            Write-Host " $($c.Red)Failed$($c.NC)"
            Write-Status "error" "Download failed: $_"
            Write-Status "info" "Make sure a release exists at: $ExeUrl"
            Write-Log "ERROR: Download failed - $_"
            throw
        }
    }

    # Add to system PATH
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

Write-Host "$($c.Bold)$($c.Cyan)========================================$($c.NC)"
Write-Host "$($c.Bold)   DELF Installer$($c.NC)"
Write-Host "$($c.Dim)   Delete Folder/File Command$($c.NC)"
Write-Host "$($c.Bold)$($c.Cyan)========================================$($c.NC)"
Write-Host ""

Write-Step "Installing to User & System Locations"
Write-Host ""
Write-Log "Installing to both user and system directories"

# Install to user directory
Install-User
Write-Host ""

# Install to system directory (if admin)
Install-System

# Check for fd (optional fast search dependency)
Write-Host ""
Write-Step "Checking Optional Dependencies"
Write-Host ""

if (Test-FdInstalled) {
    Write-Status "ok" "fd is installed (fast parallel search enabled)"
    Write-Log "fd: already installed"
}
else {
    Write-Status "warn" "fd not found (delf will use slower filepath.WalkDir)"
    Write-Log "fd: not installed"

    # Check if winget is available
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host ""
        Write-Host "  $($c.Cyan)fd$($c.NC) enables $($c.Bold)5-10x faster$($c.NC) parallel file searching."
        Write-Host ""

        $installChoice = Read-Host "  Install fd now using winget? [Y/n]"

        if ($installChoice -match "^[Yy]?$") {
            if (Install-Fd) {
                $script:FdWasInstalled = $true
                Write-Status "ok" "fd installation completed"
                Write-Log "fd: installation completed"
            }
            else {
                Write-Status "error" "fd installation failed"
                Write-Status "info" "Install manually: $($c.Cyan)winget install sharkdp.fd$($c.NC)"
                Write-Log "fd: installation failed"
            }
        }
        else {
            Write-Status "info" "Skipped fd installation"
            Write-Status "info" "Install later: $($c.Cyan)winget install sharkdp.fd$($c.NC)"
            Write-Log "fd: user skipped installation"
        }
    }
    else {
        Write-Status "info" "winget not found"
        Write-Status "info" "Install fd manually from: $($c.Cyan)https://github.com/sharkdp/fd$($c.NC)"
        Write-Log "fd: winget not available"
    }
}

# Summary
Write-Host ""
Write-Host "$($c.Bold)$($c.Cyan)========================================$($c.NC)"
Write-Host "$($c.Green)$($c.Bold)   Installation Complete!$($c.NC)"
Write-Host "$($c.Bold)$($c.Cyan)========================================$($c.NC)"
Write-Host ""
Write-Status "info" "Usage: $($c.Bold)$($c.Green)delf$($c.NC) (interactive mode)"
Write-Status "info" "Usage: $($c.Bold)$($c.Green)delf `"*.log`"$($c.NC) (delete .log files)"
Write-Status "info" "Usage: $($c.Bold)$($c.Green)delf -n `"*.tmp`"$($c.NC) (dry-run preview)"
Write-Host ""

# Show feature status
Write-Host "$($c.Bold)Features:$($c.NC)"
if (Test-FdInstalled) {
    Write-Host "  $($c.Green)OK$($c.NC) Fast parallel search (fd)"
}
elseif ($script:FdWasInstalled) {
    Write-Host "  $($c.Green)OK$($c.NC) Fast parallel search (fd) - installed, activating..."
}
else {
    Write-Host "  $($c.Yellow)!$($c.NC)  Fast parallel search (install fd for boost)"
}
Write-Host "  $($c.Green)OK$($c.NC) Critical system path protection"
Write-Host "  $($c.Green)OK$($c.NC) Dry-run preview mode"
Write-Host "  $($c.Green)OK$($c.NC) Age and size filtering"
Write-Host "  $($c.Green)OK$($c.NC) Interactive confirmations"
Write-Host "  $($c.Green)OK$($c.NC) Native Go binary (no runtime needed)"
Write-Host ""

Write-Status "info" "Installation log: $($c.Cyan)$LogFile$($c.NC)"
Write-Host ""

Write-Log "========================================="
Write-Log "DELF Installation Finished Successfully"
Write-Log "========================================="

# Refresh PATH if fd was installed (so it's immediately available without restart)
if ($script:FdWasInstalled) {
    Write-Host ""
    Write-Status "info" "Refreshing PATH to enable fd..."
    Write-Log "Refreshing PATH environment variable"

    # Reload PATH from registry (picks up winget's changes)
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

    # Verify fd is now available
    if (Test-FdInstalled) {
        Write-Status "ok" "fd is now available!"
        fd --version
        Write-Log "fd verified working after PATH refresh"
    }
    else {
        Write-Status "warn" "fd not detected - you may need to restart PowerShell manually"
        Write-Log "fd not found after PATH refresh"
    }
}
