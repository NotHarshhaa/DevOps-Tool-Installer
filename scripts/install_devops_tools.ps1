# install_devops_tools.ps1 - DevOps Tool Installer by ProDevOpsGuy Tech
# Version 3.5.0

# Ensure we're in the correct directory
$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir  = Split-Path -Parent $scriptPath
Set-Location -Path $scriptDir

# Script Configuration
$CONFIG = @{
    LogFile                   = Join-Path $scriptDir 'install_devops_tools.log'
    StateFile                 = Join-Path (Split-Path $scriptDir -Parent) 'devops_state.json'
    PreferredPackageManager   = 'choco'
    ParallelInstallation      = $false
    MaxParallelJobs           = 3
    CheckSystemRequirements   = $true
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

# Function: Write log message (thread-safe)
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        'Info'    { 'White' }
        'Warning' { 'Yellow' }
        'Error'   { 'Red' }
        'Success' { 'Green' }
    }

    Write-Host "[$timestamp] $Level : $Message" -ForegroundColor $color

    $mutex    = $null
    $acquired = $false
    try {
        try {
            $mutex = [System.Threading.Mutex]::OpenExisting("DevOpsToolInstallerLogMutex")
        } catch {
            $mutex = New-Object System.Threading.Mutex($false, "DevOpsToolInstallerLogMutex")
        }

        $acquired = $mutex.WaitOne(1000)
        if ($acquired) {
            "[$timestamp] $Level : $Message" | Out-File -FilePath $CONFIG.LogFile -Append -Encoding utf8
        }
    } catch {
        Write-Host "Warning: Could not write to log file: $_" -ForegroundColor Yellow
    } finally {
        if ($mutex -ne $null) {
            if ($acquired) { $mutex.ReleaseMutex() }
            $mutex.Dispose()
        }
    }
}

# Function: Check System Requirements
function Test-SystemRequirements {
    Write-Log 'Checking system requirements...' -Level Info

    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

    # Internet check via lightweight web request (faster than Test-NetConnection)
    $internetOk = $false
    try {
        $null = Invoke-WebRequest -Uri 'https://www.google.com' -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        $internetOk = $true
    } catch {
        $internetOk = $false
    }

    $requirements = @{
        'PowerShell Version'   = @{
            Test    = $PSVersionTable.PSVersion.Major -ge 5
            Message = 'PowerShell 5.0 or higher is required'
        }
        'Admin Rights'         = @{
            Test    = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            Message = 'Administrator privileges are required'
        }
        'Internet Connection'  = @{
            Test    = $internetOk
            Message = 'Internet connection is required'
        }
        'Available Disk Space' = @{
            Test    = (Get-PSDrive -Name C).Free -gt 10GB
            Message = 'At least 10GB of free disk space is required'
        }
        'TLS 1.2 Support'      = @{
            Test    = [bool]([System.Net.ServicePointManager]::SecurityProtocol -band 3072)
            Message = 'TLS 1.2 support is required'
        }
    }

    $allPassed = $true
    foreach ($req in $requirements.GetEnumerator()) {
        if (-not $req.Value.Test) {
            Write-Log ('[X] {0}: {1}' -f $req.Key, $req.Value.Message) -Level Error
            $allPassed = $false
        } else {
            Write-Log ('[OK] {0}: Passed' -f $req.Key) -Level Success
        }
    }

    return $allPassed
}

