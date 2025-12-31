package main

import (
	"flag"
	"fmt"
	"os"
)

const Version = "2.0.0"

// Options holds the command-line options
type Options struct {
	Pattern    string
	Path       string
	DryRun     bool
	Force      bool
	IgnoreCase bool
	Type       string
	All        bool
	ShowSize   bool
	OlderThan  int
	LargerThan string
	EmptyDirs  bool
	MaxDisplay int
	Help       bool
}

var opts Options

func main() {
	// Initialize colors
	initColors()

	// Parse command-line arguments
	parseArgs()

	// Show help if requested
	if opts.Help {
		showHelp()
		os.Exit(0)
	}

	// If pattern provided (or empty dirs mode), run direct; otherwise interactive mode
	if opts.Pattern != "" || opts.EmptyDirs {
		executeDeletionFlow()
	} else {
		runInteractiveMode()
	}
}

func parseArgs() {
	// Help
	flag.BoolVar(&opts.Help, "h", false, "Show help message")
	flag.BoolVar(&opts.Help, "help", false, "Show help message")

	// Dry-run
	flag.BoolVar(&opts.DryRun, "n", false, "Preview only, don't delete anything")
	flag.BoolVar(&opts.DryRun, "dry-run", false, "Preview only, don't delete anything")

	// Force
	flag.BoolVar(&opts.Force, "f", false, "Skip all confirmations (dangerous!)")
	flag.BoolVar(&opts.Force, "force", false, "Skip all confirmations (dangerous!)")

	// Case-insensitive
	flag.BoolVar(&opts.IgnoreCase, "i", false, "Case-insensitive pattern matching")

	// Type filter
	flag.StringVar(&opts.Type, "t", "", "Filter by type: 'f' for files, 'd' for directories")

	// Disable auto-exclusions
	flag.BoolVar(&opts.All, "a", false, "Disable auto-exclusion of common directories")

	// Show size
	flag.BoolVar(&opts.ShowSize, "show-size", false, "Display total size of matched files")

	// Age filter
	flag.IntVar(&opts.OlderThan, "older-than", 0, "Only match files older than N days")

	// Size filter
	flag.StringVar(&opts.LargerThan, "larger-than", "", "Only match files larger than SIZE (K,M,G)")

	// Empty dirs
	flag.BoolVar(&opts.EmptyDirs, "empty-dirs", false, "Find and delete empty directories only")

	// Max display
	flag.IntVar(&opts.MaxDisplay, "max-display", 100, "Maximum results to display")

	// Custom usage
	flag.Usage = func() {
		showHelp()
	}

	flag.Parse()

	// Get positional arguments
	args := flag.Args()
	if len(args) >= 1 {
		opts.Pattern = args[0]
	}
	if len(args) >= 2 {
		opts.Path = args[1]
	} else {
		opts.Path = "."
	}

	// Validate type flag
	if opts.Type != "" && opts.Type != "f" && opts.Type != "d" {
		fmt.Printf("%s Type must be 'f' (file) or 'd' (directory)\n", colors.Red("ERROR:"))
		os.Exit(1)
	}
}
