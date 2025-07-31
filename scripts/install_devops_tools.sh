#!/bin/bash

# install_devops_tools.sh - Enhanced DevOps Tool Installer by ProDevOpsGuy Tech
# Version 3.0.0

# Don't exit on errors immediately to allow for better error handling
set +e

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
    ["VERSION"]="3.0.0"
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

# Ensure the script runs with root privileges
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${RESET}"
    echo -e "Please run with: ${GREEN}sudo $0${RESET}"
    exit 1
fi

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

# Update the state file with installation status
update_state() {
    local tool=$1
    local status=$2
    local version=$3
    local date=$(date '+%Y-%m-%d %H:%M:%S')

    # Check if the tool already exists in the state file
    local exists=$(jq -r --arg tool "$tool" '.[] | select(.name == $tool) | .name' "${CONFIG[STATE_FILE]}")

    if [[ -n "$exists" ]]; then
        # Update existing entry
        jq --arg tool "$tool" --arg status "$status" --arg date "$date" --arg version "$version" \
           '[.[] | if .name == $tool then {name: $tool, status: $status, date: $date, version: $version} else . end]' \
           "${CONFIG[STATE_FILE]}" > "${CONFIG[STATE_FILE]}.tmp"
    else
        # Add new entry
        jq --arg tool "$tool" --arg status "$status" --arg date "$date" --arg version "$version" \
           '. += [{name: $tool, status: $status, date: $date, version: $version}]' \
           "${CONFIG[STATE_FILE]}" > "${CONFIG[STATE_FILE]}.tmp"
    fi

    # Replace the original file
    mv "${CONFIG[STATE_FILE]}.tmp" "${CONFIG[STATE_FILE]}"
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
                PKG_UPDATE="dnf check-update || true"
                PKG_INSTALL="dnf install -y"
            else
                PKG_MANAGER="yum"
                PKG_UPDATE="yum check-update || true"
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

    # Essential packages for most installations
    local base_packages="apt-transport-https ca-certificates curl wget gnupg lsb-release software-properties-common unzip"

    echo -e "${INFO} Installing: $base_packages"
    apt-get update
    if apt-get install -y $base_packages; then
        log "SUCCESS" "Installed base requirements"
        echo -e "${SUCCESS} Installed base requirements"
    else
        log "ERROR" "Failed to install some base requirements"
        echo -e "${WARN} Failed to install some base requirements, but continuing anyway"
    fi

    # Create common directories
    mkdir -p /etc/apt/keyrings

    # Make sure certificates are up to date
    update-ca-certificates --fresh || true
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

        # Install missing commands
        for cmd in "${missing_cmds[@]}"; do
            echo -e "${INFO} Installing $cmd..."
            if eval "sudo $PKG_INSTALL $cmd"; then
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

    if ! eval "sudo $PKG_UPDATE"; then
        log "WARN" "Failed to update package repositories. Continuing anyway."
        echo -e "${WARN} Failed to update package repositories. Continuing anyway."
    else
        log "SUCCESS" "Package repositories updated"
    fi
}

