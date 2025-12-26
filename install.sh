#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# GitHub repository details (user will need to update these)
GITHUB_USER="YOUR_USERNAME"
GITHUB_REPO="delf"
GITHUB_BRANCH="main"
SCRIPT_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/refs/heads/${GITHUB_BRANCH}/delf.sh"

# Log file location
LOG_DIR="$HOME/.delf"
LOG_FILE="$LOG_DIR/install.log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR" 2>/dev/null || true

# Logging function
log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" >> "$LOG_FILE"
}

# Status printing functions (apt-style)
print_status() {
    local status="$1"
    local message="$2"
    case $status in
        "ok")
            echo -e "${GREEN}[${BOLD}✓${NC}${GREEN}]${NC} $message"
            log "[OK] $message"
            ;;
        "info")
            echo -e "${CYAN}[${BOLD}*${NC}${CYAN}]${NC} $message"
            log "[INFO] $message"
            ;;
        "warn")
            echo -e "${YELLOW}[${BOLD}!${NC}${YELLOW}]${NC} $message"
            log "[WARN] $message"
            ;;
        "error")
            echo -e "${RED}[${BOLD}✗${NC}${RED}]${NC} $message"
            log "[ERROR] $message"
            ;;
        "step")
            echo -e "${BLUE}${BOLD}==>${NC} $message"
            log "[STEP] $message"
            ;;
    esac
}

# Progress indicator (apt-style)
progress() {
    local message="$1"
    echo -ne "${message}..."
    log "$message"
}

progress_done() {
    echo -e " ${GREEN}Done${NC}"
    log "Done"
}

# Header
log "========================================="
log "DELF Installation Started"
log "========================================="

echo -e "${BOLD}${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║${NC}   ${BOLD}DELF Installer${NC}                     ${BOLD}${CYAN}║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""

# Function to install to user bin
install_user() {
    BIN_DIR="$HOME/.local/bin"
    local IS_UPDATE=false

    print_step "User Installation"
    echo ""

    # Check if already installed
    if [ -f "$BIN_DIR/delf" ]; then
        IS_UPDATE=true
        print_status "info" "Package 'delf' is already installed"
        print_status "info" "Preparing to upgrade delf..."
        log "Action: UPDATE"
    else
        print_status "info" "Preparing to install delf..."
        log "Action: FRESH INSTALL"
    fi

    log "Installation Location: $BIN_DIR"

    # Create directory
    progress "Creating directories"
    mkdir -p "$BIN_DIR"
    progress_done
    log "Created/Verified directory: $BIN_DIR"

    # Download
    print_status "step" "Fetching delf from repository..."
    progress "  Downloading $SCRIPT_URL"
    log "Downloading from: $SCRIPT_URL"

    if command -v curl &> /dev/null; then
        if curl -sSL "$SCRIPT_URL" -o "$BIN_DIR/delf" 2>/dev/null; then
            progress_done
            log "Download method: curl"
        else
            echo -e " ${RED}Failed${NC}"
            print_status "error" "Download failed"
            log "ERROR: Download failed (curl)"
            exit 1
        fi
    elif command -v wget &> /dev/null; then
        if wget -q "$SCRIPT_URL" -O "$BIN_DIR/delf" 2>/dev/null; then
            progress_done
            log "Download method: wget"
        else
            echo -e " ${RED}Failed${NC}"
            print_status "error" "Download failed"
            log "ERROR: Download failed (wget)"
            exit 1
        fi
    else
        echo ""
        print_status "error" "Neither curl nor wget found. Please install one of them."
        log "ERROR: No download tool available (curl/wget)"
        exit 1
    fi

    # Set permissions
    progress "Setting up delf"
    chmod +x "$BIN_DIR/delf"
    progress_done
    log "Made executable: $BIN_DIR/delf"

    # Configure PATH
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        progress "Configuring environment (PATH)"

        if ! grep -q "export PATH=\"\$HOME/.local/bin:\$PATH\"" "$HOME/.bashrc" 2>/dev/null; then
            echo '' >> "$HOME/.bashrc"
            echo '# Added by delf installer' >> "$HOME/.bashrc"
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
            progress_done
            log "Added PATH to ~/.bashrc"
        else
            progress_done
            log "PATH already in ~/.bashrc (skipped)"
        fi
    else
        log "$BIN_DIR already in PATH"
    fi

    echo ""
    if [ "$IS_UPDATE" = true ]; then
        print_status "ok" "delf upgraded successfully"
        log "User upgrade completed successfully"
    else
        print_status "ok" "delf installed successfully"
        log "User installation completed successfully"
    fi

    print_status "info" "Location: $BIN_DIR/delf"
    echo ""
    print_status "warn" "Please run: ${BOLD}source ~/.bashrc${NC}"
    print_status "warn" "Or restart your terminal to use: ${BOLD}${GREEN}delf${NC}"
}

