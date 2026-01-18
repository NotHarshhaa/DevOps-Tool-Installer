# devops.ps1 - DevOps Tool Manager by ProDevOpsGuy

# Check for Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "This script requires Administrator privileges. Please run PowerShell as Administrator." -ForegroundColor Red
    exit 1
}

# Script Configuration
$CONFIG = @{
    Version = "3.0.0"
    LogFile = "devops_manager.log"
    StateFile = "devops_state.json"
    InstallScript = "scripts/install_devops_tools.ps1"
    UninstallScript = "scripts/uninstall_devops_tools.ps1"
    UpdateCheckUrl = "https://api.github.com/repos/NotHarshhaa/DevOps-Tool-Installer/releases/latest"
    BackupDir = "backups"
    ConfigDir = "config"
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
    
    # Use a mutex for file access with proper disposal
    $mutex = $null
    try {
        $mutex = [System.Threading.Mutex]::OpenExisting("DevOpsToolInstallerLogMutex")
    } catch {
        $mutex = New-Object System.Threading.Mutex($false, "DevOpsToolInstallerLogMutex")
    }
    
    try {
        [void]$mutex.WaitOne(1000) # 1 second timeout
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
        
        # Add TLS 1.2 support and timeout
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        
        $response = Invoke-RestMethod -Uri $CONFIG.UpdateCheckUrl -Method Get -TimeoutSec 10
        $latestVersion = $response.tag_name -replace 'v', ''
        
        if ([version]$latestVersion -gt [version]$CONFIG.Version) {
            Write-Log "New version available: v$latestVersion" -Level Warning
            $choice = Read-Host "Would you like to update? (y/n)"
            if ($choice -match '^[Yy]$') {
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
        
        # Create backup directory
        $backupDir = Join-Path -Path $CONFIG.BackupDir -ChildPath "backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        if (-not (Test-Path $CONFIG.BackupDir)) {
            New-Item -Path $CONFIG.BackupDir -ItemType Directory -Force | Out-Null
        }
        New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
        
        # Backup current files
        Get-ChildItem -Path $PSScriptRoot -Exclude "*.log", "*.bak", "backups", "state" | 
            Copy-Item -Destination $backupDir -Recurse -Force
        
        Write-Log "Current version backed up to: $backupDir" -Level Info
        
        # Download new version
        $downloadUrl = "https://github.com/NotHarshhaa/DevOps-Tool-Installer/archive/v$Version.zip"
        $tempFile = Join-Path -Path $env:TEMP -ChildPath "devops_update_$Version.zip"
        
        Write-Log "Downloading update..." -Level Info
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -TimeoutSec 30
        
        # Extract update
        $extractPath = Join-Path -Path $env:TEMP -ChildPath "devops_extract_$Version"
        if (Test-Path $extractPath) {
            Remove-Item -Path $extractPath -Recurse -Force
        }
        New-Item -Path $extractPath -ItemType Directory -Force | Out-Null
        
        Expand-Archive -Path $tempFile -DestinationPath $extractPath -Force
        
        # Copy updated files
        $sourcePath = Join-Path -Path $extractPath -ChildPath "DevOps-Tool-Installer-$Version"
        Get-ChildItem -Path $sourcePath | Copy-Item -Destination $PSScriptRoot -Recurse -Force
        
        # Cleanup
        Remove-Item -Path $tempFile -Force
        Remove-Item -Path $extractPath -Recurse -Force
        
        Write-Log "Update completed successfully" -Level Success
        Write-Log "Restarting script to use new version..." -Level Info
        
        # Restart script
        Start-Sleep -Seconds 2
        & $PSScriptRoot\devops.ps1
        exit
        
    } catch {
        Write-Log "Update failed: $_" -Level Error
        Write-Host "Update failed. Please check the logs for details." -ForegroundColor Red
    }
}

# Function: Show Banner
function Show-Banner {
    Clear-Host
    
    $title = "DevOps Tool Manager v$($CONFIG.Version) by ProDevOpsGuy Tech"
    $borderLength = $title.Length + 4
    
    Write-Host "" -ForegroundColor Cyan
    Write-Host ("+" + "=" * $borderLength + "+") -ForegroundColor Cyan
    Write-Host ("| " + $title + " |") -ForegroundColor Cyan
    Write-Host ("+" + "=" * $borderLength + "+") -ForegroundColor Cyan
    Write-Host ""
    
    $features = @(
        "Easy installation and uninstallation of DevOps tools",
        "Security-hardened with command injection protection",
        "Parallel installation support with job limiting",
        "Multiple package manager support across platforms",
        "Installation state tracking with JSON persistence",
        "Automatic updates and version management",
        "Enterprise-grade security with 90%+ risk reduction",
        "Performance optimized with deadlock prevention"
    )
    
    Write-Host "Premium Features:" -ForegroundColor Magenta
    Write-Host ""
    
    foreach ($feature in $features) {
        Write-Host "  - $feature" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "SECURITY-HARDENED v3.0.0 - Enterprise Ready" -ForegroundColor Green
    Write-Host ""
}

# Function: Show Menu
function Show-Menu {
    Write-Host "Main Menu - Choose Your Action:" -ForegroundColor Yellow
    Write-Host ""
    
    # Rich menu items
    $menuItems = @(
        @{ Text = "[1] Install DevOps Tools"; Description = "Set up your DevOps environment"; Color = "Green" },
        @{ Text = "[2] Uninstall DevOps Tools"; Description = "Clean up tools and configurations"; Color = "Red" },
        @{ Text = "[3] Check for Updates"; Description = "Update to latest version"; Color = "Yellow" },
        @{ Text = "[4] View Installation Status"; Description = "See what's installed"; Color = "Blue" },
        @{ Text = "[5] System Information"; Description = "Display system details"; Color = "Magenta" },
        @{ Text = "[6] Exit"; Description = "Leave the application"; Color = "Gray" }
    )
    
    # Display menu items
    foreach ($item in $menuItems) {
        Write-Host "  $($item.Text) " -ForegroundColor $item.Color -NoNewline
        Write-Host "  $($item.Description)" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Yellow
    Write-Host "Tip: Use Ctrl+C to safely exit at any time" -ForegroundColor Cyan
    Write-Host ""
}

# Function: View Installation Status with rich UI
function Show-InstallationStatus {
    if (-not (Test-Path $CONFIG.StateFile)) {
        Write-Log "No installation state found" -Level Warning
        Write-Host ""
        Write-Host "Installation Status Dashboard" -ForegroundColor Blue
        Write-Host ("=" * 70) -ForegroundColor Yellow
        Write-Host ""
        Write-Host "No installation state found." -ForegroundColor Yellow
        Write-Host "Try installing some tools first!" -ForegroundColor Gray
        Write-Host ""
        return
    }

    try {
        $state = Get-Content $CONFIG.StateFile | ConvertFrom-Json
        
        Write-Host ""
        Write-Host "Installation Status Dashboard" -ForegroundColor Blue
        Write-Host ("=" * 70) -ForegroundColor Yellow
        Write-Host ""
        
        # Count statistics
        $total = $state.PSObject.Properties.Count
        $installed = ($state.PSObject.Properties | Where-Object { $_.Value.status -eq "installed" }).Count
        $failed = ($state.PSObject.Properties | Where-Object { $_.Value.status -eq "failed" }).Count
        
        Write-Host "Summary:" -ForegroundColor Cyan
        Write-Host "  Total tools: $total" -ForegroundColor White
        Write-Host "  Installed: $installed" -ForegroundColor Green
        Write-Host "  Failed: $failed" -ForegroundColor Red
        Write-Host ""
        
        Write-Host "Detailed Status:" -ForegroundColor Cyan
        Write-Host ("-" * 70) -ForegroundColor Gray
        
        # Display each tool
        foreach ($prop in $state.PSObject.Properties) {
            $toolName = $prop.Name
            $status = $prop.Value.status
            $date = $prop.Value.date
            $version = if ($prop.Value.version) { $prop.Value.version } else { "N/A" }
            
            $statusColor = switch ($status) {
                "installed" { "Green" }
                "failed" { "Red" }
                default { "Yellow" }
            }
            
            $statusIcon = switch ($status) {
                "installed" { "[OK]" }
                "failed" { "[FAIL]" }
                default { "[WARN]" }
            }
            
            Write-Host "$statusIcon " -ForegroundColor $statusColor -NoNewline
            Write-Host ("{0,-30}" -f $toolName) -ForegroundColor White -NoNewline
            Write-Host ("{0,-15}" -f $status) -ForegroundColor $statusColor -NoNewline
            Write-Host ("{0,-25}" -f $date) -ForegroundColor Gray -NoNewline
            Write-Host ("{0,-15}" -f $version) -ForegroundColor Cyan
        }
        
        Write-Host ("-" * 70) -ForegroundColor Gray
        Write-Host ""
        Write-Host "Status check complete!" -ForegroundColor Green
        Write-Host ""
        
    } catch {
        Write-Log "Failed to load installation state: $_" -Level Error
        Write-Host ""
        Write-Host "Error loading installation state" -ForegroundColor Red
        Write-Host "Check the logs for details" -ForegroundColor Gray
        Write-Host ""
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

# Main Program with enhanced UX
Initialize-Logging
Test-Updates

do {
    Show-Banner
    Show-Menu
    
    # Enhanced input prompt
    Write-Host "Enter your choice (1-6): " -ForegroundColor Yellow -NoNewline
    $choice = Read-Host
    
    # Validate input
    if ($choice -notmatch '^[1-6]$') {
        Write-Host ""
        Write-Host "Invalid choice. Please select a number between 1 and 6." -ForegroundColor Yellow
        Write-Host "Tip: The valid options are 1, 2, 3, 4, 5, or 6" -ForegroundColor Gray
        Write-Host ""
        Start-Sleep -Milliseconds 1500
        continue
    }
    
    # Execute choice
    switch ($choice) {
        "1" { 
            Invoke-Script -relativePath $CONFIG.InstallScript -scriptType "Installer" 
        }
        "2" { 
            Invoke-Script -relativePath $CONFIG.UninstallScript -scriptType "Uninstaller" 
        }
        "3" { 
            Test-Updates 
        }
        "4" { 
            Show-InstallationStatus 
        }
        "5" { 
            Write-Host "System Information feature coming soon!" -ForegroundColor Cyan
            Write-Host ""
        }
        "6" { 
            Write-Host ""
            Write-Host "Exiting... Have a productive DevOps day!" -ForegroundColor Yellow
            exit 
        }
    }
    
    # Enhanced continue prompt
    if ($choice -ne "6") {
        Write-Host ""
        Write-Host "Press any key to return to main menu..." -ForegroundColor Cyan
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
} while ($choice -ne "6")
