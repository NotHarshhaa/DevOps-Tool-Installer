#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Constants for tool versions
KUBECTL_VERSION="$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)"
TERRAFORM_VERSION="0.14.9"
JENKINS_REPO="https://pkg.jenkins.io"
AWS_CLI_URL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
GOOGLE_CLOUD_SDK_URL="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-346.0.0-linux-x86_64.tar.gz"
HELM_SCRIPT="https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3"
GRAFANA_RPM_URL="https://packages.grafana.com/oss/rpm/grafana-7.3.1-1.x86_64.rpm"
PACKER_VERSION="1.7.2"
VAGRANT_VERSION="2.2.14"
ISTIO_VERSION="1.9.5"

# Welcome Message
clear
echo "############################################################################"
echo "#                                                                          #"
echo "#          DevOps Tool Installer/Uninstaller by ProDevOpsGuy Tech          #"
echo "#                                                                          #"
echo "############################################################################"
echo ""
echo "Automate the installation and uninstallation of essential DevOps tools on your Linux machine."
echo "Choose from a wide range of tools and get started quickly and easily."
echo ""

# Function to prompt user for their Linux distribution
get_linux_distribution() {
  echo "Select your Linux distribution:"
  echo "1. Ubuntu/Debian"
  echo "2. CentOS/RHEL"
  echo "3. Fedora"
  read -p "Enter the number corresponding to your distribution: " distro_choice

  case $distro_choice in
    1) DISTRO="ubuntu";;
    2) DISTRO="centos";;
    3) DISTRO="fedora";;
    *) echo "Invalid Linux distribution choice. Exiting." && exit 1;;
  esac
}

# Function to handle installations
install_tool() {
  local tool_name="$1"
  local install_cmd="$2"

  echo "Installing $tool_name..."
  eval "$install_cmd"
  echo "$tool_name installed successfully."
}

# Function to handle uninstallation
uninstall_tool() {
  local tool_name="$1"
  local uninstall_cmd="$2"

  echo "Uninstalling $tool_name..."
  eval "$uninstall_cmd"
  echo "$tool_name uninstalled successfully."
}

# Installation Commands
declare -A install_commands=(
  [docker]="sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io"
  [kubectl]="curl -LO https://storage.googleapis.com/kubernetes-release/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl && chmod +x ./kubectl && sudo mv ./kubectl /usr/local/bin/"
  [ansible]="sudo apt-get update && sudo apt-get install -y ansible"
  [terraform]="curl -LO https://releases.hashicorp.com/terraform/$TERRAFORM_VERSION/terraform_$TERRAFORM_VERSION_linux_amd64.zip && unzip terraform_$TERRAFORM_VERSION_linux_amd64.zip && sudo mv terraform /usr/local/bin/ && rm terraform_$TERRAFORM_VERSION_linux_amd64.zip"
  [jenkins]="curl -fsSL $JENKINS_REPO/jenkins.io.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null && echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] $JENKINS_REPO/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null && sudo apt-get update && sudo apt-get install -y jenkins"
  [awscli]="curl "$AWS_CLI_URL" -o "awscliv2.zip" && unzip awscliv2.zip && sudo ./aws/install && rm awscliv2.zip"
  [azurecli]="curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
  [gcloud]="curl -O $GOOGLE_CLOUD_SDK_URL && tar -xvzf google-cloud-sdk-346.0.0-linux-x86_64.tar.gz && ./google-cloud-sdk/install.sh"
  [helm]="curl -fsSL -o get_helm.sh $HELM_SCRIPT && chmod 700 get_helm.sh && ./get_helm.sh"
  [grafana]="sudo apt-get install -y software-properties-common && sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main" && sudo apt-get update && sudo apt-get install -y grafana"
  [gitlab-runner]="curl -L --output /usr/local/bin/gitlab-runner https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64 && chmod +x /usr/local/bin/gitlab-runner"
  [vault]="curl -LO https://releases.hashicorp.com/vault/1.7.0/vault_1.7.0_linux_amd64.zip && unzip vault_1.7.0_linux_amd64.zip && sudo mv vault /usr/local/bin/ && rm vault_1.7.0_linux_amd64.zip"
  [consul]="curl -LO https://releases.hashicorp.com/consul/1.9.4/consul_1.9.4_linux_amd64.zip && unzip consul_1.9.4_linux_amd64.zip && sudo mv consul /usr/local/bin/ && rm consul_1.9.4_linux_amd64.zip"
  [istio]="curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh - && sudo mv istio-$ISTIO_VERSION/bin/istioctl /usr/local/bin/"
  [openshift]="curl -LO https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz && tar -xvf openshift-client-linux.tar.gz && sudo mv oc /usr/local/bin/ && sudo mv kubectl /usr/local/bin/"
  [minikube]="curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && sudo install minikube-linux-amd64 /usr/local/bin/minikube"
  [packer]="curl -LO https://releases.hashicorp.com/packer/$PACKER_VERSION/packer_$PACKER_VERSION_linux_amd64.zip && unzip packer_$PACKER_VERSION_linux_amd64.zip && sudo mv packer /usr/local/bin/ && rm packer_$PACKER_VERSION_linux_amd64.zip"
  [vagrant]="curl -LO https://releases.hashicorp.com/vagrant/$VAGRANT_VERSION/vagrant_$VAGRANT_VERSION_linux_amd64.zip && unzip vagrant_$VAGRANT_VERSION_linux_amd64.zip && sudo mv vagrant /usr/local/bin/ && rm vagrant_$VAGRANT_VERSION_linux_amd64.zip"
)

