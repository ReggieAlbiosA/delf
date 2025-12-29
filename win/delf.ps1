#Requires -Version 5.1
<#
.SYNOPSIS
    DELF - Delete Files/Folders Command for Windows
    Advanced file/folder deletion tool with pattern matching and safety guards

.DESCRIPTION
    Interactive tool to find and delete files/folders with pattern matching,
    exclusions, and safety features. Recursively searches from current directory
    or specified path.

.PARAMETER Pattern
    The file/folder pattern to search for (supports wildcards)

.PARAMETER Path
    The directory to search in (defaults to current directory)

.PARAMETER DryRun
    Preview only, don't delete anything

.PARAMETER Force
    Skip all confirmations (use with caution!)

.PARAMETER IgnoreCase
    Perform case-insensitive search

.PARAMETER Type
    Filter by type: 'f' for files, 'd' for directories

.PARAMETER All
    Disable auto-exclusion of common directories

.PARAMETER ShowSize
    Display total size of matched files

.PARAMETER OlderThan
    Only match files older than N days

.PARAMETER LargerThan
    Only match files larger than SIZE (K, M, G)

.PARAMETER EmptyDirs
    Find and delete empty directories only

.PARAMETER MaxDisplay
    Maximum number of results to display (default: 100)

.PARAMETER Help
    Show help message

.EXAMPLE
    .\delf.ps1 "*.log"
    Delete all .log files in current directory

.EXAMPLE
    .\delf.ps1 -DryRun "*.tmp"
    Preview what would be deleted

.EXAMPLE
    .\delf.ps1 -OlderThan 30 -LargerThan 100M "*.mp4"
    Delete large video files older than 30 days
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Pattern,

    [Parameter(Position = 1)]
    [string]$Path = ".",

    [Alias("n")]
    [switch]$DryRun,

    [Alias("f")]
    [switch]$Force,

    [Alias("i")]
    [switch]$IgnoreCase,

    [Alias("t")]
    [ValidateSet("f", "d")]
    [string]$Type,

    [Alias("a")]
    [switch]$All,

    [switch]$ShowSize,

    [int]$OlderThan,

    [string]$LargerThan,

    [switch]$EmptyDirs,

    [int]$MaxDisplay = 100,

    [Alias("h")]
    [switch]$Help
)

$Version = "1.0.0"

# Enable ANSI colors
if ($PSVersionTable.PSVersion.Major -ge 7 -or $env:WT_SESSION) {
    $PSStyle.OutputRendering = 'Ansi'
}

# Color codes (ANSI)
$script:Colors = @{
    Red     = "`e[0;31m"
    Green   = "`e[0;32m"
    Yellow  = "`e[1;33m"
    Blue    = "`e[0;34m"
    Cyan    = "`e[0;36m"
    Magenta = "`e[0;35m"
    Bold    = "`e[1m"
    Blink   = "`e[5m"
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
        Magenta = ""
        Bold    = ""
        Blink   = ""
        NC      = ""
    }
}

# Critical system paths (Windows)
$script:CriticalSystemPaths = @(
    "C:\Windows"
    "C:\Windows\System32"
    "C:\Windows\SysWOW64"
    "C:\Program Files"
    "C:\Program Files (x86)"
    "C:\ProgramData"
    "C:\Users\Default"
    "C:\Users\Public"
    "C:\Recovery"
    "C:\Boot"
    "$env:SystemRoot"
    "$env:windir"
)

# Warning-level system paths
$script:WarningSystemPaths = @(
    "C:\Users"
    "C:\Temp"
    "$env:TEMP"
    "$env:TMP"
)

# Auto-exclude patterns
$script:AutoExcludePatterns = @(
    "*\node_modules\*"
    "*\.git\*"
    "*\.npm\*"
    "*\.cache\*"
    "*\.vscode\*"
    "*\.idea\*"
)

