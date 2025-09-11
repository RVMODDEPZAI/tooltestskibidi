# ========================================================
#     PC MANAGER BOT - ONE-CLICK INSTALLER & RUNNER
# ========================================================
# Usage: powershell -ExecutionPolicy Bypass -File setup-bot.ps1
# Or:    iex (irm https://your-github-raw-link/setup-bot.ps1)

param(
    [switch]$Uninstall,
    [switch]$Start,
    [switch]$Stop,
    [switch]$Status,
    [string]$InstallPath = "C:\PCManagerBot"
)

# Colors and UI
$Host.UI.RawUI.WindowTitle = "PC Manager Bot - One-Click Setup"
function Write-ColorText($Text, $Color = "White") { Write-Host $Text -ForegroundColor $Color }
function Write-Header($Title) { 
    Write-Host ""; Write-ColorText "═══════════════════════════════════════════════════════" "Cyan"
    Write-ColorText "                    $Title" "Yellow"
    Write-ColorText "═══════════════════════════════════════════════════════" "Cyan"; Write-Host ""
}

# Check Admin Rights
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-AdminRights {
    if (-not (Test-Administrator)) {
        Write-ColorText "⚠️  Cần quyền Administrator!" "Yellow"
        Write-ColorText "🔄 Restarting with Admin rights..." "Cyan"
        try {
            $args = $PSBoundParameters.GetEnumerator() | ForEach-Object { "-$($_.Key)" }
            Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`" $args" -Verb RunAs
            exit 0
        } catch {
            Write-ColorText "❌ Cannot get Admin rights! Run manually as Administrator." "Red"
            Read-Host "Press Enter to exit"; exit 1
        }
    }
}

# Main Functions
function Show-Menu {
    Write-Header "PC MANAGER BOT - ONE-CLICK SETUP"
    Write-ColorText "✅ Running with Administrator privileges!" "Green"
    Write-Host ""
    Write-ColorText "📊 SYSTEM INFO:" "Cyan"
    Write-ColorText "   💻 OS: $env:OS" "White"
    Write-ColorText "   👤 User: $env:USERNAME" "White"
    Write-ColorText "   🖥️  Computer: $env:COMPUTERNAME" "White"
    Write-ColorText "   📁 Install Path: $InstallPath" "White"
    Write-Host ""
    
    $service = Get-Service -Name "PCManagerBot" -ErrorAction SilentlyContinue
    if ($service) {
        $status = if ($service.Status -eq "Running") { "🟢 RUNNING" } else { "🔴 STOPPED" }
        Write-ColorText "🤖 Bot Status: $status" "Green"
    } else {
        Write-ColorText "🤖 Bot Status: 🔘 NOT INSTALLED" "Yellow"
    }
    Write-Host ""
    
    Write-ColorText "🎯 AVAILABLE ACTIONS:" "Yellow"
    Write-ColorText "   1️⃣  Install Bot (Auto download + setup service)" "White"
    Write-ColorText "   2️⃣  Start Bot Service" "White" 
    Write-ColorText "   3️⃣  Stop Bot Service" "White"
    Write-ColorText "   4️⃣  Check Status" "White"
    Write-ColorText "   5️⃣  Uninstall Bot (Complete removal)" "White"
    Write-ColorText "   0️⃣  Exit" "White"
    Write-Host ""
    
    $choice = Read-Host "Select option (0-5)"
    return $choice
}

function Install-Bot {
    Write-Header "INSTALLING PC MANAGER BOT"
    
    $downloadUrl = "https://github.com/RVMODDEPZAI/tooltestskibidi/raw/refs/heads/main/toolskibidi.zip"
    $zipFile = "$env:TEMP\toolskibidi.zip"
    $serviceName = "PCManagerBot"
    
    Write-ColorText "🎯 INSTALLATION CONFIG:" "Yellow"
    Write-ColorText "   📁 Install Path: $InstallPath" "White"
    Write-ColorText "   🌐 Download URL: $downloadUrl" "White"
    Write-ColorText "   🔧 Service Name: $serviceName" "White"
    Write-Host ""
    
    # Create install directory
    Write-ColorText "📁 Creating install directory..." "Cyan"
    try {
        if (Test-Path $InstallPath) {
            Write-ColorText "⚠️  Directory exists, cleaning..." "Yellow"
            Remove-Item -Path $InstallPath -Recurse -Force
        }
        New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
        Write-ColorText "✅ Created: $InstallPath" "Green"
    } catch {
        Write-ColorText "❌ Failed to create directory: $($_.Exception.Message)" "Red"
        return $false
    }
    
    # Download file
    Write-ColorText "⬇️  Downloading bot from GitHub..." "Cyan"
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $webClient = New-Object System.Net.WebClient
        
        # Add progress callback
        $webClient.DownloadProgressChanged += {
            $percent = $_.ProgressPercentage
            Write-Progress -Activity "Downloading toolskibidi.zip" -Status "$percent% Complete" -PercentComplete $percent
        }
        
        $webClient.DownloadFileAsync($downloadUrl, $zipFile)
        while ($webClient.IsBusy) { Start-Sleep -Milliseconds 100 }
        
        $fileSize = (Get-Item $zipFile).Length / 1MB
        Write-ColorText "✅ Downloaded: $([math]::Round($fileSize, 2)) MB" "Green"
        Write-Progress -Activity "Downloading" -Completed
    } catch {
        Write-ColorText "❌ Download failed: $($_.Exception.Message)" "Red"
        Write-ColorText "🔧 Check Internet connection and try again" "Yellow"
        return $false
    }
    
    # Extract
    Write-ColorText "📦 Extracting files..." "Cyan"
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile, $InstallPath)
        Remove-Item $zipFile -Force
        Write-ColorText "✅ Extraction complete" "Green"
    } catch {
        Write-ColorText "❌ Extraction failed: $($_.Exception.Message)" "Red"
        return $false
    }
    
    # Find bot exe and nssm
    $botExe = Get-ChildItem -Path $InstallPath -Filter "*.exe" -Recurse | Where-Object { 
        $_.Name -like "*bot*" -or $_.Name -like "*pc-manager*" -or $_.Name -like "*manager*" 
    } | Select-Object -First 1
    
    $nssmExe = Get-ChildItem -Path $InstallPath -Filter "nssm.exe" -Recurse | Select-Object -First 1
    
    # Download NSSM if not found
    if (-not $nssmExe) {
        Write-ColorText "🔧 NSSM not found, downloading..." "Cyan"
        try {
            $nssmUrl = "https://nssm.cc/release/nssm-2.24.zip"
            $nssmZip = "$env:TEMP\nssm.zip"
            $nssmTemp = "$env:TEMP\nssm_extract"
            
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($nssmUrl, $nssmZip)
            
            if (Test-Path $nssmTemp) { Remove-Item $nssmTemp -Recurse -Force }
            [System.IO.Compression.ZipFile]::ExtractToDirectory($nssmZip, $nssmTemp)
            
            $nssmSource = Get-ChildItem -Path $nssmTemp -Filter "nssm.exe" -Recurse | Where-Object { $_.Directory.Name -eq "win64" } | Select-Object -First 1
            if (-not $nssmSource) { $nssmSource = Get-ChildItem -Path $nssmTemp -Filter "nssm.exe" -Recurse | Select-Object -First 1 }
            
            if ($nssmSource) {
                Copy-Item $nssmSource.FullName -Destination $InstallPath
                $nssmExe = Get-Item "$InstallPath\nssm.exe"
                Write-ColorText "✅ NSSM downloaded and installed" "Green"
            }
            
            Remove-Item $nssmZip -Force -ErrorAction SilentlyContinue
            Remove-Item $nssmTemp -Recurse -Force -ErrorAction SilentlyContinue
        } catch {
            Write-ColorText "❌ NSSM download failed: $($_.Exception.Message)" "Red"
            return $false
        }
    }
    
    if (-not $botExe) {
        Write-ColorText "❌ Bot executable not found!" "Red"
        Write-ColorText "📂 Available exe files:" "Yellow"
        Get-ChildItem -Path $InstallPath -Filter "*.exe" -Recurse | ForEach-Object {
            Write-ColorText "   📄 $($_.Name)" "White"
        }
        return $false
    }
    
    Write-ColorText "🎯 FOUND FILES:" "Green"
    Write-ColorText "   🤖 Bot: $($botExe.Name)" "White"
    Write-ColorText "   🔧 NSSM: $($nssmExe.Name)" "White"
    Write-Host ""
    
    # Remove existing service
    $existingService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($existingService) {
        Write-ColorText "🛑 Removing existing service..." "Yellow"
        try {
            Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
            & $nssmExe.FullName remove $serviceName confirm 2>$null
            Start-Sleep -Seconds 2
        } catch {}
    }
    
    # Install service
    Write-ColorText "🔧 Installing Windows Service..." "Cyan"
    try {
        & $nssmExe.FullName install $serviceName $botExe.FullName
        & $nssmExe.FullName set $serviceName Description "PC Manager Bot - Telegram Bot for Windows Management with full CMD/PowerShell access"
        & $nssmExe.FullName set $serviceName Start SERVICE_AUTO_START
        & $nssmExe.FullName set $serviceName AppDirectory $InstallPath
        & $nssmExe.FullName set $serviceName AppStdout "$InstallPath\bot-output.log"
        & $nssmExe.FullName set $InstallPath AppStderr "$InstallPath\bot-error.log"
        & $nssmExe.FullName set $serviceName AppStopMethodSkip 6
        & $nssmExe.FullName set $serviceName AppKillProcessTree 1
        
        Write-ColorText "✅ Service installed successfully!" "Green"
    } catch {
        Write-ColorText "❌ Service installation failed: $($_.Exception.Message)" "Red"
        return $false
    }
    
    # Start service
    Write-ColorText "🚀 Starting service..." "Cyan"
    try {
        Start-Service -Name $serviceName
        Start-Sleep -Seconds 3
        
        $service = Get-Service -Name $serviceName
        if ($service.Status -eq "Running") {
            Write-ColorText "✅ Service started successfully!" "Green"
        } else {
            Write-ColorText "⚠️  Service status: $($service.Status)" "Yellow"
        }
    } catch {
        Write-ColorText "❌ Failed to start service: $($_.Exception.Message)" "Red"
    }
    
    # Create management scripts
    Write-ColorText "📎 Creating management shortcuts..." "Cyan"
    try {
        $startScript = @"
@echo off
title Start PC Manager Bot
echo Starting PC Manager Bot Service...
net start $serviceName
if %errorlevel% equ 0 (
    echo ✅ Bot started successfully!
    echo 📱 Check Telegram to use the bot
) else (
    echo ❌ Failed to start bot
    echo 🔧 Check Windows Services for details
)
pause
"@
        
        $stopScript = @"
@echo off
title Stop PC Manager Bot  
echo Stopping PC Manager Bot Service...
net stop $serviceName
if %errorlevel% equ 0 (
    echo ✅ Bot stopped successfully!
) else (
    echo ❌ Failed to stop bot
)
pause
"@
        
        $statusScript = @"
@echo off
title PC Manager Bot Status
echo ════════════════════════════════════════════════════════
echo                PC MANAGER BOT - STATUS
echo ════════════════════════════════════════════════════════
echo.
sc query $serviceName
echo.
echo ════════════════════════════════════════════════════════
echo 📁 Install Path: $InstallPath
echo 🤖 Bot Executable: $($botExe.Name)
echo 📄 Output Log: $InstallPath\bot-output.log
echo 📄 Error Log: $InstallPath\bot-error.log
echo ════════════════════════════════════════════════════════
echo.
if exist "$InstallPath\bot-output.log" (
    echo 📄 Recent bot output:
    echo ────────────────────────────────────────────────────────
    type "$InstallPath\bot-output.log" 2>nul | more
)
pause
"@
        
        Set-Content -Path "$InstallPath\start-bot.bat" -Value $startScript -Encoding UTF8
        Set-Content -Path "$InstallPath\stop-bot.bat" -Value $stopScript -Encoding UTF8  
        Set-Content -Path "$InstallPath\status-bot.bat" -Value $statusScript -Encoding UTF8
        
        # Copy to desktop
        $desktop = [Environment]::GetFolderPath("Desktop")
        Copy-Item "$InstallPath\start-bot.bat" -Destination "$desktop\🚀 Start PC Manager Bot.bat" -ErrorAction SilentlyContinue
        Copy-Item "$InstallPath\stop-bot.bat" -Destination "$desktop\🛑 Stop PC Manager Bot.bat" -ErrorAction SilentlyContinue
        Copy-Item "$InstallPath\status-bot.bat" -Destination "$desktop\📊 PC Manager Bot Status.bat" -ErrorAction SilentlyContinue
        
        Write-ColorText "✅ Desktop shortcuts created" "Green"
    } catch {
        Write-ColorText "⚠️  Warning: Could not create shortcuts: $($_.Exception.Message)" "Yellow"
    }
    
    Write-Header "INSTALLATION COMPLETE"
    Write-ColorText "🎉 PC Manager Bot installed successfully!" "Green"
    Write-Host ""
    Write-ColorText "📂 Installation: $InstallPath" "Cyan"
    Write-ColorText "🔧 Service: $serviceName" "Cyan" 
    Write-ColorText "🤖 Executable: $($botExe.Name)" "Cyan"
    Write-Host ""
    Write-ColorText "🎯 USAGE:" "Yellow"
    Write-ColorText "   📱 Open Telegram bot and send: /start" "White"
    Write-ColorText "   🖥️  Use /cmd for Command Prompt access" "White"
    Write-ColorText "   💙 Use /powershell for PowerShell access" "White"
    Write-ColorText "   📊 Use /status to check bot status" "White"
    Write-Host ""
    Write-ColorText "🔧 MANAGEMENT:" "Yellow"
    Write-ColorText "   🚀 Start: Double-click '🚀 Start PC Manager Bot.bat' on Desktop" "White"
    Write-ColorText "   🛑 Stop: Double-click '🛑 Stop PC Manager Bot.bat' on Desktop" "White"
    Write-ColorText "   📊 Status: Double-click '📊 PC Manager Bot Status.bat' on Desktop" "White"
    Write-Host ""
    
    return $true
}

function Start-BotService {
    Write-Header "STARTING BOT SERVICE"
    try {
        $service = Get-Service -Name "PCManagerBot" -ErrorAction SilentlyContinue
        if (-not $service) {
            Write-ColorText "❌ Bot service not found! Install first." "Red"
            return
        }
        
        if ($service.Status -eq "Running") {
            Write-ColorText "ℹ️  Bot service is already running!" "Yellow"
            return
        }
        
        Write-ColorText "🚀 Starting PCManagerBot service..." "Cyan"
        Start-Service -Name "PCManagerBot"
        Start-Sleep -Seconds 2
        
        $service = Get-Service -Name "PCManagerBot"
        if ($service.Status -eq "Running") {
            Write-ColorText "✅ Bot service started successfully!" "Green"
            Write-ColorText "📱 Bot is now available on Telegram!" "Cyan"
        } else {
            Write-ColorText "❌ Failed to start service. Status: $($service.Status)" "Red"
        }
    } catch {
        Write-ColorText "❌ Error starting service: $($_.Exception.Message)" "Red"
    }
}

function Stop-BotService {
    Write-Header "STOPPING BOT SERVICE"
    try {
        $service = Get-Service -Name "PCManagerBot" -ErrorAction SilentlyContinue
        if (-not $service) {
            Write-ColorText "❌ Bot service not found!" "Red"
            return
        }
        
        if ($service.Status -eq "Stopped") {
            Write-ColorText "ℹ️  Bot service is already stopped!" "Yellow"
            return
        }
        
        Write-ColorText "🛑 Stopping PCManagerBot service..." "Cyan"
        Stop-Service -Name "PCManagerBot" -Force
        Start-Sleep -Seconds 2
        
        $service = Get-Service -Name "PCManagerBot"
        if ($service.Status -eq "Stopped") {
            Write-ColorText "✅ Bot service stopped successfully!" "Green"
        } else {
            Write-ColorText "⚠️  Service status: $($service.Status)" "Yellow"
        }
    } catch {
        Write-ColorText "❌ Error stopping service: $($_.Exception.Message)" "Red"
    }
}

function Show-BotStatus {
    Write-Header "BOT STATUS"
    
    $service = Get-Service -Name "PCManagerBot" -ErrorAction SilentlyContinue
    if ($service) {
        $statusIcon = if ($service.Status -eq "Running") { "🟢" } else { "🔴" }
        Write-ColorText "🤖 Service Status: $statusIcon $($service.Status)" "Green"
        Write-ColorText "🔧 Service Name: $($service.Name)" "Cyan"
        Write-ColorText "📄 Display Name: $($service.DisplayName)" "Cyan"
        Write-ColorText "🚀 Startup Type: $($service.StartType)" "Cyan"
    } else {
        Write-ColorText "❌ PCManagerBot service not found!" "Red"
        Write-ColorText "💡 Run installation first" "Yellow"
        return
    }
    
    Write-Host ""
    if (Test-Path $InstallPath) {
        Write-ColorText "📂 Installation Path: $InstallPath" "Cyan"
        
        $botExe = Get-ChildItem -Path $InstallPath -Filter "*.exe" -Recurse | Where-Object { 
            $_.Name -like "*bot*" -or $_.Name -like "*pc-manager*" 
        } | Select-Object -First 1
        
        if ($botExe) {
            Write-ColorText "🤖 Bot Executable: $($botExe.Name)" "Cyan"
            Write-ColorText "📏 File Size: $([math]::Round($botExe.Length / 1MB, 2)) MB" "Cyan"
        }
        
        # Show recent logs
        $logFile = "$InstallPath\bot-output.log"
        if (Test-Path $logFile) {
            Write-ColorText "📄 Recent bot output:" "Yellow"
            Write-ColorText "─────────────────────────────────────────" "Gray"
            Get-Content $logFile -Tail 10 | ForEach-Object { Write-ColorText "   $_" "White" }
        }
        
        $errorLog = "$InstallPath\bot-error.log"  
        if (Test-Path $errorLog) {
            $errorContent = Get-Content $errorLog -ErrorAction SilentlyContinue
            if ($errorContent) {
                Write-ColorText "⚠️  Recent errors:" "Red"
                Write-ColorText "─────────────────────────────────────────" "Gray"
                $errorContent | Select-Object -Last 5 | ForEach-Object { Write-ColorText "   $_" "Red" }
            }
        }
    }
    
    Write-Host ""
    Write-ColorText "💡 Bot Commands (Telegram):" "Yellow"
    Write-ColorText "   /start - Show main menu" "White"
    Write-ColorText "   /cmd - Open CMD terminal" "White"
    Write-ColorText "   /powershell - Open PowerShell terminal" "White"
    Write-ColorText "   /status - Check bot status" "White"
}

function Uninstall-Bot {
    Write-Header "UNINSTALLING PC MANAGER BOT"
    
    Write-ColorText "⚠️  This will completely remove PC Manager Bot!" "Red"
    $confirm = Read-Host "Type 'YES' to confirm uninstall"
    if ($confirm -ne "YES") {
        Write-ColorText "❌ Uninstall cancelled" "Yellow"
        return
    }
    
    # Stop and remove service
    Write-ColorText "🛑 Removing service..." "Cyan"
    try {
        $service = Get-Service -Name "PCManagerBot" -ErrorAction SilentlyContinue
        if ($service) {
            Stop-Service -Name "PCManagerBot" -Force -ErrorAction SilentlyContinue
            
            $nssmExe = Get-ChildItem -Path $InstallPath -Filter "nssm.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($nssmExe) {
                & $nssmExe.FullName remove "PCManagerBot" confirm 2>$null
            } else {
                sc.exe delete "PCManagerBot" 2>$null
            }
            Write-ColorText "✅ Service removed" "Green"
        }
    } catch {
        Write-ColorText "⚠️  Service removal warning: $($_.Exception.Message)" "Yellow"
    }
    
    # Remove installation directory
    Write-ColorText "📁 Removing installation directory..." "Cyan"
    try {
        if (Test-Path $InstallPath) {
            Remove-Item -Path $InstallPath -Recurse -Force
            Write-ColorText "✅ Directory removed: $InstallPath" "Green"
        }
    } catch {
        Write-ColorText "⚠️  Directory removal warning: $($_.Exception.Message)" "Yellow"
    }
    
    # Remove desktop shortcuts
    Write-ColorText "📎 Removing desktop shortcuts..." "Cyan"
    try {
        $desktop = [Environment]::GetFolderPath("Desktop")
        $shortcuts = @(
            "🚀 Start PC Manager Bot.bat",
            "🛑 Stop PC Manager Bot.bat", 
            "📊 PC Manager Bot Status.bat"
        )
        
        foreach ($shortcut in $shortcuts) {
            $path = "$desktop\$shortcut"
            if (Test-Path $path) {
                Remove-Item $path -Force
                Write-ColorText "   ✅ Removed: $shortcut" "Green"
            }
        }
    } catch {
        Write-ColorText "⚠️  Shortcut removal warning: $($_.Exception.Message)" "Yellow"
    }
    
    Write-ColorText "🎉 PC Manager Bot uninstalled successfully!" "Green"
}

# Main Execution
try {
    Request-AdminRights
    
    # Handle command line parameters
    if ($Uninstall) { Uninstall-Bot; return }
    if ($Start) { Start-BotService; return }
    if ($Stop) { Stop-BotService; return }
    if ($Status) { Show-BotStatus; return }
    
    # Interactive menu
    do {
        $choice = Show-Menu
        switch ($choice) {
            "1" { Install-Bot }
            "2" { Start-BotService }
            "3" { Stop-BotService }
            "4" { Show-BotStatus }
            "5" { Uninstall-Bot }
            "0" { Write-ColorText "👋 Goodbye!" "Cyan"; break }
            default { Write-ColorText "❌ Invalid choice!" "Red" }
        }
        if ($choice -ne "0") { 
            Write-Host ""
            Read-Host "Press Enter to continue" 
        }
    } while ($choice -ne "0")
    
} catch {
    Write-ColorText "❌ Unexpected error: $($_.Exception.Message)" "Red"
    Write-ColorText "📄 Stack trace: $($_.ScriptStackTrace)" "Gray"
} finally {
    Write-Host ""
    Write-ColorText "📞 Need help? Check:" "Yellow"
    Write-ColorText "   • Internet connection" "White"
    Write-ColorText "   • Administrator privileges" "White"  
    Write-ColorText "   • Windows Defender/Antivirus settings" "White"
}

# One-liner usage examples:
# Install: iex (irm https://raw.githubusercontent.com/your-repo/setup-bot.ps1)
# Start: powershell -ExecutionPolicy Bypass -Command "iex (irm https://raw.githubusercontent.com/your-repo/setup-bot.ps1)" -Start
# Status: powershell -ExecutionPolicy Bypass -Command "iex (irm https://raw.githubusercontent.com/your-repo/setup-bot.ps1)" -Status
