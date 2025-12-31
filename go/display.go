package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/fatih/color"
	"github.com/mattn/go-isatty"
)

// Colors holds color functions for output
type Colors struct {
	Red     func(format string, a ...interface{}) string
	Green   func(format string, a ...interface{}) string
	Yellow  func(format string, a ...interface{}) string
	Blue    func(format string, a ...interface{}) string
	Cyan    func(format string, a ...interface{}) string
	Magenta func(format string, a ...interface{}) string
	Bold    func(format string, a ...interface{}) string
	Dim     func(format string, a ...interface{}) string
	BoldRed func(format string, a ...interface{}) string
}

var colors Colors

// initColors initializes color functions based on terminal support
func initColors() {
	isTerm := isatty.IsTerminal(os.Stdout.Fd()) || isatty.IsCygwinTerminal(os.Stdout.Fd())

	if isTerm {
		colors = Colors{
			Red:     color.New(color.FgRed).SprintfFunc(),
			Green:   color.New(color.FgGreen).SprintfFunc(),
			Yellow:  color.New(color.FgYellow, color.Bold).SprintfFunc(),
			Blue:    color.New(color.FgBlue).SprintfFunc(),
			Cyan:    color.New(color.FgCyan).SprintfFunc(),
			Magenta: color.New(color.FgMagenta).SprintfFunc(),
			Bold:    color.New(color.Bold).SprintfFunc(),
			Dim:     color.New(color.Faint).SprintfFunc(),
			BoldRed: color.New(color.FgRed, color.Bold).SprintfFunc(),
		}
	} else {
		// No colors when not a terminal
		noColor := func(format string, a ...interface{}) string {
			return fmt.Sprintf(format, a...)
		}
		colors = Colors{
			Red:     noColor,
			Green:   noColor,
			Yellow:  noColor,
			Blue:    noColor,
			Cyan:    noColor,
			Magenta: noColor,
			Bold:    noColor,
			Dim:     noColor,
			BoldRed: noColor,
		}
	}
}

// showHeader displays the DELF header
func showHeader() {
	cyan := colors.Cyan
	bold := colors.Bold
	fmt.Println(bold(cyan("delf - Delete Folder/File")) + " v" + Version)
	fmt.Println(bold("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"))
	fmt.Println()
}

// showResult displays a single search result with safety indicator
func showResult(filePath string, count int, category FileCategory) {
	info, err := os.Lstat(filePath)
	if err != nil {
		fmt.Printf("  [%d] %s\n", count, filePath)
		return
	}

	// Get file info string (size if applicable)
	fileInfo := getFileInfo(filePath, info)

	// Determine icon based on category
	var icon string
	var colorFunc func(format string, a ...interface{}) string
	switch category {
	case CategoryCritical:
		icon = "!!!"
		colorFunc = colors.BoldRed
	case CategoryWarning:
		icon = "! "
		colorFunc = colors.Yellow
	default:
		icon = "  "
		colorFunc = colors.Red
	}

	// Determine file type indicator
	var typeIndicator string
	if info.IsDir() {
		typeIndicator = fmt.Sprintf("%s%c", filePath, filepath.Separator)
	} else {
		typeIndicator = filePath
	}

	fmt.Printf("%s %s%s\n",
		colorFunc(fmt.Sprintf("  %s", icon)),
		colorFunc(typeIndicator),
		fileInfo)
}

// showMatchResult displays a result for deletion preview
func showMatchResult(filePath string, isDir bool) {
	if isDir {
		fmt.Printf("%s %s%c%s\n",
			colors.Red("  [D]"),
			colors.Red(filePath),
			filepath.Separator,
			colors.Dim(""))
	} else {
		fmt.Printf("%s %s\n",
			colors.Red("  [F]"),
			colors.Red(filePath))
	}
}

// isExecutable checks if a file is executable (Windows: by extension)
func isExecutable(path string) bool {
	ext := strings.ToLower(filepath.Ext(path))
	execExts := []string{".exe", ".bat", ".cmd", ".ps1", ".com"}
	for _, e := range execExts {
		if ext == e {
			return true
		}
	}
	return false
}

// getFileInfo returns formatted file size info if ShowSize is enabled
func getFileInfo(path string, info os.FileInfo) string {
	if !opts.ShowSize {
		return ""
	}
	if info.IsDir() {
		return ""
	}
	return colors.Dim(fmt.Sprintf(" (%s)", formatSize(info.Size())))
}

