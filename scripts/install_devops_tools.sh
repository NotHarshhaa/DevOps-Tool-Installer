#!/bin/bash

# install_devops_tools.sh - Enhanced DevOps Tool Manager by ProDevOpsGuy Tech
set -e

# Script Configuration
declare -A CONFIG=(
    ["LOG_FILE"]="install_devops_tools.log"
    ["STATE_FILE"]="install_state.json"
    ["PARALLEL_INSTALL"]="true"
    ["MAX_PARALLEL_JOBS"]=3
    ["CHECK_SYSTEM_REQUIREMENTS"]="true"
    ["CONTAINER_INSTALL"]="false"
    ["VERSION"]="2.5.0"
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
    exec 1> >(tee -a "$LOG_FILE") 2>&1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - DevOps Tool Installer v${CONFIG[VERSION]} started"
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

# Function: Check system requirements
check_system_requirements() {
    log "INFO" "Checking system requirements..."
    
    # Check disk space (10GB minimum)
    local free_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$free_space" -lt 10 ]; then
        log "ERROR" "Insufficient disk space. At least 10GB required, found ${free_space}GB"
        return 1
    fi
    
    # Check memory (2GB minimum)
    local total_mem=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$total_mem" -lt 2 ]; then
        log "ERROR" "Insufficient memory. At least 2GB required, found ${total_mem}GB"
        return 1
    fi
    
    # Check internet connectivity with timeout
    if ! timeout 10 ping -c 1 8.8.8.8 &> /dev/null; then
        log "ERROR" "No internet connection"
        return 1
    fi
    
    # Check if running as root or with sudo
    if [ "$EUID" -ne 0 ] && ! sudo -n true 2>/dev/null; then
        log "ERROR" "Root privileges required"
        return 1
    fi
    
    # Check for required commands
    for cmd in curl wget jq; do
        if ! command -v "$cmd" &> /dev/null; then
            log "ERROR" "Required command not found: $cmd"
            return 1
        fi
    done
    
    log "SUCCESS" "System requirements check passed"
    return 0
}

# Function: Initialize package managers
init_package_managers() {
    log "INFO" "Initializing package managers..."
    
    # Detect OS and package manager
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
    else
        OS=$(uname -s)
    fi

    case "$OS" in
        ubuntu|debian|zorin)
            PKG_MANAGER="apt-get"
            sudo $PKG_MANAGER update
            ;;
        centos|rhel|fedora|amazon)
            PKG_MANAGER="yum"
            sudo $PKG_MANAGER check-update || true
            ;;
        arch)
            PKG_MANAGER="pacman"
            sudo $PKG_MANAGER -Sy
            ;;
        opensuse|sles)
            PKG_MANAGER="zypper"
            sudo $PKG_MANAGER refresh
            ;;
        alpine)
            PKG_MANAGER="apk"
            sudo $PKG_MANAGER update
            ;;
        *)
            log "ERROR" "Unsupported OS: $OS"
            return 1
            ;;
    esac
    
    # Check for alternative package managers
    if command -v snap >/dev/null 2>&1; then
        HAS_SNAP=true
        log "INFO" "Snap package manager detected"
    fi
    
    if command -v flatpak >/dev/null 2>&1; then
        HAS_FLATPAK=true
        log "INFO" "Flatpak package manager detected"
    fi
    
    return 0
}

# Function: Load installation state
load_state() {
    if [ -f "${CONFIG[STATE_FILE]}" ]; then
        log "INFO" "Loading installation state..."
        cat "${CONFIG[STATE_FILE]}"
    else
        echo "{}"
    fi
}

# Function: Save installation state with lock file
save_state() {
    local state=$1
    local lock_file="${CONFIG[STATE_FILE]}.lock"
    local max_attempts=5
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if mkdir "$lock_file" 2>/dev/null; then
            echo "$state" > "${CONFIG[STATE_FILE]}"
            rmdir "$lock_file"
            log "SUCCESS" "Installation state saved"
            return 0
        else
            sleep 1
            ((attempt++))
        fi
    done
    
    log "ERROR" "Failed to acquire lock for state file"
    return 1
}

# Function: Show banner
show_banner() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════╗"
    echo -e "║                                                                        ║"
    echo -e "║        🚀 DevOps Tool Installer v${CONFIG[VERSION]} by ProDevOpsGuy Tech         ║"
    echo -e "║                                                                        ║"
    echo -e "╚════════════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "Features:"
    echo -e "  ✨ Multi-package manager support (native, snap, flatpak)"
    echo -e "  ✨ Parallel installation support"
    echo -e "  ✨ Tool health checks and validation"
    echo -e "  ✨ Installation state persistence"
    echo -e "  ✨ Container-based installation option"
    echo -e "  ✨ Advanced error handling and logging"
    echo ""
}

