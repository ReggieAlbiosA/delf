# Changelog

All notable changes to DELF will be documented in this file.

## [2.0.0] - 2025-01-01

### Changed
- **Complete rewrite from PowerShell to Go** - DELF is now a native Windows binary
- Installer now downloads pre-built `.exe` from GitHub Releases instead of raw script
- Improved ANSI color support across all Windows terminals (via fatih/color)
- Faster file search with built-in parallel walking (no longer depends on Get-ChildItem)

### Added
- **Version checking** - Installer skips download if already up-to-date
- **Smart updates** - Compares installed version vs latest GitHub release
- **Legacy migration** - Automatically removes old `.ps1` scripts when upgrading
- GitHub Actions workflow for automated builds on release

### Removed
- `win/delf.ps1` - Replaced by native Go binary (`delf.exe`)
- PowerShell execution policy requirement - No longer needed with native binary

### Fixed
- ANSI colors now work reliably on PowerShell 5.1 and legacy console
- No more execution policy errors during installation
- Consistent behavior across all Windows versions

## [1.0.0] - 2024-12-XX

### Added
- Initial PowerShell implementation
- Pattern matching with wildcards
- Age filtering (--older-than)
- Size filtering (--larger-than)
- Type filtering (-t f/d)
- Dry-run mode (-n)
- Force mode (-f)
- Critical system path protection
- Auto-exclusion of common directories (node_modules, .git, etc.)
- Interactive mode with confirmations
- fd integration for fast parallel search
- User and system-wide installation support
