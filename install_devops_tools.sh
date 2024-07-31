#!/bin/bash

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
echo "Tools available for installation/uninstallation:"
echo "  - Docker 🐳"
echo "  - Kubernetes (kubectl) ☸️"
echo "  - Ansible 📜"
echo "  - Terraform 🌍"
echo "  - Jenkins 🏗️"
echo "  - AWS CLI ☁️"
echo "  - Azure CLI ☁️"
echo "  - Google Cloud SDK ☁️"
echo "  - Helm ⛵"
echo "  - Prometheus 📈"
echo "  - Grafana 📊"
echo "  - GitLab Runner 🏃‍♂️"
echo "  - HashiCorp Vault 🔐"
echo "  - HashiCorp Consul 🌐"
echo ""

# Function to prompt user for their Linux distribution
get_linux_distribution() {
  echo "Select your Linux distribution:"
  echo "1. Ubuntu/Debian"
  echo "2. CentOS/RHEL"
  echo "3. Fedora"
  read -p "Enter the number corresponding to your distribution: " distro_choice
}

# Function to install Docker
install_docker() {
  case $distro_choice in
    1)
      sudo apt-get update
      sudo apt-get install -y docker-ce docker-ce-cli containerd.io
      ;;
    2)
      sudo yum install -y yum-utils
      sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      sudo yum install -y docker-ce docker-ce-cli containerd.io
      ;;
    3)
      sudo dnf -y install dnf-plugins-core
      sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
      sudo dnf install -y docker-ce docker-ce-cli containerd.io
      ;;
    *)
      echo "Invalid Linux distribution choice. Exiting."
      exit 1
      ;;
  esac
  sudo systemctl start docker
  sudo systemctl enable docker
  echo "Docker installed successfully."
}

# Function to uninstall Docker
uninstall_docker() {
  case $distro_choice in
    1)
      sudo apt-get remove -y docker-ce docker-ce-cli containerd.io
      sudo apt-get purge -y docker-ce docker-ce-cli containerd.io
      sudo rm -rf /var/lib/docker
      ;;
    2)
      sudo yum remove -y docker-ce docker-ce-cli containerd.io
      sudo rm -rf /var/lib/docker
      ;;
    3)
      sudo dnf remove -y docker-ce docker-ce-cli containerd.io
      sudo rm -rf /var/lib/docker
      ;;
    *)
      echo "Invalid Linux distribution choice. Exiting."
      exit 1
      ;;
  esac
  echo "Docker uninstalled successfully."
}

# Function to install Kubernetes (kubectl)
install_kubernetes() {
  curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x ./kubectl
  sudo mv ./kubectl /usr/local/bin/kubectl
  echo "Kubernetes (kubectl) installed successfully."
}

# Function to uninstall Kubernetes (kubectl)
uninstall_kubernetes() {
  sudo rm /usr/local/bin/kubectl
  echo "Kubernetes (kubectl) uninstalled successfully."
}

# Function to install Ansible
install_ansible() {
  case $distro_choice in
    1)
      sudo apt-get update
      sudo apt-get install -y ansible
      ;;
    2)
      sudo yum install -y epel-release
      sudo yum install -y ansible
      ;;
    3)
      sudo dnf install -y ansible
      ;;
    *)
      echo "Invalid Linux distribution choice. Exiting."
      exit 1
      ;;
  esac
  echo "Ansible installed successfully."
}

# Function to uninstall Ansible
uninstall_ansible() {
  case $distro_choice in
    1)
      sudo apt-get remove -y ansible
      sudo apt-get purge -y ansible
      ;;
    2)
      sudo yum remove -y ansible
      ;;
    3)
      sudo dnf remove -y ansible
      ;;
    *)
      echo "Invalid Linux distribution choice. Exiting."
      exit 1
      ;;
  esac
  echo "Ansible uninstalled successfully."
}

# Function to install Terraform
install_terraform() {
  curl -LO https://releases.hashicorp.com/terraform/0.14.9/terraform_0.14.9_linux_amd64.zip
  unzip terraform_0.14.9_linux_amd64.zip
  sudo mv terraform /usr/local/bin/
  rm terraform_0.14.9_linux_amd64.zip
  echo "Terraform installed successfully."
}

