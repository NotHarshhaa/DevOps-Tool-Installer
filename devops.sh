#!/bin/bash

# devops.sh - Enhanced DevOps Tool Manager by ProDevOpsGuy Tech

# Script Configuration
# Get the script directory path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

declare -A CONFIG=(
    ["VERSION"]="3.0.0"
    ["LOG_FILE"]="$SCRIPT_DIR/logs/devops_manager.log"
    ["STATE_FILE"]="$SCRIPT_DIR/state/devops_state.json"
    ["INSTALL_SCRIPT"]="$SCRIPT_DIR/scripts/install_devops_tools.sh"
    ["UNINSTALL_SCRIPT"]="$SCRIPT_DIR/scripts/uninstall_devops_tools.sh"
    ["UPDATE_CHECK_URL"]="https://api.github.com/repos/notharshhaa/DevOps-Tool-Installer/releases/latest"
    ["BACKUP_DIR"]="$SCRIPT_DIR/backups"
    ["CONFIG_DIR"]="$SCRIPT_DIR/config"
)

# Color codes and emojis
GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
CYAN="\033[0;36m"
PURPLE="\033[0;35m"
RESET="\033[0m"
SUCCESS="${GREEN}✅${RESET}"
FAIL="${RED}❌${RESET}"
INFO="${BLUE}ℹ️${RESET}"
WARN="${YELLOW}⚠️${RESET}"

# Function: Create required directories
create_required_dirs() {
    local dirs=("logs" "state" "backups" "config" "scripts")
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$SCRIPT_DIR/$dir" ]]; then
            mkdir -p "$SCRIPT_DIR/$dir"
            log "INFO" "Created directory: $SCRIPT_DIR/$dir"
        fi
    done
}

