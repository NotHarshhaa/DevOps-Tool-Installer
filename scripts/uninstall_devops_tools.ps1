# uninstall_devops_tools.ps1
# Enhanced version with better error handling, logging, and state management

# Check for Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host 'This script requires Administrator privileges. Please run PowerShell as Administrator.' -ForegroundColor Red
    exit 1
}

# Script Configuration
$CONFIG = @{
    LogFile = 'devops_uninstall.log'
    StateFile = 'devops_state.json'
    ChocolateyMinVersion = '1.0.0'
}

# Function: Initialize logging
function Initialize-Logging {
    if (-not (Test-Path $CONFIG.LogFile)) {
        New-Item -Path $CONFIG.LogFile -ItemType File -Force | Out-Null
    }
}

# Function: Write log message
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = '[{0}] {1} : {2}' -f $timestamp, $Level, $Message
    
    $color = switch ($Level) {
        'Info' { 'White' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        'Success' { 'Green' }
    }
    
    Write-Host $logMessage -ForegroundColor $color
    
    # Use a mutex for file access
    $mutex = New-Object System.Threading.Mutex($false, 'DevOpsToolUninstallerLogMutex')
    try {
        [void]$mutex.WaitOne()
        $logMessage | Out-File -FilePath $CONFIG.LogFile -Append -Encoding utf8
    }
    catch {
        Write-Host 'Warning: Could not write to log file: $_' -ForegroundColor Yellow
    }
    finally {
        if ($mutex) {
            $mutex.ReleaseMutex()
            $mutex.Dispose()
        }
    }
}

# Function: Verify Prerequisites
function Test-Prerequisites {
    Write-Log 'Checking prerequisites...' -Level Info
    
    # Check if Chocolatey is installed
    if (-not (Get-Command 'choco.exe' -ErrorAction SilentlyContinue)) {
        Write-Log 'Chocolatey is not installed. Cannot proceed with uninstallation.' -Level Error
        return $false
    }
    
    # Check Chocolatey version
    $chocoVersion = (choco --version)
    if ([version]$chocoVersion -lt [version]$CONFIG.ChocolateyMinVersion) {
        Write-Log ('Chocolatey version {0} is below minimum required version {1}' -f $chocoVersion, $CONFIG.ChocolateyMinVersion) -Level Warning
    }
    
    return $true
}

# Function: Display Header UI
function Show-Header {
    Write-Host ([string]::Empty)
    Write-Host '+====================================================================+' -ForegroundColor DarkRed
    Write-Host '|                                                                    |' -ForegroundColor DarkRed
    Write-Host '|        DevOps Tool Uninstaller by ProDevOpsGuy Tech               |' -ForegroundColor DarkRed
    Write-Host '|                                                                    |' -ForegroundColor DarkRed
    Write-Host '+====================================================================+' -ForegroundColor DarkRed
    Write-Host ([string]::Empty)
    Write-Host 'Remove DevOps tools from your system using Chocolatey with a clean and simple interface.'
    Write-Host 'Choose the tool you want to uninstall from the list below.'
    Write-Host ([string]::Empty)
}

# Function: Display Tool List
function Show-Tools {
    Write-Host "`nTools available for uninstallation:`n" -ForegroundColor Yellow

    $tools = @(
        'Docker', 'Kubernetes (kubectl)', 'Ansible', 'Terraform', 'Jenkins',
        'AWS CLI', 'Azure CLI', 'Google Cloud SDK', 'Helm', 'Prometheus',
        'Grafana', 'GitLab Runner (Runner)', 'HashiCorp Vault', 'HashiCorp Consul',
        'Minikube', 'Istio', 'OpenShift CLI', 'Packer', 'Vagrant'
    )

    # Check installation status for each tool
    $installedTools = Get-InstalledTools
    
    for ($i = 0; $i -lt $tools.Count; $i++) {
        $status = if ($installedTools.Contains($tools[$i])) { '[Installed]' } else { '[Not Found]' }
        $statusColor = if ($installedTools.Contains($tools[$i])) { 'Green' } else { 'Gray' }
        Write-Host ('[{0,2}] {1,-40} {2}' -f ($i + 1), $tools[$i], $status) -ForegroundColor $statusColor
    }

    return $tools
}

# Function: Get Installed Tools
function Get-InstalledTools {
    $installedTools = New-Object System.Collections.Generic.HashSet[string]
    $packageMap = Get-PackageMap
    
    foreach ($tool in $packageMap.Keys) {
        $package = $packageMap[$tool]
        if (choco list --local-only --exact $package) {
            [void]$installedTools.Add($tool)
        }
    }
    
    return $installedTools
}