# Function: Show tools menu
show_tools_menu() {
    echo -e "\n${YELLOW}🔧 Available Tools:${RESET}\n"
    
    declare -A TOOL_CATEGORIES=(
        ["Containerization & Orchestration"]="docker kubernetes-cli minikube helm istio"
        ["Infrastructure as Code"]="terraform ansible packer vagrant"
        ["CI/CD & Version Control"]="jenkins gitlab-runner git"
        ["Cloud Providers"]="aws-cli azure-cli google-cloud-sdk"
        ["Monitoring & Observability"]="prometheus grafana"
        ["Service Mesh & Discovery"]="vault consul"
    )
    
    local index=1
    declare -A TOOL_MAP
    
    for category in "${!TOOL_CATEGORIES[@]}"; do
        echo -e "\n${CYAN}[$category]${RESET}"
        for tool in ${TOOL_CATEGORIES[$category]}; do
            echo -e "${GREEN}[$index] $tool${RESET}"
            TOOL_MAP[$index]=$tool
            ((index++))
        done
    done
    
    echo -e "\n${YELLOW}Enter tool numbers (comma-separated) or 'all' to install everything:${RESET}"
    read -r selection
    
    echo "$selection:${TOOL_MAP[@]}"
}

# Function: Validate tool installation
validate_tool() {
    local tool=$1
    log "INFO" "Validating installation of $tool..."
    
    case $tool in
        docker)
            docker --version >/dev/null 2>&1
            ;;
        kubernetes-cli)
            kubectl version --client >/dev/null 2>&1
            ;;
        terraform)
            terraform --version >/dev/null 2>&1
            ;;
        ansible)
            ansible --version >/dev/null 2>&1
            ;;
        aws-cli)
            aws --version >/dev/null 2>&1
            ;;
        azure-cli)
            az --version >/dev/null 2>&1
            ;;
        *)
            command -v "$tool" >/dev/null 2>&1
            ;;
    esac
    
    local status=$?
    if [ $status -eq 0 ]; then
        log "SUCCESS" "$tool validated successfully"
        return 0
    else
        log "ERROR" "$tool validation failed"
        return 1
    fi
}

# Function: Install tool with timeout
install_tool() {
    local tool=$1
    local install_method=${2:-"native"}
    local timeout_duration=300  # 5 minutes timeout
    
    log "INFO" "Installing $tool using $install_method method..."
    
    # Create a temporary file for the installation output
    local temp_output=$(mktemp)
    
    case $install_method in
        "native")
            timeout $timeout_duration install_native "$tool" > "$temp_output" 2>&1
            ;;
        "snap")
            timeout $timeout_duration install_snap "$tool" > "$temp_output" 2>&1
            ;;
        "flatpak")
            timeout $timeout_duration install_flatpak "$tool" > "$temp_output" 2>&1
            ;;
        "container")
            timeout $timeout_duration install_container "$tool" > "$temp_output" 2>&1
            ;;
        *)
            log "ERROR" "Unknown installation method: $install_method"
            rm -f "$temp_output"
            return 1
            ;;
    esac
    
    local exit_code=$?
    if [ $exit_code -eq 124 ]; then
        log "ERROR" "Installation of $tool timed out after ${timeout_duration}s"
        cat "$temp_output"
        rm -f "$temp_output"
        return 1
    elif [ $exit_code -ne 0 ]; then
        log "ERROR" "Installation of $tool failed"
        cat "$temp_output"
        rm -f "$temp_output"
        return 1
    fi
    
    rm -f "$temp_output"
    return 0
}

# Function: Native package installation
install_native() {
    local tool=$1
    
    case $tool in
        docker)
            case $PKG_MANAGER in
                apt-get)
                    curl -fsSL https://get.docker.com -o get-docker.sh
                    sudo sh get-docker.sh
                    ;;
                yum)
                    sudo yum install -y docker
                    sudo systemctl start docker
                    sudo systemctl enable docker
                    ;;
                *)
                    sudo $PKG_MANAGER install -y docker
                    ;;
            esac
            ;;
        kubernetes-cli)
            case $PKG_MANAGER in
                apt-get)
                    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
                    ;;
                yum)
                    cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
                    sudo yum install -y kubectl
                    ;;
                *)
                    log "ERROR" "Unsupported package manager for kubernetes-cli"
                    return 1
                    ;;
            esac
            ;;
        # Add more tool-specific installation logic here
        *)
            sudo $PKG_MANAGER install -y "$tool"
            ;;
    esac
}

