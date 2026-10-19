#!/bin/bash

# install_devops_tools.sh - Enhanced DevOps Tool Installer by ProDevOpsGuy Tech
# Version 3.5.0

# Don't exit on errors immediately to allow for better error handling
set +e
# Propagate the real exit code of pipelines (won't be masked by tee, grep, etc.)
# so installation failures are correctly detected instead of silently succeeding.
set -o pipefail
shopt -s inherit_errexit 2>/dev/null || true

# Script Configuration
# Get the script directory path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

declare -A CONFIG=(
    ["LOG_DIR"]="$ROOT_DIR/logs/install"
    ["LOG_FILE"]="$ROOT_DIR/logs/install/install_$(date +%Y%m%d_%H%M%S).log"
    ["STATE_FILE"]="$ROOT_DIR/state/devops_state.json"
    ["PARALLEL_INSTALL"]="true"
    ["MAX_PARALLEL_JOBS"]=4
    ["CHECK_SYSTEM_REQUIREMENTS"]="true"
    ["CONTAINER_INSTALL"]="false"
    ["TIMEOUT"]=1800
    ["VERSION"]="3.5.0"
    ["BACKUP_CONFIG"]="true"
    ["CONFIG_DIR"]="$ROOT_DIR/config"
    ["DEBUG"]="true"
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

# Note: root privileges are enforced in main() (after argument parsing) so that
# read-only modes (-h/--help, -l/--list, -d/--dry-run) run without elevation,
# mirroring the PowerShell installer.

# Create required directories
create_required_dirs() {
    local log_dir=$(dirname "${CONFIG[LOG_FILE]}")
    local state_dir=$(dirname "${CONFIG[STATE_FILE]}")
    local config_dir="${CONFIG[CONFIG_DIR]}"

    for dir in "$log_dir" "$state_dir" "$config_dir"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log "INFO" "Created directory: $dir"
        fi
    done
}

# Log function
log() {
    local level=$1
    local msg=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Create log directory if it doesn't exist
    local log_dir=$(dirname "${CONFIG[LOG_FILE]}")
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir"
    fi

    case $level in
        "INFO") echo -e "[$timestamp] ${INFO} $msg" | tee -a "${CONFIG[LOG_FILE]}" ;;
        "SUCCESS") echo -e "[$timestamp] ${SUCCESS} $msg" | tee -a "${CONFIG[LOG_FILE]}" ;;
        "ERROR") echo -e "[$timestamp] ${FAIL} $msg" | tee -a "${CONFIG[LOG_FILE]}" ;;
        "WARN") echo -e "[$timestamp] ${WARN} $msg" | tee -a "${CONFIG[LOG_FILE]}" ;;
        "DEBUG")
            if [[ "${CONFIG[DEBUG]}" == "true" ]]; then
                echo -e "[$timestamp] DEBUG: $msg" | tee -a "${CONFIG[LOG_FILE]}"
            fi
            ;;
    esac
}

# Initialize the state file if it doesn't exist
init_state_file() {
    local state_dir=$(dirname "${CONFIG[STATE_FILE]}")
    if [[ ! -d "$state_dir" ]]; then
        mkdir -p "$state_dir"
    fi

    if [[ ! -f "${CONFIG[STATE_FILE]}" ]]; then
        echo '[]' > "${CONFIG[STATE_FILE]}"
        log "INFO" "Initialized empty state file"
    else
        # Validate JSON format
        if ! jq empty "${CONFIG[STATE_FILE]}" 2>/dev/null; then
            log "ERROR" "Invalid state file format. Creating new one."
            echo '[]' > "${CONFIG[STATE_FILE]}"
        fi
    fi
}

# Internal helper: perform one atomic state update
_perform_state_update() {
    local tool=$1
    local status=$2
    local version=$3
    local date=$4

    # Check if the tool already exists in the state file
    local exists=$(jq -r --arg tool "$tool" '.[] | select(.name == $tool) | .name' "${CONFIG[STATE_FILE]}" 2>/dev/null)

    if [[ -n "$exists" ]]; then
        # Update existing entry
        jq --arg tool "$tool" --arg status "$status" --arg date "$date" --arg version "$version" \
           '[.[] | if .name == $tool then {name: $tool, status: $status, date: $date, version: $version} else . end]' \
           "${CONFIG[STATE_FILE]}" > "${CONFIG[STATE_FILE]}.tmp.$$"
    else
        # Add new entry
        jq --arg tool "$tool" --arg status "$status" --arg date "$date" --arg version "$version" \
           '. += [{name: $tool, status: $status, date: $date, version: $version}]' \
           "${CONFIG[STATE_FILE]}" > "${CONFIG[STATE_FILE]}.tmp.$$"
    fi

    if [[ $? -eq 0 ]]; then
        # Atomically replace the original file (unique tmp name avoids clashes
        # when tools are installed in parallel)
        mv "${CONFIG[STATE_FILE]}.tmp.$$" "${CONFIG[STATE_FILE]}"
    else
        rm -f "${CONFIG[STATE_FILE]}.tmp.$$" 2>/dev/null || true
        log "WARN" "Failed to update state for $tool"
    fi
}

# Update the state file with installation status
# Uses flock when available so parallel installs don't corrupt the state JSON
update_state() {
    local tool=$1
    local status=$2
    local version=$3
    local date=$(date '+%Y-%m-%d %H:%M:%S')

    if command -v flock >/dev/null 2>&1; then
        (
            flock -x 200
            _perform_state_update "$tool" "$status" "$version" "$date"
        ) 200>"${CONFIG[STATE_FILE]}.lock"
    else
        _perform_state_update "$tool" "$status" "$version" "$date"
    fi
}

# Remove old installer logs so they don't grow forever
cleanup_old_logs() {
    local log_dir
    log_dir=$(dirname "${CONFIG[LOG_FILE]}")

    # Keep only the newest 5 root-level run logs
    find "$log_dir" -maxdepth 1 -name 'install_*.log' 2>/dev/null | sort | tail -n +6 | xargs -r rm -f 2>/dev/null

    # Per-tool subdirectories - keep the newest 5 logs per tool
    find "$log_dir" -mindepth 2 -type d 2>/dev/null | while read -r tool_log_dir; do
        find "$tool_log_dir" -maxdepth 1 -name 'install_*.log' 2>/dev/null | sort | tail -n +6 | xargs -r rm -f 2>/dev/null
    done
}