# Function: Check and Install Package Manager
function Initialize-PackageManager {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host 'This script requires Administrator privileges. Please run as Administrator.' -ForegroundColor Red
        exit 1
    }

    # Install Chocolatey if missing
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host 'Installing Chocolatey package manager...' -ForegroundColor Yellow
        try {
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            $installScript = (New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')

            $tempFile = [System.IO.Path]::GetTempFileName()
            $installScript | Out-File -FilePath $tempFile -Encoding utf8

            try {
                & $tempFile
                if ($LASTEXITCODE -ne 0) {
                    throw "Chocolatey installation failed with exit code $LASTEXITCODE"
                }
            } finally {
                Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
            }

            # Reload PATH
            $env:Path = '{0};{1}' -f `
                [System.Environment]::GetEnvironmentVariable('Path', 'Machine'), `
                [System.Environment]::GetEnvironmentVariable('Path', 'User')

            if (Get-Command choco -ErrorAction SilentlyContinue) {
                Write-Host 'Chocolatey installed successfully!' -ForegroundColor Green
            } else {
                Write-Host 'Failed to verify Chocolatey installation.' -ForegroundColor Red
            }
        } catch {
            Write-Log "Failed to install Chocolatey: $_" -Level Error
            Write-Host "Failed to install Chocolatey. Please check the logs for details." -ForegroundColor Red
        }
    }

    # Winget check
    if ($CONFIG.PreferredPackageManager -eq 'winget' -and -not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host 'Winget is not installed. Please install App Installer from the Microsoft Store.' -ForegroundColor Red
        exit 1
    }
}

# Function: Display Header UI
function Show-Header {
    $version = '3.5.0'
    Clear-Host
    Write-Host ([string]::Empty)
    Write-Host '+====================================================================+' -ForegroundColor Cyan
    Write-Host '|                                                                    |' -ForegroundColor Cyan
    Write-Host ('|        DevOps Tool Installer v{0} by ProDevOpsGuy Tech           |' -f $version) -ForegroundColor Cyan
    Write-Host '|                                                                    |' -ForegroundColor Cyan
    Write-Host '+====================================================================+' -ForegroundColor Cyan
    Write-Host ([string]::Empty)
    Write-Host 'Features:' -ForegroundColor Magenta
    Write-Host '  * Multi-package manager support (Chocolatey and Winget)' -ForegroundColor White
    Write-Host '  * Progress tracking per tool installation'                -ForegroundColor White
    Write-Host '  * Tool health checks and validation'                      -ForegroundColor White
    Write-Host '  * Installation state persistence'                         -ForegroundColor White
    Write-Host '  * Advanced error handling and logging'                    -ForegroundColor White
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
        $State | ConvertTo-Json -Depth 5 | Set-Content $CONFIG.StateFile -Encoding utf8
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
            @{ Name = "Docker Desktop";        Package = "docker-desktop" },
            @{ Name = "Kubernetes (kubectl)";  Package = "kubernetes-cli" },
            @{ Name = "Minikube";              Package = "minikube" },
            @{ Name = "Helm";                  Package = "kubernetes-helm" },
            @{ Name = "Istio CLI (istioctl)";  Package = "istioctl" }
        )
        "Infrastructure as Code" = @(
            @{ Name = "Terraform";  Package = "terraform" },
            @{ Name = "Ansible";    Package = "ansible" },
            @{ Name = "Packer";     Package = "packer" },
            @{ Name = "Vagrant";    Package = "vagrant" }
        )
        "CI/CD and Version Control" = @(
            @{ Name = "Jenkins";        Package = "jenkins" },
            @{ Name = "GitLab Runner";  Package = "gitlab-runner" },
            @{ Name = "Git";            Package = "git" }
        )
        "Cloud Providers" = @(
            @{ Name = "AWS CLI";          Package = "awscli" },
            @{ Name = "Azure CLI";        Package = "azure-cli" },
            @{ Name = "Google Cloud SDK"; Package = "gcloudsdk" }
        )
        "Monitoring and Observability" = @(
            @{ Name = "Prometheus"; Package = "prometheus" },
            @{ Name = "Grafana";    Package = "grafana" }
        )
        "Service Mesh and Discovery" = @(
            @{ Name = "HashiCorp Vault";   Package = "vault" },
            @{ Name = "HashiCorp Consul";  Package = "consul" }
        )
    }

    $index       = 1
    $toolMapping = @{}

    foreach ($category in $tools.Keys | Sort-Object) {
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

    $validationCmds = @{
        "docker-desktop"  = @{ Exe = "docker";     Args = @("--version") }
        "kubernetes-cli"  = @{ Exe = "kubectl";    Args = @("version", "--client") }
        "terraform"       = @{ Exe = "terraform";  Args = @("--version") }
        "ansible"         = @{ Exe = "ansible";    Args = @("--version") }
        "awscli"          = @{ Exe = "aws";        Args = @("--version") }
        "azure-cli"       = @{ Exe = "az";         Args = @("--version") }
        "gcloudsdk"       = @{ Exe = "gcloud";     Args = @("--version") }
        "git"             = @{ Exe = "git";        Args = @("--version") }
    }

    if ($validationCmds.ContainsKey($PackageName)) {
        $vc = $validationCmds[$PackageName]
        try {
            $result = Start-Process -FilePath $vc.Exe -ArgumentList $vc.Args -NoNewWindow -Wait -PassThru -ErrorAction Stop
            if ($result.ExitCode -eq 0) {
                Write-Log "[OK] $ToolName validated successfully" -Level Success
                return $true
            } else {
                Write-Log "[FAIL] $ToolName validation failed (exit code $($result.ExitCode))" -Level Error
                return $false
            }
        } catch {
            Write-Log "[FAIL] $ToolName validation failed: $_" -Level Error
            return $false
        }
    }

    # Generic: check if executable is on PATH using Get-Command (no external binary needed)
    if (Get-Command $PackageName -ErrorAction SilentlyContinue) {
        Write-Log "[OK] $ToolName found in PATH" -Level Success
        return $true
    } else {
        Write-Log "[FAIL] $ToolName not found in PATH" -Level Error
        return $false
    }
}