function Show-Help {
    $c = $script:Colors
    Write-Host "$($c.Bold)delf - Delete Folder/File Command$($c.NC) v$Version"
    Write-Host ""
    Write-Host "$($c.Bold)USAGE:$($c.NC)"
    Write-Host "    delf [OPTIONS] [PATTERN] [PATH]"
    Write-Host ""
    Write-Host "$($c.Bold)DESCRIPTION:$($c.NC)"
    Write-Host "    Interactive tool to find and delete files/folders with pattern matching,"
    Write-Host "    exclusions, and safety features."
    Write-Host ""
    Write-Host "$($c.Bold)OPTIONS:$($c.NC)"
    Write-Host "    $($c.Cyan)-Help, -h$($c.NC)               Show this help message"
    Write-Host "    $($c.Cyan)-DryRun, -n$($c.NC)             Preview only, don't delete anything"
    Write-Host "    $($c.Cyan)-Force, -f$($c.NC)              Skip all confirmations (dangerous!)"
    Write-Host "    $($c.Cyan)-IgnoreCase, -i$($c.NC)         Case-insensitive pattern matching"
    Write-Host "    $($c.Cyan)-Type TYPE, -t TYPE$($c.NC)     Filter by type: $($c.Yellow)f$($c.NC)(file) or $($c.Yellow)d$($c.NC)(directory)"
    Write-Host "    $($c.Cyan)-All, -a$($c.NC)                Disable auto-exclusion of common directories"
    Write-Host "    $($c.Cyan)-ShowSize$($c.NC)               Display total size of matched files"
    Write-Host "    $($c.Cyan)-OlderThan DAYS$($c.NC)         Only match files older than N days"
    Write-Host "    $($c.Cyan)-LargerThan SIZE$($c.NC)        Only match files larger than SIZE (K,M,G)"
    Write-Host "    $($c.Cyan)-EmptyDirs$($c.NC)              Find and delete empty directories only"
    Write-Host "    $($c.Cyan)-MaxDisplay NUM$($c.NC)         Maximum results to display (default: 100)"
    Write-Host ""
    Write-Host "$($c.Bold)EXAMPLES:$($c.NC)"
    Write-Host "    $($c.Green)# Delete all .log files$($c.NC)"
    Write-Host "    delf `"*.log`""
    Write-Host ""
    Write-Host "    $($c.Green)# Preview what would be deleted (dry-run)$($c.NC)"
    Write-Host "    delf -DryRun `"*.tmp`""
    Write-Host ""
    Write-Host "    $($c.Green)# Delete large video files older than 30 days$($c.NC)"
    Write-Host "    delf -OlderThan 30 -LargerThan 100M `"*.mp4`""
    Write-Host ""
    Write-Host "    $($c.Green)# Delete only directories named 'dist'$($c.NC)"
    Write-Host "    delf -Type d dist"
    Write-Host ""
    Write-Host "    $($c.Green)# Delete empty directories$($c.NC)"
    Write-Host "    delf -EmptyDirs"
    Write-Host ""
    Write-Host "$($c.Bold)AUTO-EXCLUDED DIRECTORIES:$($c.NC)"
    Write-Host "    By default, these patterns are protected (use -All to disable):"
    Write-Host "    - *\node_modules\*"
    Write-Host "    - *\.git\*"
    Write-Host "    - *\.npm\*"
    Write-Host "    - *\.cache\*"
    Write-Host "    - *\.vscode\*"
    Write-Host "    - *\.idea\*"
    Write-Host ""
    Write-Host "$($c.Bold)SAFETY FEATURES:$($c.NC)"
    Write-Host "    - Critical system path protection (C:\Windows, Program Files, etc.)"
    Write-Host "    - Auto-exclusion of important directories"
    Write-Host "    - Preview before deletion"
    Write-Host "    - Dry-run mode for testing"
    Write-Host ""
    Write-Host "$($c.Bold)PERFORMANCE:$($c.NC)"
    Write-Host "    - Uses 'fd' for fast parallel searching (if installed)"
    Write-Host "    - Falls back to Get-ChildItem if fd is not available"
    Write-Host "    - Install fd: $($c.Cyan)winget install sharkdp.fd$($c.NC)"
    Write-Host ""
}

function Test-FdInstalled {
    $null -ne (Get-Command fd -ErrorAction SilentlyContinue)
}

function Test-CriticalSystemPath {
    param([string]$FilePath)

    $normalizedPath = $FilePath.ToLower()
    foreach ($critPath in $script:CriticalSystemPaths) {
        $normalizedCrit = $critPath.ToLower()
        if ($normalizedPath -like "$normalizedCrit*") {
            return $true
        }
    }
    return $false
}

function Test-WarningSystemPath {
    param([string]$FilePath)

    $normalizedPath = $FilePath.ToLower()
    foreach ($warnPath in $script:WarningSystemPaths) {
        $normalizedWarn = $warnPath.ToLower()
        if ($normalizedPath -like "$normalizedWarn*") {
            return $true
        }
    }
    return $false
}

function Test-AutoExcluded {
    param([string]$FilePath)

    foreach ($pattern in $script:AutoExcludePatterns) {
        if ($FilePath -like $pattern) {
            return $true
        }
    }
    return $false
}

function ConvertFrom-SizeString {
    param([string]$SizeStr)

    if ($SizeStr -match '^(\d+)([KMG])$') {
        $number = [long]$Matches[1]
        $unit = $Matches[2]

        switch ($unit) {
            "K" { return $number * 1KB }
            "M" { return $number * 1MB }
            "G" { return $number * 1GB }
        }
    }
    return [long]$SizeStr
}

function Format-FileSize {
    param([long]$Bytes)

    if ($Bytes -ge 1GB) {
        return "{0:N2}G" -f ($Bytes / 1GB)
    }
    elseif ($Bytes -ge 1MB) {
        return "{0:N2}M" -f ($Bytes / 1MB)
    }
    elseif ($Bytes -ge 1KB) {
        return "{0:N2}K" -f ($Bytes / 1KB)
    }
    else {
        return "${Bytes}B"
    }
}

function Get-TotalSize {
    param([array]$Files)

    $total = 0
    foreach ($file in $Files) {
        if (Test-Path $file -PathType Leaf) {
            $total += (Get-Item $file).Length
        }
        elseif (Test-Path $file -PathType Container) {
            $total += (Get-ChildItem $file -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        }
    }
    return $total
}

function Invoke-FdSearch {
    param(
        [string]$SearchPattern,
        [string]$SearchPath
    )

    $fdArgs = @("--color", "never", "--hidden", "--no-ignore")

    # Type filter
    if ($Type -eq "f") {
        $fdArgs += @("-t", "f")
    }
    elseif ($Type -eq "d") {
        $fdArgs += @("-t", "d")
    }

    # Case sensitivity
    if ($IgnoreCase) {
        $fdArgs += "-i"
    }
    else {
        $fdArgs += "-s"
    }

    # Age filter
    if ($OlderThan -gt 0) {
        $fdArgs += @("--changed-before", "${OlderThan}days")
    }

    # Size filter
    if ($LargerThan) {
        $fdArgs += @("-S", "+$LargerThan")
    }

    # Auto-exclude patterns
    if (-not $All) {
        foreach ($exclude in $script:AutoExcludePatterns) {
            $fdArgs += @("-E", $exclude)
        }
    }

    # Pattern
    if ($SearchPattern) {
        $fdArgs += @("-g", $SearchPattern)
    }

    # Path
    $fdArgs += $SearchPath

    & fd @fdArgs 2>$null
}

function Invoke-GetChildItemSearch {
    param(
        [string]$SearchPattern,
        [string]$SearchPath
    )

    $params = @{
        Path        = $SearchPath
        Recurse     = $true
        Force       = $true
        ErrorAction = 'SilentlyContinue'
    }

    # Type filter
    if ($Type -eq "f") {
        $params['File'] = $true
    }
    elseif ($Type -eq "d") {
        $params['Directory'] = $true
    }

    # Empty dirs
    if ($EmptyDirs) {
        Get-ChildItem @params -Directory | Where-Object {
            (Get-ChildItem $_.FullName -Force -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0
        } | ForEach-Object { $_.FullName }
        return
    }

    # Get items and filter
    $results = Get-ChildItem @params | Where-Object {
        $matchesPattern = if ($SearchPattern) {
            if ($IgnoreCase) {
                $_.Name -like $SearchPattern
            }
            else {
                $_.Name -clike $SearchPattern
            }
        }
        else {
            $true
        }

        # Auto-exclude check
        $notExcluded = if (-not $All) {
            -not (Test-AutoExcluded $_.FullName)
        }
        else {
            $true
        }

        # Age filter
        $ageOk = if ($OlderThan -gt 0) {
            $_.LastWriteTime -lt (Get-Date).AddDays(-$OlderThan)
        }
        else {
            $true
        }

        # Size filter
        $sizeOk = if ($LargerThan -and -not $_.PSIsContainer) {
            $minSize = ConvertFrom-SizeString $LargerThan
            $_.Length -gt $minSize
        }
        else {
            $true
        }

        $matchesPattern -and $notExcluded -and $ageOk -and $sizeOk
    }

    $results | ForEach-Object { $_.FullName }
}

function Show-CriticalWarning {
    param([int]$CriticalCount)

    $c = $script:Colors
    Write-Host ""
    Write-Host "$($c.Red)$($c.Bold)$($c.Blink)!!! CRITICAL DANGER WARNING !!!$($c.NC)"
    Write-Host "$($c.Red)$($c.Bold)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$($c.NC)"
    Write-Host "$($c.Red)$($c.Bold)You are about to delete $CriticalCount SYSTEM FILES!$($c.NC)"
    Write-Host ""
    Write-Host "$($c.Yellow)$($c.Bold)CONSEQUENCES:$($c.NC)"
    Write-Host "$($c.Red)  - May break Windows boot$($c.NC)"
    Write-Host "$($c.Red)  - May break critical services$($c.NC)"
    Write-Host "$($c.Red)  - May make the system unrecoverable$($c.NC)"
    Write-Host "$($c.Red)  - May require Windows reinstallation$($c.NC)"
    Write-Host ""
}

# Main execution
if ($Help) {
    Show-Help
    exit 0
}

$c = $script:Colors

# Interactive mode if no pattern provided
if ([string]::IsNullOrEmpty($Pattern) -and -not $EmptyDirs) {
    Write-Host "$($c.Bold)$($c.Cyan)delf - Delete Folder/File$($c.NC)"
    Write-Host "$($c.Bold)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$($c.NC)"
    Write-Host ""

    # Ask for search path
    $userPath = Read-Host "Enter path to search (default: current directory)"
    if (-not [string]::IsNullOrEmpty($userPath)) {
        $userPath = $userPath -replace "^~", $env:USERPROFILE
        $userPath = [Environment]::ExpandEnvironmentVariables($userPath)

        if (-not (Test-Path $userPath -PathType Container)) {
            Write-Host "$($c.Red)ERROR:$($c.NC) Directory '$userPath' does not exist"
            exit 1
        }
        $Path = $userPath
    }

    Write-Host "$($c.Blue)Searching in:$($c.NC) $($c.Cyan)$Path$($c.NC)"
    Write-Host ""

    # Ask for pattern
    $Pattern = Read-Host "Enter file/folder name or pattern to delete"
    if ([string]::IsNullOrEmpty($Pattern)) {
        Write-Host "$($c.Red)ERROR:$($c.NC) Pattern cannot be empty"
        exit 1
    }
}

# Resolve search path
$resolvedPath = if ($Path -eq ".") { $PWD.Path } else { (Resolve-Path $Path -ErrorAction SilentlyContinue).Path }
if (-not $resolvedPath) {
    Write-Host "$($c.Red)ERROR:$($c.NC) Path '$Path' does not exist"
    exit 1
}

# Search
Write-Host ""
Write-Host "$($c.Blue)$($c.Bold)Searching...$($c.NC)"

if (Test-FdInstalled -and -not $EmptyDirs) {
    Write-Host "$($c.Cyan)(using fd - parallel search)$($c.NC)"
    $searchResults = @(Invoke-FdSearch -SearchPattern $Pattern -SearchPath $resolvedPath)
}
else {
    if (-not $EmptyDirs -and -not (Test-FdInstalled)) {
        Write-Host "$($c.Yellow)(using Get-ChildItem - install 'fd' for faster search)$($c.NC)"
    }
    $searchResults = @(Invoke-GetChildItemSearch -SearchPattern $Pattern -SearchPath $resolvedPath)
}

# Stream results
Write-Host ""
Write-Host "$($c.Bold)Matches:$($c.NC)"

$matchedFiles = @()
$displayCount = 0
$criticalCount = 0
$warningCount = 0
$safeCount = 0

foreach ($file in $searchResults) {
    if ([string]::IsNullOrEmpty($file)) { continue }

    $matchedFiles += $file

    # Categorize
    if (Test-CriticalSystemPath $file) {
        $criticalCount++
        $icon = "!!!"
        $color = "$($c.Red)$($c.Bold)"
    }
    elseif (Test-WarningSystemPath $file) {
        $warningCount++
        $icon = "! "
        $color = $c.Yellow
    }
    else {
        $safeCount++
        $icon = "  "
        $color = $c.Red
    }

    # Display
    if ($displayCount -lt $MaxDisplay) {
        $isDir = Test-Path $file -PathType Container
        if ($isDir) {
            Write-Host "$color  $icon $file\$($c.NC)"
        }
        else {
            Write-Host "$color  $icon $file$($c.NC)"
        }
        $displayCount++
    }
    elseif ($displayCount -eq $MaxDisplay) {
        Write-Host "$($c.Yellow)  ... (more results, display limit reached)$($c.NC)"
        $displayCount++
    }
}

$totalMatches = $matchedFiles.Count

# Check if any matches found
if ($totalMatches -eq 0) {
    Write-Host "$($c.Yellow)$($c.Bold)No matches found$($c.NC) for pattern: $($c.Cyan)$Pattern$($c.NC)"
    if (-not $All) {
        Write-Host "$($c.Yellow)Note:$($c.NC) Auto-exclusions are enabled. Use $($c.Cyan)-All$($c.NC) flag to disable."
    }
    exit 1
}

# Summary
Write-Host ""
Write-Host "$($c.Bold)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$($c.NC)"
Write-Host "$($c.Bold)Found $($c.Yellow)$totalMatches$($c.NC)$($c.Bold) total matches$($c.NC)"

if ($criticalCount -gt 0) {
    Write-Host "$($c.Red)$($c.Bold)  !!! Critical system files: $criticalCount$($c.NC)"
}
if ($warningCount -gt 0) {
    Write-Host "$($c.Yellow)$($c.Bold)  !  Warning-level files: $warningCount$($c.NC)"
}
if ($safeCount -gt 0) {
    Write-Host "$($c.Green)$($c.Bold)  OK Safe files: $safeCount$($c.NC)"
}

# Block critical files if not admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($criticalCount -gt 0 -and -not $isAdmin) {
    Write-Host ""
    Write-Host "$($c.Red)$($c.Bold)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$($c.NC)"
    Write-Host "$($c.Red)$($c.Bold)!!! DANGER: $criticalCount files are CRITICAL SYSTEM FILES!$($c.NC)"
    Write-Host "$($c.Red)$($c.Bold)X Cannot delete (insufficient permissions)$($c.NC)"
    Write-Host "$($c.Yellow)Run as Administrator if you really need to delete system files$($c.NC)"
    Write-Host "$($c.Red)$($c.Bold)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$($c.NC)"

    # Filter out critical files
    $matchedFiles = $matchedFiles | Where-Object { -not (Test-CriticalSystemPath $_) }

    if ($matchedFiles.Count -eq 0) {
        Write-Host "$($c.Yellow)All matched files are system files. Nothing can be deleted without Administrator.$($c.NC)"
        exit 1
    }

    Write-Host "$($c.Green)Proceeding with $($matchedFiles.Count) safe/warning-level files only...$($c.NC)"
}

# Show size
if ($ShowSize) {
    Write-Host ""
    Write-Host "$($c.Blue)Calculating total size...$($c.NC)"
    $totalSize = Get-TotalSize $matchedFiles
    Write-Host "$($c.Bold)Total size:$($c.NC) $($c.Yellow)$(Format-FileSize $totalSize)$($c.NC)"
}

# Ask for exclusions
if (-not $Force) {
    Write-Host ""
    Write-Host "$($c.Bold)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$($c.NC)"
    Write-Host "$($c.Cyan)Enter exclusion patterns$($c.NC) (comma-separated, or press Enter to skip):"
    Write-Host "$($c.Yellow)Examples:$($c.NC) *\important\*, *.txt, *\backup\*"
    $exclusions = Read-Host ">"

    if (-not [string]::IsNullOrEmpty($exclusions)) {
        $excludePatterns = $exclusions -split ',' | ForEach-Object { $_.Trim() }
        $excludedFiles = @()
        $keptFiles = @()

        foreach ($file in $matchedFiles) {
            $shouldExclude = $false
            foreach ($pattern in $excludePatterns) {
                if ($file -like $pattern) {
                    $shouldExclude = $true
                    $excludedFiles += $file
                    break
                }
            }
            if (-not $shouldExclude) {
                $keptFiles += $file
            }
        }

        if ($excludedFiles.Count -gt 0) {
            Write-Host ""
            Write-Host "$($c.Green)$($c.Bold)Excluded ($($excludedFiles.Count) items):$($c.NC)"
            foreach ($file in $excludedFiles) {
                Write-Host "$($c.Green)  OK $file$($c.NC)"
            }
        }

        $matchedFiles = $keptFiles
    }
}

$finalCount = $matchedFiles.Count

if ($finalCount -eq 0) {
    Write-Host ""
    Write-Host "$($c.Green)$($c.Bold)All files excluded. Nothing to delete.$($c.NC)"
    exit 0
}

# Show what will be deleted
Write-Host ""
Write-Host "$($c.Bold)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$($c.NC)"
Write-Host "$($c.Red)$($c.Bold)Will delete $finalCount items:$($c.NC)"

if ($ShowSize) {
    $totalSize = Get-TotalSize $matchedFiles
    Write-Host "$($c.Bold)Total size:$($c.NC) $($c.Yellow)$(Format-FileSize $totalSize)$($c.NC)"
}
Write-Host ""

# Show sample
$sampleCount = [Math]::Min(10, $finalCount)
for ($i = 0; $i -lt $sampleCount; $i++) {
    $file = $matchedFiles[$i]
    $isDir = Test-Path $file -PathType Container
    if ($isDir) {
        Write-Host "$($c.Red)  [D] $file\$($c.NC)"
    }
    else {
        Write-Host "$($c.Red)  [F] $file$($c.NC)"
    }
}

if ($finalCount -gt 10) {
    Write-Host "$($c.Yellow)  ... and $($finalCount - 10) more$($c.NC)"
}

# Dry-run mode
if ($DryRun) {
    Write-Host ""
    Write-Host "$($c.Yellow)$($c.Bold)DRY-RUN MODE:$($c.NC) No files were deleted"
    Write-Host "Remove $($c.Cyan)-DryRun$($c.NC) flag to actually delete these files"
    exit 0
}

# Final confirmation
if (-not $Force) {
    # Critical warning for admin
    if ($isAdmin -and $criticalCount -gt 0) {
        Show-CriticalWarning $criticalCount
        Write-Host "$($c.Red)$($c.Bold)To proceed, type exactly:$($c.NC) $($c.Yellow)YES DELETE SYSTEM FILES$($c.NC)"
        $confirmation = Read-Host ">"

        if ($confirmation -ne "YES DELETE SYSTEM FILES") {
            Write-Host ""
            Write-Host "$($c.Green)Operation cancelled. System is safe.$($c.NC)"
            exit 2
        }
    }

    Write-Host ""
    Write-Host "$($c.Bold)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$($c.NC)"
    $confirmation = Read-Host "$($c.Red)$($c.Bold)Proceed with deletion? (y/N)$($c.NC)"

    if ($confirmation -notmatch '^[Yy]$') {
        Write-Host ""
        Write-Host "$($c.Yellow)Operation cancelled$($c.NC)"
        exit 2
    }
}

# Perform deletion
Write-Host ""
Write-Host "$($c.Bold)$($c.Red)Deleting...$($c.NC)"
Write-Host ""

$deletedCount = 0
$failedCount = 0

foreach ($file in $matchedFiles) {
    if (Test-Path $file) {
        try {
            Remove-Item $file -Recurse -Force -ErrorAction Stop
            Write-Host "$($c.Green)OK$($c.NC) Deleted: $($c.Red)$file$($c.NC)"
            $deletedCount++
        }
        catch {
            Write-Host "$($c.Red)X$($c.NC) Failed: $file $($c.Yellow)(permission denied)$($c.NC)"
            $failedCount++
        }
    }
}

# Summary
Write-Host ""
Write-Host "$($c.Bold)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$($c.NC)"
Write-Host "$($c.Green)$($c.Bold)OK Deleted:$($c.NC) $deletedCount items"

if ($failedCount -gt 0) {
    Write-Host "$($c.Red)$($c.Bold)X Failed:$($c.NC) $failedCount items (try running as Administrator)"
}

Write-Host "$($c.Bold)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$($c.NC)"

exit 0