# Function: Initialize logging
init_logging() {
    # Create log directory if it doesn't exist
    local log_dir=$(dirname "${CONFIG[LOG_FILE]}")
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir"
    fi

    # Rotate logs if they get too large (>10MB)
    if [[ -f "${CONFIG[LOG_FILE]}" ]] && [[ $(stat -c%s "${CONFIG[LOG_FILE]}") -gt 10485760 ]]; then
        mv "${CONFIG[LOG_FILE]}" "${CONFIG[LOG_FILE]}.$(date +%Y%m%d_%H%M%S).bak"
        log "INFO" "Log file rotated due to size"
    fi

    # Start logging
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

# Function: Check requirements
check_requirements() {
    local required_tools=("curl" "jq" "sha256sum" "tar")
    local missing_tools=()

    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log "WARN" "Missing required tools: ${missing_tools[*]}"
        echo -e "\n${YELLOW}The following required tools are missing:${RESET} ${missing_tools[*]}"
        echo -e "${YELLOW}Would you like to install them now? (y/n)${RESET}"
        read -r choice
        if [[ "$choice" == "y" ]]; then
            install_required_tools "${missing_tools[@]}"
        else
            log "ERROR" "Required tools missing. Some features may not work correctly."
            echo -e "${YELLOW}Warning: Some features may not work correctly without these tools.${RESET}"
            sleep 2
        fi
    fi
}

# Function: Install required tools
install_required_tools() {
    local tools=("$@")
    local pkg_manager

    # Detect package manager
    if command -v apt-get &> /dev/null; then
        pkg_manager="apt-get -y install"
    elif command -v yum &> /dev/null; then
        pkg_manager="yum -y install"
    elif command -v dnf &> /dev/null; then
        pkg_manager="dnf -y install"
    elif command -v pacman &> /dev/null; then
        pkg_manager="pacman -Sy --noconfirm"
    elif command -v zypper &> /dev/null; then
        pkg_manager="zypper -n install"
    else
        log "ERROR" "Could not determine package manager"
        echo -e "${RED}Could not determine package manager.${RESET}"
        return 1
    fi

    # Map tool names to package names if necessary
    declare -A pkg_map=(
        ["jq"]="jq"
        ["curl"]="curl"
        ["sha256sum"]="coreutils"
        ["tar"]="tar"
    )

    log "INFO" "Installing required tools using $pkg_manager"
    for tool in "${tools[@]}"; do
        local package=${pkg_map[$tool]:-$tool}
        echo -e "${BLUE}Installing $tool...${RESET}"
        if ! eval "sudo $pkg_manager $package"; then
            log "ERROR" "Failed to install $tool"
            echo -e "${RED}Failed to install $tool.${RESET}"
        else
            log "SUCCESS" "Installed $tool"
        fi
    done
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

    if [[ -z "$latest_version" ]]; then
        log "ERROR" "Failed to check for updates"
        return 1
    fi

    if [[ "$latest_version" > "${CONFIG[VERSION]}" ]]; then
        log "WARN" "New version available: v$latest_version"
        echo -e "\n${GREEN}New version available: v$latest_version${RESET}"
        echo -e "${YELLOW}Would you like to update? (y/n):${RESET}"
        read -rp "" choice
        if [[ "$choice" == "y" ]]; then
            update_script "$latest_version"
        fi
    else
        log "SUCCESS" "You are running the latest version"
        echo -e "\n${GREEN}You are running the latest version.${RESET}"
    fi

    return 0
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

    echo -e "${BLUE}Downloading update...${RESET}"

    # Download new version
    local download_url="https://github.com/notharshhaa/DevOps-Tool-Installer/archive/v${version}.tar.gz"
    if ! curl -L "$download_url" -o "$temp_dir/update.tar.gz"; then
        log "ERROR" "Failed to download update"
        echo -e "${RED}Failed to download update.${RESET}"
        return 1
    fi

    echo -e "${BLUE}Verifying download...${RESET}"

    # Try to verify checksum if available
    if curl -s "https://github.com/notharshhaa/DevOps-Tool-Installer/releases/download/v${version}/SHA256SUMS" -o "$temp_dir/SHA256SUMS" 2>/dev/null; then
        pushd "$temp_dir" > /dev/null || return 1
        if ! sha256sum -c --status SHA256SUMS 2>/dev/null; then
            log "WARN" "Checksum verification failed or not available"
            echo -e "${YELLOW}Checksum verification failed or not available.${RESET}"
            echo -e "${YELLOW}Continue anyway? (y/n):${RESET}"
            read -rp "" choice
            if [[ "$choice" != "y" ]]; then
                popd > /dev/null || true
                return 1
            fi
        fi
        popd > /dev/null || true
    else
        log "WARN" "Checksum file not available. Skipping verification."
    fi

    # Backup current version
    local backup_dir="${CONFIG[BACKUP_DIR]}/backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    find . -maxdepth 1 -not -path "./.*" -not -path "." -exec cp -r {} "$backup_dir/" \;
    log "INFO" "Backed up current version to $backup_dir"

    echo -e "${BLUE}Installing update...${RESET}"

    # Extract and update
    if ! tar xzf "$temp_dir/update.tar.gz" --strip-components=1 -C .; then
        log "ERROR" "Failed to extract update"
        echo -e "${RED}Failed to extract update.${RESET}"
        echo -e "${YELLOW}Restoring from backup...${RESET}"

        # Restore from backup
        find "$backup_dir" -mindepth 1 -maxdepth 1 -exec cp -r {} . \;
        log "WARN" "Restored from backup"
        echo -e "${GREEN}Restored from backup.${RESET}"
        return 1
    fi

    # Update configuration file with new version
    CONFIG["VERSION"]="$version"

    log "SUCCESS" "Update completed successfully"
    echo -e "${GREEN}Update completed successfully.${RESET}"
    echo -e "${BLUE}Previous version backed up in: $backup_dir${RESET}"

    # Restart the script to use the new version
    echo -e "${YELLOW}Restarting script to use the new version...${RESET}"
    sleep 2
    exec "$0"
}

# Function: Initialize state file
init_state_file() {
    local state_dir=$(dirname "${CONFIG[STATE_FILE]}")
    if [[ ! -d "$state_dir" ]]; then
        mkdir -p "$state_dir"
    fi

    if [[ ! -f "${CONFIG[STATE_FILE]}" ]]; then
        echo '[]' > "${CONFIG[STATE_FILE]}"
        log "INFO" "Initialized empty state file"
    fi
}

# Function: Show banner
show_banner() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════╗"
    echo -e "║                                                                        ║"
    echo -e "║             🚀 DevOps Tool Manager v${CONFIG[VERSION]} by ProDevOpsGuy Tech         ║"
    echo -e "║                                                                        ║"
    echo -e "╚════════════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "${PURPLE}Features:${RESET}"
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
    echo -e "  ${PURPLE}[5] 🔧 System Information${RESET}"
    echo -e "  ${CYAN}[6] ❌ Exit${RESET}"
    echo ""
}