# Print the tool catalog in a stable order (used by -l/--list)
list_tool_catalog() {
    echo -e "\n${YELLOW}🔧 Available Tools:${RESET}\n"
    local idx=1
    local sorted_categories=()
    mapfile -t sorted_categories < <(printf '%s\n' "${!TOOL_CATEGORIES[@]}" | sort)
    for category in "${sorted_categories[@]}"; do
        echo -e "${CYAN}[$category]${RESET}"
        for tool in ${TOOL_CATEGORIES[$category]}; do
            printf "  [${GREEN}%2d${RESET}] %s\n" "$idx" "$tool"
            ((idx++))
        done
    done
    echo ""
}

# Usage help for command line install mode
usage_install_sh() {
    echo -e "${CYAN}Usage: $0 [options]${RESET}"
    echo ""
    echo -e "Options:"
    echo -e "  ${GREEN}-l, --list${RESET}              List available tools and exit"
    echo -e "  ${GREEN}-i, --install LIST${RESET}      Comma/space separated tools to install (non-interactive)"
    echo -e "  ${GREEN}-a, --all${RESET}               Install every tool in the catalog (non-interactive)"
    echo -e "  ${GREEN}-s, --sequential${RESET}        Force sequential installation"
    echo -e "  ${GREEN}-p, --parallel${RESET}          Force parallel installation (default for multiple tools)"
    echo -e "  ${GREEN}-j, --jobs N${RESET}            Max parallel jobs (default ${CONFIG[MAX_PARALLEL_JOBS]})"
    echo -e "  ${GREEN}-d, --dry-run${RESET}           Show what would be installed without changing anything"
    echo -e "  ${GREEN}-r, --retry-failed${RESET}      Reinstall tools that previously failed (from the state file)"
    echo -e "  ${GREEN}-U, --upgrade${RESET}           Upgrade installed tools only (a tool that is not installed is skipped)"
    echo -e "  ${GREEN}    --from FILE${RESET}         Install tools listed in a profile file (see profiles/)"
    echo -e "  ${GREEN}    --skip-requirements${RESET} Skip the interactive system requirements check"
    echo -e "  ${YELLOW}-h, --help${RESET}              Show this help message"
}

# Detect OS and package manager
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        OS=$(uname -s)
        VERSION=$(uname -r)
    fi

    case "$OS" in
        ubuntu | debian | zorin)
            PKG_MANAGER="apt-get"
            PKG_UPDATE="apt-get update"
            PKG_INSTALL="apt-get install -y"
            ;;
        centos | rhel | fedora | amazon)
            if [[ -x "$(command -v dnf)" ]]; then
                PKG_MANAGER="dnf"
                PKG_UPDATE="dnf check-update"
                PKG_INSTALL="dnf install -y"
            else
                PKG_MANAGER="yum"
                PKG_UPDATE="yum check-update"
                PKG_INSTALL="yum install -y"
            fi
            ;;
        arch)
            PKG_MANAGER="pacman"
            PKG_UPDATE="pacman -Sy"
            PKG_INSTALL="pacman -S --noconfirm"
            ;;
        opensuse | sles)
            PKG_MANAGER="zypper"
            PKG_UPDATE="zypper refresh"
            PKG_INSTALL="zypper install -y"
            ;;
        alpine)
            PKG_MANAGER="apk"
            PKG_UPDATE="apk update"
            PKG_INSTALL="apk add"
            ;;
        *)
            log "ERROR" "Unsupported OS: $OS"
            echo -e "${RED}Unsupported OS: $OS${RESET}"
            exit 1
            ;;
    esac

    log "INFO" "Detected OS: $OS $VERSION, using package manager: $PKG_MANAGER"
    echo -e "${INFO} Detected OS: ${GREEN}$OS $VERSION${RESET}, using package manager: ${GREEN}$PKG_MANAGER${RESET}"
}

# Install base requirements for all installations
install_base_requirements() {
    log "INFO" "Installing base requirements for all tools..."
    echo -e "${INFO} Installing base requirements for all tools..."

    # Essential packages for most installations, per package manager
    case "$PKG_MANAGER" in
        apt-get)
            local base_packages="apt-transport-https ca-certificates curl wget gnupg lsb-release software-properties-common unzip"
            echo -e "${INFO} Installing: $base_packages"
            if apt-get update && apt-get install -y $base_packages; then
                log "SUCCESS" "Installed base requirements"
                echo -e "${SUCCESS} Installed base requirements"
            else
                log "ERROR" "Failed to install some base requirements"
                echo -e "${WARN} Failed to install some base requirements, but continuing anyway"
            fi
            # Make sure certificates are up to date
            update-ca-certificates --fresh || true
            ;;
        dnf|yum)
            if $PKG_MANAGER install -y ca-certificates curl wget gnupg2 unzip tar; then
                log "SUCCESS" "Installed base requirements"
                echo -e "${SUCCESS} Installed base requirements"
            else
                log "WARN" "Failed to install some base requirements, but continuing anyway"
                echo -e "${WARN} Failed to install some base requirements, but continuing anyway"
            fi
            ;;
        pacman)
            pacman -Sy --noconfirm --needed ca-certificates curl wget gnupg unzip tar || {
                log "WARN" "Failed to install some base requirements, but continuing anyway"
                echo -e "${WARN} Failed to install some base requirements, but continuing anyway"
            }
            ;;
        zypper)
            zypper install -y ca-certificates curl wget gpg2 unzip tar || {
                log "WARN" "Failed to install some base requirements, but continuing anyway"
                echo -e "${WARN} Failed to install some base requirements, but continuing anyway"
            }
            ;;
        apk)
            apk add --no-cache ca-certificates curl wget gnupg unzip tar || {
                log "WARN" "Failed to install some base requirements, but continuing anyway"
                echo -e "${WARN} Failed to install some base requirements, but continuing anyway"
            }
            ;;
    esac

    # Create common directories
    mkdir -p /etc/apt/keyrings
}

