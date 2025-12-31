package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// SearchResult holds a file path and its category
type SearchResult struct {
	Path     string
	Category FileCategory
	IsDir    bool
}

// hasFd checks if fd is available in PATH
func hasFd() bool {
	_, err := exec.LookPath("fd")
	return err == nil
}

// searchWithFd uses fd for fast parallel search
func searchWithFd(pattern, searchPath string) ([]SearchResult, error) {
	args := []string{"--color", "never", "--hidden", "--no-ignore"}

	// Type filter
	if opts.Type == "f" {
		args = append(args, "-t", "f")
	} else if opts.Type == "d" {
		args = append(args, "-t", "d")
	}

	// Case sensitivity
	if opts.IgnoreCase {
		args = append(args, "-i")
	} else {
		args = append(args, "-s")
	}

	// Age filter (fd uses --changed-before)
	if opts.OlderThan > 0 {
		args = append(args, "--changed-before", fmt.Sprintf("%ddays", opts.OlderThan))
	}

	// Size filter (fd uses -S for min size)
	if opts.LargerThan != "" {
		args = append(args, "-S", "+"+opts.LargerThan)
	}

	// Auto-exclude patterns
	if !opts.All {
		for _, pattern := range AutoExcludePatterns {
			args = append(args, "-E", "*"+pattern+"*")
		}
	}

	// Glob pattern and path
	if pattern != "" {
		args = append(args, "-g", pattern)
	}
	args = append(args, searchPath)

	cmd := exec.Command("fd", args...)
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}

	if err := cmd.Start(); err != nil {
		return nil, err
	}

	var results []SearchResult
	scanner := bufio.NewScanner(stdout)
	count := 0

	for scanner.Scan() {
		line := scanner.Text()
		if line == "" {
			continue
		}

		count++
		category := categorizeFile(line)

		// Check if it's a directory
		info, err := os.Stat(line)
		isDir := err == nil && info.IsDir()

		results = append(results, SearchResult{
			Path:     line,
			Category: category,
			IsDir:    isDir,
		})

		// Display result in real-time (streaming)
		if count <= opts.MaxDisplay {
			showResult(line, count, category)
		} else if count == opts.MaxDisplay+1 {
			fmt.Printf("%s\n", colors.Yellow("  ... (more results, display limit reached)"))
		}
	}

	cmd.Wait()
	return results, nil
}

// searchWithWalk uses filepath.WalkDir as fallback
func searchWithWalk(pattern, searchPath string) ([]SearchResult, error) {
	var results []SearchResult
	count := 0

	err := filepath.WalkDir(searchPath, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return nil // Skip errors, continue walking
		}

		// Skip the root directory itself
		if path == searchPath {
			return nil
		}

		// Type filter
		if opts.Type == "f" && d.IsDir() {
			return nil
		}
		if opts.Type == "d" && !d.IsDir() {
			return nil
		}

		// Auto-exclude check
		if !opts.All && isAutoExcluded(path) {
			if d.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}

		// Pattern matching (if pattern provided)
		if pattern != "" {
			name := d.Name()
			matched := matchPattern(name, pattern, opts.IgnoreCase)
			if !matched {
				return nil
			}
		}

		// Get file info for filtering
		info, err := d.Info()
		if err != nil {
			return nil
		}

		// Age filter
		if opts.OlderThan > 0 {
			cutoff := time.Now().AddDate(0, 0, -opts.OlderThan)
			if info.ModTime().After(cutoff) {
				return nil
			}
		}

		// Size filter (only for files)
		if opts.LargerThan != "" && !d.IsDir() {
			minSize, err := parseSize(opts.LargerThan)
			if err == nil && info.Size() <= minSize {
				return nil
			}
		}

		count++
		category := categorizeFile(path)

		results = append(results, SearchResult{
			Path:     path,
			Category: category,
			IsDir:    d.IsDir(),
		})

		// Display result in real-time (streaming)
		if count <= opts.MaxDisplay {
			showResult(path, count, category)
		} else if count == opts.MaxDisplay+1 {
			fmt.Printf("%s\n", colors.Yellow("  ... (more results, display limit reached)"))
		}

		return nil
	})

	return results, err
}