# Function: Show system information
show_system_info() {
    echo -e "\n${PURPLE}🔧 System Information:${RESET}"
    echo "═══════════════════════════════════════════"

    # OS Info
    echo -e "${CYAN}OS Information:${RESET}"
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo -e "  Name: ${GREEN}$NAME${RESET}"
        echo -e "  Version: ${GREEN}$VERSION_ID${RESET}"
        echo -e "  ID: ${GREEN}$ID${RESET}"
    else
        echo -e "  OS: ${GREEN}$(uname -s)${RESET}"
        echo -e "  Version: ${GREEN}$(uname -r)${RESET}"
    fi

    # Hardware Info
    echo -e "\n${CYAN}Hardware Information:${RESET}"
    echo -e "  CPU: ${GREEN}$(grep "model name" /proc/cpuinfo | head -n1 | cut -d':' -f2 | sed 's/^ *//')${RESET}"
    echo -e "  CPU Cores: ${GREEN}$(grep -c processor /proc/cpuinfo)${RESET}"
    echo -e "  Memory: ${GREEN}$(free -h | grep Mem | awk '{print $2}')${RESET}"
    echo -e "  Disk Space: ${GREEN}$(df -h / | awk 'NR==2 {print $2}')${RESET} (Total), ${GREEN}$(df -h / | awk 'NR==2 {print $4}')${RESET} (Available)"

    # Package Managers
    echo -e "\n${CYAN}Available Package Managers:${RESET}"
    for pm in apt-get yum dnf pacman zypper apk; do
        if command -v "$pm" &> /dev/null; then
            echo -e "  ${GREEN}✓${RESET} $pm"
        else
            echo -e "  ${RED}✗${RESET} $pm"
        fi
    done

    # DevOps Tools Manager Info
    echo -e "\n${CYAN}DevOps Tool Manager:${RESET}"
    echo -e "  Version: ${GREEN}v${CONFIG[VERSION]}${RESET}"
    echo -e "  Log File: ${GREEN}${CONFIG[LOG_FILE]}${RESET}"
    echo -e "  State File: ${GREEN}${CONFIG[STATE_FILE]}${RESET}"

    echo "═══════════════════════════════════════════"
    echo ""
}

# Function: Show installation status with validation
show_installation_status() {
    if [[ ! -f "${CONFIG[STATE_FILE]}" ]]; then
        log "WARN" "No installation state found"
        echo -e "\n${YELLOW}No installation state found.${RESET}"
        return 0
    fi

    # Validate JSON format
    if ! jq empty "${CONFIG[STATE_FILE]}" 2>/dev/null; then
        log "ERROR" "Invalid state file format"
        echo -e "\n${RED}Invalid state file format. Recreating...${RESET}"
        echo '[]' > "${CONFIG[STATE_FILE]}"
        return 1
    fi

    echo -e "\n${BLUE}📊 Installation Status:${RESET}"
    echo "═══════════════════════════════════════════"

    # Count installed tools
    local total=$(jq '. | length' "${CONFIG[STATE_FILE]}")
    local installed=$(jq '[.[] | select(.status == "installed")] | length' "${CONFIG[STATE_FILE]}")
    local failed=$(jq '[.[] | select(.status == "failed")] | length' "${CONFIG[STATE_FILE]}")

    echo -e "${CYAN}Summary:${RESET} ${GREEN}$installed${RESET} tools installed, ${RED}$failed${RESET} failed, ${BLUE}$total${RESET} total"
    echo ""

    # Table header
    printf "%-30s %-15s %-25s %-20s\n" "Tool" "Status" "Date" "Version"
    echo "────────────────────────────────────────────────────────────────────────────────"

    # Read state file with error handling
    while IFS= read -r line; do
        if ! tool=$(echo "$line" | jq -r '.name' 2>/dev/null); then
            continue
        fi
        if ! status=$(echo "$line" | jq -r '.status' 2>/dev/null); then
            continue
        fi
        if ! date=$(echo "$line" | jq -r '.date' 2>/dev/null); then
            continue
        fi
        if ! version=$(echo "$line" | jq -r '.version // "N/A"' 2>/dev/null); then
            version="N/A"
        fi

        case "$status" in
            "installed") status_color=$GREEN ;;
            "failed") status_color=$RED ;;
            *) status_color=$YELLOW ;;
        esac

        printf "%-30s ${status_color}%-15s${RESET} %-25s %-20s\n" "$tool" "$status" "$date" "$version"
    done < <(jq -c '.[]' "${CONFIG[STATE_FILE]}" 2>/dev/null)

    echo "═══════════════════════════════════════════"
    echo ""
}

# Function: Run script with timeout - Note: Now we use direct exec instead of this in main code
run_script() {
    local script=$1
    local script_type=$2
    local timeout_duration=3600  # 1 hour timeout

    if [[ ! -f "$script" ]]; then
        log "ERROR" "$script_type script not found at: $script"
        echo -e "${RED}$script_type script not found at: $script${RESET}"
        return 1
    fi

    if [[ ! -x "$script" ]]; then
        log "WARN" "$script_type script is not executable. Adding execute permission."
        chmod +x "$script"
    fi

    log "INFO" "Launching $script_type script..."
    echo -e "${BLUE}Launching $script_type script...${RESET}"

    # Direct execution to preserve terminal interaction
    (exec "$script")
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        log "SUCCESS" "$script_type completed successfully"
        echo -e "${GREEN}$script_type completed successfully${RESET}"
        return 0
    else
        log "ERROR" "$script_type failed with exit code $exit_code"
        echo -e "${RED}$script_type failed with exit code $exit_code${RESET}"
        return 1
    fi
}