# Function: Snap package installation
install_snap() {
    local tool=$1
    if [ "$HAS_SNAP" = true ]; then
        sudo snap install "$tool"
    else
        log "ERROR" "Snap is not available"
        return 1
    fi
}

# Function: Flatpak package installation
install_flatpak() {
    local tool=$1
    if [ "$HAS_FLATPAK" = true ]; then
        flatpak install -y flathub "$tool"
    else
        log "ERROR" "Flatpak is not available"
        return 1
    fi
}

# Function: Container-based installation
install_container() {
    local tool=$1
    
    if ! command -v docker >/dev/null 2>&1; then
        log "ERROR" "Docker is required for container-based installation"
        return 1
    fi
    
    case $tool in
        jenkins)
            docker run -d --name jenkins -p 8080:8080 -p 50000:50000 jenkins/jenkins:lts
            ;;
        grafana)
            docker run -d --name grafana -p 3000:3000 grafana/grafana
            ;;
        prometheus)
            docker run -d --name prometheus -p 9090:9090 prom/prometheus
            ;;
        *)
            log "ERROR" "No container configuration available for $tool"
            return 1
            ;;
    esac
}

# Function: Install tools in parallel
install_tools_parallel() {
    local tools=("$@")
    local pids=()
    local running=0
    
    for tool in "${tools[@]}"; do
        # Wait if we've reached max parallel jobs
        while [ $running -ge "${CONFIG[MAX_PARALLEL_JOBS]}" ]; do
            for pid in "${pids[@]}"; do
                if ! kill -0 $pid 2>/dev/null; then
                    running=$((running - 1))
                fi
            done
            sleep 1
        done
        
        # Start installation in background
        install_tool "$tool" &
        pids+=($!)
        running=$((running + 1))
    done
    
    # Wait for all installations to complete
    for pid in "${pids[@]}"; do
        wait $pid
    done
}

# Function: Clean up temporary files
cleanup_temp_files() {
    log "INFO" "Cleaning up temporary files..."
    rm -f get-docker.sh
    rm -f kubectl
    # Add more temporary files as needed
}

# Main function
main() {
    init_logging
    show_banner
    
    if [ "${CONFIG[CHECK_SYSTEM_REQUIREMENTS]}" = "true" ]; then
        check_system_requirements || exit 1
    fi
    
    init_package_managers || exit 1
    
    # Load existing state
    local state=$(load_state)
    
    # Show tool menu and get selection
    local selection_output=$(show_tools_menu)
    local selection=$(echo "$selection_output" | cut -d: -f1)
    local tool_map=$(echo "$selection_output" | cut -d: -f2-)
    
    local tools_to_install=()
    if [ "$selection" = "all" ]; then
        tools_to_install=($tool_map)
    else
        IFS=',' read -ra selected_numbers <<< "$selection"
        for num in "${selected_numbers[@]}"; do
            tool=${tool_map[$num]}
            if [ -n "$tool" ]; then
                tools_to_install+=("$tool")
            fi
        done
    fi
    
    if [ ${#tools_to_install[@]} -eq 0 ]; then
        log "ERROR" "No valid tools selected"
        exit 1
    fi
    
    log "INFO" "Installing ${#tools_to_install[@]} tools..."
    
    # Install tools
    if [ "${CONFIG[PARALLEL_INSTALL]}" = "true" ]; then
        install_tools_parallel "${tools_to_install[@]}"
    else
        for tool in "${tools_to_install[@]}"; do
            install_tool "$tool"
        done
    fi
    
    # Validate installations
    log "INFO" "Validating installations..."
    for tool in "${tools_to_install[@]}"; do
        if validate_tool "$tool"; then
            # Update state
            state=$(echo "$state" | jq --arg tool "$tool" --arg date "$(date '+%Y-%m-%d %H:%M:%S')" \
                '. + {($tool): {"status": "installed", "date": $date}}')
        else
            state=$(echo "$state" | jq --arg tool "$tool" --arg date "$(date '+%Y-%m-%d %H:%M:%S')" \
                '. + {($tool): {"status": "failed", "date": $date}}')
        fi
    done
    
    # Save final state
    save_state "$state"
    
    log "SUCCESS" "Installation process completed"
    echo -e "\n${GREEN}✨ Installation process completed. Check ${CONFIG[LOG_FILE]} for details.${RESET}"
}

# Add trap for cleanup
trap cleanup_temp_files EXIT

# Execute main function
main "$@"
