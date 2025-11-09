# WinAFL Fuzzing Script
# This script helps configure and launch fuzzing campaigns against Windows targets
# Run with: PowerShell -ExecutionPolicy Bypass -File fuzz_target.ps1

param(
    [Parameter(Mandatory=$false)]
    [string]$TargetExe = "",

    [Parameter(Mandatory=$false)]
    [string]$TargetModule = "",

    [Parameter(Mandatory=$false)]
    [string]$TargetMethod = "",

    [Parameter(Mandatory=$false)]
    [string]$TargetOffset = "0x0",

    [Parameter(Mandatory=$false)]
    [string]$CoverageModule = "",

    [Parameter(Mandatory=$false)]
    [string]$InputDir = "C:\fuzzing\input",

    [Parameter(Mandatory=$false)]
    [string]$OutputDir = "C:\fuzzing\output",

    [Parameter(Mandatory=$false)]
    [int]$Timeout = 20000,

    [Parameter(Mandatory=$false)]
    [int]$Iterations = 5000,

    [Parameter(Mandatory=$false)]
    [int]$NumArgs = 2,

    [Parameter(Mandatory=$false)]
    [string]$DynamoRIODir = "C:\fuzzing\DynamoRIO",

    [Parameter(Mandatory=$false)]
    [string]$WinAFLDir = "C:\fuzzing\winafl",

    [Parameter(Mandatory=$false)]
    [switch]$Debug,

    [Parameter(Mandatory=$false)]
    [switch]$DryRun,

    [Parameter(Mandatory=$false)]
    [ValidateSet("bb", "edge")]
    [string]$CoverageType = "edge"
)

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "   WinAFL Fuzzing Script" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Common Microsoft targets and their configurations
$commonTargets = @{
    "notepad" = @{
        exe = "C:\Windows\System32\notepad.exe"
        module = "notepad.exe"
        method = ""
        offset = "0x0"
        coverage = "notepad.exe"
        args = 1
        cmdline = "notepad.exe @@"
    }
    "wordpad" = @{
        exe = "C:\Program Files\Windows NT\Accessories\wordpad.exe"
        module = "riched20.dll"
        method = ""
        offset = "0x0"
        coverage = "riched20.dll"
        args = 2
        cmdline = "wordpad.exe @@"
    }
    "mspaint" = @{
        exe = "C:\Windows\System32\mspaint.exe"
        module = "gdiplus.dll"
        method = ""
        offset = "0x0"
        coverage = "gdiplus.dll"
        args = 2
        cmdline = "mspaint.exe @@"
    }
    "ie" = @{
        exe = "C:\Program Files\Internet Explorer\iexplore.exe"
        module = "mshtml.dll"
        method = ""
        offset = "0x0"
        coverage = "mshtml.dll"
        args = 2
        cmdline = "iexplore.exe @@"
    }
}

# Interactive mode if no target specified
if (-not $TargetExe) {
    Write-Host "Available common Microsoft targets:" -ForegroundColor Yellow
    Write-Host ""
    $i = 1
    foreach ($key in $commonTargets.Keys) {
        Write-Host "  $i. $key - $($commonTargets[$key].exe)" -ForegroundColor White
        $i++
    }
    Write-Host "  $i. Custom target" -ForegroundColor White
    Write-Host ""

    $choice = Read-Host "Select target (1-$i)"

    $targetKeys = $commonTargets.Keys | Sort-Object
    if ([int]$choice -le $targetKeys.Count) {
        $selectedKey = $targetKeys[[int]$choice - 1]
        $target = $commonTargets[$selectedKey]

        $TargetExe = $target.exe
        $TargetModule = $target.module
        $TargetMethod = $target.method
        $TargetOffset = $target.offset
        $CoverageModule = $target.coverage
        $NumArgs = $target.args

        Write-Host "[+] Selected: $selectedKey" -ForegroundColor Green
    } else {
        Write-Host "[*] Custom target selected" -ForegroundColor Yellow
        $TargetExe = Read-Host "Enter target executable path"
        $TargetModule = Read-Host "Enter target module name"
        $TargetMethod = Read-Host "Enter target method name (or press Enter to use offset)"

        if (-not $TargetMethod) {
            $TargetOffset = Read-Host "Enter target offset (e.g., 0x1270)"
        }

        $CoverageModule = Read-Host "Enter coverage module(s) (comma-separated)"
        $NumArgs = Read-Host "Enter number of arguments to fuzz function"
    }
}

# Validate inputs
if (-not (Test-Path $TargetExe)) {
    Write-Host "[!] Error: Target executable not found: $TargetExe" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $InputDir)) {
    Write-Host "[!] Error: Input directory not found: $InputDir" -ForegroundColor Red
    Write-Host "[*] Creating input directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $InputDir -Force | Out-Null
}

