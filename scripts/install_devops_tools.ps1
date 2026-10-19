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

    # Check free space on the actual system drive (not hard-coded C:)
    $systemDriveName = $env:SystemDrive -replace ':', ''
    $systemDrive = Get-PSDrive -Name $systemDriveName -ErrorAction SilentlyContinue
    $diskSpaceOk = ($systemDrive -ne $null -and $systemDrive.Free -gt 10GB)

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
            Test    = $diskSpaceOk
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

            $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ("choco_install_{0}.ps1" -f [guid]::NewGuid().ToString('N'))
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

# Function: Get Validation Command for a Package
function Get-ValidationCommand {
    param([string]$PackageName)

    $validationCmds = @{
        "docker-desktop"  = @{ Exe = "docker";     Args = @("--version") }
        "kubernetes-cli"  = @{ Exe = "kubectl";    Args = @("version", "--client") }
        "minikube"        = @{ Exe = "minikube";   Args = @("version") }
        "kubernetes-helm" = @{ Exe = "helm";       Args = @("version") }
        "istioctl"        = @{ Exe = "istioctl";   Args = @("version") }
        "terraform"       = @{ Exe = "terraform";  Args = @("--version") }
        "packer"          = @{ Exe = "packer";     Args = @("version") }
        "vagrant"         = @{ Exe = "vagrant";    Args = @("--version") }
        "jenkins"         = @{ Exe = "jenkins";    Args = @("--version") }
        "gitlab-runner"   = @{ Exe = "gitlab-runner"; Args = @("--version") }
        "ansible"         = @{ Exe = "ansible";    Args = @("--version") }
        "awscli"          = @{ Exe = "aws";        Args = @("--version") }
        "azure-cli"       = @{ Exe = "az";         Args = @("--version") }
        "gcloudsdk"       = @{ Exe = "gcloud";     Args = @("--version") }
        "prometheus"      = @{ Exe = "prometheus"; Args = @("--version") }
        "grafana"         = @{ Exe = "grafana";    Args = @("--version") }
        "vault"           = @{ Exe = "vault";      Args = @("version") }
        "consul"          = @{ Exe = "consul";     Args = @("version") }
        "git"             = @{ Exe = "git";        Args = @("--version") }
    }

    if ($validationCmds.ContainsKey($PackageName)) {
        return $validationCmds[$PackageName]
    }
    return $null
}

# Function: Get Detected Version of an Installed Tool
function Get-ToolVersion {
    param([string]$PackageName)

    $vc = Get-ValidationCommand -PackageName $PackageName
    if ($null -ne $vc) {
        try {
            $output = & $vc.Exe $vc.Args 2>$null | Select-Object -First 1
            if ($output) { return "$output".Trim() }
        } catch { }
    }
    return 'N/A'
}

# Function: Validate Tool Installation
function Test-ToolInstallation {
    param(
        [string]$ToolName,
        [string]$PackageName
    )

    Write-Log "Validating installation of $ToolName..." -Level Info

    $vc = Get-ValidationCommand -PackageName $PackageName
    if ($null -ne $vc) {
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

    # Helper: exit codes that mean success (0 = ok, 3010/1641 = success, reboot required)
    function Test-InstallExitCode {
        param([int]$Code)
        return ($Code -eq 0 -or $Code -eq 3010 -or $Code -eq 1641)
    }

    # Helper: make freshly installed binaries visible again in this session
    function Update-SessionPath {
        $env:Path = '{0};{1}' -f `
            [System.Environment]::GetEnvironmentVariable('Path', 'Machine'), `
            [System.Environment]::GetEnvironmentVariable('Path', 'User')
    }

    try {
        Write-Log "Installing '$ToolName' (package: $PackageName) using $($CONFIG.PreferredPackageManager)..." -Level Info
        Write-Host ('Installing "{0}" using {1}...' -f $ToolName, $CONFIG.PreferredPackageManager) -ForegroundColor Yellow

        switch ($CONFIG.PreferredPackageManager) {
            'choco' {
                if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
                    Write-Host 'Chocolatey not found. Attempting to install it first...' -ForegroundColor Yellow
                    Initialize-PackageManager
                    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
                        Write-Host 'Chocolatey could not be installed. Aborting.' -ForegroundColor Red
                        return $false
                    }
                }

                $result = Start-Process -FilePath 'choco' -ArgumentList 'install', $PackageName, '-y', '--no-progress' -NoNewWindow -Wait -PassThru
                if (Test-InstallExitCode $result.ExitCode) {
                    Update-SessionPath
                    Write-Host ('{0} installed successfully' -f $ToolName) -ForegroundColor Green
                    return $true
                }
                Write-Log "Chocolatey returned exit code $($result.ExitCode) for $ToolName" -Level Error
                Write-Host ('Chocolatey returned exit code {0} for {1}' -f $result.ExitCode, $ToolName) -ForegroundColor Red
                return $false
            }
            'winget' {
                if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
                    Write-Log 'Winget is not available on this system.' -Level Error
                    Write-Host 'Winget is not available. Please install App Installer from the Microsoft Store.' -ForegroundColor Red
                    return $false
                }

                $result = Start-Process -FilePath 'winget' `
                    -ArgumentList 'install', $PackageName, '--accept-source-agreements', '--accept-package-agreements', '--silent' `
                    -NoNewWindow -Wait -PassThru
                if (Test-InstallExitCode $result.ExitCode) {
                    Update-SessionPath
                    if ($result.ExitCode -ne 0) {
                        Write-Log "$ToolName installed successfully (exit code $($result.ExitCode): reboot required)" -Level Success
                    }
                    Write-Host ('{0} installed successfully' -f $ToolName) -ForegroundColor Green
                    return $true
                }
                Write-Log "Winget returned exit code $($result.ExitCode) for $ToolName" -Level Error
                Write-Host ('Winget returned exit code {0} for {1}' -f $result.ExitCode, $ToolName) -ForegroundColor Red
                return $false
            }
        }

        Write-Log "Unsupported package manager: $($CONFIG.PreferredPackageManager)" -Level Error
        Write-Host ('Failed to install {0}' -f $ToolName) -ForegroundColor Red
        return $false
    } catch {
        Write-Log "Error installing $ToolName : $($_.Exception.Message)" -Level Error
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

        # Validate the installation and capture the detected version
        $version = 'N/A'
        if ($success) {
            if (Test-ToolInstallation -ToolName $tool.Name -PackageName $tool.Package) {
                $version = Get-ToolVersion -PackageName $tool.Package
            } else {
                $success = $false
            }
        }

        # Update state
        $state | Add-Member -NotePropertyName $tool.Name -NotePropertyValue @{
            status  = if ($success) { 'installed' } else { 'failed' }
            date    = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            version = $version
        } -Force

        $notes = if ($success) { "Installed OK ($version)" } else { 'Installation failed — check logs' }
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