# Uninstallation Commands
declare -A uninstall_commands=(
  [docker]="sudo apt-get remove -y docker-ce docker-ce-cli containerd.io && sudo apt-get purge -y docker-ce docker-ce-cli containerd.io && sudo rm -rf /var/lib/docker"
  [kubectl]="sudo rm /usr/local/bin/kubectl"
  [ansible]="sudo apt-get remove -y ansible && sudo apt-get purge -y ansible"
  [terraform]="sudo rm /usr/local/bin/terraform"
  [jenkins]="sudo apt-get remove -y jenkins && sudo apt-get purge -y jenkins"
  [awscli]="sudo rm /usr/local/bin/aws && sudo rm -rf /usr/local/aws-cli"
  [azurecli]="sudo apt-get remove -y azure-cli && sudo apt-get purge -y azure-cli"
  [gcloud]="sudo rm -rf google-cloud-sdk"
  [helm]="sudo rm /usr/local/bin/helm"
  [grafana]="sudo apt-get remove -y grafana && sudo apt-get purge -y grafana"
  [gitlab-runner]="sudo rm /usr/local/bin/gitlab-runner"
  [vault]="sudo rm /usr/local/bin/vault"
  [consul]="sudo rm /usr/local/bin/consul"
  [istio]="sudo rm /usr/local/bin/istioctl"
  [openshift]="sudo rm /usr/local/bin/oc && sudo rm /usr/local/bin/kubectl"
  [minikube]="sudo rm /usr/local/bin/minikube"
  [packer]="sudo rm /usr/local/bin/packer"
  [vagrant]="sudo rm /usr/local/bin/vagrant"
)

# Prompt user for action
read -p "Do you want to install or uninstall tools? (install/uninstall): " action

if [[ "$action" != "install" && "$action" != "uninstall" ]]; then
  echo "Invalid action selected. Exiting."
  exit 1
fi

get_linux_distribution

# Prompt user for tool selection
echo "Select tools to $action (separate with spaces):"
for tool in "${!install_commands[@]}"; do
  echo "- $tool"
done
read -p "Your selection: " selected_tools

# Process each selected tool
for tool in $selected_tools; do
  if [[ "$action" == "install" ]]; then
    if [[ -v install_commands["$tool"] ]]; then
      install_tool "$tool" "${install_commands[$tool]}"
    else
      echo "No installation command found for $tool."
    fi
  elif [[ "$action" == "uninstall" ]]; then
    if [[ -v uninstall_commands["$tool"] ]]; then
      uninstall_tool "$tool" "${uninstall_commands[$tool]}"
    else
      echo "No uninstallation command found for $tool."
    fi
  fi
done

echo "Operation completed successfully."
