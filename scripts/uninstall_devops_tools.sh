#!/bin/bash

# uninstall_devops_tools.sh - Enhanced DevOps Tool Uninstaller by ProDevOpsGuy Tech
# Version 3.0.0

# Config
# Get the script directory path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

declare -A CONFIG=(
    ["LOG_DIR"]="$ROOT_DIR/logs/uninstall"
    ["LOG_FILE"]="$ROOT_DIR/logs/uninstall/uninstall_$(date +%Y%m%d_%H%M%S).log"
    ["STATE_FILE"]="$ROOT_DIR/state/devops_state.json"
    ["DRY_RUN"]=false
    ["MAX_LOG_DIRS"]=10
    ["VERSION"]="3.0.0"
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

# Check for root/sudo privileges
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${RESET}"
    echo -e "Please run with: ${GREEN}sudo $0${RESET}"
    exit 1
fi

# Create required directories
create_required_dirs() {
    local log_dir=$(dirname "${CONFIG[LOG_FILE]}")
    local state_dir=$(dirname "${CONFIG[STATE_FILE]}")

    for dir in "$log_dir" "$state_dir"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log "INFO" "Created directory: $dir"
        fi
    done
}

# Cleanup old log directories
cleanup_old_logs() {
    local log_dir=$(dirname "${CONFIG[LOG_FILE]}")
    local parent_dir=$(dirname "$log_dir")

    if [[ -d "$parent_dir" ]]; then
        local log_count=$(find "$parent_dir" -name "uninstall_*" -type d | wc -l)
        if [[ "$log_count" -gt "${CONFIG[MAX_LOG_DIRS]}" ]]; then
            find "$parent_dir" -name "uninstall_*" -type d | sort | head -n -"${CONFIG[MAX_LOG_DIRS]}" | xargs rm -rf
            log "INFO" "Cleaned up old log directories"
        fi
    fi
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
    esac
}

# Initialize or validate the state file
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

# Update the state file after uninstallation
update_state() {
    local tool=$1
    local status=$2
    local date=$(date '+%Y-%m-%d %H:%M:%S')

    # Remove the tool from the state file
    jq --arg tool "$tool" '[.[] | select(.name != $tool)]' "${CONFIG[STATE_FILE]}" > "${CONFIG[STATE_FILE]}.tmp"
    mv "${CONFIG[STATE_FILE]}.tmp" "${CONFIG[STATE_FILE]}"

    log "INFO" "Updated state file: removed $tool"
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
            PKG_REMOVE="apt-get remove -y"
            PKG_PURGE="apt-get purge -y"
            ;;
        centos | rhel | fedora | amazon)
            if [[ -x "$(command -v dnf)" ]]; then
                PKG_MANAGER="dnf"
                PKG_REMOVE="dnf remove -y"
                PKG_PURGE="dnf remove -y"
            else
                PKG_MANAGER="yum"
                PKG_REMOVE="yum remove -y"
                PKG_PURGE="yum remove -y"
            fi
            ;;
        arch)
            PKG_MANAGER="pacman"
            PKG_REMOVE="pacman -R --noconfirm"
            PKG_PURGE="pacman -Rns --noconfirm"
            ;;
        opensuse | sles)
            PKG_MANAGER="zypper"
            PKG_REMOVE="zypper remove -y"
            PKG_PURGE="zypper remove -y --clean-deps"
            ;;
        alpine)
            PKG_MANAGER="apk"
            PKG_REMOVE="apk del"
            PKG_PURGE="apk del --purge"
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

# Run command with dry run support
run_cmd() {
    local cmd=$1

    if [[ "${CONFIG[DRY_RUN]}" == true ]]; then
        log "INFO" "DRY RUN: $cmd"
        echo -e "${YELLOW}[DRY RUN] $cmd${RESET}"
        return 0
    else
        log "INFO" "Executing: $cmd"
        if eval "$cmd"; then
            return 0
        else
            return $?
        fi
    fi
}