# Function to uninstall Terraform
uninstall_terraform() {
  sudo rm /usr/local/bin/terraform
  echo "Terraform uninstalled successfully."
}

# Function to install Jenkins
install_jenkins() {
  case $distro_choice in
    1)
      curl -fsSL https://pkg.jenkins.io/debian/jenkins.io.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
      echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
      sudo apt-get update
      sudo apt-get install -y jenkins
      ;;
    2)
      sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
      sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
      sudo yum install -y jenkins
      ;;
    3)
      sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
      sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
      sudo dnf install -y jenkins
      ;;
    *)
      echo "Invalid Linux distribution choice. Exiting."
      exit 1
      ;;
  esac
  sudo systemctl start jenkins
  sudo systemctl enable jenkins
  echo "Jenkins installed successfully."
}

# Function to uninstall Jenkins
uninstall_jenkins() {
  case $distro_choice in
    1)
      sudo apt-get remove -y jenkins
      sudo apt-get purge -y jenkins
      ;;
    2|3)
      sudo yum remove -y jenkins
      ;;
    *)
      echo "Invalid Linux distribution choice. Exiting."
      exit 1
      ;;
  esac
  echo "Jenkins uninstalled successfully."
}

# Function to install AWS CLI
install_awscli() {
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  sudo ./aws/install
  rm awscliv2.zip
  echo "AWS CLI installed successfully."
}

# Function to uninstall AWS CLI
uninstall_awscli() {
  sudo rm /usr/local/bin/aws
  sudo rm -rf /usr/local/aws-cli
  echo "AWS CLI uninstalled successfully."
}

# Function to install Azure CLI
install_azurecli() {
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
  echo "Azure CLI installed successfully."
}

# Function to uninstall Azure CLI
uninstall_azurecli() {
  sudo apt-get remove -y azure-cli
  sudo apt-get purge -y azure-cli
  echo "Azure CLI uninstalled successfully."
}

# Function to install Google Cloud SDK
install_gcloud() {
  curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-346.0.0-linux-x86_64.tar.gz
  tar -xvzf google-cloud-sdk-346.0.0-linux-x86_64.tar.gz
  ./google-cloud-sdk/install.sh
  echo "Google Cloud SDK installed successfully."
}

# Function to uninstall Google Cloud SDK
uninstall_gcloud() {
  sudo rm -rf google-cloud-sdk
  echo "Google Cloud SDK uninstalled successfully."
}

# Function to install Helm
install_helm() {
  curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  chmod 700 get_helm.sh
  ./get_helm.sh
  echo "Helm installed successfully."
}

# Function to uninstall Helm
uninstall_helm() {
  sudo rm /usr/local/bin/helm
  echo "Helm uninstalled successfully."
}

# Function to install Prometheus
install_prometheus() {
  curl -LO https://github.com/prometheus/prometheus/releases/download/v2.26.0/prometheus-2.26.0.linux-amd64.tar.gz
  tar -xvf prometheus-2.26.0.linux-amd64.tar.gz
  sudo mv prometheus-2.26.0.linux-amd64 /usr/local/bin/prometheus
  echo "Prometheus installed successfully."
}

# Function to uninstall Prometheus
uninstall_prometheus() {
  sudo rm -rf /usr/local/bin/prometheus
  echo "Prometheus uninstalled successfully."
}

# Function to install Grafana
install_grafana() {
  sudo apt-get install -y software-properties-common
  sudo apt-add-repository "deb https://packages.grafana.com/oss/deb stable main"
  sudo apt-get update
  sudo apt-get install -y grafana
  echo "Grafana installed successfully."
}

# Function to uninstall Grafana
uninstall_grafana() {
  sudo apt-get remove -y grafana
  sudo apt-get purge -y grafana
  echo "Grafana uninstalled successfully."
}

# Function to install GitLab Runner
install_gitlab_runner() {
  curl -L --output /usr/local/bin/gitlab-runner https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64
  sudo chmod +x /usr/local/bin/gitlab-runner
  echo "GitLab Runner installed successfully."
}

