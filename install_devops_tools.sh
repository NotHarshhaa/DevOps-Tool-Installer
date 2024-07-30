#!/bin/bash

# Welcome Message
clear
echo "############################################################"
echo "#                                                          #"
echo "#          Welcome to ProDevOpsGuy Tech Community          #"
echo "#                                                          #"
echo "############################################################"
echo ""
echo "Automate the installation of essential DevOps tools on your Linux machine."
echo "Choose from a wide range of tools and get started quickly and easily."
echo ""
echo "Tools available for installation:"
echo "  - Docker"
echo "  - Kubernetes (kubectl)"
echo "  - Ansible"
echo "  - Terraform"
echo "  - Jenkins"
echo "  - AWS CLI"
echo "  - Azure CLI"
echo "  - Google Cloud SDK"
echo "  - Helm"
echo "  - Prometheus"
echo "  - Grafana"
echo "  - GitLab Runner"
echo "  - HashiCorp Vault"
echo "  - HashiCorp Consul"
echo ""
echo "############################################################"
echo ""
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
echo "13) Vault"
echo "14) Consul"
echo "15) All tools"
echo ""

# Prompt user for choice
read -p "Enter your choice (1-15): " choice

# DevOps Tools
declare -A tools
tools=(
  [docker]="Install Docker"
  [kubernetes]="Install Kubernetes"
  [ansible]="Install Ansible"
  [terraform]="Install Terraform"
  [jenkins]="Install Jenkins"
  [awscli]="Install AWS CLI"
  [azurecli]="Install Azure CLI"
  [gcloud]="Install Google Cloud SDK"
  [helm]="Install Helm"
  [prometheus]="Install Prometheus"
  [grafana]="Install Grafana"
  [gitlab]="Install GitLab Runner"
  [vault]="Install HashiCorp Vault"
  [consul]="Install HashiCorp Consul"
)

# Function to install Docker
install_docker() {
  echo "Installing Docker..."
  sudo apt-get update
  sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io
  sudo usermod -aG docker $USER
  echo "Docker installed successfully."
}

# Function to install Kubernetes (kubectl)
install_kubernetes() {
  echo "Installing Kubernetes (kubectl)..."
  sudo apt-get update
  sudo apt-get install -y apt-transport-https ca-certificates curl
  sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
  echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
  sudo apt-get update
  sudo apt-get install -y kubectl
  echo "Kubernetes (kubectl) installed successfully."
}

# Function to install Ansible
install_ansible() {
  echo "Installing Ansible..."
  sudo apt-get update
  sudo apt-get install -y software-properties-common
  sudo add-apt-repository --yes --update ppa:ansible/ansible
  sudo apt-get update
  sudo apt-get install -y ansible
  echo "Ansible installed successfully."
}

# Function to install Terraform
install_terraform() {
  echo "Installing Terraform..."
  sudo apt-get update
  sudo apt-get install -y gnupg software-properties-common curl
  curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
  sudo apt-get update
  sudo apt-get install -y terraform
  echo "Terraform installed successfully."
}

# Function to install Jenkins
install_jenkins() {
  echo "Installing Jenkins..."
  sudo apt-get update
  sudo apt-get install -y openjdk-11-jdk
  curl -fsSL https://pkg.jenkins.io/debian/jenkins.io.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
  echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
  sudo apt-get update
  sudo apt-get install -y jenkins
  sudo systemctl start jenkins
  sudo systemctl enable jenkins
  echo "Jenkins installed successfully."
}

# Function to install AWS CLI
install_awscli() {
  echo "Installing AWS CLI..."
  sudo apt-get update
  sudo apt-get install -y awscli
  echo "AWS CLI installed successfully."
}

# Function to install Azure CLI
install_azurecli() {
  echo "Installing Azure CLI..."
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
  echo "Azure CLI installed successfully."
}

# Function to install Google Cloud SDK
install_gcloud() {
  echo "Installing Google Cloud SDK..."
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
  curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
  sudo apt-get update
  sudo apt-get install -y google-cloud-sdk
  echo "Google Cloud SDK installed successfully."
}

# Function to install Helm
install_helm() {
  echo "Installing Helm..."
  curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -
  sudo apt-get install -y apt-transport-https
  echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
  sudo apt-get update
  sudo apt-get install -y helm
  echo "Helm installed successfully."
}

# Function to install Prometheus
install_prometheus() {
  echo "Installing Prometheus..."
  sudo useradd -M -r -s /bin/false prometheus
  sudo mkdir /etc/prometheus /var/lib/prometheus
  sudo chown prometheus:prometheus /etc/prometheus /var/lib/prometheus
  curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest | grep browser_download_url | grep linux-amd64.tar.gz | cut -d '"' -f 4 | wget -qi -
  tar xvf prometheus-*.tar.gz
  sudo cp prometheus-*/prometheus prometheus-*/promtool /usr/local/bin/
  sudo cp -r prometheus-*/consoles prometheus-*/console_libraries /etc/prometheus/
  sudo cp prometheus-*/prometheus.yml /etc/prometheus/prometheus.yml
  sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
  echo "Prometheus installed successfully."
}

# Function to install Grafana
install_grafana() {
  echo "Installing Grafana..."
  sudo apt-get update
  sudo apt-get install -y software-properties-common
  sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
  sudo apt-get update
  sudo apt-get install -y grafana
  sudo systemctl start grafana-server
  sudo systemctl enable grafana-server
  echo "Grafana installed successfully."
}

# Function to install GitLab Runner
install_gitlab() {
  echo "Installing GitLab Runner..."
  curl -L --output /usr/local/bin/gitlab-runner https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64
  sudo chmod +x /usr/local/bin/gitlab-runner
  sudo useradd --comment 'GitLab Runner' --create-home gitlab-runner --shell /bin/bash
  sudo gitlab-runner install --user=gitlab-runner --working-directory=/home/gitlab-runner
  sudo gitlab-runner start
  echo "GitLab Runner installed successfully."
}

# Function to install HashiCorp Vault
install_vault() {
  echo "Installing HashiCorp Vault..."
  curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
  sudo apt-get update
  sudo apt-get install -y vault
  echo "Vault installed successfully."
}

# Function to install HashiCorp Consul
install_consul() {
  echo "Installing HashiCorp Consul..."
  curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
  sudo apt-get update
  sudo apt-get install -y consul
  echo "Consul installed successfully."
}

# Display menu
echo "Select the DevOps tools you want to install:"
for key in "${!tools[@]}"; do
  echo "$key) ${tools[$key]}"
done
echo "all) Install all tools"

read -p "Enter your choice (e.g., docker, kubernetes, ansible, terraform, jenkins, awscli, azurecli, gcloud, helm, prometheus, grafana, gitlab, vault, consul, all): " choice

# Install selected tools
if [[ $choice == "all" ]]; then
  for key in "${!tools[@]}"; do
    install_$key
  done
else
  for key in $choice; do
    install_$key
  done
fi