# Check system requirements
check_system_requirements() {
    log "INFO" "Checking system requirements..."
    echo -e "${INFO} Checking system requirements..."

    # Check disk space (need at least 10GB free)
    local free_space=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
    if [[ "$free_space" -lt 10 ]]; then
        log "WARN" "Low disk space: ${free_space}GB available. Some tools may require more space."
        echo -e "${WARN} Low disk space: ${free_space}GB available. Some tools may require more space."
        read -p "Continue anyway? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "INFO" "Installation aborted by user due to low disk space."
            exit 1
        fi
    else
        log "SUCCESS" "Disk space check passed: ${free_space}GB available"
    fi

    # Check memory (need at least 2GB)
    local total_mem=$(free -m | awk '/^Mem:/{print $2}')
    if [[ "$total_mem" -lt 2048 ]]; then
        log "WARN" "Low memory: ${total_mem}MB available. Some tools may require more memory."
        echo -e "${WARN} Low memory: ${total_mem}MB available. Some tools may require more memory."
        read -p "Continue anyway? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "INFO" "Installation aborted by user due to low memory."
            exit 1
        fi
    else
        log "SUCCESS" "Memory check passed: ${total_mem}MB available"
    fi

    # Check for required commands
    local required_cmds=("curl" "wget" "jq" "tar" "git")
    local missing_cmds=()

    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_cmds+=("$cmd")
        fi
    done

    if [[ ${#missing_cmds[@]} -gt 0 ]]; then
        log "WARN" "Missing required commands: ${missing_cmds[*]}"
        echo -e "${WARN} Missing required commands: ${missing_cmds[*]}"
        echo -e "${INFO} Installing missing commands..."

        # Install missing commands (script already runs as root - no sudo needed,
        # and sudo may not even exist in minimal container images)
        for cmd in "${missing_cmds[@]}"; do
            echo -e "${INFO} Installing $cmd..."
            if $PKG_INSTALL "$cmd"; then
                log "SUCCESS" "Installed $cmd"
            else
                log "ERROR" "Failed to install $cmd"
                echo -e "${FAIL} Failed to install $cmd. This might cause issues."
            fi
        done
    else
        log "SUCCESS" "All required commands are available"
    fi

    # Install base requirements
    install_base_requirements
}

# Update package repositories
update_package_repositories() {
    log "INFO" "Updating package repositories..."
    echo -e "${INFO} Updating package repositories..."

    # Package-manager strings (e.g. 'dnf check-update') are executed through a
    # controlled shell so they parse correctly.
    # Running as root already, so no sudo.
    if ! bash -c "$PKG_UPDATE"; then
        log "WARN" "Failed to update package repositories. Continuing anyway."
        echo -e "${WARN} Failed to update package repositories. Continuing anyway."
    else
        log "SUCCESS" "Package repositories updated successfully"
        echo -e "${SUCCESS} Package repositories updated successfully"
    fi
}

# Install tool function
install_tool() {
    local tool=$1
    local install_cmd=$2
    local verify_cmd=$3
    local version_cmd=$4

    # Add TLS 1.2 support for secure connections
    export SSL_VERSION="TLSv1.2"
    export SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"
    
    log "INFO" "Installing $tool..."
    echo -e "\n${INFO} Installing ${CYAN}$tool${RESET}..."

    # Check if already installed - SECURE VERSION
    if bash -c "$verify_cmd" >/dev/null 2>&1; then
        local version=$(bash -c "$version_cmd" 2>/dev/null || echo "Unknown")
        if [[ "${CONFIG[UPGRADE]:-false}" == "true" ]]; then
            log "INFO" "$tool is installed (version: $version) - upgrading"
            echo -e "${INFO} $tool is installed (version: ${YELLOW}$version${RESET}) - upgrading..."
        else
            log "SUCCESS" "$tool is already installed (version: $version)"
            echo -e "${SUCCESS} $tool is already installed (version: ${GREEN}$version${RESET})"
            update_state "$tool" "installed" "$version"
            return 0
        fi
    elif [[ "${CONFIG[UPGRADE]:-false}" == "true" ]]; then
        # Upgrade mode leaves tools that are not installed alone
        log "INFO" "$tool is not installed - skipped in upgrade mode"
        echo -e "${INFO} $tool is not installed - skipped (upgrade mode)"
        return 0
    fi

    # Dry run: report the plan without changing anything
    if [[ "${CONFIG[DRY_RUN]}" == "true" ]]; then
        local action_word="installed"
        [[ "${CONFIG[UPGRADE]:-false}" == "true" ]] && action_word="upgraded"
        log "INFO" "[DRY RUN] $tool would be $action_word with the following commands:"
        echo -e "${WARN} [DRY RUN] $tool would be $action_word with the following commands:"
        echo -e "  ${YELLOW}${INSTALL_CMDS[$tool]}${RESET}"
        return 0
    fi

    # Create a temporary script for this installation with better error handling
    local temp_script=$(mktemp)
    cat > "$temp_script" << 'EOF'
#!/bin/bash
# Enhanced installation script with error handling
set -x  # Print commands for debugging
# Temporarily disable error handling to allow for better debugging
# We'll check exit codes manually

# Make sure PATH includes common directories
export PATH=$PATH:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin

# Function to run commands with error checking
run_cmd() {
    echo "RUNNING: $*"
    "$@"
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "ERROR: Command failed with exit code $exit_code: $*"
        return $exit_code
    fi
    return 0
}

# No trap - we want to see all errors

# Run installation commands
EOF

    # Add the installation command with full logging
    echo "echo \"Starting installation of $tool...\"" >> "$temp_script"
    echo "echo \"Running installation commands...\"" >> "$temp_script"
    # We need to make sure we use explicit commands and avoid pipe errors
    echo "${INSTALL_CMDS[$tool]}" >> "$temp_script"
    echo "echo \"Installation commands completed successfully\"" >> "$temp_script"
    chmod +x "$temp_script"

    log "DEBUG" "Running installation script for $tool using temporary script"

    # Log the command that will be executed for debugging
    log "DEBUG" "Command to execute: ${INSTALL_CMDS[$tool]}"
    echo -e "${CYAN}Executing installation commands...${RESET}"

    # Install with timeout and capture output.
    # Capture the *installer's* exit code via PIPESTATUS - a pipeline's status is
    # normally tee's, which always succeeds and masked installation failures.
    local output_file=$(mktemp)
    echo -e "${CYAN}Running installation script for $tool...${RESET}"
    echo -e "${CYAN}See live output below:${RESET}"
    echo -e "${YELLOW}----------------------------------------${RESET}"
    timeout "${CONFIG[TIMEOUT]}" bash "$temp_script" 2>&1 | tee "$output_file"
    local exit_code=${PIPESTATUS[0]}
    echo -e "${YELLOW}----------------------------------------${RESET}"

    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}Installation commands completed successfully${RESET}"
        rm -f "$temp_script" "$output_file"

        # Verify installation
        if bash -c "$verify_cmd" &>/dev/null; then
            local version=$(bash -c "$version_cmd" 2>/dev/null || echo "Unknown")
            log "SUCCESS" "$tool installed successfully (version: $version)"
            echo -e "${SUCCESS} $tool installed successfully (version: ${GREEN}$version${RESET})"
            update_state "$tool" "installed" "$version"
            return 0
        else
            log "ERROR" "$tool installation verification failed"
            echo -e "${FAIL} $tool installation verification failed. Commands completed but verification failed."
            update_state "$tool" "failed" "Unknown"
            return 1
        fi
    else
        # Show error output
        echo -e "${RED}Installation failed with output:${RESET}"
        cat "$output_file"
        rm -f "$temp_script" "$output_file"

        if [[ $exit_code -eq 124 ]]; then
            log "ERROR" "$tool installation timed out after ${CONFIG[TIMEOUT]}s"
            echo -e "${FAIL} $tool installation timed out after ${CONFIG[TIMEOUT]}s"
        else
            log "ERROR" "$tool installation failed with exit code $exit_code"
            echo -e "${FAIL} $tool installation failed with exit code $exit_code"
        fi
        update_state "$tool" "failed" "N/A"
        return 1
    fi
}

# Define tool installation commands, verification commands, and version commands
declare -A INSTALL_CMDS=(
    [docker]="apt-get update && apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release && mkdir -p /etc/apt/keyrings && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && echo \"deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null && apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io && systemctl enable --now docker"
    [kubernetes-cli]="curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && echo \"deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /\" | tee /etc/apt/sources.list.d/kubernetes.list && apt-get update && apt-get install -y kubectl"
    [ansible]="$PKG_UPDATE && $PKG_INSTALL ansible"
    [terraform]="wget -O /tmp/hashicorp.gpg https://apt.releases.hashicorp.com/gpg && gpg --dearmor < /tmp/hashicorp.gpg > /usr/share/keyrings/hashicorp-archive-keyring.gpg && rm -f /tmp/hashicorp.gpg && echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main\" > /etc/apt/sources.list.d/hashicorp.list && apt-get update && apt-get install -y terraform"
    [helm]="curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
    [aws-cli]="apt-get update && apt-get install -y unzip && curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"/tmp/awscliv2.zip\" && unzip -q /tmp/awscliv2.zip -d /tmp/aws-install && /tmp/aws-install/aws/install && rm -rf /tmp/awscliv2.zip /tmp/aws-install"
    [azure-cli]="apt-get update && apt-get install -y ca-certificates curl apt-transport-https lsb-release gnupg && mkdir -p /etc/apt/keyrings && curl -sLS https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/keyrings/microsoft.gpg > /dev/null && echo \"deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main\" | tee /etc/apt/sources.list.d/azure-cli.list > /dev/null && apt-get update && apt-get install -y azure-cli"
    [google-cloud-sdk]="apt-get update && apt-get install -y apt-transport-https ca-certificates gnupg curl && mkdir -p /etc/apt/keyrings && curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /etc/apt/keyrings/cloud.google.gpg && echo \"deb [signed-by=/etc/apt/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main\" | tee /etc/apt/sources.list.d/google-cloud-sdk.list > /dev/null && apt-get update && apt-get install -y google-cloud-cli"
    [grafana]="apt-get update && apt-get install -y apt-transport-https software-properties-common wget && mkdir -p /etc/apt/keyrings && wget -q -O /etc/apt/keyrings/grafana.key https://apt.grafana.com/gpg.key && echo \"deb [signed-by=/etc/apt/keyrings/grafana.key] https://apt.grafana.com stable main\" | tee /etc/apt/sources.list.d/grafana.list > /dev/null && apt-get update && apt-get install -y grafana && systemctl enable grafana-server && systemctl start grafana-server"
    [gitlab-runner]="curl -L \"https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh\" | bash && apt-get install -y gitlab-runner && gitlab-runner start"
    [istio]="curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.22.3 sh - && mv istio-1.22.3/bin/istioctl /usr/local/bin/ && rm -rf istio-1.22.3"
    [minikube]="apt-get update && apt-get install -y curl && curl -Lo /tmp/minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && chmod +x /tmp/minikube && mv /tmp/minikube /usr/local/bin/"
    [packer]="wget -O /tmp/hashicorp.gpg https://apt.releases.hashicorp.com/gpg && gpg --dearmor < /tmp/hashicorp.gpg > /usr/share/keyrings/hashicorp-archive-keyring.gpg && rm -f /tmp/hashicorp.gpg && echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main\" > /etc/apt/sources.list.d/hashicorp.list && apt-get update && apt-get install -y packer"
    [jenkins]="apt-get update && apt-get install -y openjdk-17-jdk gnupg && curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | gpg --dearmor -o /usr/share/keyrings/jenkins-keyring.gpg && echo \"deb [signed-by=/usr/share/keyrings/jenkins-keyring.gpg] https://pkg.jenkins.io/debian-stable binary/\" | tee /etc/apt/sources.list.d/jenkins.list > /dev/null && apt-get update && apt-get install -y jenkins && systemctl enable jenkins && systemctl start jenkins"
    [vagrant]="wget -O /tmp/hashicorp.gpg https://apt.releases.hashicorp.com/gpg && gpg --dearmor < /tmp/hashicorp.gpg > /usr/share/keyrings/hashicorp-archive-keyring.gpg && rm -f /tmp/hashicorp.gpg && echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main\" > /etc/apt/sources.list.d/hashicorp.list && apt-get update && apt-get install -y vagrant"
    [git]="apt-get update && $PKG_INSTALL git"
    [prometheus]="apt-get update && apt-get install -y curl tar && useradd --no-create-home --shell /bin/false prometheus 2>/dev/null || true && mkdir -p /etc/prometheus /var/lib/prometheus && PROM_VER=2.53.1 && curl -LO https://github.com/prometheus/prometheus/releases/download/v${PROM_VER}/prometheus-${PROM_VER}.linux-amd64.tar.gz && tar -xzf prometheus-${PROM_VER}.linux-amd64.tar.gz && cp prometheus-${PROM_VER}.linux-amd64/prometheus /usr/local/bin/ && cp prometheus-${PROM_VER}.linux-amd64/promtool /usr/local/bin/ && cp -r prometheus-${PROM_VER}.linux-amd64/consoles /etc/prometheus && cp -r prometheus-${PROM_VER}.linux-amd64/console_libraries /etc/prometheus && rm -rf prometheus-${PROM_VER}.linux-amd64 prometheus-${PROM_VER}.linux-amd64.tar.gz && printf 'global:\n  scrape_interval: 15s\nscrape_configs:\n  - job_name: prometheus\n    static_configs:\n      - targets: [localhost:9090]\n' > /etc/prometheus/prometheus.yml && chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus && printf '[Unit]\nDescription=Prometheus\nWants=network-online.target\nAfter=network-online.target\n\n[Service]\nUser=prometheus\nGroup=prometheus\nType=simple\nExecStart=/usr/local/bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/var/lib/prometheus/ --web.console.templates=/etc/prometheus/consoles --web.console.libraries=/etc/prometheus/console_libraries\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/prometheus.service && systemctl daemon-reload && systemctl enable prometheus && systemctl start prometheus"
    [vault]="wget -O /tmp/hashicorp.gpg https://apt.releases.hashicorp.com/gpg && gpg --dearmor < /tmp/hashicorp.gpg > /usr/share/keyrings/hashicorp-archive-keyring.gpg && rm -f /tmp/hashicorp.gpg && echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main\" > /etc/apt/sources.list.d/hashicorp.list && apt-get update && apt-get install -y vault"
    [consul]="wget -O /tmp/hashicorp.gpg https://apt.releases.hashicorp.com/gpg && gpg --dearmor < /tmp/hashicorp.gpg > /usr/share/keyrings/hashicorp-archive-keyring.gpg && rm -f /tmp/hashicorp.gpg && echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main\" > /etc/apt/sources.list.d/hashicorp.list && apt-get update && apt-get install -y consul"
    [argocd]="apt-get update && apt-get install -y curl && curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 && chmod +x /usr/local/bin/argocd"
    [podman]="apt-get update && $PKG_INSTALL podman"
    [k9s]="apt-get update && apt-get install -y curl && K9S_VER=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep tag_name | cut -d'\"' -f4) && curl -sL https://github.com/derailed/k9s/releases/download/${K9S_VER}/k9s_Linux_amd64.tar.gz | tar xz -C /tmp && install /tmp/k9s /usr/local/bin/k9s && rm -f /tmp/k9s"
    [flux]="apt-get update && apt-get install -y curl && curl -s https://fluxcd.io/install.sh | bash"
)

declare -A VERIFY_CMDS=(
    [docker]="command -v docker && systemctl is-active --quiet docker"
    [kubernetes-cli]="command -v kubectl"
    [ansible]="command -v ansible"
    [terraform]="command -v terraform"
    [helm]="command -v helm"
    [aws-cli]="command -v aws"
    [azure-cli]="command -v az"
    [google-cloud-sdk]="command -v gcloud"
    [grafana]="systemctl is-active --quiet grafana-server"
    [gitlab-runner]="command -v gitlab-runner && gitlab-runner status"
    [istio]="command -v istioctl"
    [minikube]="command -v minikube"
    [packer]="command -v packer"
    [jenkins]="systemctl is-active --quiet jenkins"
    [vagrant]="command -v vagrant"
    [git]="command -v git"
    [prometheus]="systemctl is-active --quiet prometheus"
    [vault]="command -v vault"
    [consul]="command -v consul"
    [argocd]="command -v argocd"
    [podman]="command -v podman"
    [k9s]="command -v k9s"
    [flux]="command -v flux"
)

declare -A VERSION_CMDS=(
    [docker]="docker --version | cut -d' ' -f3 | tr -d ','"
    [kubernetes-cli]="kubectl version --client -o json | jq -r '.clientVersion.gitVersion'"
    [ansible]="ansible --version | head -n1 | cut -d' ' -f2"
    [terraform]="terraform version | head -n1 | cut -d' ' -f2"
    [helm]="helm version --short | cut -d' ' -f2"
    [aws-cli]="aws --version | cut -d' ' -f1 | cut -d'/' -f2"
    [azure-cli]="az version | jq -r '.[\"azure-cli\"]'"
    [google-cloud-sdk]="gcloud --version | head -n1 | cut -d' ' -f4"
    [grafana]="apt-cache policy grafana | grep Installed | cut -d' ' -f4"
    [gitlab-runner]="gitlab-runner --version | head -n1 | cut -d' ' -f2"
    [istio]="istioctl version --remote=false | head -n1 | cut -d' ' -f2"
    [minikube]="minikube version | cut -d' ' -f3"
    [packer]="packer version | head -n1 | cut -d' ' -f2"
    [jenkins]="systemctl status jenkins | grep -oE 'Jenkins Automation Server [0-9.]+' | cut -d' ' -f4 || echo 'Unknown'"
    [vagrant]="vagrant --version | cut -d' ' -f2"
    [git]="git --version | cut -d' ' -f3"
    [prometheus]="prometheus --version | grep 'prometheus,' | cut -d' ' -f3"
    [vault]="vault --version | cut -d' ' -f2"
    [consul]="consul --version | head -n1 | cut -d' ' -f2"
    [argocd]="argocd version --client | grep 'argocd:' | cut -d':' -f2 | tr -d ' '"
    [podman]="podman --version | cut -d' ' -f3"
    [k9s]="k9s version | grep Version | cut -d':' -f2 | tr -d ' '"
    [flux]="flux --version | cut -d' ' -f2"
)

# Group tools by category
declare -A TOOL_CATEGORIES=(
    ["Containerization & Orchestration"]="docker kubernetes-cli minikube helm istio podman"
    ["Infrastructure as Code"]="terraform ansible packer vagrant"
    ["CI/CD & Version Control"]="jenkins gitlab-runner git argocd flux"
    ["Cloud Providers"]="aws-cli azure-cli google-cloud-sdk"
    ["Monitoring & Observability"]="prometheus grafana k9s"
    ["Service Mesh & Discovery"]="vault consul"
)

# Show welcome banner
show_banner() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BLUE}║${RESET}                                                                      ${BLUE}║${RESET}"
    echo -e "${BLUE}║${RESET}   ${GREEN}🚀 ProDevOpsGuy DevOps Tool Installer - Deploy With Confidence! ${RESET}   ${BLUE}║${RESET}"
    echo -e "${BLUE}║${RESET}                                                                      ${BLUE}║${RESET}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "  ${YELLOW}🔸 Install DevOps tools with parallel installation support${RESET}"
    echo -e "  ${YELLOW}🔸 Logs stored at ${CONFIG[LOG_FILE]}${RESET}"
    echo -e "  ${YELLOW}🔸 Version: ${CONFIG[VERSION]}${RESET}"
    echo ""
}

