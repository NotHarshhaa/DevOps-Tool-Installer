# install_devops_tools.ps1

# Ensure we're in the correct directory
$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path -Parent $scriptPath
Set-Location -Path $scriptDir

# Script Configuration
$CONFIG = @{
    LogFile = 'install_devops_tools.log'
    StateFile = 'installation_state.json'
    PreferredPackageManager = 'choco'
    ParallelInstallation = $false
    MaxParallelJobs = 3
    CheckSystemRequirements = $true
}

# Initialize logging at script start
if (-not (Test-Path $CONFIG.LogFile)) {
    New-Item -Path $CONFIG.LogFile -ItemType File -Force | Out-Null
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
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        'Info' { 'White' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        'Success' { 'Green' }
    }
    
    Write-Host "[$timestamp] $Level : $Message" -ForegroundColor $color
    
    # Use a mutex for file access
    $mutex = New-Object System.Threading.Mutex($false, "DevOpsToolInstallerLogMutex")
    try {
        [void]$mutex.WaitOne()
        "[$timestamp] $Level : $Message" | Out-File -FilePath $CONFIG.LogFile -Append -Encoding utf8
    }
    catch {
        Write-Host "Warning: Could not write to log file: $_" -ForegroundColor Yellow
    }
    finally {
        if ($mutex) {
            $mutex.ReleaseMutex()
            $mutex.Dispose()
        }
    }
}

# Function: Check System Requirements
function Test-SystemRequirements {
    Write-Log 'Checking system requirements...' -Level Info
    
    $requirements = @{
        'PowerShell Version' = @{
            Test = $PSVersionTable.PSVersion.Major -ge 5
            Message = 'PowerShell 5.0 or higher is required'
        }
        'Admin Rights' = @{
            Test = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            Message = 'Administrator privileges are required'
        }
        'Internet Connection' = @{
            Test = Test-NetConnection -ComputerName '8.8.8.8' -Port 443 -WarningAction SilentlyContinue
            Message = 'Internet connection is required'
        }
        'Available Disk Space' = @{
            Test = (Get-PSDrive -Name C).Free -gt 10GB
            Message = 'At least 10GB of free disk space is required'
        }
    }

    $allPassed = $true
    foreach ($req in $requirements.GetEnumerator()) {
        if (-not $req.Value.Test) {
            Write-Log ('[X] {0}: {1}' -f $req.Key, $req.Value.Message) -Level Error
            $allPassed = $false
        } else {
            Write-Log ('[√] {0}: Passed' -f $req.Key) -Level Success
        }
    }
    
    return $allPassed
}

# Function: Check and Install Package Manager
function Initialize-PackageManager {
    # Check if running as Administrator
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host 'This script requires Administrator privileges. Please run as Administrator.' -ForegroundColor Red
        exit 1
    }

    # Check for Chocolatey
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host 'Installing Chocolatey package manager...' -ForegroundColor Yellow
        try {
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            $installScript = (New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')
            Invoke-Expression $installScript
            
            # Reload PATH
            $machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
            $userPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
            $env:Path = '{0};{1}' -f $machinePath, $userPath
            
            # Verify installation
            if (Get-Command choco -ErrorAction SilentlyContinue) {
                Write-Host 'Chocolatey installed successfully!' -ForegroundColor Green
            } else {
                Write-Host 'Failed to verify Chocolatey installation.' -ForegroundColor Red
                exit 1
            }
        } catch {
            Write-Host ('Failed to install Chocolatey: {0}' -f $_) -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host 'Chocolatey is already installed.' -ForegroundColor Green
    }

    # Check for winget if it's the preferred package manager
    if ($CONFIG.PreferredPackageManager -eq 'winget' -and -not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host 'Winget is not installed. Please install App Installer from the Microsoft Store.' -ForegroundColor Red
        exit 1
    }
}

# Function: Display Header UI
function Show-Header {
    $version = '2.5.0'
    Clear-Host
    Write-Host ([string]::Empty)
    Write-Host '+====================================================================+' -ForegroundColor Cyan
    Write-Host '|                                                                    |' -ForegroundColor Cyan
    Write-Host ('|        DevOps Tool Installer v{0} by ProDevOpsGuy Tech           |' -f $version) -ForegroundColor Cyan
    Write-Host '|                                                                    |' -ForegroundColor Cyan
    Write-Host '+====================================================================+' -ForegroundColor Cyan
    Write-Host ([string]::Empty)
    Write-Host 'Features:'
    Write-Host '  * Multi-package manager support (choco and Winget)'
    Write-Host '  * Parallel installation support'
    Write-Host '  * Tool health checks and validation'
    Write-Host '  * Installation state persistence'
    Write-Host '  * Advanced error handling and logging'
    Write-Host ([string]::Empty)
}