# Uninstall commands per tool
declare -A UNINSTALL_CMDS=(
    [docker]="(systemctl is-active docker &>/dev/null && systemctl stop docker); $PKG_PURGE docker* containerd.io docker-ce docker-ce-cli || true; rm -rf /var/lib/docker /etc/docker /var/run/docker.sock; groupdel docker &>/dev/null || true"
    [kubernetes-cli]="rm -f /usr/local/bin/kubectl"
    [ansible]="$PKG_PURGE ansible || true"
    [terraform]="$PKG_PURGE terraform || true; rm -f /usr/local/bin/terraform"
    [helm]="rm -f /usr/local/bin/helm"
    [aws-cli]="rm -rf /usr/local/aws-cli /usr/local/bin/aws /usr/local/bin/aws_completer"
    [azure-cli]="$PKG_PURGE azure-cli || true"
    [google-cloud-sdk]="rm -rf /usr/local/google-cloud-sdk; rm -f /usr/local/bin/gcloud /usr/local/bin/gsutil /usr/local/bin/bq"
    [grafana]="(systemctl is-active grafana-server &>/dev/null && systemctl stop grafana-server); $PKG_PURGE grafana || true; rm -rf /etc/grafana /var/lib/grafana"
    [gitlab-runner]="(command -v gitlab-runner &>/dev/null && gitlab-runner uninstall); rm -f /usr/local/bin/gitlab-runner"
    [istio]="rm -f /usr/local/bin/istioctl; rm -rf ~/.istio"
    [minikube]="(command -v minikube &>/dev/null && minikube delete --all --purge); rm -f /usr/local/bin/minikube; rm -rf ~/.minikube"
    [packer]="$PKG_PURGE packer || true; rm -f /usr/local/bin/packer"
    [jenkins]="(systemctl is-active jenkins &>/dev/null && systemctl stop jenkins); $PKG_PURGE jenkins || true; rm -rf /var/lib/jenkins /etc/jenkins /var/cache/jenkins /var/log/jenkins"
    [vagrant]="$PKG_PURGE vagrant || true"
    [git]="$PKG_PURGE git || true"
    [prometheus]="(systemctl is-active prometheus &>/dev/null && systemctl stop prometheus); $PKG_PURGE prometheus || true; rm -rf /etc/prometheus /var/lib/prometheus; userdel prometheus &>/dev/null || true"
    [vault]="(systemctl is-active vault &>/dev/null && systemctl stop vault); $PKG_PURGE vault || true; rm -f /usr/local/bin/vault"
    [consul]="(systemctl is-active consul &>/dev/null && systemctl stop consul); $PKG_PURGE consul || true; rm -f /usr/local/bin/consul"
    [argocd]="rm -f /usr/local/bin/argocd"
    [podman]="$PKG_PURGE podman || true"
    [k9s]="rm -f /usr/local/bin/k9s ~/.local/bin/k9s"
    [flux]="rm -f /usr/local/bin/flux"
)

# Verification commands to check if tool is uninstalled
declare -A VERIFY_CMDS=(
    [docker]="! command -v docker &>/dev/null && ! systemctl is-active docker &>/dev/null"
    [kubernetes-cli]="! command -v kubectl &>/dev/null"
    [ansible]="! command -v ansible &>/dev/null"
    [terraform]="! command -v terraform &>/dev/null"
    [helm]="! command -v helm &>/dev/null"
    [aws-cli]="! command -v aws &>/dev/null"
    [azure-cli]="! command -v az &>/dev/null"
    [google-cloud-sdk]="! command -v gcloud &>/dev/null"
    [grafana]="! systemctl is-active grafana-server &>/dev/null"
    [gitlab-runner]="! command -v gitlab-runner &>/dev/null"
    [istio]="! command -v istioctl &>/dev/null"
    [minikube]="! command -v minikube &>/dev/null"
    [packer]="! command -v packer &>/dev/null"
    [jenkins]="! systemctl is-active jenkins &>/dev/null"
    [vagrant]="! command -v vagrant &>/dev/null"
    [git]="! command -v git &>/dev/null"
    [prometheus]="! systemctl is-active prometheus &>/dev/null"
    [vault]="! command -v vault &>/dev/null"
    [consul]="! command -v consul &>/dev/null"
    [argocd]="! command -v argocd &>/dev/null"
    [podman]="! command -v podman &>/dev/null"
    [k9s]="! command -v k9s &>/dev/null"
    [flux]="! command -v flux &>/dev/null"
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

# Welcome Banner
show_banner() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BLUE}║${RESET}                                                                      ${BLUE}║${RESET}"
    echo -e "${BLUE}║${RESET}   ${GREEN}🔥 ProDevOpsGuy DevOps Tool Uninstaller - Clean With Confidence! ${RESET}   ${BLUE}║${RESET}"
    echo -e "${BLUE}║${RESET}                                                                      ${BLUE}║${RESET}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "  ${YELLOW}🔸 Remove DevOps tools with thorough cleanup of configs and services${RESET}"
    echo -e "  ${YELLOW}🔸 Logs stored at ${CONFIG[LOG_FILE]}${RESET}"
    echo -e "  ${YELLOW}🔸 Version: ${CONFIG[VERSION]}${RESET}"
    if [[ "${CONFIG[DRY_RUN]}" == true ]]; then
        echo -e "  ${PURPLE}🔸 DRY RUN MODE ENABLED - No changes will be made${RESET}"
    fi
    echo ""
}