# Function to install system-wide
install_system() {
    BIN_DIR="/usr/local/bin"
    local IS_UPDATE=false

    print_step "System-Wide Installation"
    echo ""

    # Check if already installed
    if [ -f "$BIN_DIR/delf" ]; then
        IS_UPDATE=true
        print_status "info" "Package 'delf' is already installed (system-wide)"
        print_status "info" "Preparing to upgrade delf..."
        log "Action: UPDATE (SYSTEM-WIDE)"
    else
        print_status "info" "Preparing to install delf (system-wide)..."
        log "Action: FRESH INSTALL (SYSTEM-WIDE)"
    fi

    log "Installation Location: $BIN_DIR"
    print_status "warn" "Root privileges required"
    log "Requesting sudo privileges"

    # Download to temp
    TMP_FILE=$(mktemp)
    print_status "step" "Fetching delf from repository..."
    progress "  Downloading $SCRIPT_URL"
    log "Downloading from: $SCRIPT_URL"
    log "Temporary file: $TMP_FILE"

    if command -v curl &> /dev/null; then
        if curl -sSL "$SCRIPT_URL" -o "$TMP_FILE" 2>/dev/null; then
            progress_done
            log "Download method: curl"
        else
            echo -e " ${RED}Failed${NC}"
            print_status "error" "Download failed"
            log "ERROR: Download failed (curl)"
            exit 1
        fi
    elif command -v wget &> /dev/null; then
        if wget -q "$SCRIPT_URL" -O "$TMP_FILE" 2>/dev/null; then
            progress_done
            log "Download method: wget"
        else
            echo -e " ${RED}Failed${NC}"
            print_status "error" "Download failed"
            log "ERROR: Download failed (wget)"
            exit 1
        fi
    else
        echo ""
        print_status "error" "Neither curl nor wget found. Please install one of them."
        log "ERROR: No download tool available (curl/wget)"
        exit 1
    fi

    # Install with sudo
    progress "Setting up delf (requires sudo)"
    sudo mv "$TMP_FILE" "$BIN_DIR/delf"
    sudo chmod +x "$BIN_DIR/delf"
    progress_done
    log "Moved to system bin with sudo"
    log "Made executable: $BIN_DIR/delf"

    echo ""
    if [ "$IS_UPDATE" = true ]; then
        print_status "ok" "delf upgraded successfully (system-wide)"
        log "System-wide upgrade completed successfully"
    else
        print_status "ok" "delf installed successfully (system-wide)"
        log "System-wide installation completed successfully"
    fi

    print_status "info" "Location: $BIN_DIR/delf"
    print_status "info" "Available to all users"
}

print_step() {
    echo -e "${BOLD}${BLUE}▸ $1${NC}"
}

# Main installation menu
print_step "Installation Type"
echo ""
echo "  1) User installation (~/.local/bin)"
echo "     └─ No sudo required, current user only"
echo ""
echo "  2) System installation (/usr/local/bin)"
echo "     └─ Requires sudo, available to all users"
echo ""
echo "  3) Both locations"
echo "     └─ Install to both user and system directories"
echo ""
read -p "Enter choice [1-3]: " choice
echo ""

log "User selected option: $choice"

case $choice in
    1)
        log "Installing to user directory only"
        install_user
        ;;
    2)
        log "Installing to system directory only"
        install_system
        ;;
    3)
        log "Installing to both user and system directories"
        install_user
        echo ""
        install_system
        ;;
    *)
        print_status "error" "Invalid choice. Exiting."
        log "ERROR: Invalid choice ($choice)"
        exit 1
        ;;
esac

# Summary
echo ""
echo -e "${BOLD}${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║${NC}   ${GREEN}${BOLD}Installation Complete!${NC}             ${BOLD}${CYAN}║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""
print_status "info" "Usage: ${BOLD}${GREEN}delf${NC} (run as user)"
print_status "info" "Usage: ${BOLD}${GREEN}sudo delf${NC} (run with root privileges)"
echo ""
print_status "info" "Installation log: ${CYAN}$LOG_FILE${NC}"
echo ""

log "========================================="
log "DELF Installation Finished Successfully"
log "========================================="