# Function: Wait for keypress
wait_for_keypress() {
    echo ""
    read -n 1 -s -r -p "Press any key to continue..."
    echo ""
}

# Function: Shutdown
shutdown() {
    log "INFO" "Shutting down DevOps Tool Manager"
    echo -e "\n👋 ${GREEN}Exiting... Have a productive DevOps day!${RESET}"
    exit 0
}

# Handle interrupts gracefully
trap shutdown SIGINT SIGTERM

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${RESET}"
    echo -e "Please run with: ${GREEN}sudo $0${RESET}"
    exit 1
fi

# Make sure scripts are executable
for script in "${CONFIG[INSTALL_SCRIPT]}" "${CONFIG[UNINSTALL_SCRIPT]}"; do
    if [[ ! -x "$script" && -f "$script" ]]; then
        chmod +x "$script"
        log "INFO" "Made script executable: $script"
    fi
done

# Change to script directory to ensure relative paths work
cd "$SCRIPT_DIR" || {
    echo "Failed to change directory to $SCRIPT_DIR"
    exit 1
}

# Main program
create_required_dirs
init_logging
init_state_file
check_requirements
check_updates

while true; do
    show_banner
    show_menu

    read -rp "👉 Enter your choice (1-6): " choice
    echo ""

    case "$choice" in
        1)
            log "INFO" "Starting installer..."
            # Execute the script directly with terminal interaction
            if [[ -x "${CONFIG[INSTALL_SCRIPT]}" ]]; then
                # Preserve terminal interactions by using exec
                (exec "${CONFIG[INSTALL_SCRIPT]}")
                status=$?
                if [ $status -ne 0 ]; then
                    log "ERROR" "Installation failed with exit code $status. Check the logs for details."
                    echo -e "${RED}Installation failed with exit code $status. Check the logs for details.${RESET}"
                fi
            else
                log "ERROR" "Installer script not executable: ${CONFIG[INSTALL_SCRIPT]}"
                echo -e "${RED}Installer script not executable: ${CONFIG[INSTALL_SCRIPT]}${RESET}"
                chmod +x "${CONFIG[INSTALL_SCRIPT]}" 2>/dev/null
                if [ $? -eq 0 ]; then
                    # Try again with executable permission
                    (exec "${CONFIG[INSTALL_SCRIPT]}")
                fi
            fi
            wait_for_keypress
            ;;
        2)
            log "INFO" "Starting uninstaller..."
            # Execute the script directly with terminal interaction
            if [[ -x "${CONFIG[UNINSTALL_SCRIPT]}" ]]; then
                # Preserve terminal interactions by using exec
                (exec "${CONFIG[UNINSTALL_SCRIPT]}")
                status=$?
                if [ $status -ne 0 ]; then
                    log "ERROR" "Uninstallation failed with exit code $status. Check the logs for details."
                    echo -e "${RED}Uninstallation failed with exit code $status. Check the logs for details.${RESET}"
                fi
            else
                log "ERROR" "Uninstaller script not executable: ${CONFIG[UNINSTALL_SCRIPT]}"
                echo -e "${RED}Uninstaller script not executable: ${CONFIG[UNINSTALL_SCRIPT]}${RESET}"
                chmod +x "${CONFIG[UNINSTALL_SCRIPT]}" 2>/dev/null
                if [ $? -eq 0 ]; then
                    # Try again with executable permission
                    (exec "${CONFIG[UNINSTALL_SCRIPT]}")
                fi
            fi
            wait_for_keypress
            ;;
        3)
            log "INFO" "Checking for updates..."
            if ! check_updates; then
                log "ERROR" "Update check failed."
                echo -e "${RED}Update check failed.${RESET}"
            fi
            wait_for_keypress
            ;;
        4)
            log "INFO" "Showing installation status..."
            if ! show_installation_status; then
                log "ERROR" "Failed to show installation status."
                echo -e "${RED}Failed to show installation status.${RESET}"
            fi
            wait_for_keypress
            ;;
        5)
            log "INFO" "Showing system information..."
            show_system_info
            wait_for_keypress
            ;;
        6)
            shutdown
            ;;
        *)
            log "ERROR" "Invalid choice. Please select a number between 1 and 6."
            echo -e "${RED}Invalid choice. Please select a number between 1 and 6.${RESET}"
            wait_for_keypress
            ;;
    esac
done
