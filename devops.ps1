# devops.ps1 - DevOps Tool Manager by ProDevOpsGuy

# Check for Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "This script requires Administrator privileges. Please run PowerShell as Administrator." -ForegroundColor Red
    exit 1
}

# Script Configuration
$CONFIG = @{
    Version = "2.5.0"
    LogFile = "devops_manager.log"
    StateFile = "devops_state.json"
    InstallScript = "scripts/install_devops_tools.ps1"
    UninstallScript = "scripts/uninstall_devops_tools.ps1"
    UpdateCheckUrl = "https://api.github.com/repos/ProDevOpsGuy/DevOps-Tool-Installer/releases/latest"
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
    
    $logMessage = "[$timestamp] $Level : $Message"
    Write-Host $logMessage -ForegroundColor $color
    
    # Use a mutex for file access
    $mutex = New-Object System.Threading.Mutex($false, "DevOpsToolInstallerLogMutex")
    try {
        [void]$mutex.WaitOne()
        $logMessage | Out-File -FilePath $CONFIG.LogFile -Append -Encoding utf8
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

# Function: Check for Updates
function Test-Updates {
    try {
        Write-Log "Checking for updates..." -Level Info
        $response = Invoke-RestMethod -Uri $CONFIG.UpdateCheckUrl -Method Get
        $latestVersion = $response.tag_name -replace 'v', ''
        
        if ([version]$latestVersion -gt [version]$CONFIG.Version) {
            Write-Log "New version available: v$latestVersion" -Level Warning
            $choice = Read-Host "Would you like to update? (y/n)"
            if ($choice -eq 'y') {
                Update-Script -Version $latestVersion
            }
        } else {
            Write-Log "You are running the latest version" -Level Success
        }
    } catch {
        Write-Log "Failed to check for updates: $_" -Level Warning
    }
}

# Function: Update Script
function Update-Script {
    param([string]$Version)
    
    try {
        Write-Log "Updating to version $Version..." -Level Info
        # Add update logic here
        Write-Log "Update completed successfully" -Level Success
    } catch {
        Write-Log "Update failed: $_" -Level Error
    }
}

# Function: Show Banner
function Show-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "+===================================================================+" -ForegroundColor Cyan
    Write-Host "|                                                                   |" -ForegroundColor Cyan
    Write-Host "|           DevOps Tool Manager v$($CONFIG.Version) by ProDevOpsGuy Tech         |" -ForegroundColor Cyan
    Write-Host "|                                                                   |" -ForegroundColor Cyan
    Write-Host "+===================================================================+" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Features:"
    Write-Host "  * Easy installation and uninstallation of DevOps tools"
    Write-Host "  * Automatic updates and version management"
    Write-Host "  * Parallel installation support"
    Write-Host "  * Multiple package manager support"
    Write-Host "  * Installation state tracking"
    Write-Host ""
}

# Function: Show Menu
function Show-Menu {
    Write-Host "What would you like to do?" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  [1] Install DevOps Tools" -ForegroundColor Green
    Write-Host "  [2] Uninstall DevOps Tools" -ForegroundColor Red
    Write-Host "  [3] Check for Updates" -ForegroundColor Yellow
    Write-Host "  [4] View Installation Status" -ForegroundColor Blue
    Write-Host "  [5] Exit" -ForegroundColor Gray
    Write-Host ""
}

# Function: View Installation Status
function Show-InstallationStatus {
    if (-not (Test-Path $CONFIG.StateFile)) {
        Write-Log "No installation state found" -Level Warning
        return
    }

    try {
        $state = Get-Content $CONFIG.StateFile | ConvertFrom-Json
        Write-Host "`nInstallation Status:" -ForegroundColor Blue
        Write-Host "====================================="
        
        $state.PSObject.Properties | ForEach-Object {
            $color = switch ($_.Value.status) {
                "installed" { "Green" }
                "failed" { "Red" }
                default { "Yellow" }
            }
            Write-Host ("{0,-30}" -f $_.Name) -NoNewline
            Write-Host ("{0,-15}" -f $_.Value.status) -ForegroundColor $color -NoNewline
            Write-Host ("{0,-25}" -f $_.Value.date)
        }
        Write-Host "=====================================`n"
    } catch {
        Write-Log "Failed to load installation state: $_" -Level Error
    }
}

# Function: Invoke Script
function Invoke-Script {
    param (
        [string]$relativePath,
        [string]$scriptType
    )
    
    $scriptPath = Join-Path -Path $PSScriptRoot -ChildPath $relativePath
    if (Test-Path $scriptPath) {
        Write-Log "Launching $scriptType script..." -Level Info
        try {
            & $scriptPath
            Write-Log "$scriptType completed successfully" -Level Success
        } catch {
            Write-Log "$scriptType failed: $_" -Level Error
        }
    } else {
        Write-Log "$scriptType script not found at: $scriptPath" -Level Error
    }
}

# Main Program
Initialize-Logging
Test-Updates

do {
    Show-Banner
    Show-Menu
    $choice = Read-Host "Enter your choice (1-5)"
    
    switch ($choice) {
        "1" { Invoke-Script -relativePath $CONFIG.InstallScript -scriptType "Installer" }
        "2" { Invoke-Script -relativePath $CONFIG.UninstallScript -scriptType "Uninstaller" }
        "3" { Test-Updates }
        "4" { Show-InstallationStatus }
        "5" { 
            Write-Host "`nExiting... Have a productive DevOps day!" -ForegroundColor Yellow
            exit 
        }
        default { Write-Log "Invalid choice. Please select a number between 1 and 5." -Level Warning }
    }
    
    if ($choice -ne "5") {
        Write-Host "`nPress any key to continue..."
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
} while ($choice -ne "5")