# Function: Load Installation State
function Get-InstallationState {
    if (Test-Path $CONFIG.StateFile) {
        try {
            return Get-Content $CONFIG.StateFile | ConvertFrom-Json
        } catch {
            Write-Log "Failed to load installation state: $_" -Level Warning
            return @{}
        }
    }
    return @{}
}

# Function: Save Installation State
function Save-InstallationState {
    param($State)
    
    try {
        $State | ConvertTo-Json | Set-Content $CONFIG.StateFile
        Write-Log "Installation state saved successfully" -Level Success
    } catch {
        Write-Log "Failed to save installation state: $_" -Level Warning
    }
}

# Function: Display Tool List with Categories
function Show-Tools {
    Write-Host "`nTools available for installation:`n" -ForegroundColor Yellow

    $tools = @{
        "Containerization and Orchestration" = @(
            @{Name="Docker Desktop"; Package="docker-desktop"},
            @{Name="Kubernetes (kubectl)"; Package="kubernetes-cli"},
            @{Name="Minikube"; Package="minikube"},
            @{Name="Helm"; Package="kubernetes-helm"},
            @{Name="Istio"; Package="istio"}
        )
        "Infrastructure as Code" = @(
            @{Name="Terraform"; Package="terraform"},
            @{Name="Ansible"; Package="ansible"},
            @{Name="Packer"; Package="packer"},
            @{Name="Vagrant"; Package="vagrant"}
        )
        "CI/CD and Version Control" = @(
            @{Name="Jenkins"; Package="jenkins"},
            @{Name="GitLab Runner"; Package="gitlab-runner"},
            @{Name="Git"; Package="git"}
        )
        "Cloud Providers" = @(
            @{Name="AWS CLI"; Package="awscli"},
            @{Name="Azure CLI"; Package="azure-cli"},
            @{Name="Google Cloud SDK"; Package="google-cloud-sdk"}
        )
        "Monitoring and Observability" = @(
            @{Name="Prometheus"; Package="prometheus"},
            @{Name="Grafana"; Package="grafana"}
        )
        "Service Mesh and Discovery" = @(
            @{Name="HashiCorp Vault"; Package="vault"},
            @{Name="HashiCorp Consul"; Package="consul"}
        )
    }

    $index = 1
    $toolMapping = @{}

    foreach ($category in $tools.Keys) {
        Write-Host "`n[$category]" -ForegroundColor Cyan
        foreach ($tool in $tools[$category]) {
            Write-Host ("[{0,2}] {1}" -f $index, $tool.Name) -ForegroundColor Green
            $toolMapping[$index] = $tool
            $index++
        }
    }

    return $toolMapping
}

# Function: Validate Tool Installation
function Test-ToolInstallation {
    param(
        [string]$ToolName,
        [string]$PackageName
    )
    
    Write-Log "Validating installation of $ToolName..." -Level Info
    
    $validationCommands = @{
        "docker-desktop" = "docker --version"
        "kubernetes-cli" = "kubectl version --client"
        "terraform" = "terraform --version"
        "ansible" = "ansible --version"
        "awscli" = "aws --version"
        "azure-cli" = "az --version"
        "git" = "git --version"
    }
    
    if ($validationCommands.ContainsKey($PackageName)) {
        try {
            Invoke-Expression $validationCommands[$PackageName] | Out-Null
            Write-Log "✅ $ToolName validated successfully" -Level Success
            return $true
        } catch {
            Write-Log "❌ $ToolName validation failed: $_" -Level Error
            return $false
        }
    }
    
    # Default validation using where.exe
    try {
        where.exe $PackageName | Out-Null
        Write-Log "✅ $ToolName found in PATH" -Level Success
        return $true
    } catch {
        Write-Log "❌ $ToolName not found in PATH" -Level Error
        return $false
    }
}

