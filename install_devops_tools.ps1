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
Write-Host "  - Minikube ☸️"
Write-Host "  - Istio 📦"
Write-Host "  - OpenShift CLI ☸️"
Write-Host "  - Packer 📦"
Write-Host "  - Vagrant 📦"
Write-Host ""

# Generic function to install tools using Chocolatey
function Install-Tool {
    param (
        [string]$tool
    )
    try {
        choco install $tool -y
        Write-Host "$tool installed successfully." -ForegroundColor Green
    } catch {
        $errorMessage = $_.Exception.Message
        Write-Host "Failed to install ${tool}: ${errorMessage}" -ForegroundColor Red
    }
}

# Generic function to uninstall tools using Chocolatey
function Uninstall-Tool {
    param (
        [string]$tool
    )
    try {
        choco uninstall $tool -y
        Write-Host "$tool uninstalled successfully." -ForegroundColor Green
    } catch {
        $errorMessage = $_.Exception.Message
        Write-Host "Failed to uninstall ${tool}: ${errorMessage}" -ForegroundColor Red
    }
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
        $tools = @(
            "Docker", "Kubernetes (kubectl)", "Ansible", "Terraform", "Jenkins", 
            "AWS CLI", "Azure CLI", "Google Cloud SDK", "Helm", "Prometheus", 
            "Grafana", "GitLab Runner", "HashiCorp Vault", "HashiCorp Consul", 
            "Minikube", "Istio", "OpenShift CLI", "Packer", "Vagrant"
        )

        for ($i = 0; $i -lt $tools.Count; $i++) {
            Write-Host "$($i + 1). $($tools[$i])"
        }

        $tool_choice = [int](Read-Host "Enter the number corresponding to the tool")
        if ($tool_choice -ge 1 -and $tool_choice -le $tools.Count) {
            $selected_tool = $tools[$tool_choice - 1]

            # Map tool names to Chocolatey package names
            $toolMap = @{
                "Docker" = "docker-desktop"
                "Kubernetes (kubectl)" = "kubernetes-cli"
                "Ansible" = "ansible"
                "Terraform" = "terraform"
                "Jenkins" = "jenkins"
                "AWS CLI" = "awscli"
                "Azure CLI" = "azure-cli"
                "Google Cloud SDK" = "google-cloud-sdk"
                "Helm" = "kubernetes-helm"
                "Prometheus" = "prometheus"
                "Grafana" = "grafana"
                "GitLab Runner" = "gitlab-runner"
                "HashiCorp Vault" = "vault"
                "HashiCorp Consul" = "consul"
                "Minikube" = "minikube"
                "Istio" = "istio"
                "OpenShift CLI" = "openshift-cli"
                "Packer" = "packer"
                "Vagrant" = "vagrant"
            }

            if ($toolMap.ContainsKey($selected_tool)) {
                $packageName = $toolMap[$selected_tool]
                if ($action_choice -eq 1) {
                    Install-Tool -tool $packageName
                } else {
                    Uninstall-Tool -tool $packageName
                }
            } else {
                Write-Host "Invalid tool selection. Exiting." -ForegroundColor Red
            }
        } else {
            Write-Host "Invalid input. Please enter a valid number." -ForegroundColor Red
        }
    } elseif ($action_choice -eq 3) {
        Write-Host "Exiting. Goodbye!" -ForegroundColor Yellow
        exit
    } else {
        Write-Host "Invalid action choice. Exiting." -ForegroundColor Red
    }
}

# Run the main menu
Main-Menu
