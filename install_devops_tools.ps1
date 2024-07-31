# Welcome Message
Clear-Host
Write-Host "############################################################################" -ForegroundColor Green
Write-Host "#                                                                          #" -ForegroundColor Green
Write-Host "#          DevOps Tool Installer/Uninstaller by ProDevOpsGuy Tech          #" -ForegroundColor Green
Write-Host "#                                                                          #" -ForegroundColor Green
Write-Host "############################################################################" -ForegroundColor Green
Write-Host ""
Write-Host "Automate the installation and uninstallation of essential DevOps tools on your Windows machine."
Write-Host "Choose from a wide range of tools and get started quickly and easily."
Write-Host ""
Write-Host "Tools available for installation/uninstallation:"
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

# Function to install Docker
function Install-Docker {
    choco install docker-desktop -y
    Write-Host "Docker installed successfully."
}

# Function to uninstall Docker
function Uninstall-Docker {
    choco uninstall docker-desktop -y
    Write-Host "Docker uninstalled successfully."
}

# Function to install Kubernetes (kubectl)
function Install-Kubectl {
    choco install kubernetes-cli -y
    Write-Host "Kubernetes (kubectl) installed successfully."
}

# Function to uninstall Kubernetes (kubectl)
function Uninstall-Kubectl {
    choco uninstall kubernetes-cli -y
    Write-Host "Kubernetes (kubectl) uninstalled successfully."
}

# Function to install Ansible
function Install-Ansible {
    choco install ansible -y
    Write-Host "Ansible installed successfully."
}

# Function to uninstall Ansible
function Uninstall-Ansible {
    choco uninstall ansible -y
    Write-Host "Ansible uninstalled successfully."
}

# Function to install Terraform
function Install-Terraform {
    choco install terraform -y
    Write-Host "Terraform installed successfully."
}

# Function to uninstall Terraform
function Uninstall-Terraform {
    choco uninstall terraform -y
    Write-Host "Terraform uninstalled successfully."
}

# Function to install Jenkins
function Install-Jenkins {
    choco install jenkins -y
    Write-Host "Jenkins installed successfully."
}

# Function to uninstall Jenkins
function Uninstall-Jenkins {
    choco uninstall jenkins -y
    Write-Host "Jenkins uninstalled successfully."
}

# Function to install AWS CLI
function Install-AWSCLI {
    choco install awscli -y
    Write-Host "AWS CLI installed successfully."
}

# Function to uninstall AWS CLI
function Uninstall-AWSCLI {
    choco uninstall awscli -y
    Write-Host "AWS CLI uninstalled successfully."
}

# Function to install Azure CLI
function Install-AzureCLI {
    choco install azure-cli -y
    Write-Host "Azure CLI installed successfully."
}

# Function to uninstall Azure CLI
function Uninstall-AzureCLI {
    choco uninstall azure-cli -y
    Write-Host "Azure CLI uninstalled successfully."
}

# Function to install Google Cloud SDK
function Install-GCloud {
    choco install google-cloud-sdk -y
    Write-Host "Google Cloud SDK installed successfully."
}

# Function to uninstall Google Cloud SDK
function Uninstall-GCloud {
    choco uninstall google-cloud-sdk -y
    Write-Host "Google Cloud SDK uninstalled successfully."
}

# Function to install Helm
function Install-Helm {
    choco install helm -y
    Write-Host "Helm installed successfully."
}

# Function to uninstall Helm
function Uninstall-Helm {
    choco uninstall helm -y
    Write-Host "Helm uninstalled successfully."
}

# Function to install Prometheus
function Install-Prometheus {
    choco install prometheus -y
    Write-Host "Prometheus installed successfully."
}

# Function to uninstall Prometheus
function Uninstall-Prometheus {
    choco uninstall prometheus -y
    Write-Host "Prometheus uninstalled successfully."
}

# Function to install Grafana
function Install-Grafana {
    choco install grafana -y
    Write-Host "Grafana installed successfully."
}

# Function to uninstall Grafana
function Uninstall-Grafana {
    choco uninstall grafana -y
    Write-Host "Grafana uninstalled successfully."
}

