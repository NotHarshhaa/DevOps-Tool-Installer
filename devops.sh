#!/bin/bash

# devops.sh - Enhanced DevOps Tool Manager by ProDevOpsGuy Tech

# Script Configuration
declare -A CONFIG=(
    ["VERSION"]="2.5.0"
    ["LOG_FILE"]="devops_manager.log"
    ["STATE_FILE"]="devops_state.json"
    ["INSTALL_SCRIPT"]="scripts/install_devops_tools.sh"
    ["UNINSTALL_SCRIPT"]="scripts/uninstall_devops_tools.sh"
    ["UPDATE_CHECK_URL"]="https://api.github.com/repos/notharshhaa/DevOps-Tool-Installer/releases/latest"
)

# Color codes and emojis
GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
CYAN="\033[0;36m"
RESET="\033[0m"
SUCCESS="${GREEN}✅${RESET}"
FAIL="${RED}❌${RESET}"
INFO="${BLUE}ℹ️${RESET}"
WARN="${YELLOW}⚠️${RESET}"

# Function: Initialize logging
init_logging() {
    exec 3>&1 4>&2
    trap 'exec 2>&4 1>&3' 0 1 2 3
    exec 1> >(tee -a "${CONFIG[LOG_FILE]}") 2>&1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - DevOps Tool Manager v${CONFIG[VERSION]} started"
}

# Function: Write log message
log() {
    local level=$1
    local msg=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    case $level in
        "INFO") echo -e "[$timestamp] ${INFO} $msg" ;;
        "SUCCESS") echo -e "[$timestamp] ${SUCCESS} $msg" ;;
        "ERROR") echo -e "[$timestamp] ${FAIL} $msg" ;;
        "WARN") echo -e "[$timestamp] ${WARN} $msg" ;;
    esac
}

# Function: Check for updates
check_updates() {
    log "INFO" "Checking for updates..."
    
    # Check required commands
    for cmd in curl jq sha256sum; do
        if ! command -v "$cmd" &> /dev/null; then
            log "ERROR" "$cmd is required for update checks"
            return 1
        fi
    done
    
    # Check with timeout
    local response
    if ! response=$(timeout 10 curl -s "${CONFIG[UPDATE_CHECK_URL]}"); then
        log "ERROR" "Failed to check for updates (timeout or connection error)"
        return 1
    fi
    
    # Parse version with error handling
    local latest_version
    if ! latest_version=$(echo "$response" | jq -r '.tag_name' 2>/dev/null | tr -d 'v'); then
        log "ERROR" "Failed to parse version information"
        return 1
    fi
    
    if [[ -n "$latest_version" ]]; then
        if [[ "$latest_version" > "${CONFIG[VERSION]}" ]]; then
            log "WARN" "New version available: v$latest_version"
            read -rp "Would you like to update? (y/n): " choice
            if [[ "$choice" == "y" ]]; then
                update_script "$latest_version"
            fi
        else
            log "SUCCESS" "You are running the latest version"
        fi
    else
        log "ERROR" "Failed to check for updates"
    fi
}

