# WinAFL Setup Script for Windows
# This script sets up the WinAFL fuzzing environment on Windows
# Run with: PowerShell -ExecutionPolicy Bypass -File setup_winafl.ps1

param(
    [string]$DynamoRIOVersion = "9.0.1",
    [string]$InstallDir = "C:\fuzzing"
)

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "   WinAFL Setup Script" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Check for Administrator privileges
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] This script requires Administrator privileges" -ForegroundColor Red
    Write-Host "[*] Please run PowerShell as Administrator and try again" -ForegroundColor Yellow
    exit 1
}

# Create installation directory
Write-Host "[*] Creating installation directory: $InstallDir" -ForegroundColor Green
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

# Set up directory structure
$winaflDir = Join-Path $InstallDir "winafl"
$dynamorioDir = Join-Path $InstallDir "DynamoRIO"
$inputDir = Join-Path $InstallDir "input"
$outputDir = Join-Path $InstallDir "output"

Write-Host "[*] Creating directory structure..." -ForegroundColor Green
@($winaflDir, $dynamorioDir, $inputDir, $outputDir) | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }
}

# Download DynamoRIO
Write-Host "[*] Downloading DynamoRIO $DynamoRIOVersion..." -ForegroundColor Green
$dynamorioUrl = "https://github.com/DynamoRIO/dynamorio/releases/download/release_$DynamoRIOVersion/DynamoRIO-Windows-$DynamoRIOVersion.zip"
$dynamorioZip = Join-Path $InstallDir "DynamoRIO.zip"

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $dynamorioUrl -OutFile $dynamorioZip -UseBasicParsing
    Write-Host "[+] Downloaded DynamoRIO successfully" -ForegroundColor Green

    # Extract DynamoRIO
    Write-Host "[*] Extracting DynamoRIO..." -ForegroundColor Green
    Expand-Archive -Path $dynamorioZip -DestinationPath $InstallDir -Force

    # Find and rename the extracted directory
    $extractedDir = Get-ChildItem -Path $InstallDir -Directory | Where-Object { $_.Name -like "DynamoRIO*" } | Select-Object -First 1
    if ($extractedDir) {
        if (Test-Path $dynamorioDir) {
            Remove-Item -Path $dynamorioDir -Recurse -Force
        }
        Move-Item -Path $extractedDir.FullName -Destination $dynamorioDir
    }

    Remove-Item -Path $dynamorioZip -Force
    Write-Host "[+] DynamoRIO extracted successfully" -ForegroundColor Green
} catch {
    Write-Host "[!] Failed to download DynamoRIO: $_" -ForegroundColor Red
    Write-Host "[*] Please download manually from: $dynamorioUrl" -ForegroundColor Yellow
}

# Copy WinAFL binaries
Write-Host "[*] Setting up WinAFL binaries..." -ForegroundColor Green
$currentDir = Get-Location

# Detect architecture
$arch = if ([Environment]::Is64BitOperatingSystem) { "64" } else { "32" }
Write-Host "[*] Detected architecture: $arch-bit" -ForegroundColor Green

# Copy binaries from the repository
$binSource = Join-Path $currentDir "bin$arch"
if (Test-Path $binSource) {
    Copy-Item -Path "$binSource\*" -Destination $winaflDir -Recurse -Force
    Write-Host "[+] Copied WinAFL binaries" -ForegroundColor Green
} else {
    Write-Host "[!] Binary directory not found: $binSource" -ForegroundColor Red
    Write-Host "[*] You may need to build WinAFL from source" -ForegroundColor Yellow
}

# Create sample input files
Write-Host "[*] Creating sample input files..." -ForegroundColor Green
$sampleFile = Join-Path $inputDir "sample.txt"
"Test input file for fuzzing" | Out-File -FilePath $sampleFile -Encoding ASCII

$sampleBmp = Join-Path $inputDir "sample.bmp"
$bmpHeader = [byte[]](0x42, 0x4D, 0x46, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x36, 0x00, 0x00, 0x00, 0x28, 0x00)
[System.IO.File]::WriteAllBytes($sampleBmp, $bmpHeader)

Write-Host "[+] Created sample input files" -ForegroundColor Green

# Add to PATH
Write-Host "[*] Updating environment variables..." -ForegroundColor Green
$paths = @($winaflDir, (Join-Path $dynamorioDir "bin$arch"))
$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")

foreach ($path in $paths) {
    if ($currentPath -notlike "*$path*") {
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$path", "Machine")
        Write-Host "[+] Added $path to PATH" -ForegroundColor Green
    }
}

# Create environment variables
[Environment]::SetEnvironmentVariable("WINAFL_DIR", $winaflDir, "Machine")
[Environment]::SetEnvironmentVariable("DYNAMORIO_DIR", $dynamorioDir, "Machine")
[Environment]::SetEnvironmentVariable("FUZZING_DIR", $InstallDir, "Machine")

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "   Setup Complete!" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Installation directories:" -ForegroundColor Green
Write-Host "  WinAFL:     $winaflDir" -ForegroundColor White
Write-Host "  DynamoRIO:  $dynamorioDir" -ForegroundColor White
Write-Host "  Input:      $inputDir" -ForegroundColor White
Write-Host "  Output:     $outputDir" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Restart your PowerShell session to apply PATH changes" -ForegroundColor White
Write-Host "  2. Use fuzz_target.ps1 to start fuzzing" -ForegroundColor White
Write-Host "  3. Review VULNERABILITY_HUNTING_GUIDE.md for detailed instructions" -ForegroundColor White
Write-Host ""
Write-Host "Note: You may need to restart your computer for all changes to take effect" -ForegroundColor Yellow
