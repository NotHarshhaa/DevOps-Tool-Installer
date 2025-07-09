#!/bin/bash

set -e

# === Config ===
TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
LOG_DIR="logs/uninstall_$TIMESTAMP"
LOG_FILE="$LOG_DIR/uninstall.log"
DRY_RUN=false
MAX_LOG_DIRS=5

# Check for root/sudo privileges
if [ "$EUID" -ne 0 ] && ! sudo -n true 2>/dev/null; then
    echo "This script requires root privileges. Please run with sudo."
    exit 1
fi

# Create log directory with error handling
if ! mkdir -p "$LOG_DIR"; then
    echo "Failed to create log directory: $LOG_DIR"
    exit 1
fi

# Cleanup old log directories
cleanup_old_logs() {
    local log_count=$(ls -d logs/uninstall_* 2>/dev/null | wc -l)
    if [ "$log_count" -gt "$MAX_LOG_DIRS" ]; then
        ls -dt logs/uninstall_* | tail -n +$((MAX_LOG_DIRS + 1)) | xargs rm -rf
    fi
}
cleanup_old_logs

# Emojis and colors
GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
RESET="\033[0m"
SUCCESS="${GREEN}✅${RESET}"
FAIL="${RED}❌${RESET}"
INFO="${BLUE}ℹ️${RESET}"

# Welcome Banner
clear
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BLUE}║${RESET}                                                                      ${BLUE}║${RESET}"
echo -e "${BLUE}║${RESET}   ${GREEN}🔥 ProDevOpsGuy DevOps Tool Uninstaller - Clean With Confidence! ${RESET}   ${BLUE}║${RESET}"
echo -e "${BLUE}║${RESET}                                                                      ${BLUE}║${RESET}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  ${YELLOW}🔸 Remove DevOps tools with cleanup of configs and services.${RESET}"
echo -e "  ${YELLOW}🔸 Logs stored at ${LOG_FILE}.${RESET}"
echo -e "  ${YELLOW}🔸 Use \`--dry-run\` to simulate uninstallation.${RESET}"
echo ""

# Log function
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# OS and package manager detection
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
    else
        OS=$(uname -s)
    fi

    case "$OS" in
        ubuntu | debian | zorin) PKG_MANAGER="apt-get" ;;
        centos | rhel | fedora | amazon) PKG_MANAGER="yum" ;;
        arch) PKG_MANAGER="pacman" ;;
        opensuse | sles) PKG_MANAGER="zypper" ;;
        alpine) PKG_MANAGER="apk" ;;
        *) log "${FAIL} Unsupported OS: $OS" && exit 1 ;;
    esac
    log "${INFO} Detected OS: $OS, using package manager: $PKG_MANAGER"
}

# Dry run notice
run_cmd() {
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY RUN] $1"
    else
        eval "$1"
    fi
}

