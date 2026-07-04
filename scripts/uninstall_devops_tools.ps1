# uninstall_devops_tools.ps1
# Enhanced version with better error handling, logging, and state management

# Check for Administrator privileges
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host 'ERROR: This script requires Administrator privileges.' -ForegroundColor Red
    Write-Host 'Please right-click PowerShell and select "Run as Administrator"' -ForegroundColor Yellow
    Write-Host 'Current user: ' -ForegroundColor White -NoNewline
    Write-Host $currentUser.Name -ForegroundColor Gray
    exit 1
}

# Additional check for elevated privileges
try {
    $testPath = "$env:TEMP\admin_test_$(Get-Random)"
    New-Item -Path $testPath -ItemType Directory -Force | Out-Null
    Remove-Item -Path $testPath -Force -Recurse | Out-Null
} catch {
    Write-Host 'ERROR: Cannot create/remove directories. Administrator privileges required.' -ForegroundColor Red
    exit 1
}

# Script Configuration
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$CONFIG = @{
    LogFile              = Join-Path $scriptDir 'devops_uninstall.log'
    StateFile            = Join-Path (Split-Path $scriptDir -Parent) 'devops_state.json'
    ChocolateyMinVersion = '1.0.0'
}

# Function: Initialize logging
function Initialize-Logging {
    # Add TLS 1.2 support
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    
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

    # Use a mutex for thread-safe file access
    $mutex    = $null
    $acquired = $false
    try {
        try {
            $mutex = [System.Threading.Mutex]::OpenExisting('DevOpsToolUninstallerLogMutex')
        } catch {
            $mutex = New-Object System.Threading.Mutex($false, 'DevOpsToolUninstallerLogMutex')
        }

        $acquired = $mutex.WaitOne(1000) # 1 second timeout
        if ($acquired) {
            $logMessage | Out-File -FilePath $CONFIG.LogFile -Append -Encoding utf8
        } else {
            Write-Host 'Warning: Log mutex timeout, skipping write.' -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Warning: Could not write to log file: $_" -ForegroundColor Yellow
    }
    finally {
        if ($mutex -ne $null) {
            if ($acquired) { $mutex.ReleaseMutex() }
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
    Write-Host "`nScanning your system for installed DevOps tools..." -ForegroundColor Yellow
    Write-Host "This may take a few seconds..." -ForegroundColor Gray

    $tools = @(
        'Docker', 'Kubernetes (kubectl)', 'Ansible', 'Terraform', 'Jenkins',
        'AWS CLI', 'Azure CLI', 'Google Cloud SDK', 'Helm', 'Prometheus',
        'Grafana', 'GitLab Runner (Runner)', 'HashiCorp Vault', 'HashiCorp Consul',
        'Minikube', 'Istio', 'OpenShift CLI', 'Packer', 'Vagrant'
    )

    # Check installation status for each tool
    $installedTools = Get-InstalledTools
    
    Write-Host "`nTools available for uninstallation:`n" -ForegroundColor Yellow
    
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
        try {
            # Chocolatey 2.x: 'choco list <pkg>' without --exact is sufficient;
            # match on package name in the output line rather than the summary count.
            $listOutput = & choco list $package 2>$null
            $found = $listOutput | Where-Object { $_ -match "^$([regex]::Escape($package))\s" }
            if ($found) {
                [void]$installedTools.Add($tool)
                Write-Log ("Found {0} installed as {1}" -f $tool, $package) -Level Info
            }
        } catch {
            Write-Log ("Error checking {0}: {1}" -f $tool, $_.Exception.Message) -Level Warning
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
            try {
                $state = Get-Content $CONFIG.StateFile | ConvertFrom-Json
                # Convert to hashtable if it's a PSCustomObject
                if ($state -is [PSCustomObject]) {
                    $hashtable = @{}
                    $state.PSObject.Properties | ForEach-Object { $hashtable[$_.Name] = $_.Value }
                    $state = $hashtable
                }
            } catch {
                $state = @{}
            }
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
        
        # Check if package is actually installed (Chocolatey 2.x compatible)
        try {
            $listOutput = & choco list $packageName 2>$null
            $found = $listOutput | Where-Object { $_ -match "^$([regex]::Escape($packageName))\s" }
            if (-not $found) {
                Write-Log ('{0} is not installed.' -f $toolName) -Level Warning
                Update-StateFile -toolName $toolName -status 'not_installed'
                return
            }
        } catch {
            Write-Log ('Error checking {0}: {1}' -f $toolName, $_.Exception.Message) -Level Error
            return
        }
        
        # Attempt uninstallation
        Write-Log ('Attempting to uninstall {0}...' -f $toolName) -Level Info
        
        # Check if we can write to chocolatey directories
        $chocoPath = $env:ChocolateyInstall
        if (-not $chocoPath) {
            $chocoPath = "C:\ProgramData\chocolatey"
        }
        
        $testPath = Join-Path $chocoPath "test_write_$(Get-Random)"
        try {
            New-Item -Path $testPath -ItemType File -Force | Out-Null
            Remove-Item -Path $testPath -Force | Out-Null
        } catch {
            Write-Log ('Permission denied: Cannot write to Chocolatey directory {0}' -f $chocoPath) -Level Error
            Write-Host ('ERROR: Permission denied when accessing {0}' -f $chocoPath) -ForegroundColor Red
            Write-Host 'Please ensure you are running PowerShell as Administrator' -ForegroundColor Yellow
            Update-StateFile -toolName $toolName -status 'failed' -message 'Permission denied'
            return
        }
        
        # Run uninstall (omit --skip-autouninstaller; deprecated in Chocolatey 2.x)
        $uninstallResult = & choco uninstall $packageName -y 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Write-Log ('{0} uninstalled successfully.' -f $toolName) -Level Success
            Update-StateFile -toolName $toolName -status 'uninstalled'
        } else {
            Write-Log ('Chocolatey uninstall failed with exit code {0}: {1}' -f $exitCode, ($uninstallResult -join '; ')) -Level Error
            Write-Host ('ERROR: Failed to uninstall {0}' -f $toolName) -ForegroundColor Red
            Write-Host 'This may be due to permission issues or files in use.' -ForegroundColor Yellow
            Update-StateFile -toolName $toolName -status 'failed' -message "Exit code: $exitCode"
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
