# Welcome Message
Clear-Host
Write-Host "################################################################" -ForegroundColor Green
Write-Host "#                                                              #" -ForegroundColor Green
Write-Host "#          DevOps Tool Installer by ProDevOpsGuy Tech          #" -ForegroundColor Green
Write-Host "#                                                              #" -ForegroundColor Green
Write-Host "################################################################" -ForegroundColor Green
Write-Host ""
Write-Host "Automate the installation of essential DevOps tools on your Windows machine."
Write-Host "Choose from a wide range of tools and get started quickly and easily."
Write-Host ""
Write-Host "Tools available for installation:"
Write-Host "  - Docker 🐳"
Write-Host "  - Kubernetes (kubectl) ☸️"
Write-Host "  - Ansible 📜"
Write-Host "  - Terraform 🌍"
Write-Host "  - Jenkins 🏗️"
Write-Host "  - AWS CLI ☁️"
Write-Host "  - Azure CLI ☁️"
Write-Host "  - Google Cloud SDK ☁️"
Write-Host "  - Helm ⛵"
Write-Host "  - Prometheus 📈"
Write-Host "  - Grafana 📊"
Write-Host "  - GitLab Runner 🏃‍♂️"
Write-Host "  - HashiCorp Vault 🔐"
Write-Host "  - HashiCorp Consul 🌐"
Write-Host ""
Write-Host "############################################################"
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
Write-Host "13) HashiCorp Vault"
Write-Host "14) HashiCorp Consul"
Write-Host "15) All tools"
Write-Host ""

$tools_choice = Read-Host "Enter your choice (1-15)"

# Function to install Docker
Function Install-Docker {
  Invoke-WebRequest -Uri "https://desktop.docker.com/win/stable/Docker%20Desktop%20Installer.exe" -OutFile "$env:TEMP\DockerDesktopInstaller.exe"
  Start-Process -FilePath "$env:TEMP\DockerDesktopInstaller.exe" -ArgumentList "/install", "/quiet" -Wait
  Remove-Item -Path "$env:TEMP\DockerDesktopInstaller.exe"
  Write-Host "Docker installed successfully." -ForegroundColor Green
}

# Function to install Kubernetes (kubectl)
Function Install-Kubernetes {
  Invoke-WebRequest -Uri "https://dl.k8s.io/release/v1.21.0/bin/windows/amd64/kubectl.exe" -OutFile "C:\Windows\kubectl.exe"
  [Environment]::SetEnvironmentVariable("PATH", $env:PATH + ";C:\Windows", [System.EnvironmentVariableTarget]::Machine)
  Write-Host "Kubernetes (kubectl) installed successfully." -ForegroundColor Green
}

# Function to install Ansible
Function Install-Ansible {
  Invoke-WebRequest -Uri "https://github.com/ansible/ansible/releases/download/v2.10.7/ansible-2.10.7.tar.gz" -OutFile "$env:TEMP\ansible-2.10.7.tar.gz"
  tar -xvf "$env:TEMP\ansible-2.10.7.tar.gz" -C "C:\Program Files"
  Remove-Item -Path "$env:TEMP\ansible-2.10.7.tar.gz"
  Write-Host "Ansible installed successfully." -ForegroundColor Green
}

# Function to install Terraform
Function Install-Terraform {
  Invoke-WebRequest -Uri "https://releases.hashicorp.com/terraform/0.14.9/terraform_0.14.9_windows_amd64.zip" -OutFile "$env:TEMP\terraform.zip"
  Expand-Archive -Path "$env:TEMP\terraform.zip" -DestinationPath "C:\Program Files\Terraform"
  [Environment]::SetEnvironmentVariable("PATH", $env:PATH + ";C:\Program Files\Terraform", [System.EnvironmentVariableTarget]::Machine)
  Remove-Item -Path "$env:TEMP\terraform.zip"
  Write-Host "Terraform installed successfully." -ForegroundColor Green
}

# Function to install Jenkins
Function Install-Jenkins {
  Invoke-WebRequest -Uri "http://mirrors.jenkins.io/windows/jenkins.msi" -OutFile "$env:TEMP\jenkins.msi"
  Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $env:TEMP\jenkins.msi /quiet" -Wait
  Remove-Item -Path "$env:TEMP\jenkins.msi"
  Write-Host "Jenkins installed successfully." -ForegroundColor Green
}

# Function to install AWS CLI
Function Install-AwsCli {
  Invoke-WebRequest -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile "$env:TEMP\AWSCLIV2.msi"
  Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $env:TEMP\AWSCLIV2.msi /quiet" -Wait
  Remove-Item -Path "$env:TEMP\AWSCLIV2.msi"
  Write-Host "AWS CLI installed successfully." -ForegroundColor Green
}

# Function to install Azure CLI
Function Install-AzureCli {
  Invoke-WebRequest -Uri "https://aka.ms/installazurecliwindows" -OutFile "$env:TEMP\AzureCLI.msi"
  Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $env:TEMP\AzureCLI.msi /quiet" -Wait
  Remove-Item -Path "$env:TEMP\AzureCLI.msi"
  Write-Host "Azure CLI installed successfully." -ForegroundColor Green
}

