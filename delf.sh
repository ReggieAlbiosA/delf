#!/bin/bash

# df - Delete Folder/File Command
# Advanced file/folder deletion tool with pattern matching and exclusions

VERSION="1.0.0"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'
BLINK='\033[5m'

# Critical system paths (deletion here can break the system)
CRITICAL_SYSTEM_PATHS=(
    "/bin"
    "/sbin"
    "/usr/bin"
    "/usr/sbin"
    "/usr/lib"
    "/usr/lib64"
    "/lib"
    "/lib64"
    "/etc"
    "/boot"
    "/sys"
    "/proc"
    "/dev"
    "/root"
    "/var/lib/dpkg"
    "/var/lib/apt"
    "/usr/share"
)

# Warning-level system paths (generally safe but user should be careful)
WARNING_SYSTEM_PATHS=(
    "/opt"
    "/srv"
    "/var/log"
    "/var/www"
    "/var/cache"
)

# Default settings
DRY_RUN=false
FORCE=false
IGNORE_CASE=false
TYPE_FILTER=""
SHOW_SIZE=false
AUTO_EXCLUDE=true
OLDER_THAN=""
LARGER_THAN=""
EMPTY_DIRS=false
MAX_DISPLAY=100

# Auto-exclude patterns (common directories to protect)
AUTO_EXCLUDE_PATTERNS=(
    "*/node_modules/*"
    "*/.git/*"
    "*/.npm/*"
    "*/.cache/*"
    "*/.vscode/*"
    "*/.idea/*"
)