if (-not (Test-Path $OutputDir)) {
    Write-Host "[*] Creating output directory: $OutputDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Detect architecture
$is64Bit = $false
try {
    $peHeader = [System.IO.File]::ReadAllBytes($TargetExe)[0x3C..0x3D]
    $peOffset = [BitConverter]::ToUInt16($peHeader, 0)
    $machineType = [System.IO.File]::ReadAllBytes($TargetExe)[($peOffset + 4)..($peOffset + 5)]
    $machine = [BitConverter]::ToUInt16($machineType, 0)
    $is64Bit = ($machine -eq 0x8664)
} catch {
    Write-Host "[!] Warning: Could not detect target architecture, assuming 64-bit" -ForegroundColor Yellow
    $is64Bit = $true
}

$arch = if ($is64Bit) { "64" } else { "32" }
Write-Host "[*] Target architecture: $arch-bit" -ForegroundColor Green

# Set paths based on architecture
$drrunExe = Join-Path $DynamoRIODir "bin$arch\drrun.exe"
$winaflDll = Join-Path $WinAFLDir "winafl.dll"
$aflFuzzExe = Join-Path $WinAFLDir "afl-fuzz.exe"

# Verify required files
$requiredFiles = @($drrunExe, $winaflDll, $aflFuzzExe)
foreach ($file in $requiredFiles) {
    if (-not (Test-Path $file)) {
        Write-Host "[!] Error: Required file not found: $file" -ForegroundColor Red
        Write-Host "[*] Please run setup_winafl.ps1 first" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host ""
Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  Target:            $TargetExe" -ForegroundColor White
Write-Host "  Target Module:     $TargetModule" -ForegroundColor White
Write-Host "  Target Method:     $TargetMethod" -ForegroundColor White
Write-Host "  Target Offset:     $TargetOffset" -ForegroundColor White
Write-Host "  Coverage Module:   $CoverageModule" -ForegroundColor White
Write-Host "  Coverage Type:     $CoverageType" -ForegroundColor White
Write-Host "  Input Directory:   $InputDir" -ForegroundColor White
Write-Host "  Output Directory:  $OutputDir" -ForegroundColor White
Write-Host "  Timeout:           $Timeout ms" -ForegroundColor White
Write-Host "  Iterations:        $Iterations" -ForegroundColor White
Write-Host "  Architecture:      $arch-bit" -ForegroundColor White
Write-Host ""

# Step 1: Debug mode to verify setup
if ($Debug -or $DryRun) {
    Write-Host "[*] Running in debug mode to verify configuration..." -ForegroundColor Yellow
    Write-Host ""

    $debugArgs = @(
        "-c", $winaflDll,
        "-debug",
        "-target_module", $TargetModule,
        "-fuzz_iterations", "10",
        "-nargs", $NumArgs,
        "-covtype", $CoverageType
    )

    if ($TargetMethod) {
        $debugArgs += @("-target_method", $TargetMethod)
    } else {
        $debugArgs += @("-target_offset", $TargetOffset)
    }

    if ($CoverageModule) {
        $modules = $CoverageModule -split ","
        foreach ($mod in $modules) {
            $debugArgs += @("-coverage_module", $mod.Trim())
        }
    }

    $debugArgs += @("--", $TargetExe, (Join-Path $InputDir "sample.txt"))

    $debugCmd = "& `"$drrunExe`" $($debugArgs -join ' ')"
    Write-Host "Debug command:" -ForegroundColor Cyan
    Write-Host $debugCmd -ForegroundColor Gray
    Write-Host ""

    if ($DryRun) {
        Write-Host "[*] Dry run mode - not executing" -ForegroundColor Yellow
        exit 0
    }

    & $drrunExe @debugArgs

    Write-Host ""
    Write-Host "[*] Debug mode completed. Check the .log file in the current directory" -ForegroundColor Green
    Write-Host "[*] If the target ran correctly, you can start fuzzing" -ForegroundColor Yellow

    $continue = Read-Host "Continue to fuzzing? (y/n)"
    if ($continue -ne "y") {
        exit 0
    }
}

# Step 2: Start fuzzing
Write-Host ""
Write-Host "[*] Starting fuzzing campaign..." -ForegroundColor Green
Write-Host "[*] Press Ctrl+C to stop fuzzing" -ForegroundColor Yellow
Write-Host ""

$fuzzArgs = @(
    "-i", $InputDir,
    "-o", $OutputDir,
    "-D", (Join-Path $DynamoRIODir "bin$arch"),
    "-t", $Timeout,
    "--"
)

# Add instrumentation options
$instrArgs = @(
    "-covtype", $CoverageType,
    "-fuzz_iterations", $Iterations,
    "-target_module", $TargetModule,
    "-nargs", $NumArgs
)

if ($TargetMethod) {
    $instrArgs += @("-target_method", $TargetMethod)
} else {
    $instrArgs += @("-target_offset", $TargetOffset)
}

if ($CoverageModule) {
    $modules = $CoverageModule -split ","
    foreach ($mod in $modules) {
        $instrArgs += @("-coverage_module", $mod.Trim())
    }
}

# Combine all arguments
$allArgs = $fuzzArgs + $instrArgs + @("--", $TargetExe, "@@")

$fuzzCmd = "& `"$aflFuzzExe`" $($allArgs -join ' ')"
Write-Host "Fuzzing command:" -ForegroundColor Cyan
Write-Host $fuzzCmd -ForegroundColor Gray
Write-Host ""

# Create a timestamp for this fuzzing session
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$sessionLog = Join-Path $OutputDir "session_$timestamp.log"

Write-Host "[*] Session log: $sessionLog" -ForegroundColor Green
Write-Host ""

# Start fuzzing
try {
    & $aflFuzzExe @allArgs 2>&1 | Tee-Object -FilePath $sessionLog
} catch {
    Write-Host ""
    Write-Host "[!] Fuzzing stopped: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "   Fuzzing Session Ended" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Results saved to: $OutputDir" -ForegroundColor Green
Write-Host "Use analyze_crashes.ps1 to analyze any crashes found" -ForegroundColor Yellow