# Function to uninstall GitLab Runner
uninstall_gitlab_runner() {
  sudo rm /usr/local/bin/gitlab-runner
  echo "GitLab Runner uninstalled successfully."
}

# Function to install HashiCorp Vault
install_vault() {
  curl -LO https://releases.hashicorp.com/vault/1.7.0/vault_1.7.0_linux_amd64.zip
  unzip vault_1.7.0_linux_amd64.zip
  sudo mv vault /usr/local/bin/
  rm vault_1.7.0_linux_amd64.zip
  echo "HashiCorp Vault installed successfully."
}

# Function to uninstall HashiCorp Vault
uninstall_vault() {
  sudo rm /usr/local/bin/vault
  echo "HashiCorp Vault uninstalled successfully."
}

# Function to install HashiCorp Consul
install_consul() {
  curl -LO https://releases.hashicorp.com/consul/1.9.5/consul_1.9.5_linux_amd64.zip
  unzip consul_1.9.5_linux_amd64.zip
  sudo mv consul /usr/local/bin/
  rm consul_1.9.5_linux_amd64.zip
  echo "HashiCorp Consul installed successfully."
}

# Function to uninstall HashiCorp Consul
uninstall_consul() {
  sudo rm /usr/local/bin/consul
  echo "HashiCorp Consul uninstalled successfully."
}

# Function to display the main menu and handle user input
main_menu() {
  echo "Choose an action:"
  echo "1. Install a tool"
  echo "2. Uninstall a tool"
  echo "3. Exit"
  read -p "Enter your choice: " action_choice

  if [[ $action_choice -eq 1 || $action_choice -eq 2 ]]; then
    get_linux_distribution
    echo "Select a tool:"
    echo "1. Docker"
    echo "2. Kubernetes (kubectl)"
    echo "3. Ansible"
    echo "4. Terraform"
    echo "5. Jenkins"
    echo "6. AWS CLI"
    echo "7. Azure CLI"
    echo "8. Google Cloud SDK"
    echo "9. Helm"
    echo "10. Prometheus"
    echo "11. Grafana"
    echo "12. GitLab Runner"
    echo "13. HashiCorp Vault"
    echo "14. HashiCorp Consul"
    read -p "Enter the number corresponding to the tool: " tool_choice

    case $tool_choice in
      1)
        [[ $action_choice -eq 1 ]] && install_docker || uninstall_docker
        ;;
      2)
        [[ $action_choice -eq 1 ]] && install_kubernetes || uninstall_kubernetes
        ;;
      3)
        [[ $action_choice -eq 1 ]] && install_ansible || uninstall_ansible
        ;;
      4)
        [[ $action_choice -eq 1 ]] && install_terraform || uninstall_terraform
        ;;
      5)
        [[ $action_choice -eq 1 ]] && install_jenkins || uninstall_jenkins
        ;;
      6)
        [[ $action_choice -eq 1 ]] && install_awscli || uninstall_awscli
        ;;
      7)
        [[ $action_choice -eq 1 ]] && install_azurecli || uninstall_azurecli
        ;;
      8)
        [[ $action_choice -eq 1 ]] && install_gcloud || uninstall_gcloud
        ;;
      9)
        [[ $action_choice -eq 1 ]] && install_helm || uninstall_helm
        ;;
      10)
        [[ $action_choice -eq 1 ]] && install_prometheus || uninstall_prometheus
        ;;
      11)
        [[ $action_choice -eq 1 ]] && install_grafana || uninstall_grafana
        ;;
      12)
        [[ $action_choice -eq 1 ]] && install_gitlab_runner || uninstall_gitlab_runner
        ;;
      13)
        [[ $action_choice -eq 1 ]] && install_vault || uninstall_vault
        ;;
      14)
        [[ $action_choice -eq 1 ]] && install_consul || uninstall_consul
        ;;
      *)
        echo "Invalid tool choice. Exiting."
        exit 1
        ;;
    esac
  elif [[ $action_choice -eq 3 ]]; then
    echo "Exiting. Goodbye!"
    exit 0
  else
    echo "Invalid action choice. Exiting."
    exit 1
  fi
}

# Run the main menu
main_menu
