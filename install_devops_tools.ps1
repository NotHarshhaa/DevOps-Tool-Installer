# Welcome Message
Clear-Host
Write-Host "############################################################" -ForegroundColor Green
Write-Host "#                                                          #" -ForegroundColor Green
Write-Host "#          Welcome to ProDevOpsGuy Tech Community          #" -ForegroundColor Green
Write-Host "#                                                          #" -ForegroundColor Green
Write-Host "############################################################" -ForegroundColor Green
Write-Host ""
Write-Host "Automate the installation of essential DevOps tools on your Windows machine."
Write-Host "Choose from a wide range of tools and get started quickly and easily."
Write-Host ""
Write-Host "Tools available for installation:"
Write-Host "  - Docker"
Write-Host "  - Kubernetes (kubectl)"
Write-Host "  - Ansible"
Write-Host "  - Terraform"
Write-Host "  - Jenkins"
Write-Host "  - AWS CLI"
Write-Host "  - Azure CLI"
Write-Host "  - Google Cloud SDK"
Write-Host "  - Helm"
Write-Host "  - Prometheus"
Write-Host "  - Grafana"
Write-Host "  - GitLab Runner"
Write-Host "  - HashiCorp Vault"
Write-Host "  - HashiCorp Consul"
Write-Host ""
Write-Host "############################################################" -ForegroundColor Green
Write-Host ""
Write-Host "Please select the tools you want to install:"
Write-Host "1) Docker"
Write-Host "2) Kubernetes (kubectl)"
Write-Host "3) Ansible"
Write-Host "4) Terraform"
Write-Host "5) Jenkins"
Write-Host "6) AWS CLI"
Write-Host "7) Azure CLI"
Write-Host "8) Google Cloud SDK"
Write-Host "9) Helm"
Write-Host "10) Prometheus"
Write-Host "11) Grafana"
Write-Host "12) GitLab Runner"
Write-Host "13) Vault"
Write-Host "14) Consul"
Write-Host "15) All tools"
Write-Host ""

# Prompt user for choice
$choice = Read-Host "Enter your choice (1-15)"

# DevOps Tools Installation Script

# Function to install Docker
function Install-Docker {
    Write-Host "Installing Docker..."
    Invoke-WebRequest -Uri https://desktop.docker.com/win/stable/Docker%20Desktop%20Installer.exe -OutFile DockerDesktopInstaller.exe
    Start-Process -FilePath .\DockerDesktopInstaller.exe -ArgumentList "/quiet" -Wait
    Write-Host "Docker installed successfully."
}

# Function to install Kubernetes (kubectl)
function Install-Kubernetes {
    Write-Host "Installing Kubernetes (kubectl)..."
    Invoke-WebRequest -Uri https://dl.k8s.io/release/v1.21.0/bin/windows/amd64/kubectl.exe -OutFile kubectl.exe
    $env:Path += ";$PWD"
    [Environment]::SetEnvironmentVariable("Path", $env:Path, [EnvironmentVariableTarget]::Machine)
    Write-Host "Kubernetes (kubectl) installed successfully."
}

# Function to install Ansible
function Install-Ansible {
    Write-Host "Installing Ansible..."
    Invoke-WebRequest -Uri https://bootstrap.pypa.io/get-pip.py -OutFile get-pip.py
    python get-pip.py
    pip install ansible
    Write-Host "Ansible installed successfully."
}

# Function to install Terraform
function Install-Terraform {
    Write-Host "Installing Terraform..."
    Invoke-WebRequest -Uri https://releases.hashicorp.com/terraform/0.14.5/terraform_0.14.5_windows_amd64.zip -OutFile terraform.zip
    Expand-Archive -Path terraform.zip -DestinationPath $PWD
    $env:Path += ";$PWD"
    [Environment]::SetEnvironmentVariable("Path", $env:Path, [EnvironmentVariableTarget]::Machine)
    Write-Host "Terraform installed successfully."
}

# Function to install Jenkins
function Install-Jenkins {
    Write-Host "Installing Jenkins..."
    Invoke-WebRequest -Uri http://mirrors.jenkins.io/windows/latest/jenkins.msi -OutFile jenkins.msi
    Start-Process -FilePath msiexec.exe -ArgumentList "/i jenkins.msi /quiet" -Wait
    Write-Host "Jenkins installed successfully."
}

# Function to install AWS CLI
function Install-AWSCLI {
    Write-Host "Installing AWS CLI..."
    Invoke-WebRequest -Uri https://awscli.amazonaws.com/AWSCLIV2.msi -OutFile AWSCLIV2.msi
    Start-Process -FilePath msiexec.exe -ArgumentList "/i AWSCLIV2.msi /quiet" -Wait
    Write-Host "AWS CLI installed successfully."
}

# Function to install Azure CLI
function Install-AzureCLI {
    Write-Host "Installing Azure CLI..."
    Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile AzureCLISetup.msi
    Start-Process -FilePath msiexec.exe -ArgumentList "/i AzureCLISetup.msi /quiet" -Wait
    Write-Host "Azure CLI installed successfully."
}

# Function to install Google Cloud SDK
function Install-GCloud {
    Write-Host "Installing Google Cloud SDK..."
    Invoke-WebRequest -Uri https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe -OutFile GoogleCloudSDKInstaller.exe
    Start-Process -FilePath .\GoogleCloudSDKInstaller.exe -ArgumentList "/quiet" -Wait
    Write-Host "Google Cloud SDK installed successfully."
}

