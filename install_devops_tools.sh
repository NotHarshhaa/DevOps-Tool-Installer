#!/bin/bash

# Welcome Message
clear
echo "#################################################################"
echo "#                                                               #"
echo "#          DevOps Tool Installer by ProDevOpsGuy Tech           #"
echo "#                                                               #"
echo "#################################################################"
echo ""
echo "Automate the installation of essential DevOps tools on your Linux machine."
echo "Choose from a wide range of tools and get started quickly and easily."
echo ""
echo "Tools available for installation:"
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
echo "############################################################"
echo ""
echo "Please select your Linux distribution:"
echo "1) Ubuntu/Debian"
echo "2) CentOS/RHEL"
echo "3) Fedora"
echo ""

read -p "Enter your choice (1-3): " os_choice

# Function to install Docker
install_docker() {
  case $os_choice in
    1)
      sudo apt-get update
      sudo apt-get install -y docker.io
      ;;
    2)
      sudo yum install -y docker
      ;;
    3)
      sudo dnf install -y docker
      ;;
    *)
      echo "Invalid OS choice. Exiting."
      exit 1
      ;;
  esac
  sudo systemctl start docker
  sudo systemctl enable docker
  echo "Docker installed successfully."
}

# Function to install Kubernetes (kubectl)
install_kubernetes() {
  case $os_choice in
    1)
      sudo apt-get update
      sudo apt-get install -y kubectl
      ;;
    2)
      sudo yum install -y kubectl
      ;;
    3)
      sudo dnf install -y kubectl
      ;;
    *)
      echo "Invalid OS choice. Exiting."
      exit 1
      ;;
  esac
  echo "Kubernetes (kubectl) installed successfully."
}

# Function to install Ansible
install_ansible() {
  case $os_choice in
    1)
      sudo apt-get update
      sudo apt-get install -y ansible
      ;;
    2)
      sudo yum install -y ansible
      ;;
    3)
      sudo dnf install -y ansible
      ;;
    *)
      echo "Invalid OS choice. Exiting."
      exit 1
      ;;
  esac
  echo "Ansible installed successfully."
}

# Function to install Terraform
install_terraform() {
  sudo curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
  sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
  sudo apt-get update && sudo apt-get install terraform
  echo "Terraform installed successfully."
}

# Function to install Jenkins
install_jenkins() {
  case $os_choice in
    1)
      wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo apt-key add -
      sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
      sudo apt-get update
      sudo apt-get install -y jenkins
      ;;
    2)
      sudo yum install -y epel-release
      sudo yum install -y java-11-openjdk-devel
      sudo wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins-ci.org/redhat/jenkins.repo
      sudo rpm --import https://pkg.jenkins.io/redhat/jenkins.io.key
      sudo yum install -y jenkins
      ;;
    3)
      sudo dnf install -y epel-release
      sudo dnf install -y java-11-openjdk-devel
      sudo wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins-ci.org/redhat/jenkins.repo
      sudo rpm --import https://pkg.jenkins.io/redhat/jenkins.io.key
      sudo dnf install -y jenkins
      ;;
    *)
      echo "Invalid OS choice. Exiting."
      exit 1
      ;;
  esac
  sudo systemctl start jenkins
  sudo systemctl enable jenkins
  echo "Jenkins installed successfully."
}

# Function to install AWS CLI
install_awscli() {
  case $os_choice in
    1)
      sudo apt-get update
      sudo apt-get install -y awscli
      ;;
    2)
      sudo yum install -y awscli
      ;;
    3)
      sudo dnf install -y awscli
      ;;
    *)
      echo "Invalid OS choice. Exiting."
      exit 1
      ;;
  esac
  echo "AWS CLI installed successfully."
}

# Function to install Azure CLI
install_azurecli() {
  case $os_choice in
    1)
      curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
      ;;
    2)
      sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
      sudo sh -c 'echo -e "[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/azure-cli.repo'
      sudo yum install -y azure-cli
      ;;
    3)
      sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
      sudo sh -c 'echo -e "[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/azure-cli.repo'
      sudo dnf install -y azure-cli
      ;;
    *)
      echo "Invalid OS choice. Exiting."
      exit 1
      ;;
  esac
  echo "Azure CLI installed successfully."
}