// searchEmptyDirs finds empty directories
func searchEmptyDirs(searchPath string) ([]SearchResult, error) {
	var results []SearchResult
	count := 0

	err := filepath.WalkDir(searchPath, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return nil
		}

		if path == searchPath {
			return nil
		}

		if !d.IsDir() {
			return nil
		}

		// Auto-exclude check
		if !opts.All && isAutoExcluded(path) {
			return filepath.SkipDir
		}

		isEmpty, err := isEmptyDirectory(path)
		if err != nil || !isEmpty {
			return nil
		}

		count++
		category := categorizeFile(path)

		results = append(results, SearchResult{
			Path:     path,
			Category: category,
			IsDir:    true,
		})

		if count <= opts.MaxDisplay {
			showResult(path, count, category)
		} else if count == opts.MaxDisplay+1 {
			fmt.Printf("%s\n", colors.Yellow("  ... (more results, display limit reached)"))
		}

		return nil
	})

	return results, err
}

// matchPattern checks if name matches the glob pattern
func matchPattern(name, pattern string, ignoreCase bool) bool {
	if ignoreCase {
		name = strings.ToLower(name)
		pattern = strings.ToLower(pattern)
	}

	matched, err := filepath.Match(pattern, name)
	if err != nil {
		return false
	}
	return matched
}

// search performs the search using fd or fallback
func search(pattern, searchPath string) ([]SearchResult, bool) {
	// Resolve search path
	absPath, err := filepath.Abs(searchPath)
	if err != nil {
		absPath = searchPath
	}

	// Handle empty dirs mode
	if opts.EmptyDirs {
		showSearchInfo(absPath, "(empty directories)", false)
		fmt.Printf("%s\n", colors.Bold("Matches:"))
		results, _ := searchEmptyDirs(absPath)
		return results, false
	}

	usingFd := hasFd()
	showSearchInfo(absPath, pattern, usingFd)

	fmt.Printf("%s\n", colors.Bold("Matches:"))

	var results []SearchResult
	if usingFd {
		results, _ = searchWithFd(pattern, absPath)
	} else {
		results, _ = searchWithWalk(pattern, absPath)
	}

	return results, usingFd
}

// getTotalSize calculates total size of all files
func getTotalSize(results []SearchResult) int64 {
	var total int64
	for _, result := range results {
		info, err := os.Stat(result.Path)
		if err != nil {
			continue
		}
		if info.IsDir() {
			// Sum up directory contents
			filepath.WalkDir(result.Path, func(path string, d os.DirEntry, err error) error {
				if err != nil || d.IsDir() {
					return nil
				}
				info, err := d.Info()
				if err == nil {
					total += info.Size()
				}
				return nil
			})
		} else {
			total += info.Size()
		}
	}
	return total
}

// countByCategory counts results by category
func countByCategory(results []SearchResult) (critical, warning, safe int) {
	for _, r := range results {
		switch r.Category {
		case CategoryCritical:
			critical++
		case CategoryWarning:
			warning++
		default:
			safe++
		}
	}
	return
}

// filterOutCritical removes critical files from results (for non-admin)
func filterOutCritical(results []SearchResult) []SearchResult {
	var filtered []SearchResult
	for _, r := range results {
		if r.Category != CategoryCritical {
			filtered = append(filtered, r)
		}
	}
	return filtered
}

// filterByExclusions removes files matching exclusion patterns
func filterByExclusions(results []SearchResult, patterns []string) (kept, excluded []SearchResult) {
	for _, r := range results {
		if matchesExclusionPattern(r.Path, patterns) {
			excluded = append(excluded, r)
		} else {
			kept = append(kept, r)
		}
	}
	return
}