# Function to install Helm
function Install-Helm {
    Write-Host "Installing Helm..."
    Invoke-WebRequest -Uri https://get.helm.sh/helm-v3.5.4-windows-amd64.zip -OutFile helm.zip
    Expand-Archive -Path helm.zip -DestinationPath $PWD
    Move-Item -Path .\windows-amd64\helm.exe -Destination .\helm.exe
    $env:Path += ";$PWD"
    [Environment]::SetEnvironmentVariable("Path", $env:Path, [EnvironmentVariableTarget]::Machine)
    Write-Host "Helm installed successfully."
}

# Function to install Prometheus
function Install-Prometheus {
    Write-Host "Installing Prometheus..."
    Invoke-WebRequest -Uri https://github.com/prometheus/prometheus/releases/latest/download/prometheus-2.26.0.windows-amd64.zip -OutFile prometheus.zip
    Expand-Archive -Path prometheus.zip -DestinationPath $PWD
    Move-Item -Path .\prometheus-2.26.0.windows-amd64\prometheus.exe -Destination .\prometheus.exe
    Move-Item -Path .\prometheus-2.26.0.windows-amd64\promtool.exe -Destination .\promtool.exe
    $env:Path += ";$PWD"
    [Environment]::SetEnvironmentVariable("Path", $env:Path, [EnvironmentVariableTarget]::Machine)
    Write-Host "Prometheus installed successfully."
}

# Function to install Grafana
function Install-Grafana {
    Write-Host "Installing Grafana..."
    Invoke-WebRequest -Uri https://dl.grafana.com/oss/release/grafana-7.5.5.windows-amd64.msi -OutFile grafana.msi
    Start-Process -FilePath msiexec.exe -ArgumentList "/i grafana.msi /quiet" -Wait
    Write-Host "Grafana installed successfully."
}

# Function to install GitLab Runner
function Install-GitLab {
    Write-Host "Installing GitLab Runner..."
    Invoke-WebRequest -Uri https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-windows-amd64.exe -OutFile gitlab-runner.exe
    Move-Item -Path .\gitlab-runner.exe -Destination "C:\Program Files\GitLab-Runner\gitlab-runner.exe"
    [System.Environment]::SetEnvironmentVariable('Path', [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';C:\Program Files\GitLab-Runner', 'Machine')
    Write-Host "GitLab Runner installed successfully."
}

# Function to install HashiCorp Vault
function Install-Vault {
    Write-Host "Installing HashiCorp Vault..."
    Invoke-WebRequest -Uri https://releases.hashicorp.com/vault/1.7.0/vault_1.7.0_windows_amd64.zip -OutFile vault.zip
    Expand-Archive -Path vault.zip -DestinationPath $PWD
    Move-Item -Path .\vault.exe -Destination "C:\Program Files\Vault\vault.exe"
    [System.Environment]::SetEnvironmentVariable('Path', [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';C:\Program Files\Vault', 'Machine')
    Write-Host "Vault installed successfully."
}

# Function to install HashiCorp Consul
function Install-Consul {
    Write-Host "Installing HashiCorp Consul..."
    Invoke-WebRequest -Uri https://releases.hashicorp.com/consul/1.9.5/consul_1.9.5_windows_amd64.zip -OutFile consul.zip
    Expand-Archive -Path consul.zip -DestinationPath $PWD
    Move-Item -Path .\consul.exe -Destination "C:\Program Files\Consul\consul.exe"
    [System.Environment]::SetEnvironmentVariable('Path', [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';C:\Program Files\Consul', 'Machine')
    Write-Host "Consul installed successfully."
}

# Display menu
Write-Host "Select the DevOps tools you want to install:"
Write-Host "1) Docker"
Write-Host "2) Kubernetes (kubectl)"
Write-Host "3) Ansible"
Write-Host "4) Terraform"
Write-Host "5) Jenkins"
Write-Host "6) AWS CLI"
Write-Host "7) Azure CLI"
Write-Host "8) Google Cloud SDK"
Write-Host "9) Helm"
Write-Host "10) Prometheus"
Write-Host "11) Grafana"
Write-Host "12) GitLab Runner"
Write-Host "13) Vault"
Write-Host "14) Consul"
Write-Host "15) All tools"

$choice = Read-Host "Enter your choice (1-15)"

# Install selected tools
switch ($choice) {
    1 { Install-Docker }
    2 { Install-Kubernetes }
    3 { Install-Ansible }
    4 { Install-Terraform }
    5 { Install-Jenkins }
    6 { Install-AWSCLI }
    7 { Install-AzureCLI }
    8 { Install-GCloud }
    9 { Install-Helm }
    10 { Install-Prometheus }
    11 { Install-Grafana }
    12 { Install-GitLab }
    13 { Install-Vault }
    14 { Install-Consul }
    15 {
        Install-Docker
        Install-Kubernetes
        Install-Ansible
        Install-Terraform
        Install-Jenkins
        Install-AWSCLI
        Install-AzureCLI
        Install-GCloud
        Install-Helm
        Install-Prometheus
        Install-Grafana
        Install-GitLab
        Install-Vault
        Install-Consul
    }
    default { Write-Host "Invalid choice. Exiting." }
}