# Function: Install a Single Tool
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
                    $result = Start-Process -FilePath 'choco' -ArgumentList 'install', $PackageName, '-y', '--no-progress' -NoNewWindow -Wait -PassThru
                    if ($result.ExitCode -eq 0) {
                        Write-Host ('{0} installed successfully' -f $ToolName) -ForegroundColor Green
                        return $true
                    }
                    Write-Host ('Chocolatey returned exit code {0} for {1}' -f $result.ExitCode, $ToolName) -ForegroundColor Red
                    return $false
                } else {
                    Write-Host 'Chocolatey not found. Attempting to install it first...' -ForegroundColor Yellow
                    Initialize-PackageManager

                    if (Get-Command choco -ErrorAction SilentlyContinue) {
                        $result = Start-Process -FilePath 'choco' -ArgumentList 'install', $PackageName, '-y', '--no-progress' -NoNewWindow -Wait -PassThru
                        if ($result.ExitCode -eq 0) {
                            Write-Host ('{0} installed successfully' -f $ToolName) -ForegroundColor Green
                            return $true
                        }
                    } else {
                        Write-Host 'Chocolatey could not be installed. Aborting.' -ForegroundColor Red
                        return $false
                    }
                }
            }
            'winget' {
                if (Get-Command winget -ErrorAction SilentlyContinue) {
                    $result = Start-Process -FilePath 'winget' -ArgumentList `
                        'install', $PackageName, '--accept-source-agreements', '--accept-package-agreements', '--silent' `
                        -NoNewWindow -Wait -PassThru
                    if ($result.ExitCode -eq 0) {
                        Write-Host ('{0} installed successfully' -f $ToolName) -ForegroundColor Green
                        return $true
                    }
                    Write-Host ('Winget returned exit code {0} for {1}' -f $result.ExitCode, $ToolName) -ForegroundColor Red
                    return $false
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

# Function: Show Installation Summary Table
function Show-InstallationSummary {
    param(
        [System.Collections.Generic.List[hashtable]]$Results
    )

    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Yellow
    Write-Host "  Installation Summary" -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor Yellow
    Write-Host ("{0,-30} {1,-15} {2}" -f "Tool", "Status", "Notes") -ForegroundColor White
    Write-Host ("-" * 70) -ForegroundColor Gray

    $successCount = 0
    $failCount    = 0

    foreach ($r in $Results) {
        $color  = if ($r.Success) { 'Green' } else { 'Red' }
        $status = if ($r.Success) { '[OK]  ' } else { '[FAIL]' }
        if ($r.Success) { $successCount++ } else { $failCount++ }

        Write-Host ("{0} {1,-28} {2}" -f $status, $r.Name, $r.Notes) -ForegroundColor $color
    }

    Write-Host ("-" * 70) -ForegroundColor Gray
    Write-Host ("  Installed: {0}  |  Failed: {1}  |  Total: {2}" -f $successCount, $failCount, $Results.Count) -ForegroundColor White
    Write-Host ("=" * 70) -ForegroundColor Yellow
    Write-Host ""
}

# Entry Point
try {
    Initialize-Logging
    Show-Header

    Initialize-PackageManager

    if ($CONFIG.CheckSystemRequirements -and -not (Test-SystemRequirements)) {
        Write-Host 'System requirements not met. Please address the issues above and try again.' -ForegroundColor Red
        exit 1
    }

    $toolMapping    = Show-Tools
    $selectedTools  = @()

    do {
        $choice = Read-Host ("`nEnter the number of the tool to install (or 'done' to finish, 'q' to quit)")
        if ($choice -eq 'q') {
            Write-Host 'Exiting installer.' -ForegroundColor Yellow
            exit 0
        }
        if ($choice -ne 'done') {
            try {
                $index = [int]$choice
                if ($toolMapping.ContainsKey($index)) {
                    # Avoid duplicates
                    if ($selectedTools | Where-Object { $_.Package -eq $toolMapping[$index].Package }) {
                        Write-Host ('{0} is already in the queue.' -f $toolMapping[$index].Name) -ForegroundColor Gray
                    } else {
                        $selectedTools += $toolMapping[$index]
                        Write-Host ('Added [{0}] {1} to installation queue' -f $index, $toolMapping[$index].Name) -ForegroundColor Green
                    }
                } else {
                    Write-Host 'Invalid selection. Please enter a number from the list.' -ForegroundColor Yellow
                }
            } catch {
                Write-Host 'Invalid input. Please enter a number or "done"' -ForegroundColor Yellow
            }
        }
    } while ($choice -ne 'done')

    if ($selectedTools.Count -eq 0) {
        Write-Host 'No tools selected for installation.' -ForegroundColor Yellow
        exit 0
    }

    Write-Host ("`nInstalling {0} selected tool(s)..." -f $selectedTools.Count) -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor Yellow

    $results = [System.Collections.Generic.List[hashtable]]::new()
    $state   = Get-InstallationState
    $i       = 0

    foreach ($tool in $selectedTools) {
        $i++
        Write-Host ""
        Write-Host ("[{0}/{1}] Installing: {2}" -f $i, $selectedTools.Count, $tool.Name) -ForegroundColor Cyan
        Write-Host ("-" * 50) -ForegroundColor Gray

        $success = Install-Tool -ToolName $tool.Name -PackageName $tool.Package

        # Update state
        $state | Add-Member -NotePropertyName $tool.Name -NotePropertyValue @{
            status  = if ($success) { 'installed' } else { 'failed' }
            date    = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            version = 'N/A'
        } -Force

        $notes = if ($success) { 'Installed OK' } else { 'Installation failed — check logs' }
        $results.Add(@{ Name = $tool.Name; Success = $success; Notes = $notes })

        Write-Log ("{0}: {1}" -f $tool.Name, $(if ($success) { 'installed' } else { 'failed' })) -Level $(if ($success) { 'Success' } else { 'Error' })
    }

    Save-InstallationState -State $state
    Show-InstallationSummary -Results $results

    Write-Host "Installation process completed! Logs saved to:" -ForegroundColor Green
    Write-Host "  $($CONFIG.LogFile)" -ForegroundColor Gray

} catch {
    Write-Host ('An error occurred: {0}' -f $_) -ForegroundColor Red
    exit 1
}
