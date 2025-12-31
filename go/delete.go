package main

import (
	"fmt"
	"os"
)

// DeleteResult holds the result of a deletion attempt
type DeleteResult struct {
	Path    string
	Success bool
	Error   error
}

// deleteFile deletes a single file or directory
func deleteFile(path string) error {
	return os.RemoveAll(path)
}

// performDeletion deletes all files in the results list
func performDeletion(results []SearchResult, verbose bool) (deleted, failed int) {
	fmt.Println()
	fmt.Println(colors.Bold(colors.Red("Deleting...")))
	fmt.Println()

	for _, result := range results {
		// Check if file still exists
		if _, err := os.Stat(result.Path); os.IsNotExist(err) {
			continue
		}

		err := deleteFile(result.Path)
		if err != nil {
			failed++
			if verbose {
				fmt.Printf("%s Failed: %s %s\n",
					colors.Red("X"),
					result.Path,
					colors.Yellow(fmt.Sprintf("(%s)", err.Error())))
			}
		} else {
			deleted++
			if verbose {
				fmt.Printf("%s Deleted: %s\n",
					colors.Green("OK"),
					colors.Red(result.Path))
			}
		}
	}

	return deleted, failed
}

// previewDeletion shows what would be deleted without actually deleting
func previewDeletion(results []SearchResult, maxPreview int) {
	fmt.Println()
	fmt.Println(colors.Bold("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"))
	fmt.Printf("%s %d items:\n", colors.BoldRed("Will delete"), len(results))
	fmt.Println()

	count := 0
	for _, result := range results {
		if count >= maxPreview {
			remaining := len(results) - maxPreview
			if remaining > 0 {
				fmt.Printf("%s\n", colors.Yellow(fmt.Sprintf("  ... and %d more", remaining)))
			}
			break
		}
		showMatchResult(result.Path, result.IsDir)
		count++
	}
}

// showExcludedFiles displays files that were excluded
func showExcludedFiles(excluded []SearchResult) {
	if len(excluded) == 0 {
		return
	}

	fmt.Println()
	fmt.Printf("%s (%d items):\n", colors.Green(colors.Bold("Excluded")), len(excluded))
	for _, result := range excluded {
		fmt.Printf("%s %s\n", colors.Green("  OK"), result.Path)
	}
}