# Function: Update script
update_script() {
    local version=$1
    local temp_dir
    local checksum
    
    log "INFO" "Updating to version $version..."
    
    # Create temporary directory
    temp_dir=$(mktemp -d)
    trap 'rm -rf "$temp_dir"' EXIT
    
    # Download new version
    local download_url="https://github.com/notharshhaa/DevOps-Tool-Installer/archive/v${version}.tar.gz"
    if ! curl -L "$download_url" -o "$temp_dir/update.tar.gz"; then
        log "ERROR" "Failed to download update"
        return 1
    fi
    
    # Verify checksum
    if ! checksum=$(curl -s "https://github.com/notharshhaa/DevOps-Tool-Installer/releases/download/v${version}/SHA256SUMS"); then
        log "ERROR" "Failed to download checksum"
        return 1
    fi
    
    if ! echo "$checksum" | sha256sum -c --status; then
        log "ERROR" "Checksum verification failed"
        return 1
    fi
    
    # Backup current version
    local backup_dir="backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    cp -r * "$backup_dir/"
    
    # Extract and update
    if ! tar xzf "$temp_dir/update.tar.gz" --strip-components=1; then
        log "ERROR" "Failed to extract update"
        # Restore from backup
        cp -r "$backup_dir"/* ./
        return 1
    fi
    
    log "SUCCESS" "Update completed successfully"
    log "INFO" "Previous version backed up in: $backup_dir"
}

# Function: Show banner
show_banner() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════╗"
    echo -e "║                                                                        ║"
    echo -e "║        🚀 DevOps Tool Manager v${CONFIG[VERSION]} by ProDevOpsGuy Tech         ║"
    echo -e "║                                                                        ║"
    echo -e "╚════════════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "Features:"
    echo -e "  ✨ Easy installation and uninstallation of DevOps tools"
    echo -e "  ✨ Automatic updates and version management"
    echo -e "  ✨ Parallel installation support"
    echo -e "  ✨ Multiple package manager support"
    echo -e "  ✨ Installation state tracking"
    echo -e "  ✨ Container-based installation options"
    echo ""
}

# Function: Show menu
show_menu() {
    echo -e "${YELLOW}📦 What would you like to do?${RESET}"
    echo ""
    echo -e "  ${GREEN}[1] ➕ Install DevOps Tools${RESET}"
    echo -e "  ${RED}[2] ➖ Uninstall DevOps Tools${RESET}"
    echo -e "  ${YELLOW}[3] 🔄 Check for Updates${RESET}"
    echo -e "  ${BLUE}[4] 📊 View Installation Status${RESET}"
    echo -e "  ${CYAN}[5] ❌ Exit${RESET}"
    echo ""
}

# Function: Show installation status with validation
show_installation_status() {
    if [[ ! -f "${CONFIG[STATE_FILE]}" ]]; then
        log "WARN" "No installation state found"
        return 0
    fi
    
    # Validate JSON format
    if ! jq empty "${CONFIG[STATE_FILE]}" 2>/dev/null; then
        log "ERROR" "Invalid state file format"
        return 1
    fi
    
    echo -e "\n${BLUE}📊 Installation Status:${RESET}"
    echo "═══════════════════════════════════════════"
    
    # Read state file with error handling
    while IFS= read -r line; do
        if ! tool=$(echo "$line" | jq -r 'keys[]' 2>/dev/null); then
            continue
        fi
        if ! status=$(echo "$line" | jq -r ".[\"$tool\"].status" 2>/dev/null); then
            continue
        fi
        if ! date=$(echo "$line" | jq -r ".[\"$tool\"].date" 2>/dev/null); then
            continue
        fi
        
        case "$status" in
            "installed") status_color=$GREEN ;;
            "failed") status_color=$RED ;;
            *) status_color=$YELLOW ;;
        esac
        
        printf "%-30s ${status_color}%-15s${RESET} %-25s\n" "$tool" "$status" "$date"
    done < <(jq -c '.[]' "${CONFIG[STATE_FILE]}" 2>/dev/null)
    
    echo "═══════════════════════════════════════════"
    echo ""
}

# Function: Run script with timeout
run_script() {
    local script=$1
    local script_type=$2
    local timeout_duration=3600  # 1 hour timeout
    
    if [[ ! -f "$script" ]]; then
        log "ERROR" "$script_type script not found at: $script"
        return 1
    fi
    
    if [[ ! -x "$script" ]]; then
        log "ERROR" "$script_type script is not executable"
        return 1
    fi
    
    log "INFO" "Launching $script_type script..."
    if timeout $timeout_duration bash "$script"; then
        log "SUCCESS" "$script_type completed successfully"
        return 0
    else
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            log "ERROR" "$script_type timed out after ${timeout_duration}s"
        else
            log "ERROR" "$script_type failed with exit code $exit_code"
        fi
        return 1
    fi
}

# Function: Wait for keypress
wait_for_keypress() {
    echo ""
    read -n 1 -s -r -p "Press any key to continue..."
    echo ""
}

# Main program
init_logging
check_updates

while true; do
    show_banner
    show_menu
    
    read -rp "👉 Enter your choice (1-5): " choice
    echo ""
    
    case "$choice" in
        1)
            run_script "${CONFIG[INSTALL_SCRIPT]}" "Installer"
            wait_for_keypress
            ;;
        2)
            run_script "${CONFIG[UNINSTALL_SCRIPT]}" "Uninstaller"
            wait_for_keypress
            ;;
        3)
            check_updates
            wait_for_keypress
            ;;
        4)
            show_installation_status
            wait_for_keypress
            ;;
        5)
            echo -e "\n👋 ${GREEN}Exiting... Have a productive DevOps day!${RESET}"
            exit 0
            ;;
        *)
            log "ERROR" "Invalid choice. Please select a number between 1 and 5."
            wait_for_keypress
            ;;
    esac
done