# Install tool function
install_tool() {
    local tool=$1
    local install_cmd=$2
    local verify_cmd=$3
    local version_cmd=$4

    log "INFO" "Installing $tool..."
    echo -e "\n${INFO} Installing ${CYAN}$tool${RESET}..."

    # Check if already installed
    if eval "$verify_cmd" &>/dev/null; then
        local version=$(eval "$version_cmd" 2>/dev/null || echo "Unknown")
        log "SUCCESS" "$tool is already installed (version: $version)"
        echo -e "${SUCCESS} $tool is already installed (version: ${GREEN}$version${RESET})"
        update_state "$tool" "installed" "$version"
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

    # Install with timeout and capture output
    local output_file=$(mktemp)
    echo -e "${CYAN}Running installation script for $tool...${RESET}"
    echo -e "${CYAN}See live output below:${RESET}"
    echo -e "${YELLOW}----------------------------------------${RESET}"
    if timeout "${CONFIG[TIMEOUT]}" bash "$temp_script" 2>&1 | tee "$output_file"; then
        echo -e "${YELLOW}----------------------------------------${RESET}"
        echo -e "${GREEN}Installation commands completed successfully${RESET}"
        rm -f "$temp_script" "$output_file"

        # Verify installation
        if eval "$verify_cmd" &>/dev/null; then
            local version=$(eval "$version_cmd" 2>/dev/null || echo "Unknown")
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
        local exit_code=$?
        # Show error output
        echo -e "${RED}Installation failed with output:${RESET}"
        cat "$output_file"
        rm -f "$temp_script" "$output_file"

        if [ $exit_code -eq 124 ]; then
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
    [kubernetes-cli]="curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && echo \"deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /\" | tee /etc/apt/sources.list.d/kubernetes.list && apt-get update && apt-get install -y kubectl"
    [ansible]="$PKG_UPDATE && $PKG_INSTALL ansible"
    [terraform]="apt-get update && apt-get install -y unzip && rm -rf /tmp/terraform_install && mkdir -p /tmp/terraform_install && cd /tmp/terraform_install && wget -q https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip && unzip -q terraform_1.6.6_linux_amd64.zip && install -o root -g root -m 0755 terraform /usr/local/bin/terraform && cd / && rm -rf /tmp/terraform_install"
    [helm]="curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
    [aws-cli]="apt-get update && apt-get install -y unzip && curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"awscliv2.zip\" && unzip -q awscliv2.zip && ./aws/install && rm -rf aws awscliv2.zip"
    [azure-cli]="apt-get update && apt-get install -y ca-certificates curl apt-transport-https lsb-release gnupg && mkdir -p /etc/apt/keyrings && curl -sLS https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/keyrings/microsoft.gpg > /dev/null && echo \"deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main\" | tee /etc/apt/sources.list.d/azure-cli.list > /dev/null && apt-get update && apt-get install -y azure-cli"
    [google-cloud-sdk]="apt-get update && apt-get install -y apt-transport-https ca-certificates gnupg curl && echo \"deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main\" | tee /etc/apt/sources.list.d/google-cloud-sdk.list && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - && apt-get update && apt-get install -y google-cloud-cli"
    [grafana]="apt-get update && apt-get install -y apt-transport-https software-properties-common wget && mkdir -p /etc/apt/keyrings && wget -q -O /etc/apt/keyrings/grafana.key https://apt.grafana.com/gpg.key && echo \"deb [signed-by=/etc/apt/keyrings/grafana.key] https://apt.grafana.com stable main\" | tee /etc/apt/sources.list.d/grafana.list > /dev/null && apt-get update && apt-get install -y grafana && systemctl enable grafana-server && systemctl start grafana-server"
    [gitlab-runner]="curl -L \"https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh\" | bash && apt-get install -y gitlab-runner && gitlab-runner start"
    [istio]="curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.20.0 sh - && mv istio-1.20.0/bin/istioctl /usr/local/bin/ && rm -rf istio-1.20.0"
    [minikube]="apt-get update && apt-get install -y curl && curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && chmod +x minikube && mv minikube /usr/local/bin/"
    [packer]="apt-get update && apt-get install -y gnupg software-properties-common wget && wget -O /tmp/hashicorp.asc https://apt.releases.hashicorp.com/gpg && gpg --dearmor < /tmp/hashicorp.asc > /usr/share/keyrings/hashicorp-archive-keyring.gpg && echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main\" > /etc/apt/sources.list.d/hashicorp.list && apt-get update && apt-get install -y packer"
    [jenkins]="apt-get update && apt-get install -y openjdk-11-jdk gnupg && curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | gpg --dearmor -o /usr/share/keyrings/jenkins-keyring.gpg && echo \"deb [signed-by=/usr/share/keyrings/jenkins-keyring.gpg] https://pkg.jenkins.io/debian-stable binary/\" | tee /etc/apt/sources.list.d/jenkins.list > /dev/null && apt-get update && apt-get install -y jenkins && systemctl enable jenkins && systemctl start jenkins"
    [vagrant]="apt-get update && apt-get install -y gnupg software-properties-common wget && wget -O /tmp/hashicorp.asc https://apt.releases.hashicorp.com/gpg && gpg --dearmor < /tmp/hashicorp.asc > /usr/share/keyrings/hashicorp-archive-keyring.gpg && echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main\" > /etc/apt/sources.list.d/hashicorp.list && apt-get update && apt-get install -y vagrant"
    [git]="apt-get update && $PKG_INSTALL git"
    [prometheus]="apt-get update && apt-get install -y curl tar && useradd --no-create-home --shell /bin/false prometheus || true && mkdir -p /etc/prometheus /var/lib/prometheus && curl -LO https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.linux-amd64.tar.gz && tar -xvf prometheus-2.45.0.linux-amd64.tar.gz && cp prometheus-2.45.0.linux-amd64/prometheus /usr/local/bin/ && cp prometheus-2.45.0.linux-amd64/promtool /usr/local/bin/ && cp -r prometheus-2.45.0.linux-amd64/consoles /etc/prometheus && cp -r prometheus-2.45.0.linux-amd64/console_libraries /etc/prometheus && rm -rf prometheus-2.45.0.linux-amd64 prometheus-2.45.0.linux-amd64.tar.gz && echo 'global:\n  scrape_interval: 15s\nscrape_configs:\n  - job_name: \"prometheus\"\n    static_configs:\n      - targets: [\"localhost:9090\"]' > /etc/prometheus/prometheus.yml && chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus && echo '[Unit]\nDescription=Prometheus\nWants=network-online.target\nAfter=network-online.target\n\n[Service]\nUser=prometheus\nGroup=prometheus\nType=simple\nExecStart=/usr/local/bin/prometheus \\\n  --config.file=/etc/prometheus/prometheus.yml \\\n  --storage.tsdb.path=/var/lib/prometheus/ \\\n  --web.console.templates=/etc/prometheus/consoles \\\n  --web.console.libraries=/etc/prometheus/console_libraries\n\n[Install]\nWantedBy=multi-user.target' > /etc/systemd/system/prometheus.service && systemctl daemon-reload && systemctl enable prometheus && systemctl start prometheus"
    [vault]="apt-get update && apt-get install -y gnupg software-properties-common wget && wget -O /tmp/hashicorp.asc https://apt.releases.hashicorp.com/gpg && gpg --dearmor < /tmp/hashicorp.asc > /usr/share/keyrings/hashicorp-archive-keyring.gpg && echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main\" > /etc/apt/sources.list.d/hashicorp.list && apt-get update && apt-get install -y vault"
    [consul]="apt-get update && apt-get install -y gnupg software-properties-common wget && wget -O /tmp/hashicorp.asc https://apt.releases.hashicorp.com/gpg && gpg --dearmor < /tmp/hashicorp.asc > /usr/share/keyrings/hashicorp-archive-keyring.gpg && echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main\" > /etc/apt/sources.list.d/hashicorp.list && apt-get update && apt-get install -y consul"
    [argocd]="apt-get update && apt-get install -y curl && curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 && chmod +x /usr/local/bin/argocd"
    [podman]="apt-get update && $PKG_INSTALL podman"
    [k9s]="apt-get update && apt-get install -y curl && curl -sS https://webinstall.dev/k9s | bash && mkdir -p /usr/local/bin && cp ~/.local/bin/k9s /usr/local/bin/ || true"
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

    for category in "${!TOOL_CATEGORIES[@]}"; do
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
        for category in "${!TOOL_CATEGORIES[@]}"; do
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

    # Convert numbers to tool names
    local tools=""
    IFS=',' read -ra selected_numbers <<< "$selection"

    for num in "${selected_numbers[@]}"; do
        num=$(echo "$num" | tr -d '[:space:]')
        local idx=$((num - 1))
        if [[ "$idx" -ge 0 && "$idx" -lt "${#all_tools[@]}" ]]; then
            tools+="${all_tools[$idx]} "
        else
            printf "${RED}Invalid selection: $num. Skipping.${RESET}\n" > /dev/tty
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
                log "SUCCESS" "$tool is already installed (version: $version)"
                echo -e "${SUCCESS} $tool is already installed (version: ${GREEN}$version${RESET})"
                update_state "$tool" "installed" "$version"
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

            # Launch in background with timeout and capture output
            echo -e "${INFO} Starting installation of ${CYAN}$tool${RESET} in parallel..."
            (
                timeout "${CONFIG[TIMEOUT]}" bash "$temp_script" 2>&1 | tee "$output_file"
                local status=$?

                if [[ $status -eq 0 ]]; then
                    local version=$(eval "${VERSION_CMDS[$tool]}" 2>/dev/null || echo "Unknown")
                    echo -e "${SUCCESS} $tool installed successfully (version: ${GREEN}$version${RESET})"
                    update_state "$tool" "installed" "$version"
                else
                    echo -e "${FAIL} $tool installation failed with status $status"
                    echo -e "${RED}Last 10 lines of output:${RESET}"
                    tail -n 10 "$output_file" | sed 's/^/    /'
                    update_state "$tool" "failed" "Unknown"
                fi

                # Store the full log in a persistent location
                mkdir -p "${CONFIG[LOG_DIR]}/$tool"
                cp "$output_file" "${CONFIG[LOG_DIR]}/$tool/install_$(date +%Y%m%d_%H%M%S).log"

                rm -f "$temp_script" "$output_file"
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

    show_banner
    create_required_dirs
    init_state_file
    detect_os

    # Check system requirements if enabled
    if [[ "${CONFIG[CHECK_SYSTEM_REQUIREMENTS]}" == "true" ]]; then
        check_system_requirements
    fi

    # Update package repositories
    update_package_repositories

    # Install base requirements
    install_base_requirements

    # Get tool selection
    echo -e "${CYAN}Loading tool selection menu...${RESET}"
    # No stdout redirection - keep it simple
    local selected_tools=$(cli_tool_prompt)

    if [[ -z "$selected_tools" ]]; then
        log "ERROR" "No tools selected for installation"
        echo -e "${RED}No tools selected for installation.${RESET}"
        exit 1
    fi

    # Count selected tools
    read -ra tools_array <<< "$selected_tools"
    local tool_count=${#tools_array[@]}

    log "INFO" "Selected $tool_count tools for installation: $selected_tools"
    echo -e "${INFO} Selected ${BLUE}$tool_count${RESET} tools for installation"

    # Confirm installation
    echo -e "${YELLOW}Do you want to proceed with installation? (y/n):${RESET}"
    read -rp "👉 " confirm
    if [[ "$confirm" != "y" ]]; then
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
