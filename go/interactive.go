package main

import (
	"bufio"
	"fmt"
	"os"
	"strings"
	"time"
)

var reader = bufio.NewReader(os.Stdin)

// readLine reads a line of input from stdin
func readLine(prompt string) string {
	fmt.Print(prompt)
	input, _ := reader.ReadString('\n')
	return strings.TrimSpace(input)
}

// getSearchPath prompts for and returns the search path
func getSearchPath() string {
	cwd, _ := os.Getwd()

	fmt.Println("Enter path to search (default: current directory)")
	userPath := readLine(colors.Cyan("> "))

	if userPath == "" {
		fmt.Printf("%s %s\n", colors.Blue("Searching in:"), colors.Cyan(cwd))
		return "."
	}

	// Expand ~ to home directory
	if strings.HasPrefix(userPath, "~") {
		home, err := os.UserHomeDir()
		if err == nil {
			userPath = strings.Replace(userPath, "~", home, 1)
		}
	}

	// Expand environment variables
	userPath = os.ExpandEnv(userPath)

	// Validate path exists
	info, err := os.Stat(userPath)
	if err != nil || !info.IsDir() {
		fmt.Printf("%s Directory '%s' does not exist\n", colors.Red("ERROR:"), userPath)
		return ""
	}

	fmt.Printf("%s %s\n", colors.Blue("Searching in:"), colors.Cyan(userPath))
	fmt.Println()
	return userPath
}

// getPattern prompts for and returns the search pattern
func getPattern() string {
	fmt.Println("Enter file/folder name or pattern to delete")
	pattern := readLine(colors.Cyan("> "))

	if pattern == "" {
		fmt.Printf("%s Pattern cannot be empty\n", colors.Red("ERROR:"))
		return ""
	}

	return pattern
}

// getExclusions prompts for exclusion patterns
func getExclusions() []string {
	fmt.Println()
	fmt.Println(colors.Bold("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"))
	fmt.Printf("%s (comma-separated, or press Enter to skip):\n", colors.Cyan("Enter exclusion patterns"))
	fmt.Printf("%s *\\important\\*, *.txt, *\\backup\\*\n", colors.Yellow("Examples:"))

	input := readLine(colors.Cyan("> "))

	if input == "" {
		return nil
	}

	patterns := strings.Split(input, ",")
	for i := range patterns {
		patterns[i] = strings.TrimSpace(patterns[i])
	}

	return patterns
}

// confirmDeletion asks for final confirmation before deletion
func confirmDeletion() bool {
	fmt.Println()
	fmt.Println(colors.Bold("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"))
	confirmation := readLine(colors.BoldRed("Proceed with deletion? (y/N) "))

	return strings.ToLower(confirmation) == "y"
}

// confirmCriticalDeletion asks for extra confirmation for system files
func confirmCriticalDeletion(criticalCount int) bool {
	showCriticalWarning(criticalCount)
	fmt.Printf("%s %s\n", colors.BoldRed("To proceed, type exactly:"), colors.Yellow("YES DELETE SYSTEM FILES"))

	confirmation := readLine(colors.Cyan("> "))

	return confirmation == "YES DELETE SYSTEM FILES"
}

// runInteractiveMode runs the main interactive loop
func runInteractiveMode() {
	showHeader()

	// Get search path
	searchPath := getSearchPath()
	if searchPath == "" {
		os.Exit(1)
	}

	// Get pattern
	pattern := getPattern()
	if pattern == "" {
		os.Exit(1)
	}

	// Set the pattern and path for the search
	opts.Pattern = pattern
	opts.Path = searchPath

	// Execute main deletion flow
	executeDeletionFlow()
}

// executeDeletionFlow handles the complete deletion workflow
func executeDeletionFlow() {
	// Search
	results, _ := search(opts.Pattern, opts.Path)

	// Check for matches
	if len(results) == 0 {
		fmt.Println()
		fmt.Printf("%s for pattern: %s\n",
			colors.Yellow(colors.Bold("No matches found")),
			colors.Cyan(opts.Pattern))
		if !opts.All {
			fmt.Printf("%s Auto-exclusions are enabled. Use %s flag to disable.\n",
				colors.Yellow("Note:"),
				colors.Cyan("-a"))
		}
		os.Exit(1)
	}

	// Show summary by category
	total := len(results)
	critical, warning, safe := countByCategory(results)
	showMatchSummary(total, critical, warning, safe)

	// Handle critical files for non-admin
	if critical > 0 && !isAdmin() {
		showNoPermissionWarning(critical)
		results = filterOutCritical(results)

		if len(results) == 0 {
			fmt.Println(colors.Yellow("All matched files are system files. Nothing can be deleted without Administrator."))
			os.Exit(1)
		}

		fmt.Printf("%s\n", colors.Green(fmt.Sprintf("Proceeding with %d safe/warning-level files only...", len(results))))
	}

	// Show size if requested
	if opts.ShowSize {
		fmt.Println()
		fmt.Printf("%s\n", colors.Blue("Calculating total size..."))
		totalSize := getTotalSize(results)
		fmt.Printf("%s %s\n", colors.Bold("Total size:"), colors.Yellow(formatSize(totalSize)))
	}

	// Ask for exclusions (unless Force mode)
	if !opts.Force {
		exclusionPatterns := getExclusions()
		if len(exclusionPatterns) > 0 {
			kept, excluded := filterByExclusions(results, exclusionPatterns)
			showExcludedFiles(excluded)
			results = kept
		}
	}

	// Check if anything left to delete
	if len(results) == 0 {
		fmt.Println()
		fmt.Println(colors.Green(colors.Bold("All files excluded. Nothing to delete.")))
		os.Exit(0)
	}

	// Preview deletion
	previewDeletion(results, 10)

	// Show size again after exclusions
	if opts.ShowSize {
		totalSize := getTotalSize(results)
		fmt.Printf("%s %s\n", colors.Bold("Total size:"), colors.Yellow(formatSize(totalSize)))
	}

	// Dry-run mode
	if opts.DryRun {
		showDryRunNotice()
		os.Exit(0)
	}

	// Final confirmation
	if !opts.Force {
		// Extra confirmation for critical files (admin only)
		critical, _, _ = countByCategory(results)
		if isAdmin() && critical > 0 {
			if !confirmCriticalDeletion(critical) {
				fmt.Println()
				fmt.Println(colors.Green("Operation cancelled. System is safe."))
				os.Exit(2)
			}
		}

		if !confirmDeletion() {
			fmt.Println()
			fmt.Println(colors.Yellow("Operation cancelled"))
			os.Exit(2)
		}
	}

	// Perform deletion
	deleted, failed := performDeletion(results, true)

	// Show final summary
	showDeletionProgress(deleted, failed)
}

// getTime returns current time in seconds
func getTime() float64 {
	return float64(time.Now().UnixNano()) / 1e9
}