# Function to install Google Cloud SDK
install_gcloud() {
  case $os_choice in
    1)
      echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
      sudo apt-get update && sudo apt-get install -y google-cloud-sdk
      ;;
    2)
      sudo tee -a /etc/yum.repos.d/google-cloud-sdk.repo << EOM
[google-cloud-sdk]
name=Google Cloud SDK
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOM
      sudo yum install -y google-cloud-sdk
      ;;
    3)
      sudo tee -a /etc/yum.repos.d/google-cloud-sdk.repo << EOM
[google-cloud-sdk]
name=Google Cloud SDK
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOM
      sudo dnf install -y google-cloud-sdk
      ;;
    *)
      echo "Invalid OS choice. Exiting."
      exit 1
      ;;
  esac
  echo "Google Cloud SDK installed successfully."
}

# Function to install Helm
install_helm() {
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  echo "Helm installed successfully."
}

# Function to install Prometheus
install_prometheus() {
  wget https://github.com/prometheus/prometheus/releases/download/v2.26.0/prometheus-2.26.0.linux-amd64.tar.gz
  tar xvfz prometheus-*.tar.gz
  sudo mv prometheus-*/prometheus /usr/local/bin/
  sudo mv prometheus-*/promtool /usr/local/bin/
  echo "Prometheus installed successfully."
}

# Function to install Grafana
install_grafana() {
  sudo apt-get install -y software-properties-common
  sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
  sudo apt-get update
  sudo apt-get install -y grafana
  sudo systemctl start grafana-server
  sudo systemctl enable grafana-server
  echo "Grafana installed successfully."
}

# Function to install GitLab Runner
install_gitlab_runner() {
  curl -L --output /usr/local/bin/gitlab-runner https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64
  sudo chmod +x /usr/local/bin/gitlab-runner
  sudo useradd --comment 'GitLab Runner' --create-home gitlab-runner --shell /bin/bash
  sudo gitlab-runner install --user=gitlab-runner --working-directory=/home/gitlab-runner
  sudo gitlab-runner start
  echo "GitLab Runner installed successfully."
}

# Function to install HashiCorp Vault
install_vault() {
  sudo curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
  sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
  sudo apt-get update && sudo apt-get install vault
  echo "HashiCorp Vault installed successfully."
}

# Function to install HashiCorp Consul
install_consul() {
  sudo curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
  sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
  sudo apt-get update && sudo apt-get install consul
  echo "HashiCorp Consul installed successfully."
}

echo "Please select the tools you want to install:"
echo "1) Docker"
echo "2) Kubernetes (kubectl)"
echo "3) Ansible"
echo "4) Terraform"
echo "5) Jenkins"
echo "6) AWS CLI"
echo "7) Azure CLI"
echo "8) Google Cloud SDK"
echo "9) Helm"
echo "10) Prometheus"
echo "11) Grafana"
echo "12) GitLab Runner"
echo "13) HashiCorp Vault"
echo "14) HashiCorp Consul"
echo "15) All tools"
echo ""

read -p "Enter your choice (1-15): " tools_choice

# Install selected tools
case $tools_choice in
  1)
    install_docker
    ;;
  2)
    install_docker
    install_kubernetes
    ;;
  3)
    install_ansible
    ;;
  4)
    install_terraform
    ;;
  5)
    install_jenkins
    ;;
  6)
    install_awscli
    ;;
  7)
    install_azurecli
    ;;
  8)
    install_gcloud
    ;;
  9)
    install_helm
    ;;
  10)
    install_prometheus
    ;;
  11)
    install_grafana
    ;;
  12)
    install_gitlab_runner
    ;;
  13)
    install_vault
    ;;
  14)
    install_consul
    ;;
  15)
    install_docker
    install_kubernetes
    install_ansible
    install_terraform
    install_jenkins
    install_awscli
    install_azurecli
    install_gcloud
    install_helm
    install_prometheus
    install_grafana
    install_gitlab_runner
    install_vault
    install_consul
    ;;
  *)
    echo "Invalid choice. Exiting."
    exit 1
    ;;
esac