# Function to install GitLab Runner
function Install-GitLabRunner {
    choco install gitlab-runner -y
    Write-Host "GitLab Runner installed successfully."
}

# Function to uninstall GitLab Runner
function Uninstall-GitLabRunner {
    choco uninstall gitlab-runner -y
    Write-Host "GitLab Runner uninstalled successfully."
}

# Function to install HashiCorp Vault
function Install-Vault {
    choco install vault -y
    Write-Host "HashiCorp Vault installed successfully."
}

# Function to uninstall HashiCorp Vault
function Uninstall-Vault {
    choco uninstall vault -y
    Write-Host "HashiCorp Vault uninstalled successfully."
}

# Function to install HashiCorp Consul
function Install-Consul {
    choco install consul -y
    Write-Host "HashiCorp Consul installed successfully."
}

# Function to uninstall HashiCorp Consul
function Uninstall-Consul {
    choco uninstall consul -y
    Write-Host "HashiCorp Consul uninstalled successfully."
}

# Function to display the main menu and handle user input
function Main-Menu {
    Write-Host "Choose an action:"
    Write-Host "1. Install a tool"
    Write-Host "2. Uninstall a tool"
    Write-Host "3. Exit"
    $action_choice = Read-Host "Enter your choice"

    if ($action_choice -eq 1 -or $action_choice -eq 2) {
        Write-Host "Select a tool:"
        Write-Host "1. Docker"
        Write-Host "2. Kubernetes (kubectl)"
        Write-Host "3. Ansible"
        Write-Host "4. Terraform"
        Write-Host "5. Jenkins"
        Write-Host "6. AWS CLI"
        Write-Host "7. Azure CLI"
        Write-Host "8. Google Cloud SDK"
        Write-Host "9. Helm"
        Write-Host "10. Prometheus"
        Write-Host "11. Grafana"
        Write-Host "12. GitLab Runner"
        Write-Host "13. HashiCorp Vault"
        Write-Host "14. HashiCorp Consul"
        $tool_choice = Read-Host "Enter the number corresponding to the tool"

        switch ($tool_choice) {
            1 {
                if ($action_choice -eq 1) { Install-Docker } else { Uninstall-Docker }
            }
            2 {
                if ($action_choice -eq 1) { Install-Kubectl } else { Uninstall-Kubectl }
            }
            3 {
                if ($action_choice -eq 1) { Install-Ansible } else { Uninstall-Ansible }
            }
            4 {
                if ($action_choice -eq 1) { Install-Terraform } else { Uninstall-Terraform }
            }
            5 {
                if ($action_choice -eq 1) { Install-Jenkins } else { Uninstall-Jenkins }
            }
            6 {
                if ($action_choice -eq 1) { Install-AWSCLI } else { Uninstall-AWSCLI }
            }
            7 {
                if ($action_choice -eq 1) { Install-AzureCLI } else { Uninstall-AzureCLI }
            }
            8 {
                if ($action_choice -eq 1) { Install-GCloud } else { Uninstall-GCloud }
            }
            9 {
                if ($action_choice -eq 1) { Install-Helm } else { Uninstall-Helm }
            }
            10 {
                if ($action_choice -eq 1) { Install-Prometheus } else { Uninstall-Prometheus }
            }
            11 {
                if ($action_choice -eq 1) { Install-Grafana } else { Uninstall-Grafana }
            }
            12 {
                if ($action_choice -eq 1) { Install-GitLabRunner } else { Uninstall-GitLabRunner }
            }
            13 {
                if ($action_choice -eq 1) { Install-Vault } else { Uninstall-Vault }
            }
            14 {
                if ($action_choice -eq 1) { Install-Consul } else { Uninstall-Consul }
            }
            default {
                Write-Host "Invalid tool choice. Exiting."
                exit
            }
        }
    } elseif ($action_choice -eq 3) {
        Write-Host "Exiting. Goodbye!"
        exit
    } else {
        Write-Host "Invalid action choice. Exiting."
        exit
    }
}

# Run the main menu
Main-Menu