# Function to show help
show_help() {
    cat << EOF
${BOLD}df - Delete Folder/File Command${NC} v${VERSION}

${BOLD}USAGE:${NC}
    df [OPTIONS] [PATTERN] [PATH]

${BOLD}DESCRIPTION:${NC}
    Interactive tool to find and delete files/folders with pattern matching,
    exclusions, and safety features. Recursively searches from current directory
    or specified path.

${BOLD}OPTIONS:${NC}
    ${CYAN}-h, --help${NC}              Show this help message
    ${CYAN}-n, --dry-run${NC}           Preview only, don't delete anything
    ${CYAN}-f, --force${NC}             Skip all confirmations (use with caution!)
    ${CYAN}-i, --ignore-case${NC}       Case-insensitive pattern matching
    ${CYAN}-t, --type TYPE${NC}         Filter by type: ${YELLOW}f${NC}(file) or ${YELLOW}d${NC}(directory)
    ${CYAN}-a, --all${NC}               Disable auto-exclusion of common directories
    ${CYAN}--show-size${NC}             Display total size of matched files
    ${CYAN}--older-than DAYS${NC}       Only match files older than N days
    ${CYAN}--larger-than SIZE${NC}      Only match files larger than SIZE (K,M,G)
                            Examples: 10M, 500K, 1G
    ${CYAN}--empty-dirs${NC}            Find and delete empty directories only
    ${CYAN}--max-display NUM${NC}       Maximum lines to display (default: 100)

${BOLD}EXAMPLES:${NC}
    ${GREEN}# Basic usage - delete all .log files${NC}
    df *.log

    ${GREEN}# Delete .claude directories except in origin-stack${NC}
    df .claude
    # When prompted for exclusions: */origin-stack/*

    ${GREEN}# Delete large video files older than 30 days${NC}
    df --older-than 30 --larger-than 100M "*.mp4"

    ${GREEN}# Preview what would be deleted (dry-run)${NC}
    df -n *.tmp

    ${GREEN}# Delete only directories named 'dist'${NC}
    df -t d dist

    ${GREEN}# Case-insensitive search for PNG files${NC}
    df -i "*.PNG"

    ${GREEN}# Delete empty directories${NC}
    df --empty-dirs

    ${GREEN}# Delete node_modules folders (including auto-excluded ones)${NC}
    df -a node_modules

    ${GREEN}# Force delete without confirmations${NC}
    df -f *.cache

${BOLD}AUTO-EXCLUDED DIRECTORIES:${NC}
    By default, these patterns are protected (use -a to disable):
    - */node_modules/*
    - */.git/*
    - */.npm/*
    - */.cache/*
    - */.vscode/*
    - */.idea/*

${BOLD}INTERACTIVE WORKFLOW:${NC}
    1. Enter pattern to match (e.g., *.png, .next, dist/)
    2. Preview matched files/folders (max 100 shown)
    3. Enter exclusion patterns (comma-separated, optional)
    4. Review what will be deleted with total size
    5. Confirm deletion (y/N)
    6. See verbose deletion logs

${BOLD}SAFETY FEATURES:${NC}
    - Root directory protection (requires sudo when run from /)
    - Pattern validation (rejects if no matches found)
    - Preview before deletion with file count and size
    - Color-coded output (red=delete, green=exclude, yellow=warning)
    - Dry-run mode for testing
    - Auto-exclusion of critical directories

${BOLD}NOTES:${NC}
    - Patterns are case-sensitive by default (use -i for case-insensitive)
    - Searches recursively from current directory or specified path
    - Exclusion patterns use glob matching (e.g., */folder/*, *.txt)
    - For regex patterns, use quotes: ".*\\.log$"

${BOLD}EXIT CODES:${NC}
    0 - Success
    1 - No matches found or validation error
    2 - User cancelled operation
    3 - Permission denied (try sudo)

${BOLD}AUTHOR:${NC}
    Created for convenient file/folder management in Next.js projects

${BOLD}REPORT BUGS:${NC}
    Use 'df --help' for this guide anytime

EOF
}

# Function to check if running from root
check_root_directory() {
    if [[ "$PWD" == "/" ]] && [[ $EUID -ne 0 ]]; then
        echo -e "${RED}${BOLD}ERROR:${NC} Running from root directory requires sudo privileges"
        echo -e "Please run: ${YELLOW}sudo df${NC} $@"
        exit 3
    fi
}

# Function to check if file is in critical system path
is_critical_system_file() {
    local file=$1
    for path in "${CRITICAL_SYSTEM_PATHS[@]}"; do
        if [[ "$file" == "$path"* ]]; then
            return 0  # True - is critical
        fi
    done
    return 1  # False - not critical
}

# Function to check if file is in warning system path
is_warning_system_file() {
    local file=$1
    for path in "${WARNING_SYSTEM_PATHS[@]}"; do
        if [[ "$file" == "$path"* ]]; then
            return 0  # True - is warning level
        fi
    done
    return 1  # False - not warning level
}

# Function to categorize files by safety level
categorize_files() {
    local -n files_ref=$1
    local critical_files=()
    local warning_files=()
    local safe_files=()
    
    for file in "${files_ref[@]}"; do
        if is_critical_system_file "$file"; then
            critical_files+=("$file")
        elif is_warning_system_file "$file"; then
            warning_files+=("$file")
        else
            safe_files+=("$file")
        fi
    done
    
    echo "${#critical_files[@]}|${#warning_files[@]}|${#safe_files[@]}"
}

# Function to show critical system file warning
show_critical_warning() {
    local critical_count=$1
    local total_count=$2
    
    echo -e "\n${RED}${BOLD}${BLINK}🚨🚨🚨 CRITICAL DANGER WARNING 🚨🚨🚨${NC}"
    echo -e "${RED}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}${BOLD}You are about to delete ${critical_count} SYSTEM FILES!${NC}\n"
    
    echo -e "${YELLOW}${BOLD}CONSEQUENCES:${NC}"
    echo -e "${RED}⚠️  May break system boot${NC}"
    echo -e "${RED}⚠️  May break critical services (SSH, network, etc.)${NC}"
    echo -e "${RED}⚠️  May make the system unrecoverable${NC}"
    echo -e "${RED}⚠️  May require system reinstallation${NC}"
    echo -e "${RED}⚠️  BACKUPS ARE STRONGLY RECOMMENDED${NC}\n"
}

# Function to show system file breakdown
show_system_file_breakdown() {
    local -n files_ref=$1
    local -A path_counts
    
    for file in "${files_ref[@]}"; do
        if is_critical_system_file "$file"; then
            # Extract base system path
            for path in "${CRITICAL_SYSTEM_PATHS[@]}"; do
                if [[ "$file" == "$path"* ]]; then
                    ((path_counts["$path"]++))
                    break
                fi
            done
        fi
    done
    
    if [[ ${#path_counts[@]} -gt 0 ]]; then
        echo -e "${YELLOW}${BOLD}Critical system files detected in:${NC}"
        for path in "${!path_counts[@]}"; do
            echo -e "${RED}  $path (${path_counts[$path]} files)${NC}"
        done
        echo ""
    fi
}

# Function to require full confirmation for critical operations
require_critical_confirmation() {
    local critical_count=$1
    
    echo -e "${RED}${BOLD}To proceed, type exactly:${NC} ${YELLOW}YES DELETE SYSTEM FILES${NC}"
    read -p "> " confirmation
    
    if [[ "$confirmation" != "YES DELETE SYSTEM FILES" ]]; then
        echo -e "\n${GREEN}Operation cancelled. System is safe.${NC}"
        exit 2
    fi
}

# Function to parse size (e.g., 10M, 500K, 1G)
parse_size() {
    local size=$1
    local number="${size%[KMG]}"
    local unit="${size: -1}"
    
    case $unit in
        K|k) echo "$((number * 1024))" ;;
        M|m) echo "$((number * 1024 * 1024))" ;;
        G|g) echo "$((number * 1024 * 1024 * 1024))" ;;
        *) echo "$number" ;;
    esac
}

# Function to format size for display
format_size() {
    local bytes=$1
    if (( bytes >= 1073741824 )); then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1073741824}")G"
    elif (( bytes >= 1048576 )); then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1048576}")M"
    elif (( bytes >= 1024 )); then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1024}")K"
    else
        echo "${bytes}B"
    fi
}

# Function to calculate total size
calculate_total_size() {
    local files=("$@")
    local total=0
    
    for file in "${files[@]}"; do
        if [[ -e "$file" ]]; then
            local size=$(du -sb "$file" 2>/dev/null | cut -f1)
            total=$((total + size))
        fi
    done
    
    echo "$total"
}

# Function to build find command
build_find_command() {
    local pattern=$1
    local search_path=${2:-.}
    local find_cmd="find \"$search_path\""
    
    # Add type filter
    if [[ -n "$TYPE_FILTER" ]]; then
        find_cmd+=" -type $TYPE_FILTER"
    fi
    
    # Add empty directory filter
    if [[ "$EMPTY_DIRS" == true ]]; then
        find_cmd+=" -type d -empty"
    elif [[ -n "$pattern" ]]; then
        # Add name pattern
        if [[ "$IGNORE_CASE" == true ]]; then
            find_cmd+=" -iname \"$pattern\""
        else
            find_cmd+=" -name \"$pattern\""
        fi
    fi
    
    # Add age filter
    if [[ -n "$OLDER_THAN" ]]; then
        find_cmd+=" -mtime +$OLDER_THAN"
    fi
    
    # Add size filter
    if [[ -n "$LARGER_THAN" ]]; then
        local size_bytes=$(parse_size "$LARGER_THAN")
        find_cmd+=" -size +${size_bytes}c"
    fi
    
    # Add auto-exclude patterns
    if [[ "$AUTO_EXCLUDE" == true ]]; then
        for exclude in "${AUTO_EXCLUDE_PATTERNS[@]}"; do
            find_cmd+=" -not -path \"$exclude\""
        done
    fi
    
    echo "$find_cmd"
}

# Function to apply user exclusions
apply_exclusions() {
    local -n files_ref=$1
    local exclusions=$2
    local excluded_files=()
    local kept_files=()
    
    if [[ -z "$exclusions" ]]; then
        return
    fi
    
    # Split exclusions by comma
    IFS=',' read -ra EXCLUDE_PATTERNS <<< "$exclusions"
    
    for file in "${files_ref[@]}"; do
        local should_exclude=false
        
        for pattern in "${EXCLUDE_PATTERNS[@]}"; do
            # Trim whitespace
            pattern=$(echo "$pattern" | xargs)
            
            # Check if file matches exclusion pattern
            if [[ "$file" == $pattern ]]; then
                should_exclude=true
                excluded_files+=("$file")
                break
            fi
        done
        
        if [[ "$should_exclude" == false ]]; then
            kept_files+=("$file")
        fi
    done
    
    # Update the array
    files_ref=("${kept_files[@]}")
    
    # Print excluded files
    if [[ ${#excluded_files[@]} -gt 0 ]]; then
        echo -e "\n${GREEN}${BOLD}Excluded (${#excluded_files[@]} items):${NC}"
        for file in "${excluded_files[@]}"; do
            echo -e "${GREEN}  ✓ $file${NC}"
        done
    fi
}

# Parse command line arguments
PATTERN=""
SEARCH_PATH="."

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -i|--ignore-case)
            IGNORE_CASE=true
            shift
            ;;
        -t|--type)
            TYPE_FILTER="$2"
            if [[ "$TYPE_FILTER" != "f" && "$TYPE_FILTER" != "d" ]]; then
                echo -e "${RED}ERROR:${NC} Invalid type '$TYPE_FILTER'. Use 'f' for files or 'd' for directories"
                exit 1
            fi
            shift 2
            ;;
        -a|--all)
            AUTO_EXCLUDE=false
            shift
            ;;
        --show-size)
            SHOW_SIZE=true
            shift
            ;;
        --older-than)
            OLDER_THAN="$2"
            shift 2
            ;;
        --larger-than)
            LARGER_THAN="$2"
            shift 2
            ;;
        --empty-dirs)
            EMPTY_DIRS=true
            shift
            ;;
        --max-display)
            MAX_DISPLAY="$2"
            shift 2
            ;;
        -*)
            echo -e "${RED}ERROR:${NC} Unknown option: $1"
            echo "Use 'df --help' for usage information"
            exit 1
            ;;
        *)
            if [[ -z "$PATTERN" ]]; then
                PATTERN="$1"
            else
                SEARCH_PATH="$1"
            fi
            shift
            ;;
    esac
done

# Check root directory protection
check_root_directory "$@"

# Interactive mode if no pattern provided
if [[ -z "$PATTERN" ]] && [[ "$EMPTY_DIRS" == false ]]; then
    echo -e "${BOLD}${CYAN}df - Delete Folder/File${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    # Ask for search path first
    read -p "Enter path to search (default: current directory): " user_path

    if [[ -n "$user_path" ]]; then
        # Expand tilde to home directory
        user_path="${user_path/#\~/$HOME}"

        if [[ ! -d "$user_path" ]]; then
            echo -e "${RED}ERROR:${NC} Directory '$user_path' does not exist"
            exit 1
        fi
        SEARCH_PATH="$user_path"
    fi

    echo -e "${BLUE}Searching in:${NC} ${CYAN}$SEARCH_PATH${NC}\n"

    # Ask for pattern second
    read -p "Enter file/folder name or pattern to delete: " PATTERN

    if [[ -z "$PATTERN" ]]; then
        echo -e "${RED}ERROR:${NC} Pattern cannot be empty"
        exit 1
    fi
fi

# Build and execute find command
echo -e "\n${BLUE}${BOLD}Searching...${NC}"

find_cmd=$(build_find_command "$PATTERN" "$SEARCH_PATH")
mapfile -t matched_files < <(eval "$find_cmd" 2>/dev/null | sort)

# Check if any matches found
if [[ ${#matched_files[@]} -eq 0 ]]; then
    echo -e "${YELLOW}${BOLD}No matches found${NC} for pattern: ${CYAN}$PATTERN${NC}"
    if [[ "$AUTO_EXCLUDE" == true ]]; then
        echo -e "${YELLOW}Note:${NC} Auto-exclusions are enabled. Use ${CYAN}-a${NC} flag to disable."
    fi
    exit 1
fi

# Display matched files
total_matches=${#matched_files[@]}
echo -e "\n${BOLD}Found ${YELLOW}$total_matches${NC}${BOLD} matches:${NC}"

# Categorize files by safety level
IFS='|' read -r critical_count warning_count safe_count <<< "$(categorize_files matched_files)"

# Show safety summary
if [[ $critical_count -gt 0 ]]; then
    echo -e "${RED}${BOLD}  🚨 Critical system files: $critical_count${NC}"
fi
if [[ $warning_count -gt 0 ]]; then
    echo -e "${YELLOW}${BOLD}  ⚠️  Warning-level files: $warning_count${NC}"
fi
if [[ $safe_count -gt 0 ]]; then
    echo -e "${GREEN}${BOLD}  ✓ Safe files: $safe_count${NC}"
fi

if [[ $total_matches -gt $MAX_DISPLAY ]]; then
    echo -e "${YELLOW}(Showing first $MAX_DISPLAY out of $total_matches)${NC}\n"
    display_count=$MAX_DISPLAY
else
    echo ""
    display_count=$total_matches
fi

for ((i=0; i<display_count; i++)); do
    file="${matched_files[$i]}"
    
    # Color-code by safety level
    if is_critical_system_file "$file"; then
        icon="🚨"
        color="${RED}${BOLD}"
    elif is_warning_system_file "$file"; then
        icon="⚠️ "
        color="${YELLOW}"
    else
        icon="📄"
        color="${RED}"
    fi
    
    if [[ -d "$file" ]]; then
        echo -e "${color}  $icon $file/${NC}"
    else
        echo -e "${color}  $icon $file${NC}"
    fi
done

if [[ $total_matches -gt $MAX_DISPLAY ]]; then
    echo -e "\n${YELLOW}... and $((total_matches - MAX_DISPLAY)) more${NC}"
fi

# Check if user has permission to delete critical files
if [[ $critical_count -gt 0 ]] && [[ $EUID -ne 0 ]]; then
    echo -e "\n${RED}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}${BOLD}⚠️  DANGER: $critical_count files are CRITICAL SYSTEM FILES!${NC}"
    echo -e "${RED}${BOLD}❌ Cannot delete (insufficient permissions)${NC}"
    echo -e "${YELLOW}💡 Run with ${CYAN}sudo${YELLOW} if you really need to delete system files${NC}"
    echo -e "${RED}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    # Remove critical files from the list (user can't delete them anyway)
    filtered_files=()
    for file in "${matched_files[@]}"; do
        if ! is_critical_system_file "$file"; then
            filtered_files+=("$file")
        fi
    done
    matched_files=("${filtered_files[@]}")
    
    if [[ ${#matched_files[@]} -eq 0 ]]; then
        echo -e "${YELLOW}All matched files are system files. Nothing can be deleted without sudo.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Proceeding with ${#matched_files[@]} safe/warning-level files only...${NC}\n"
fi

# Calculate total size if requested
if [[ "$SHOW_SIZE" == true ]]; then
    echo -e "\n${BLUE}Calculating total size...${NC}"
    total_size=$(calculate_total_size "${matched_files[@]}")
    formatted_size=$(format_size "$total_size")
    echo -e "${BOLD}Total size:${NC} ${YELLOW}$formatted_size${NC}"
fi

# Ask for exclusions
if [[ "$FORCE" == false ]]; then
    echo -e "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Enter exclusion patterns${NC} (comma-separated, or press Enter to skip):"
    echo -e "${YELLOW}Examples:${NC} */origin-stack/*, important.txt, */node_modules/*"
    read -p "> " exclusions
    
    if [[ -n "$exclusions" ]]; then
        apply_exclusions matched_files "$exclusions"
    fi
fi

# Final count after exclusions
final_count=${#matched_files[@]}

if [[ $final_count -eq 0 ]]; then
    echo -e "\n${GREEN}${BOLD}All files excluded. Nothing to delete.${NC}"
    exit 0
fi

# Show what will be deleted
echo -e "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${RED}${BOLD}Will delete ${final_count} items:${NC}"

if [[ "$SHOW_SIZE" == true ]]; then
    total_size=$(calculate_total_size "${matched_files[@]}")
    formatted_size=$(format_size "$total_size")
    echo -e "${BOLD}Total size:${NC} ${YELLOW}$formatted_size${NC}\n"
else
    echo ""
fi

# Show sample of what will be deleted
sample_count=$((final_count > 10 ? 10 : final_count))
for ((i=0; i<sample_count; i++)); do
    file="${matched_files[$i]}"
    if [[ -d "$file" ]]; then
        echo -e "${RED}  📁 $file/${NC}"
    else
        echo -e "${RED}  📄 $file${NC}"
    fi
done

if [[ $final_count -gt 10 ]]; then
    echo -e "${YELLOW}  ... and $((final_count - 10)) more${NC}"
fi

# Dry-run mode
if [[ "$DRY_RUN" == true ]]; then
    echo -e "\n${YELLOW}${BOLD}DRY-RUN MODE:${NC} No files were deleted"
    echo -e "Remove ${CYAN}-n${NC} flag to actually delete these files"
    exit 0
fi

# Final confirmation
if [[ "$FORCE" == false ]]; then
    # Show critical warning if running as root with critical files
    if [[ $EUID -eq 0 ]]; then
        # Recount critical files after exclusions
        IFS='|' read -r critical_count warning_count safe_count <<< "$(categorize_files matched_files)"
        
        if [[ $critical_count -gt 0 ]]; then
            show_critical_warning "$critical_count" "$final_count"
            show_system_file_breakdown matched_files
            require_critical_confirmation "$critical_count"
        fi
    fi
    
    echo -e "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "$(echo -e ${RED}${BOLD}Proceed with deletion? \(y/N\):${NC} )" confirmation
    
    if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
        echo -e "\n${YELLOW}Operation cancelled${NC}"
        exit 2
    fi
fi

# Perform deletion with verbose output
echo -e "\n${BOLD}${RED}Deleting...${NC}\n"

deleted_count=0
failed_count=0

for file in "${matched_files[@]}"; do
    if [[ -e "$file" ]]; then
        if rm -rfv "$file" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Deleted: ${RED}$file${NC}"
            ((deleted_count++))
        else
            echo -e "${RED}✗${NC} Failed: $file ${YELLOW}(permission denied)${NC}"
            ((failed_count++))
        fi
    fi
done

# Summary
echo -e "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}✓ Deleted:${NC} $deleted_count items"

if [[ $failed_count -gt 0 ]]; then
    echo -e "${RED}${BOLD}✗ Failed:${NC} $failed_count items (try with sudo)"
fi

echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

exit 0