# CLI tool selection prompt - with direct terminal output
cli_tool_prompt() {
    printf "\n${YELLOW}🔧 Available Tools:${RESET}\n\n" > /dev/tty
    local index=1
    local all_tools=()

    for category in "${!TOOL_CATEGORIES[@]}"; do
        printf "\n${CYAN}[$category]${RESET}\n" > /dev/tty
        for tool in ${TOOL_CATEGORIES[$category]}; do
            # Check if tool is in state file as installed
            local installed="No"
            if jq -e --arg tool "$tool" '.[] | select(.name == $tool and .status == "installed")' "${CONFIG[STATE_FILE]}" &>/dev/null; then
                installed="${GREEN}Yes${RESET}"
            fi
            printf "${GREEN}[%2d] %-30s${RESET} Installed: %s\n" "$index" "$tool" "$installed" > /dev/tty
            all_tools+=("$tool")
            ((index++))
        done
    done

    printf "\n${YELLOW}Enter tool numbers (comma-separated), 'all' to uninstall everything, or 'installed' for installed tools only:${RESET}\n" > /dev/tty
    printf "👉 " > /dev/tty
    read -r selection < /dev/tty

    if [[ "$selection" = "all" ]]; then
        # Return all tools
        local all_tools_str=""
        for category in "${!TOOL_CATEGORIES[@]}"; do
            all_tools_str+=" ${TOOL_CATEGORIES[$category]}"
        done
        echo "$all_tools_str"
        return 0
    elif [[ "$selection" = "installed" ]]; then
        # Return only installed tools
        local installed_tools=""
        local all_tools_str=""

        for category in "${!TOOL_CATEGORIES[@]}"; do
            all_tools_str+=" ${TOOL_CATEGORIES[$category]}"
        done

        for tool in $all_tools_str; do
            if jq -e --arg tool "$tool" '.[] | select(.name == $tool and .status == "installed")' "${CONFIG[STATE_FILE]}" &>/dev/null; then
                installed_tools+="$tool "
            fi
        done

        if [[ -z "$installed_tools" ]]; then
            printf "${YELLOW}No installed tools found in the state file.${RESET}\n" > /dev/tty
            # Default to docker if nothing is installed
            echo "docker"
            return 0
        fi

        echo "$installed_tools"
        return 0
    elif [[ -z "$selection" ]]; then
        # Default to first tool if nothing selected
        printf "${YELLOW}No selection made. Defaulting to tool #1 (${all_tools[0]})${RESET}\n" > /dev/tty
        echo "${all_tools[0]}"
        return 0
    else
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
    fi
}

# Check if a tool is currently used by another process
check_if_in_use() {
    local tool=$1
    local process_count=0

    case "$tool" in
        docker)
            process_count=$(ps aux | grep -v grep | grep -c "docker" || true)
            ;;
        kubernetes-cli)
            process_count=$(ps aux | grep -v grep | grep -c "kubectl" || true)
            ;;
        jenkins)
            process_count=$(ps aux | grep -v grep | grep -c "jenkins" || true)
            ;;
        grafana)
            process_count=$(ps aux | grep -v grep | grep -c "grafana" || true)
            ;;
        prometheus)
            process_count=$(ps aux | grep -v grep | grep -c "prometheus" || true)
            ;;
        *)
            # For other tools, check if binary is in use
            if command -v "$tool" &>/dev/null; then
                process_count=$(lsof "$(command -v "$tool")" 2>/dev/null | grep -v COMMAND | wc -l || true)
            fi
            ;;
    esac

    if [[ $process_count -gt 0 ]]; then
        return 0  # Tool is in use
    else
        return 1  # Tool is not in use
    fi
}

# Uninstall a specific tool
uninstall_tool() {
    local tool=$1

    log "INFO" "Uninstalling $tool..."
    echo -e "\n${INFO} Uninstalling ${CYAN}$tool${RESET}..."

    # Check if the tool exists in our uninstall commands
    if [[ -z "${UNINSTALL_CMDS[$tool]}" ]]; then
        log "WARN" "Unknown tool: $tool. Skipping."
        echo -e "${WARN} Unknown tool: $tool. Skipping."
        return 1
    fi

    # Check if tool is in use (only if not in dry run mode)
    if [[ "${CONFIG[DRY_RUN]}" != true ]] && check_if_in_use "$tool"; then
        log "WARN" "$tool appears to be in use. This may cause issues."
        echo -e "${WARN} $tool appears to be in use. This may cause issues."
        echo -e "${YELLOW}Do you want to continue anyway? (y/n):${RESET}"
        read -r choice
        if [[ "$choice" != "y" ]]; then
            log "INFO" "Skipping uninstallation of $tool due to user choice."
            echo -e "${INFO} Skipping uninstallation of $tool."
            return 1
        fi
    fi

    # Run the uninstallation command
    if run_cmd "${UNINSTALL_CMDS[$tool]}"; then
        # Verify uninstallation
        if [[ "${CONFIG[DRY_RUN]}" != true ]]; then
            if eval "${VERIFY_CMDS[$tool]}" &>/dev/null; then
                log "SUCCESS" "$tool uninstalled successfully"
                echo -e "${SUCCESS} $tool uninstalled successfully"
                update_state "$tool" "uninstalled"
                return 0
            else
                log "WARN" "$tool uninstallation verification failed"
                echo -e "${WARN} $tool uninstallation verification failed. Some components may remain."
                update_state "$tool" "uninstalled"
                return 1
            fi
        else
            log "SUCCESS" "DRY RUN: $tool would be uninstalled"
            echo -e "${SUCCESS} DRY RUN: $tool would be uninstalled"
            return 0
        fi
    else
        log "ERROR" "Failed to uninstall $tool"
        echo -e "${FAIL} Failed to uninstall $tool"
        return 1
    fi
}

