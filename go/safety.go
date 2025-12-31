package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// FileCategory represents the safety category of a file
type FileCategory int

const (
	CategorySafe FileCategory = iota
	CategoryWarning
	CategoryCritical
)

// CriticalSystemPaths are paths that should NEVER be deleted
var CriticalSystemPaths = []string{
	`C:\Windows`,
	`C:\Windows\System32`,
	`C:\Windows\SysWOW64`,
	`C:\Program Files`,
	`C:\Program Files (x86)`,
	`C:\ProgramData`,
	`C:\Users\Default`,
	`C:\Users\Public`,
	`C:\Recovery`,
	`C:\Boot`,
}

// WarningSystemPaths are paths that require extra caution
var WarningSystemPaths = []string{
	`C:\Users`,
	`C:\Temp`,
}

// AutoExcludePatterns are patterns excluded by default
var AutoExcludePatterns = []string{
	"node_modules",
	".git",
	".npm",
	".cache",
	".vscode",
	".idea",
}

// init adds environment variable paths to critical lists
func init() {
	// Add environment variable paths
	if systemRoot := os.Getenv("SystemRoot"); systemRoot != "" {
		CriticalSystemPaths = append(CriticalSystemPaths, systemRoot)
	}
	if winDir := os.Getenv("windir"); winDir != "" {
		CriticalSystemPaths = append(CriticalSystemPaths, winDir)
	}
	if temp := os.Getenv("TEMP"); temp != "" {
		WarningSystemPaths = append(WarningSystemPaths, temp)
	}
	if tmp := os.Getenv("TMP"); tmp != "" {
		WarningSystemPaths = append(WarningSystemPaths, tmp)
	}
}

// isCriticalSystemPath checks if a path is a critical system path
func isCriticalSystemPath(filePath string) bool {
	normalizedPath := strings.ToLower(filepath.Clean(filePath))

	for _, critPath := range CriticalSystemPaths {
		normalizedCrit := strings.ToLower(filepath.Clean(critPath))
		if strings.HasPrefix(normalizedPath, normalizedCrit) {
			return true
		}
	}
	return false
}

// isWarningSystemPath checks if a path is a warning-level path
func isWarningSystemPath(filePath string) bool {
	normalizedPath := strings.ToLower(filepath.Clean(filePath))

	for _, warnPath := range WarningSystemPaths {
		normalizedWarn := strings.ToLower(filepath.Clean(warnPath))
		if strings.HasPrefix(normalizedPath, normalizedWarn) {
			return true
		}
	}
	return false
}

// categorizeFile determines the safety category of a file
func categorizeFile(filePath string) FileCategory {
	if isCriticalSystemPath(filePath) {
		return CategoryCritical
	}
	if isWarningSystemPath(filePath) {
		return CategoryWarning
	}
	return CategorySafe
}

// isAutoExcluded checks if a path matches auto-exclude patterns
func isAutoExcluded(filePath string) bool {
	normalizedPath := strings.ToLower(filePath)

	for _, pattern := range AutoExcludePatterns {
		// Check if any path component matches the pattern
		if strings.Contains(normalizedPath, strings.ToLower(pattern)) {
			return true
		}
	}
	return false
}

// isAdmin checks if the current process is running as Administrator
func isAdmin() bool {
	// Use 'net session' command - it fails if not running as admin
	cmd := exec.Command("net", "session")
	err := cmd.Run()
	return err == nil
}

// isEmptyDirectory checks if a directory is empty
func isEmptyDirectory(path string) (bool, error) {
	info, err := os.Stat(path)
	if err != nil {
		return false, err
	}
	if !info.IsDir() {
		return false, nil
	}

	entries, err := os.ReadDir(path)
	if err != nil {
		return false, err
	}
	return len(entries) == 0, nil
}

// matchesExclusionPattern checks if a path matches any exclusion pattern
func matchesExclusionPattern(filePath string, patterns []string) bool {
	for _, pattern := range patterns {
		pattern = strings.TrimSpace(pattern)
		if pattern == "" {
			continue
		}

		// Handle wildcard patterns
		if strings.Contains(pattern, "*") {
			matched, err := filepath.Match(pattern, filepath.Base(filePath))
			if err == nil && matched {
				return true
			}
			// Also check full path
			matched, err = filepath.Match(pattern, filePath)
			if err == nil && matched {
				return true
			}
		} else {
			// Simple substring match
			if strings.Contains(strings.ToLower(filePath), strings.ToLower(pattern)) {
				return true
			}
		}
	}
	return false
}