# Uninstall commands per tool
declare -A UNINSTALL_CMDS=(
    [docker]="if systemctl is-active docker &>/dev/null; then sudo systemctl stop docker; fi; sudo $PKG_MANAGER remove -y docker* || true; sudo rm -rf /var/lib/docker /etc/docker"
    [kubectl]="if [ -f /usr/local/bin/kubectl ]; then sudo rm -f /usr/local/bin/kubectl; fi"
    [ansible]="sudo $PKG_MANAGER remove -y ansible || true"
    [terraform]="sudo $PKG_MANAGER remove -y terraform || true; if [ -f /usr/local/bin/terraform ]; then sudo rm -f /usr/local/bin/terraform; fi"
    [helm]="if [ -f /usr/local/bin/helm ]; then sudo rm -f /usr/local/bin/helm; fi"
    [awscli]="if [ -d /usr/local/aws ]; then sudo rm -rf /usr/local/aws /usr/local/bin/aws; fi"
    [azurecli]="sudo $PKG_MANAGER remove -y azure-cli || true"
    [gcloud]="if [ -d /usr/local/google-cloud-sdk ]; then sudo rm -rf /usr/local/google-cloud-sdk; fi"
    [grafana]="if systemctl is-active grafana-server &>/dev/null; then sudo systemctl stop grafana-server; fi; sudo $PKG_MANAGER remove -y grafana || true; sudo rm -rf /etc/grafana /var/lib/grafana"
    [gitlab-runner]="if command -v gitlab-runner &>/dev/null; then sudo gitlab-runner uninstall; fi; sudo rm -f /usr/local/bin/gitlab-runner"
    [istio]="if [ -f /usr/local/bin/istioctl ]; then sudo rm -f /usr/local/bin/istioctl; fi"
    [openshift]="if [ -f /usr/local/bin/oc ]; then sudo rm -f /usr/local/bin/oc /usr/local/bin/kubectl; fi"
    [minikube]="if [ -f /usr/local/bin/minikube ]; then sudo rm -f /usr/local/bin/minikube; fi"
    [packer]="if [ -f /usr/local/bin/packer ]; then sudo rm -f /usr/local/bin/packer; fi"
    [jenkins]="if systemctl is-active jenkins &>/dev/null; then sudo systemctl stop jenkins; fi; sudo $PKG_MANAGER remove -y jenkins || true; sudo rm -rf /var/lib/jenkins /etc/jenkins"
    [vault]="if [ -f /usr/local/bin/vault ]; then sudo rm -f /usr/local/bin/vault; fi"
    [consul]="if [ -f /usr/local/bin/consul ]; then sudo rm -f /usr/local/bin/consul; fi"
)

# Group tools by category
declare -A TOOL_CATEGORIES=(
    [Cloud]="awscli azurecli gcloud"
    [Containers]="docker kubectl helm openshift istio minikube"
    [IaC]="terraform ansible packer vault consul"
    [CI/CD]="gitlab-runner jenkins"
    [Monitoring]="grafana"
)

# Gum-based checklist UI
show_tool_checklist() {
    local tool_list=()
    for CATEGORY in "${!TOOL_CATEGORIES[@]}"; do
        for TOOL in ${TOOL_CATEGORIES[$CATEGORY]}; do
            tool_list+=("$TOOL ($CATEGORY)")
        done
    done

    SELECTED=$(printf "%s\n" "${tool_list[@]}" | gum choose --no-limit --height=20 --header="Select tools to uninstall:")

    for item in $SELECTED; do
        echo "$item" | awk '{print $1}'
    done
}

# CLI fallback
cli_tool_prompt() {
    echo "Enter tool names to uninstall (space-separated). Options:"
    for CATEGORY in "${!TOOL_CATEGORIES[@]}"; do
        echo "- $CATEGORY: ${TOOL_CATEGORIES[$CATEGORY]}"
    done
    read -rp "Your selection: " selection
    echo "$selection"
}

# === MAIN ===

# Check for dry run
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    log "${INFO} Dry run enabled. No changes will be made."
fi

detect_os

# Check gum or fallback
if command -v gum >/dev/null 2>&1; then
    SELECTED_TOOLS=$(show_tool_checklist)
else
    SELECTED_TOOLS=$(cli_tool_prompt)
fi

SELECTED_TOOLS=$(echo "$SELECTED_TOOLS" | tr -d '"')

for TOOL in $SELECTED_TOOLS; do
    if [[ -n "${UNINSTALL_CMDS[$TOOL]}" ]]; then
        log "${INFO} Uninstalling $TOOL..."
        run_cmd "${UNINSTALL_CMDS[$TOOL]}" \
            && log "${SUCCESS} $TOOL uninstalled successfully." \
            || log "${FAIL} Failed to uninstall $TOOL."
    else
        log "${YELLOW}⚠️ Unknown tool: $TOOL. Skipping.${RESET}"
    fi
done

log "${SUCCESS} Uninstallation complete."
echo -e "\n📁 Logs saved in: ${BLUE}$LOG_FILE${RESET}"
echo -e "🧹 ${GREEN}Cleanup done. You're all set!${RESET}"
echo ""
echo "############################################################################"
echo "#                                                                          #"
echo "#     🧹 DevOps Tool Uninstaller by ProDevOpsGuy Tech                     #"
echo "#                                                                          #"
echo "############################################################################"
echo ""
echo "🔸 For more tools and scripts, visit: https://github.com/notharshhaa       🔸"