# Function: Map Tool Names to Chocolatey Package Names
function Get-PackageMap {
    return @{
        'Docker' = 'docker-desktop'
        'Kubernetes (kubectl)' = 'kubernetes-cli'
        'Ansible' = 'ansible'
        'Terraform' = 'terraform'
        'Jenkins' = 'jenkins'
        'AWS CLI' = 'awscli'
        'Azure CLI' = 'azure-cli'
        'Google Cloud SDK' = 'google-cloud-sdk'
        'Helm' = 'kubernetes-helm'
        'Prometheus' = 'prometheus'
        'Grafana' = 'grafana'
        'GitLab Runner (Runner)' = 'gitlab-runner'
        'HashiCorp Vault' = 'vault'
        'HashiCorp Consul' = 'consul'
        'Minikube' = 'minikube'
        'Istio' = 'istio'
        'OpenShift CLI' = 'openshift-cli'
        'Packer' = 'packer'
        'Vagrant' = 'vagrant'
    }
}

# Function: Get Package Name
function Get-PackageName {
    param([string]$toolName)
    $map = Get-PackageMap
    return $map[$toolName]
}

# Function: Update State File
function Update-StateFile {
    param(
        [string]$toolName,
        [string]$status,
        [string]$message = ''
    )
    
    try {
        $state = @{}
        if (Test-Path $CONFIG.StateFile) {
            $state = Get-Content $CONFIG.StateFile | ConvertFrom-Json -AsHashtable
        }
        
        $state[$toolName] = @{
            status = $status
            date = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            message = $message
        }
        
        $state | ConvertTo-Json | Set-Content $CONFIG.StateFile
    }
    catch {
        Write-Log ('Failed to update state file: {0}' -f $_.Exception.Message) -Level Warning
    }
}

# Function: Uninstall Tool
function Uninstall-Tool {
    param([string]$packageName, [string]$toolName)

    try {
        Write-Log ('Uninstalling {0} ({1})...' -f $toolName, $packageName) -Level Info
        
        # Check if package is actually installed
        if (-not (choco list --local-only --exact $packageName)) {
            Write-Log ('{0} is not installed.' -f $toolName) -Level Warning
            Update-StateFile -toolName $toolName -status 'not_installed'
            return
        }
        
        # Attempt uninstallation
        choco uninstall $packageName -y
        if ($LASTEXITCODE -eq 0) {
            Write-Log ('{0} uninstalled successfully.' -f $toolName) -Level Success
            Update-StateFile -toolName $toolName -status 'uninstalled'
        } else {
            throw 'Chocolatey uninstall failed.'
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log ('Failed to uninstall {0}: {1}' -f $toolName, $errorMsg) -Level Error
        Update-StateFile -toolName $toolName -status 'failed' -message $errorMsg
    }
}

# Function: Confirm Uninstallation
function Confirm-Uninstallation {
    param([string]$toolName)
    
    Write-Host ([string]::Empty)
    Write-Host ('Are you sure you want to uninstall {0}?' -f $toolName) -ForegroundColor Yellow
    Write-Host 'This action cannot be undone.' -ForegroundColor Yellow
    $response = Read-Host 'Type ''yes'' to confirm or any other key to cancel'
    
    return $response -eq 'yes'
}

# Main Menu Function
function Show-MainMenu {
    Show-Header
    $toolList = Show-Tools

    do {
        $selection = Read-Host "`nEnter the number of the tool to uninstall (or 'q' to quit)"
        
        if ($selection -eq 'q') {
            Write-Log 'Exiting uninstaller...' -Level Info
            break
        }

        if ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $toolList.Count) {
            $toolName = $toolList[[int]$selection - 1]
            $package = Get-PackageName -toolName $toolName

            if ($null -ne $package) {
                if (Confirm-Uninstallation -toolName $toolName) {
                    Uninstall-Tool -packageName $package -toolName $toolName
                } else {
                    Write-Log ('Uninstallation of {0} cancelled by user.' -f $toolName) -Level Info
                }
            } else {
                Write-Log ('Package mapping not found for {0}.' -f $toolName) -Level Error
            }
        } else {
            Write-Log 'Invalid input. Please enter a valid number from the list.' -Level Warning
        }
        
        Write-Host "`nPress Enter to continue..."
        Read-Host
        Clear-Host
        Show-Header
        $toolList = Show-Tools
        
    } while ($true)
}

# Entry Point
try {
    Initialize-Logging
    Write-Log 'Starting DevOps Tool Uninstaller...' -Level Info
    
    if (-not (Test-Prerequisites)) {
        exit 1
    }
    
    Show-MainMenu
    Write-Log 'DevOps Tool Uninstaller completed successfully.' -Level Success
}
catch {
    Write-Log ('An unexpected error occurred: {0}' -f $_.Exception.Message) -Level Error
    exit 1
}