# CLI tool selection prompt - simplified version to avoid getting stuck
cli_tool_prompt() {
    # Store all tools in an array
    local all_tools=()
    local index=1

    # Print directly to stdout (not to a pipe)
    printf "\n${YELLOW}🔧 Available Tools:${RESET}\n\n" > /dev/tty

    # Sort categories so tool numbers are stable between runs
    local sorted_categories=()
    mapfile -t sorted_categories < <(printf '%s\n' "${!TOOL_CATEGORIES[@]}" | sort)

    for category in "${sorted_categories[@]}"; do
        printf "\n${CYAN}[$category]${RESET}\n" > /dev/tty
        for tool in ${TOOL_CATEGORIES[$category]}; do
            printf "${GREEN}[%2d] %-30s${RESET}\n" "$index" "$tool" > /dev/tty
            all_tools+=("$tool")
            ((index++))
        done
    done

    printf "\n${YELLOW}Enter tool numbers (comma-separated) or 'all' to install everything:${RESET}\n" > /dev/tty
    printf "👉 " > /dev/tty

    # Read directly from terminal
    read -r selection < /dev/tty

    if [[ "$selection" = "all" ]]; then
        # Return all tools
        local all_tools_str=""
        for category in "${sorted_categories[@]}"; do
            all_tools_str+=" ${TOOL_CATEGORIES[$category]}"
        done
        echo "$all_tools_str"
        return 0
    fi

    if [[ -z "$selection" ]]; then
        # Default to first tool if nothing selected
        printf "${YELLOW}No selection made. Defaulting to tool #1 (${all_tools[0]})${RESET}\n" > /dev/tty
        echo "${all_tools[0]}"
        return 0
    fi

    # Convert numbers (with range support) to tool names
    local tools=""
    IFS=',' read -ra selected_numbers <<< "$selection"

    for num in "${selected_numbers[@]}"; do
        num=$(echo "$num" | tr -d '[:space:]')
        if [[ "$num" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            # Range like 1-5
            local r_start=$((BASH_REMATCH[1]))
            local r_end=$((BASH_REMATCH[2]))
            if (( r_start > r_end )); then
                local tmp=$r_start; r_start=$r_end; r_end=$tmp
            fi
            for ((r = r_start; r <= r_end; r++)); do
                local idx=$((r - 1))
                if [[ "$idx" -ge 0 && "$idx" -lt "${#all_tools[@]}" ]]; then
                    tools+="${all_tools[$idx]} "
                else
                    printf "${RED}Invalid selection: $r. Skipping.${RESET}\n" > /dev/tty
                fi
            done
        else
            local idx=$((num - 1))
            if [[ "$num" =~ ^[0-9]+$ && "$idx" -ge 0 && "$idx" -lt "${#all_tools[@]}" ]]; then
                tools+="${all_tools[$idx]} "
            else
                printf "${RED}Invalid selection: $num. Skipping.${RESET}\n" > /dev/tty
            fi
        fi
    done

    if [[ -z "$tools" ]]; then
        printf "${RED}No valid tools selected. Defaulting to tool #1 (${all_tools[0]})${RESET}\n" > /dev/tty
        echo "${all_tools[0]}"
    else
        echo "$tools"
    fi
}

# Install selected tools sequentially
install_sequentially() {
    local tools=($@)
    local total=${#tools[@]}
    local success=0
    local failed=0

    echo -e "\n${INFO} Installing ${total} tools sequentially..."

    for ((i=0; i<total; i++)); do
        local tool=${tools[$i]}
        echo -e "\n${INFO} [${i}/${total}] Installing ${CYAN}$tool${RESET}..."

        if [[ -n "${INSTALL_CMDS[$tool]}" && -n "${VERIFY_CMDS[$tool]}" ]]; then
            if install_tool "$tool" "${INSTALL_CMDS[$tool]}" "${VERIFY_CMDS[$tool]}" "${VERSION_CMDS[$tool]}"; then
                ((success++))
            else
                ((failed++))
            fi
        else
            log "ERROR" "Unknown tool: $tool. Skipping."
            echo -e "${FAIL} Unknown tool: $tool. Skipping."
            ((failed++))
            update_state "$tool" "failed" "Unknown"
        fi
    done

    echo -e "\n${SUCCESS} Installation summary: ${GREEN}$success${RESET} succeeded, ${RED}$failed${RESET} failed, ${BLUE}$total${RESET} total"
    log "INFO" "Installation summary: $success succeeded, $failed failed, $total total"
}

# Install selected tools in parallel
install_parallel() {
    local tools=($@)
    local total=${#tools[@]}
    local max_jobs=${CONFIG[MAX_PARALLEL_JOBS]}
    local running=0
    local success=0
    local failed=0
    local pids=()
    local tool_map=()

    echo -e "\n${INFO} Installing ${total} tools in parallel (max ${max_jobs} jobs)..."

    for ((i=0; i<total; i++)); do
        local tool=${tools[$i]}

        # Wait if we've reached the maximum number of parallel jobs
        while [[ $running -ge $max_jobs ]]; do
            for j in "${!pids[@]}"; do
                if ! kill -0 ${pids[$j]} 2>/dev/null; then
                    wait ${pids[$j]}
                    local status=$?

                    if [[ $status -eq 0 ]]; then
                        ((success++))
                        log "SUCCESS" "${tool_map[$j]} installation completed successfully in parallel"
                    else
                        ((failed++))
                        log "ERROR" "${tool_map[$j]} installation failed in parallel with status $status"
                        update_state "${tool_map[$j]}" "failed" "Unknown"
                    fi

                    unset pids[$j]
                    unset tool_map[$j]
                    ((running--))
                fi
            done
            sleep 1
        done

        if [[ -n "${INSTALL_CMDS[$tool]}" && -n "${VERIFY_CMDS[$tool]}" ]]; then
            # Check if already installed first
            if eval "${VERIFY_CMDS[$tool]}" &>/dev/null; then
                local version=$(eval "${VERSION_CMDS[$tool]}" 2>/dev/null || echo "Unknown")
                if [[ "${CONFIG[UPGRADE]:-false}" == "true" ]]; then
                    log "INFO" "$tool is installed (version: $version) - upgrading"
                    echo -e "${INFO} $tool is installed (version: ${YELLOW}$version${RESET}) - upgrading..."
                else
                    log "SUCCESS" "$tool is already installed (version: $version)"
                    echo -e "${SUCCESS} $tool is already installed (version: ${GREEN}$version${RESET})"
                    update_state "$tool" "installed" "$version"
                    ((success++))
                    continue
                fi
            elif [[ "${CONFIG[UPGRADE]:-false}" == "true" ]]; then
                # Upgrade mode leaves tools that are not installed alone
                log "INFO" "$tool is not installed - skipped in upgrade mode"
                echo -e "${INFO} $tool is not installed - skipped (upgrade mode)"
                ((success++))
                continue
            fi

            # Dry run: report the plan without changing anything
            if [[ "${CONFIG[DRY_RUN]}" == "true" ]]; then
                local dry_action="installed"
                [[ "${CONFIG[UPGRADE]:-false}" == "true" ]] && dry_action="upgraded"
                log "INFO" "[DRY RUN] $tool would be $dry_action with the following commands:"
                echo -e "${WARN} [DRY RUN] $tool would be $dry_action with the following commands:"
                echo -e "  ${YELLOW}${INSTALL_CMDS[$tool]}${RESET}"
                ((success++))
                continue
            fi

            # Create a temporary script for this tool's installation with better error handling
            local temp_script=$(mktemp)
            local output_file=$(mktemp)

            cat > "$temp_script" << 'EOF'
#!/bin/bash
# Enhanced installation script with error handling
set -x  # Print commands for debugging
# Temporarily disable error handling to allow for better debugging
# We'll check exit codes manually

# Make sure PATH includes common directories
export PATH=$PATH:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin

# Function to run commands with error checking
run_cmd() {
    echo "RUNNING: $*"
    "$@"
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "ERROR: Command failed with exit code $exit_code: $*"
        return $exit_code
    fi
    return 0
}

# No trap - we want to see all errors

# Run installation commands
EOF

            # Add the installation command with full logging
            echo "echo \"Starting installation of $tool...\"" >> "$temp_script"
            echo "echo \"Running installation commands...\"" >> "$temp_script"
            echo "${INSTALL_CMDS[$tool]}" >> "$temp_script"
            echo "echo \"Installation commands completed successfully\"" >> "$temp_script"
            echo "if ${VERIFY_CMDS[$tool]}; then" >> "$temp_script"
            echo "    version=\$(${VERSION_CMDS[$tool]} 2>/dev/null || echo \"Unknown\")" >> "$temp_script"
            echo "    echo \"Verification successful: $tool installed (version: \$version)\"" >> "$temp_script"
            echo "    exit 0" >> "$temp_script"
            echo "else" >> "$temp_script"
            echo "    echo \"Verification failed: $tool not properly installed\"" >> "$temp_script"
            echo "    exit 1" >> "$temp_script"
            echo "fi" >> "$temp_script"
            chmod +x "$temp_script"

            # Log the command that will be executed for debugging
            log "DEBUG" "Command to execute: ${INSTALL_CMDS[$tool]}"

            # Launch in background with timeout and capture output.
            # The subshell must exit with the installer's real status so the
            # surrounding job-scheduler can count successes/failures correctly.
            echo -e "${INFO} Starting installation of ${CYAN}$tool${RESET} in parallel..."
            (
                timeout "${CONFIG[TIMEOUT]}" bash "$temp_script" 2>&1 | tee "$output_file"
                local status=${PIPESTATUS[0]}

                # Store the full log in a persistent location
                mkdir -p "${CONFIG[LOG_DIR]}/$tool"
                cp "$output_file" "${CONFIG[LOG_DIR]}/$tool/install_$(date +%Y%m%d_%H%M%S).log"

                if [[ $status -eq 0 ]]; then
                    local version=$(eval "${VERSION_CMDS[$tool]}" 2>/dev/null || echo "Unknown")
                    echo -e "${SUCCESS} $tool installed successfully (version: ${GREEN}$version${RESET})"
                    update_state "$tool" "installed" "$version"
                else
                    if [[ $status -eq 124 ]]; then
                        echo -e "${FAIL} $tool installation timed out after ${CONFIG[TIMEOUT]}s"
                    else
                        echo -e "${FAIL} $tool installation failed with status $status"
                    fi
                    echo -e "${RED}Last 10 lines of output:${RESET}"
                    tail -n 10 "$output_file" | sed 's/^/    /'
                    update_state "$tool" "failed" "Unknown"
                fi

                rm -f "$temp_script" "$output_file"
                exit $status
            ) &

            local pid=$!
            pids+=($pid)
            tool_map+=($tool)
            ((running++))
        else
            log "ERROR" "Unknown tool: $tool. Skipping."
            echo -e "${FAIL} Unknown tool: $tool. Skipping."
            ((failed++))
            update_state "$tool" "failed" "Unknown"
        fi
    done

    # Wait for all remaining installations to complete
    for pid in "${pids[@]}"; do
        if kill -0 $pid 2>/dev/null; then
            wait $pid
            local status=$?
            if [[ $status -eq 0 ]]; then
                ((success++))
            else
                ((failed++))
            fi
        fi
    done

    echo -e "\n${SUCCESS} Installation summary: ${GREEN}$success${RESET} succeeded, ${RED}$failed${RESET} failed, ${BLUE}$total${RESET} total"
    log "INFO" "Installation summary: $success succeeded, $failed failed, $total total"
}

# Main function
main() {
    # Change to script directory to ensure relative paths work
    cd "$SCRIPT_DIR" || {
        echo "Failed to change directory to $SCRIPT_DIR"
        exit 1
    }

    # ---- Command line arguments (non-interactive automation support) ----
    local CLI_MODE=false LIST_ONLY=false ALL_MODE=false DRY_RUN=false SKIP_REQUIREMENTS=false RETRY_FAILED=false UPGRADE=false
    local INSTALL_LIST=""
    local PROFILE_FILE=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) usage_install_sh; exit 0 ;;
            -l|--list) LIST_ONLY=true ;;
            -i|--install) INSTALL_LIST="${2:-}"; CLI_MODE=true; shift ;;
            -a|--all) ALL_MODE=true; CLI_MODE=true ;;
            -r|--retry-failed) RETRY_FAILED=true; CLI_MODE=true ;;
            -U|--upgrade) UPGRADE=true; CLI_MODE=true ;;
            --from) PROFILE_FILE="${2:-}"; CLI_MODE=true; shift ;;
            -s|--sequential) CONFIG[PARALLEL_INSTALL]=false ;;
            -p|--parallel) CONFIG[PARALLEL_INSTALL]=true ;;
            -j|--jobs) CONFIG[MAX_PARALLEL_JOBS]="${2:-4}"; shift ;;
            -d|--dry-run) DRY_RUN=true ;;
            --skip-requirements) SKIP_REQUIREMENTS=true ;;
            *) echo -e "${RED}Unknown option: $1${RESET}"; usage_install_sh; exit 1 ;;
        esac
        shift
    done

    # Root privileges are required for actions that change the system;
    # read-only modes (help, list, dry-run) run as a normal user.
    if [[ "$LIST_ONLY" != true && "$DRY_RUN" != true && $EUID -ne 0 ]]; then
        echo -e "${RED}Error: This script must be run as root${RESET}"
        echo -e "Please run with: ${GREEN}sudo $0${RESET}"
        exit 1
    fi

    if [[ "$DRY_RUN" == true ]]; then
        CONFIG["DRY_RUN"]="true"
        log "INFO" "Dry run mode enabled - no changes will be made"
    fi

    if [[ "$UPGRADE" == true ]]; then
        CONFIG["UPGRADE"]="true"
        log "INFO" "Upgrade mode enabled - only installed tools will be upgraded"
    fi

    show_banner
    create_required_dirs
    init_state_file
    cleanup_old_logs
    detect_os

    # The requirements check can prompt - skip it in CLI mode (or on request).
    # Dry-run mode skips all system changes entirely.
    if [[ "$DRY_RUN" == true ]]; then
        log "INFO" "Skipping requirements and repository setup in dry-run mode"
    else
        if [[ "${CONFIG[CHECK_SYSTEM_REQUIREMENTS]}" == "true" && "$CLI_MODE" != true && "$SKIP_REQUIREMENTS" != true ]]; then
            check_system_requirements
        fi

        # Update package repositories
        update_package_repositories

        # Install base requirements
        install_base_requirements
    fi

    # ---- Tool selection ----
    local tools_input=""

    if [[ "$LIST_ONLY" == true ]]; then
        list_tool_catalog
        exit 0
    fi

    if [[ "$ALL_MODE" == true ]]; then
        # Install every tool in the catalog
        local sorted_categories=()
        mapfile -t sorted_categories < <(printf '%s\n' "${!TOOL_CATEGORIES[@]}" | sort)
        for category in "${sorted_categories[@]}"; do
            tools_input+=" ${TOOL_CATEGORIES[$category]}"
        done
    elif [[ -n "$PROFILE_FILE" ]]; then
        # Tool profile file with optional [windows]/[linux] sections;
        # the Windows section is ignored here. Lines before any section
        # header count as Linux entries, and '#' starts a comment.
        if [[ ! -f "$PROFILE_FILE" ]]; then
            log "ERROR" "Profile file not found: $PROFILE_FILE"
            echo -e "${FAIL} Profile file not found: $PROFILE_FILE"
            exit 1
        fi
        tools_input=$(awk '
            /^[ \t]*#/ { next }
            /^[ \t]*\[[^]]+\][ \t]*$/ {
                sec=tolower($0)
                gsub(/[ \t\[\]]/, "", sec)
                next
            }
            /^[ \t]*$/ { next }
            {
                gsub(/[ \t]/, "", $0)
                n=split($0, a, ",")
                for (i = 1; i <= n; i++) {
                    if (a[i] != "" && (sec == "" || sec == "linux")) printf "%s ", a[i]
                }
            }
        ' "$PROFILE_FILE")
        log "INFO" "Loaded tool selection from profile: $PROFILE_FILE"
        echo -e "${INFO} Loaded tool selection from profile: ${BLUE}${PROFILE_FILE}${RESET}"
    elif [[ "$RETRY_FAILED" == true ]]; then
        # Reinstall everything previously recorded as failed in the state file
        tools_input=$(jq -r '.[] | select(.status == "failed") | .name' "${CONFIG[STATE_FILE]}" 2>/dev/null | sort -u | tr '\n' ' ')
        if [[ -z "$tools_input" ]]; then
            log "INFO" "No failed installations found in the state file"
            echo -e "${SUCCESS} No failed installations found - everything looks good."
            exit 0
        fi
        echo -e "${INFO} Retrying previously failed tools: ${CYAN}${tools_input}${RESET}"
    elif [[ -n "$INSTALL_LIST" ]]; then
        tools_input="${INSTALL_LIST//,/ }"
    else
        # Get tool selection interactively
        echo -e "${CYAN}Loading tool selection menu...${RESET}"
        # No stdout redirection - keep it simple
        tools_input=$(cli_tool_prompt)
    fi

    if [[ -z "$tools_input" ]]; then
        log "ERROR" "No tools selected for installation"
        echo -e "${RED}No tools selected for installation.${RESET}"
        exit 1
    fi

    # Count and validate selected tools
    read -ra tools_array <<< "$tools_input"
    local tool_count=${#tools_array[@]}

    for tool in "${tools_array[@]}"; do
        if [[ -z "${INSTALL_CMDS[$tool]}" ]]; then
            log "ERROR" "Unknown tool '$tool'. Use -l/--list to see available tools."
            echo -e "${FAIL} Unknown tool '$tool'. Use -l/--list to see available tools."
            exit 1
        fi
    done

    log "INFO" "Selected $tool_count tools for installation: $tools_input"
    echo -e "${INFO} Selected ${BLUE}$tool_count${RESET} tools for installation"

    # Confirm installation (interactive mode only)
    if [[ "$CLI_MODE" != true ]]; then
        echo -e "${YELLOW}Do you want to proceed with installation? (y/n):${RESET}"
        read -rp "👉 " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log "INFO" "Installation aborted by user"
            echo -e "${INFO} Installation aborted."
            exit 0
        fi

        # Create log directories if they don't exist
        mkdir -p "${CONFIG[LOG_DIR]}"

        # Ask about installation mode if more than one tool
        if [[ $tool_count -gt 1 ]]; then
            echo -e "${YELLOW}Installation mode:${RESET}"
            echo -e "  ${GREEN}[1] Parallel${RESET} (faster, but harder to troubleshoot)"
            echo -e "  ${GREEN}[2] Sequential${RESET} (slower, but easier to troubleshoot)"
            read -rp "👉 Enter your choice [1]: " install_mode

            if [[ "$install_mode" == "2" ]]; then
                CONFIG[PARALLEL_INSTALL]=false
            else
                CONFIG[PARALLEL_INSTALL]=true
            fi
        fi
    else
        # CLI mode: single tool installs are sequential, multiple go parallel
        if [[ $tool_count -eq 1 ]]; then
            CONFIG[PARALLEL_INSTALL]=false
        fi
        mkdir -p "${CONFIG[LOG_DIR]}"
    fi

    # Install tools based on parallel flag
    if [[ "${CONFIG[PARALLEL_INSTALL]}" == "true" && $tool_count -gt 1 ]]; then
        echo -e "${INFO} Using parallel installation mode with up to ${CONFIG[MAX_PARALLEL_JOBS]} jobs"
        install_parallel "${tools_array[@]}"
    else
        echo -e "${INFO} Using sequential installation mode"
        install_sequentially "${tools_array[@]}"
    fi

    echo -e "\n${SUCCESS} Installation process completed. See logs at: ${BLUE}${CONFIG[LOG_FILE]}${RESET}"
    log "SUCCESS" "Installation process completed"
}

# Execute main function
main "$@"