# Function to install Google Cloud SDK
Function Install-Gcloud {
  Invoke-WebRequest -Uri "https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe" -OutFile "$env:TEMP\GoogleCloudSDKInstaller.exe"
  Start-Process -FilePath "$env:TEMP\GoogleCloudSDKInstaller.exe" -ArgumentList "/S" -Wait
  Remove-Item -Path "$env:TEMP\GoogleCloudSDKInstaller.exe"
  Write-Host "Google Cloud SDK installed successfully." -ForegroundColor Green
}

# Function to install Helm
Function Install-Helm {
  Invoke-WebRequest -Uri "https://get.helm.sh/helm-v3.5.4-windows-amd64.zip" -OutFile "$env:TEMP\helm.zip"
  Expand-Archive -Path "$env:TEMP\helm.zip" -DestinationPath "C:\Program Files\Helm"
  [Environment]::SetEnvironmentVariable("PATH", $env:PATH + ";C:\Program Files\Helm\windows-amd64", [System.EnvironmentVariableTarget]::Machine)
  Remove-Item -Path "$env:TEMP\helm.zip"
  Write-Host "Helm installed successfully." -ForegroundColor Green
}

# Function to install Prometheus
Function Install-Prometheus {
  Invoke-WebRequest -Uri "https://github.com/prometheus/prometheus/releases/download/v2.26.0/prometheus-2.26.0.windows-amd64.zip" -OutFile "$env:TEMP\prometheus.zip"
  Expand-Archive -Path "$env:TEMP\prometheus.zip" -DestinationPath "C:\Program Files\Prometheus"
  [Environment]::SetEnvironmentVariable("PATH", $env:PATH + ";C:\Program Files\Prometheus", [System.EnvironmentVariableTarget]::Machine)
  Remove-Item -Path "$env:TEMP\prometheus.zip"
  Write-Host "Prometheus installed successfully." -ForegroundColor Green
}

# Function to install Grafana
Function Install-Grafana {
  Invoke-WebRequest -Uri "https://dl.grafana.com/oss/release/grafana-7.5.5.windows-amd64.msi" -OutFile "$env:TEMP\grafana.msi"
  Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $env:TEMP\grafana.msi /quiet" -Wait
  Remove-Item -Path "$env:TEMP\grafana.msi"
  Write-Host "Grafana installed successfully." -ForegroundColor Green
}

# Function to install GitLab Runner
Function Install-GitLabRunner {
  Invoke-WebRequest -Uri "https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-windows-amd64.exe" -OutFile "C:\Program Files\GitLabRunner\gitlab-runner.exe"
  [Environment]::SetEnvironmentVariable("PATH", $env:PATH + ";C:\Program Files\GitLabRunner", [System.EnvironmentVariableTarget]::Machine)
  Write-Host "GitLab Runner installed successfully." -ForegroundColor Green
}

# Function to install HashiCorp Vault
Function Install-Vault {
  Invoke-WebRequest -Uri "https://releases.hashicorp.com/vault/1.6.2/vault_1.6.2_windows_amd64.zip" -OutFile "$env:TEMP\vault.zip"
  Expand-Archive -Path "$env:TEMP\vault.zip" -DestinationPath "C:\Program Files\Vault"
  [Environment]::SetEnvironmentVariable("PATH", $env:PATH + ";C:\Program Files\Vault", [System.EnvironmentVariableTarget]::Machine)
  Remove-Item -Path "$env:TEMP\vault.zip"
  Write-Host "HashiCorp Vault installed successfully." -ForegroundColor Green
}

# Function to install HashiCorp Consul
Function Install-Consul {
  Invoke-WebRequest -Uri "https://releases.hashicorp.com/consul/1.9.5/consul_1.9.5_windows_amd64.zip" -OutFile "$env:TEMP\consul.zip"
  Expand-Archive -Path "$env:TEMP\consul.zip" -DestinationPath "C:\Program Files\Consul"
  [Environment]::SetEnvironmentVariable("PATH", $env:PATH + ";C:\Program Files\Consul", [System.EnvironmentVariableTarget]::Machine)
  Remove-Item -Path "$env:TEMP\consul.zip"
  Write-Host "HashiCorp Consul installed successfully." -ForegroundColor Green
}

# Install selected tools
switch ($tools_choice) {
  1 { Install-Docker }
  2 { Install-Kubernetes }
  3 { Install-Ansible }
  4 { Install-Terraform }
  5 { Install-Jenkins }
  6 { Install-AwsCli }
  7 { Install-AzureCli }
  8 { Install-Gcloud }
  9 { Install-Helm }
  10 { Install-Prometheus }
  11 { Install-Grafana }
  12 { Install-GitLabRunner }
  13 { Install-Vault }
  14 { Install-Consul }
  15 { 
    Install-Docker
    Install-Kubernetes
    Install-Ansible
    Install-Terraform
    Install-Jenkins
    Install-AwsCli
    Install-AzureCli
    Install-Gcloud
    Install-Helm
    Install-Prometheus
    Install-Grafana
    Install-GitLabRunner
    Install-Vault
    Install-Consul
  }
  default { Write-Host "Invalid choice. Exiting." -ForegroundColor Red }
}