// formatSize formats bytes into human-readable size
func formatSize(bytes int64) string {
	const (
		KB = 1024
		MB = KB * 1024
		GB = MB * 1024
	)

	switch {
	case bytes >= GB:
		return fmt.Sprintf("%.2fG", float64(bytes)/float64(GB))
	case bytes >= MB:
		return fmt.Sprintf("%.2fM", float64(bytes)/float64(MB))
	case bytes >= KB:
		return fmt.Sprintf("%.2fK", float64(bytes)/float64(KB))
	default:
		return fmt.Sprintf("%dB", bytes)
	}
}

// parseSize converts size string like "100M" to bytes
func parseSize(sizeStr string) (int64, error) {
	sizeStr = strings.TrimSpace(strings.ToUpper(sizeStr))
	if sizeStr == "" {
		return 0, fmt.Errorf("empty size string")
	}

	var multiplier int64 = 1
	var numStr string

	lastChar := sizeStr[len(sizeStr)-1]
	switch lastChar {
	case 'K':
		multiplier = 1024
		numStr = sizeStr[:len(sizeStr)-1]
	case 'M':
		multiplier = 1024 * 1024
		numStr = sizeStr[:len(sizeStr)-1]
	case 'G':
		multiplier = 1024 * 1024 * 1024
		numStr = sizeStr[:len(sizeStr)-1]
	case 'B':
		multiplier = 1
		numStr = sizeStr[:len(sizeStr)-1]
	default:
		if lastChar >= '0' && lastChar <= '9' {
			numStr = sizeStr
		} else {
			return 0, fmt.Errorf("invalid size unit: %c", lastChar)
		}
	}

	var num int64
	_, err := fmt.Sscanf(numStr, "%d", &num)
	if err != nil {
		return 0, fmt.Errorf("invalid size number: %s", numStr)
	}

	return num * multiplier, nil
}

// showSearchInfo displays search parameters
func showSearchInfo(searchPath, pattern string, usingFd bool) {
	fmt.Println()
	fmt.Println(colors.Bold("Searching..."))
	fmt.Printf("%s %s\n", colors.Blue("Path:"), colors.Cyan(searchPath))
	fmt.Printf("%s %s\n", colors.Blue("Pattern:"), colors.Yellow(pattern))

	if usingFd {
		fmt.Printf("%s %s\n", colors.Blue("Method:"), colors.Green("fd (parallel search)"))
	} else {
		fmt.Printf("%s %s\n", colors.Blue("Method:"), colors.Yellow("walk (install 'fd' for faster search)"))
	}
	fmt.Println()
}

// showMatchSummary displays summary of matched files by category
func showMatchSummary(total, critical, warning, safe int) {
	fmt.Println()
	fmt.Println(colors.Bold("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"))
	fmt.Printf("%s %s%s\n", colors.Bold("Found"), colors.Yellow(fmt.Sprintf("%d", total)), colors.Bold(" total matches"))

	if critical > 0 {
		fmt.Printf("  %s %d\n", colors.BoldRed("!!! Critical system files:"), critical)
	}
	if warning > 0 {
		fmt.Printf("  %s %d\n", colors.Yellow("!  Warning-level files:"), warning)
	}
	if safe > 0 {
		fmt.Printf("  %s %d\n", colors.Green("OK Safe files:"), safe)
	}
}

// showCriticalWarning displays a critical system warning
func showCriticalWarning(criticalCount int) {
	fmt.Println()
	fmt.Println(colors.BoldRed("!!! CRITICAL DANGER WARNING !!!"))
	fmt.Println(colors.BoldRed("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"))
	fmt.Printf("%s %d %s\n", colors.BoldRed("You are about to delete"), criticalCount, colors.BoldRed("SYSTEM FILES!"))
	fmt.Println()
	fmt.Println(colors.Yellow(colors.Bold("CONSEQUENCES:")))
	fmt.Println(colors.Red("  - May break Windows boot"))
	fmt.Println(colors.Red("  - May break critical services"))
	fmt.Println(colors.Red("  - May make the system unrecoverable"))
	fmt.Println(colors.Red("  - May require Windows reinstallation"))
	fmt.Println()
}

// showNoPermissionWarning displays permission warning for system files
func showNoPermissionWarning(criticalCount int) {
	fmt.Println()
	fmt.Println(colors.BoldRed("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"))
	fmt.Printf("%s %d %s\n", colors.BoldRed("!!! DANGER:"), criticalCount, colors.BoldRed("files are CRITICAL SYSTEM FILES!"))
	fmt.Println(colors.BoldRed("X Cannot delete (insufficient permissions)"))
	fmt.Println(colors.Yellow("Run as Administrator if you really need to delete system files"))
	fmt.Println(colors.BoldRed("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"))
}