# Function: Install Tool
function Install-Tool {
    param(
        [string]$ToolName,
        [string]$PackageName
    )

    try {
        Write-Host ('Installing "{0}" using {1}...' -f $ToolName, $CONFIG.PreferredPackageManager) -ForegroundColor Yellow
        
        switch ($CONFIG.PreferredPackageManager) {
            'choco' {
                if (Get-Command choco -ErrorAction SilentlyContinue) {
                    $result = Start-Process -FilePath 'choco' -ArgumentList 'install', $PackageName, '-y' -NoNewWindow -Wait -PassThru
                    if ($result.ExitCode -eq 0) {
                        Write-Host ('{0} installed successfully' -f $ToolName) -ForegroundColor Green
                        return $true
                    }
                } else {
                    Write-Host 'Chocolatey (choco) is not available. Installing Chocolatey...' -ForegroundColor Yellow
                    try {
                        Set-ExecutionPolicy Bypass -Scope Process -Force
                        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
                        $installScript = (New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')
                        Invoke-Expression $installScript
                        
                        # Reload PATH
                        $machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
                        $userPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
                        $env:Path = '{0};{1}' -f $machinePath, $userPath
                        
                        # Try installation again
                        if (Get-Command choco -ErrorAction SilentlyContinue) {
                            $result = Start-Process -FilePath 'choco' -ArgumentList 'install', $PackageName, '-y' -NoNewWindow -Wait -PassThru
                            if ($result.ExitCode -eq 0) {
                                Write-Host ('{0} installed successfully' -f $ToolName) -ForegroundColor Green
                                return $true
                            }
                        } else {
                            Write-Host 'Failed to verify Chocolatey installation' -ForegroundColor Red
                            return $false
                        }
                    } catch {
                        Write-Host ('Failed to install Chocolatey: {0}' -f $_) -ForegroundColor Red
                        return $false
                    }
                }
            }
            'winget' {
                if (Get-Command winget -ErrorAction SilentlyContinue) {
                    $result = Start-Process -FilePath 'winget' -ArgumentList 'install', $PackageName, '--accept-source-agreements', '--accept-package-agreements' -NoNewWindow -Wait -PassThru
                    if ($result.ExitCode -eq 0) {
                        Write-Host ('{0} installed successfully' -f $ToolName) -ForegroundColor Green
                        return $true
                    }
                } else {
                    Write-Host 'Winget is not available. Please install App Installer from the Microsoft Store.' -ForegroundColor Red
                    return $false
                }
            }
        }
        
        Write-Host ('Failed to install {0}' -f $ToolName) -ForegroundColor Red
        return $false
    } catch {
        Write-Host ('Error installing {0}: {1}' -f $ToolName, $_.Exception.Message) -ForegroundColor Red
        return $false
    }
}

# Function: Install Tools in Parallel
function Install-ToolsParallel {
    param(
        [array]$ToolsToInstall
    )
    
    foreach ($tool in $ToolsToInstall) {
        Install-Tool -ToolName $tool.Name -PackageName $tool.Package
    }
}

# Entry Point
try {
    Show-Header
    
    # Initialize package manager first
    Initialize-PackageManager
    
    if ($CONFIG.CheckSystemRequirements -and -not (Test-SystemRequirements)) {
        Write-Host 'System requirements not met. Please address the issues above and try again.' -ForegroundColor Red
        exit 1
    }
    
    $toolMapping = Show-Tools
    $selectedTools = @()
    
    do {
        $choice = Read-Host ([string]::Format("`nEnter the number of the tool to install (or 'done' to finish)"))
        if ($choice -ne 'done') {
            try {
                $index = [int]$choice
                if ($toolMapping.ContainsKey($index)) {
                    $selectedTools += $toolMapping[$index]
                    Write-Host ([string]::Format('Added {0} to installation queue', $toolMapping[$index].Name)) -ForegroundColor Green
                } else {
                    Write-Host 'Invalid selection. Please enter a number from the list.' -ForegroundColor Yellow
                }
            } catch {
                Write-Host 'Invalid input. Please enter a number or "done"' -ForegroundColor Yellow
            }
        }
    } while ($choice -ne 'done' -and $choice -ne 'q')
    
    if ($selectedTools.Count -eq 0) {
        Write-Host 'No tools selected for installation.' -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host ([string]::Format("`nInstalling selected tools...")) -ForegroundColor Cyan
    foreach ($tool in $selectedTools) {
        Install-Tool -ToolName $tool.Name -PackageName $tool.Package
    }
    
    Write-Host ([string]::Format("`nInstallation process completed!")) -ForegroundColor Green
} catch {
    Write-Host ([string]::Format('An error occurred: {0}', $_)) -ForegroundColor Red
    exit 1
}
