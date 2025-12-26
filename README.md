# DELF (Delete Files)

🗑️ A smart, safe file deletion tool with pattern matching and intelligent safeguards. Never accidentally `rm -rf` your system again.

## What is DELF?

DELF is an interactive command-line tool for finding and deleting files/folders with advanced pattern matching, safety features, and automatic protection for critical system paths and important directories like `.git` and `node_modules`.

Think of it as `rm` with a brain - it asks before destroying, protects what matters, and gives you full control.

## Key Features

- 🎯 **Pattern Matching** - Use wildcards and globs to find files (`*.log`, `dist`, `.next`)
- 🛡️ **Safety Guards** - Automatic protection for critical system paths (`/bin`, `/etc`, `/boot`, etc.)
- 🚫 **Auto-Exclusion** - Protects `.git`, `node_modules`, `.npm`, `.cache`, `.vscode`, `.idea` by default
- 📊 **Size & Age Filters** - Delete only files larger than X or older than Y days
- 👁️ **Dry-Run Mode** - Preview what would be deleted before actually deleting
- 📁 **Type Filtering** - Target only files or only directories
- 💬 **Interactive** - Preview, confirm, and exclude patterns before deletion
- 🎨 **Color-Coded Output** - Clear visual feedback (red=delete, green=exclude, yellow=warning)
- 📏 **Size Calculation** - See total size of files to be deleted

## Quick Start

### Installation

Install with a single command:

```bash
curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/delf/refs/heads/main/install.sh | bash
```

Choose your installation type:
- **Option 1:** User installation (`~/.local/bin`) - No sudo needed
- **Option 2:** System-wide (`/usr/local/bin`) - Requires sudo, available to all users
- **Option 3:** Both locations

## Usage

### Basic Syntax

```bash
delf [OPTIONS] [PATTERN] [PATH]
```

### Common Examples

**Delete all .log files:**
```bash
delf *.log
```

**Delete node_modules folders (interactive):**
```bash
delf node_modules
```

**Preview deletion (dry-run):**
```bash
delf -n *.tmp
```

**Delete only directories named 'dist':**
```bash
delf -t d dist
```

**Delete large video files older than 30 days:**
```bash
delf --older-than 30 --larger-than 100M "*.mp4"
```

**Delete empty directories:**
```bash
delf --empty-dirs
```

**Case-insensitive search:**
```bash
delf -i "*.PNG"
```

**Force delete without confirmations (use with caution!):**
```bash
delf -f *.cache
```

**Include normally auto-excluded directories:**
```bash
delf -a node_modules  # Will also delete protected node_modules
```

## Options

| Option | Description |
|--------|-------------|
| `-h, --help` | Show help message |
| `-n, --dry-run` | Preview only, don't delete anything |
| `-f, --force` | Skip all confirmations (dangerous!) |
| `-i, --ignore-case` | Case-insensitive pattern matching |
| `-t, --type TYPE` | Filter by type: `f` (file) or `d` (directory) |
| `-a, --all` | Disable auto-exclusion of protected directories |
| `--show-size` | Display total size of matched files |
| `--older-than DAYS` | Only match files older than N days |
| `--larger-than SIZE` | Only match files larger than SIZE (K/M/G) |
| `--empty-dirs` | Find and delete empty directories only |
| `--max-display NUM` | Maximum files to display (default: 100) |

## Interactive Workflow

1. **Enter pattern** - e.g., `*.png`, `.next`, `dist/`
2. **Preview matches** - See matched files/folders (max 100 shown)
3. **Add exclusions** - Optional comma-separated exclusion patterns
4. **Review** - See what will be deleted with total size
5. **Confirm** - Type `y` to proceed or `N` to cancel
6. **Deletion** - Watch verbose deletion logs

## Safety Features

### Critical System Path Protection

DELF blocks deletion of critical system directories:
```
/bin, /sbin, /usr/bin, /usr/sbin, /etc, /boot, /sys, /proc, /dev, /root
/var/lib/dpkg, /var/lib/apt, /usr/lib, /lib
```

### Auto-Excluded Directories

By default, these patterns are protected (disable with `-a`):
```
*/node_modules/*
*/.git/*
*/.npm/*
*/.cache/*
*/.vscode/*
*/.idea/*
```

### Other Safety Measures

- ✅ Root directory protection (requires sudo when run from `/`)
- ✅ Pattern validation (rejects if no matches found)
- ✅ Preview before deletion with file count and size
- ✅ Color-coded output for clarity
- ✅ Interactive confirmations

## Why Use DELF?

| Situation | Standard `rm` | DELF |
|-----------|--------------|------|
| Delete all `.log` files | `find . -name "*.log" -delete` | `delf *.log` |
| Accidentally delete `.git` | 💥 Gone forever | ✅ Auto-protected |
| Delete system files | 💥 System broken | ✅ Blocked |
| Preview before delete | Manual scripting needed | ✅ Built-in dry-run |
| Delete by size/age | Complex `find` command | ✅ Simple flags |

## Advanced Examples

### Scenario: Clean build artifacts

```bash
# Delete all dist, build, and .next folders
delf -t d "dist|build|.next"
```

### Scenario: Clean old cache files

```bash
# Delete cache files older than 7 days and larger than 10MB
delf --older-than 7 --larger-than 10M "*.cache"
```

### Scenario: Clean project except specific folder

```bash
# Delete all .log files
delf *.log
# When prompted for exclusions: */important-project/*
```

## Installation Options

### User Installation (Recommended for personal use)
- **Location:** `~/.local/bin/delf`
- **Requires:** No sudo
- **Available to:** Current user only
- **Pros:** Safe, isolated, no root needed

### System-Wide Installation (For shared servers)
- **Location:** `/usr/local/bin/delf`
- **Requires:** sudo
- **Available to:** All users
- **Pros:** Accessible system-wide

## Updating

Re-run the installation command to update:

```bash
curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/delf/refs/heads/main/install.sh | bash
```

The installer will detect existing installation and upgrade automatically.

## Manual Installation

```bash
# Download
curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/delf/refs/heads/main/delf.sh -o delf

# Make executable
chmod +x delf

# Move to PATH
mv delf ~/.local/bin/  # or /usr/local/bin with sudo

# Add to PATH if needed
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## Uninstallation

```bash
# User installation
rm ~/.local/bin/delf

# System-wide installation
sudo rm /usr/local/bin/delf

# Remove logs
rm -rf ~/.delf
```

## Troubleshooting

### Command not found
```bash
source ~/.bashrc  # Reload shell config
# or restart terminal
```

### Permission denied
```bash
chmod +x ~/.local/bin/delf
```

## Use with Sudo

Run DELF with elevated privileges to access system files:

```bash
sudo delf *.log  # Runs with root permissions
```

**Warning:** Use sudo mode carefully - you can delete system files!

## Installation Logs

All installations are logged to: `~/.delf/install.log`

```bash
cat ~/.delf/install.log  # View installation history
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

MIT License - see LICENSE file for details

## Author

**YOUR_NAME**
- GitHub: [@ReggieAlbiosA](https://github.com/ReggieAlbiosA)

## Changelog

### v1.0.0 (2025-12-26)
- Initial release
- Pattern matching with wildcards
- Critical system path protection
- Auto-exclusion for .git, node_modules, etc.
- Size and age filters
- Dry-run mode
- Interactive deletion workflow
- APT-style installer

---

**⚠️ Use responsibly. Always preview with `--dry-run` first when unsure!**