// showDeletionProgress displays deletion progress
func showDeletionProgress(deleted, failed int) {
	fmt.Println()
	fmt.Println(colors.Bold("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"))
	fmt.Printf("%s %d items\n", colors.Green(colors.Bold("OK Deleted:")), deleted)
	if failed > 0 {
		fmt.Printf("%s %d items (try running as Administrator)\n", colors.BoldRed("X Failed:"), failed)
	}
	fmt.Println(colors.Bold("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"))
}

// showDryRunNotice displays dry-run mode notice
func showDryRunNotice() {
	fmt.Println()
	fmt.Printf("%s No files were deleted\n", colors.Yellow(colors.Bold("DRY-RUN MODE:")))
	fmt.Printf("Remove %s flag to actually delete these files\n", colors.Cyan("-n"))
}

// showHelp displays the help message
func showHelp() {
	fmt.Printf("%s v%s\n", colors.Bold("delf - Delete Folder/File Command"), Version)
	fmt.Println()
	fmt.Println(colors.Bold("USAGE:"))
	fmt.Println("    delf [OPTIONS] [PATTERN] [PATH]")
	fmt.Println()
	fmt.Println(colors.Bold("DESCRIPTION:"))
	fmt.Println("    Interactive tool to find and delete files/folders with pattern matching,")
	fmt.Println("    exclusions, and safety features.")
	fmt.Println()
	fmt.Println(colors.Bold("OPTIONS:"))
	fmt.Printf("    %s               Show this help message\n", colors.Cyan("-h, --help"))
	fmt.Printf("    %s             Preview only, don't delete anything\n", colors.Cyan("-n, --dry-run"))
	fmt.Printf("    %s              Skip all confirmations (dangerous!)\n", colors.Cyan("-f, --force"))
	fmt.Printf("    %s                  Case-insensitive pattern matching\n", colors.Cyan("-i"))
	fmt.Printf("    %s           Filter by type: %s(file) or %s(directory)\n",
		colors.Cyan("-t TYPE"), colors.Yellow("f"), colors.Yellow("d"))
	fmt.Printf("    %s                  Disable auto-exclusion of common directories\n", colors.Cyan("-a"))
	fmt.Printf("    %s          Display total size of matched files\n", colors.Cyan("--show-size"))
	fmt.Printf("    %s    Only match files older than N days\n", colors.Cyan("--older-than DAYS"))
	fmt.Printf("    %s   Only match files larger than SIZE (K,M,G)\n", colors.Cyan("--larger-than SIZE"))
	fmt.Printf("    %s         Find and delete empty directories only\n", colors.Cyan("--empty-dirs"))
	fmt.Printf("    %s   Maximum results to display (default: 100)\n", colors.Cyan("--max-display NUM"))
	fmt.Println()
	fmt.Println(colors.Bold("EXAMPLES:"))
	fmt.Printf("    %s\n", colors.Green("# Delete all .log files"))
	fmt.Println("    delf \"*.log\"")
	fmt.Println()
	fmt.Printf("    %s\n", colors.Green("# Preview what would be deleted (dry-run)"))
	fmt.Println("    delf -n \"*.tmp\"")
	fmt.Println()
	fmt.Printf("    %s\n", colors.Green("# Delete large video files older than 30 days"))
	fmt.Println("    delf --older-than 30 --larger-than 100M \"*.mp4\"")
	fmt.Println()
	fmt.Printf("    %s\n", colors.Green("# Delete only directories named 'dist'"))
	fmt.Println("    delf -t d dist")
	fmt.Println()
	fmt.Printf("    %s\n", colors.Green("# Delete empty directories"))
	fmt.Println("    delf --empty-dirs")
	fmt.Println()
	fmt.Println(colors.Bold("AUTO-EXCLUDED DIRECTORIES:"))
	fmt.Println("    By default, these patterns are protected (use -a to disable):")
	fmt.Println("    - node_modules, .git, .npm, .cache, .vscode, .idea")
	fmt.Println()
	fmt.Println(colors.Bold("SAFETY FEATURES:"))
	fmt.Println("    - Critical system path protection (C:\\Windows, Program Files, etc.)")
	fmt.Println("    - Auto-exclusion of important directories")
	fmt.Println("    - Preview before deletion")
	fmt.Println("    - Dry-run mode for testing")
	fmt.Println()
	fmt.Println(colors.Bold("PERFORMANCE:"))
	fmt.Println("    - Uses 'fd' for fast parallel searching (if installed)")
	fmt.Println("    - Falls back to Go's filepath.WalkDir if fd is not available")
	fmt.Printf("    - Install fd: %s\n", colors.Cyan("winget install sharkdp.fd"))
	fmt.Println()
}