# Perform system cleanup after uninstallations
system_cleanup() {
    log "INFO" "Performing system cleanup..."
    echo -e "\n${INFO} Performing system cleanup..."

    # Remove unused packages
    case "$PKG_MANAGER" in
        apt-get)
            run_cmd "apt-get autoremove -y"
            run_cmd "apt-get clean"
            ;;
        dnf|yum)
            run_cmd "$PKG_MANAGER autoremove -y"
            run_cmd "$PKG_MANAGER clean all"
            ;;
        pacman)
            run_cmd "pacman -Sc --noconfirm"
            ;;
        zypper)
            run_cmd "zypper clean"
            ;;
        apk)
            run_cmd "apk cache clean"
            ;;
    esac

    # Clean up temporary files
    run_cmd "rm -rf /tmp/tmp.*"

    log "SUCCESS" "System cleanup completed"
    echo -e "${SUCCESS} System cleanup completed"
}

# Main function
main() {
    # Change to script directory to ensure relative paths work
    cd "$SCRIPT_DIR" || {
        echo "Failed to change directory to $SCRIPT_DIR"
        exit 1
    }

    # Check for dry run flag
    if [[ "$1" == "--dry-run" ]]; then
        CONFIG[DRY_RUN]=true
    fi

    # Initialize
    create_required_dirs
    init_state_file
    cleanup_old_logs
    detect_os
    show_banner

    # Get tool selection
    echo -e "${CYAN}Loading tool selection menu...${RESET}"
    local selected_tools=$(cli_tool_prompt)

    if [[ -z "$selected_tools" ]]; then
        log "ERROR" "No tools selected for uninstallation"
        echo -e "${RED}No tools selected for uninstallation.${RESET}"
        exit 1
    fi

    # Count selected tools
    read -ra tools_array <<< "$selected_tools"
    local tool_count=${#tools_array[@]}

    log "INFO" "Selected $tool_count tools for uninstallation: $selected_tools"
    echo -e "${INFO} Selected ${BLUE}$tool_count${RESET} tools for uninstallation"

    if [[ "${CONFIG[DRY_RUN]}" == true ]]; then
        echo -e "${PURPLE}DRY RUN MODE: No changes will actually be made${RESET}"
        echo -e "${YELLOW}Continue with dry run? (y/n):${RESET}"
    else
        echo -e "${RED}WARNING: This will uninstall the selected tools and remove their data${RESET}"
        echo -e "${YELLOW}Continue? (y/n):${RESET}"
    fi
    read -r confirm

    if [[ "$confirm" != "y" ]]; then
        log "INFO" "Uninstallation aborted by user"
        echo -e "${INFO} Uninstallation aborted."
        exit 0
    fi

    # Track success and failure
    local success=0
    local failed=0

    # Uninstall each tool
    for tool in "${tools_array[@]}"; do
        if uninstall_tool "$tool"; then
            ((success++))
        else
            ((failed++))
        fi
    done

    # Perform system cleanup
    if [[ $success -gt 0 && "${CONFIG[DRY_RUN]}" != true ]]; then
        system_cleanup
    fi

    # Summary
    echo -e "\n${SUCCESS} Uninstallation summary: ${GREEN}$success${RESET} succeeded, ${RED}$failed${RESET} failed, ${BLUE}$tool_count${RESET} total"
    log "INFO" "Uninstallation summary: $success succeeded, $failed failed, $tool_count total"

    echo -e "\n📁 Logs saved in: ${BLUE}${CONFIG[LOG_FILE]}${RESET}"
    echo -e "🧹 ${GREEN}Cleanup done. You're all set!${RESET}"
    echo ""
    echo "############################################################################"
    echo "#                                                                          #"
    echo "#     🧹 DevOps Tool Uninstaller by ProDevOpsGuy Tech                     #"
    echo "#                                                                          #"
    echo "############################################################################"
    echo ""
    echo "🔸 For more tools and scripts, visit: https://github.com/notharshhaa       🔸"
}

# Execute main function
main "$@"
