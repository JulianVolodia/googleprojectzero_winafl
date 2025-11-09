# WinAFL Fuzzing Deployment Script
# This script automates the entire fuzzing setup process for your own code
# Run with: PowerShell -ExecutionPolicy Bypass -File deploy_fuzzing.ps1

param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectPath = "",

    [Parameter(Mandatory=$false)]
    [string]$TargetExecutable = "",

    [Parameter(Mandatory=$false)]
    [string]$SourceFiles = "",

    [Parameter(Mandatory=$false)]
    [string]$OutputDir = "",

    [Parameter(Mandatory=$false)]
    [ValidateSet("source", "binary", "example")]
    [string]$Mode = "",

    [Parameter(Mandatory=$false)]
    [switch]$AutoBuild,

    [Parameter(Mandatory=$false)]
    [switch]$AutoFuzz,

    [Parameter(Mandatory=$false)]
    [switch]$Interactive
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  WinAFL Fuzzing Deployment Wizard" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# Helper Functions
# ============================================================================

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "[*] $Message" -ForegroundColor Green
}

function Write-Success {
    param([string]$Message)
    Write-Host "[+] $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "[!] $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "    $Message" -ForegroundColor White
}

function Test-Administrator {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Find-VisualStudio {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"

    if (Test-Path $vswhere) {
        $vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
        if ($vsPath) {
            return Join-Path $vsPath "VC\Auxiliary\Build\vcvarsall.bat"
        }
    }

    # Fallback: common locations
    $commonPaths = @(
        "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat",
        "C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvarsall.bat",
        "C:\Program Files\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvarsall.bat",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvarsall.bat"
    )

    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            return $path
        }
    }

    return $null
}

# ============================================================================
# Interactive Mode
# ============================================================================

if ($Interactive -or -not $Mode) {
    Write-Host "Welcome to the WinAFL Fuzzing Deployment Wizard!" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This wizard will help you integrate fuzzing into your application." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Choose deployment mode:" -ForegroundColor White
    Write-Host "  1. Source Code Fuzzing (I have the source code)" -ForegroundColor White
    Write-Host "  2. Binary Fuzzing (I only have the compiled binary)" -ForegroundColor White
    Write-Host "  3. Run Example (Try the simple_parser example)" -ForegroundColor White
    Write-Host ""

    $choice = Read-Host "Select option (1-3)"

    switch ($choice) {
        "1" { $Mode = "source" }
        "2" { $Mode = "binary" }
        "3" { $Mode = "example" }
        default {
            Write-Error "Invalid choice"
            exit 1
        }
    }

    Write-Host ""
    Write-Host "Selected mode: $Mode" -ForegroundColor Green
    Write-Host ""
}

# ============================================================================
# Mode: Example
# ============================================================================

if ($Mode -eq "example") {
    Write-Step "Running Simple Parser Example"

    $exampleDir = Join-Path $PSScriptRoot "examples\simple_parser"

    if (-not (Test-Path $exampleDir)) {
        Write-Error "Example directory not found: $exampleDir"
        exit 1
    }

    Write-Info "Example location: $exampleDir"
    Write-Host ""

    # Check for Visual Studio
    Write-Step "Checking for Visual Studio..."
    $vcvars = Find-VisualStudio

    if (-not $vcvars) {
        Write-Error "Visual Studio not found"
        Write-Info "Please install Visual Studio 2019 or later with C++ tools"
        Write-Info "Download from: https://visualstudio.microsoft.com/downloads/"
        exit 1
    }

    Write-Success "Found Visual Studio: $vcvars"

    # Build the example
    Write-Step "Building example..."

    Push-Location $exampleDir

    try {
        # Run build script
        if (Test-Path "build.bat") {
            Write-Info "Running build.bat..."

            $buildProcess = Start-Process -FilePath "cmd.exe" `
                -ArgumentList "/c", "`"$vcvars`" x64 && build.bat" `
                -NoNewWindow -Wait -PassThru

            if ($buildProcess.ExitCode -ne 0) {
                Write-Error "Build failed"
                exit 1
            }

            Write-Success "Build successful!"
        } else {
            Write-Error "build.bat not found"
            exit 1
        }

        # Check if binary exists
        if (-not (Test-Path "build\fuzz_harness.exe")) {
            Write-Error "Fuzzing harness not created"
            exit 1
        }

        Write-Success "Created: build\fuzz_harness.exe"

        # Instructions
        Write-Host ""
        Write-Host "=========================================" -ForegroundColor Cyan
        Write-Host "  Example Build Complete!" -ForegroundColor Cyan
        Write-Host "=========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "1. Read the example README:" -ForegroundColor White
        Write-Info "   notepad README.md"
        Write-Host ""
        Write-Host "2. Run the fuzzing script:" -ForegroundColor White
        Write-Info "   .\run_fuzzing.bat"
        Write-Host ""
        Write-Host "3. The script will guide you through:" -ForegroundColor White
        Write-Info "   - Finding the target offset"
        Write-Info "   - Testing in debug mode"
        Write-Info "   - Starting the fuzzing campaign"
        Write-Host ""
        Write-Host "4. Check for crashes:" -ForegroundColor White
        Write-Info "   dir corpus\output\crashes"
        Write-Host ""
        Write-Host "Expected time to first crash: 30 minutes - 2 hours" -ForegroundColor Yellow
        Write-Host ""

    } finally {
        Pop-Location
    }

    exit 0
}

# ============================================================================
# Mode: Source Code Fuzzing
# ============================================================================

if ($Mode -eq "source") {
    Write-Step "Source Code Fuzzing Setup"

    # Get project path
    if (-not $ProjectPath) {
        Write-Host ""
        Write-Host "Enter the path to your project directory:" -ForegroundColor White
        $ProjectPath = Read-Host "Project path"
    }

    if (-not (Test-Path $ProjectPath)) {
        Write-Error "Project path not found: $ProjectPath"
        exit 1
    }

    $ProjectPath = Resolve-Path $ProjectPath
    Write-Info "Project: $ProjectPath"

    # Get source files
    if (-not $SourceFiles) {
        Write-Host ""
        Write-Host "Enter your source file(s) to fuzz (comma-separated):" -ForegroundColor White
        Write-Info "Example: parser.c,utils.c"
        $SourceFiles = Read-Host "Source files"
    }

    # Set output directory
    if (-not $OutputDir) {
        $OutputDir = Join-Path $ProjectPath "fuzz"
    }

    # Create fuzzing directory
    Write-Step "Creating fuzzing infrastructure..."

    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    # Copy template harness
    $templatePath = Join-Path $PSScriptRoot "templates\harness_template.c"
    $harnessPath = Join-Path $OutputDir "fuzz_harness.c"

    if (Test-Path $templatePath) {
        Copy-Item -Path $templatePath -Destination $harnessPath -Force
        Write-Success "Created fuzzing harness: $harnessPath"
    } else {
        Write-Error "Template not found: $templatePath"
        exit 1
    }

    # Create build script
    $buildScript = @"
@echo off
REM Auto-generated build script for fuzzing

echo Building fuzzing harness...

REM Find Visual Studio
set VSWHERE="%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
for /f "usebackq tokens=*" %%i in (``%VSWHERE% -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath``) do (
    set VSINSTALLDIR=%%i
)

if not defined VSINSTALLDIR (
    echo Visual Studio not found
    exit /b 1
)

call "%VSINSTALLDIR%\VC\Auxiliary\Build\vcvarsall.bat" x64

REM Create build directory
if not exist build mkdir build
cd build

REM Build
cl.exe /O2 /Zi /MD /W3 ^
    ..\fuzz_harness.c ^
    $($SourceFiles.Replace(',', ' ^' + [Environment]::NewLine + '    ')) ^
    /Fe:fuzz_target.exe ^
    /link /DEBUG

if %ERRORLEVEL% NEQ 0 (
    echo Build failed
    exit /b 1
)

echo.
echo Build successful: build\fuzz_target.exe
cd ..
"@

    $buildScriptPath = Join-Path $OutputDir "build.bat"
    $buildScript | Out-File -FilePath $buildScriptPath -Encoding ASCII
    Write-Success "Created build script: $buildScriptPath"

    # Create corpus directories
    $inputDir = Join-Path $OutputDir "corpus\input"
    $outputCorpus = Join-Path $OutputDir "corpus\output"

    New-Item -ItemType Directory -Path $inputDir -Force | Out-Null
    New-Item -ItemType Directory -Path $outputCorpus -Force | Out-Null
    Write-Success "Created corpus directories"

    # Instructions
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "  Source Fuzzing Setup Complete!" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Files created:" -ForegroundColor Green
    Write-Info "$harnessPath"
    Write-Info "$buildScriptPath"
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Edit the fuzzing harness:" -ForegroundColor White
    Write-Info "   notepad `"$harnessPath`""
    Write-Info "   - Replace TODOs with your code"
    Write-Info "   - Implement fuzz_entry() to call your target function"
    Write-Host ""
    Write-Host "2. Add sample input files:" -ForegroundColor White
    Write-Info "   Copy valid test files to: $inputDir"
    Write-Host ""
    Write-Host "3. Build the fuzzing harness:" -ForegroundColor White
    Write-Info "   cd `"$OutputDir`""
    Write-Info "   .\build.bat"
    Write-Host ""
    Write-Host "4. Follow the integration guide:" -ForegroundColor White
    Write-Info "   See: FUZZING_INTEGRATION_GUIDE.md"
    Write-Host ""
    Write-Host "5. Check the example:" -ForegroundColor White
    Write-Info "   See: examples\simple_parser\ for a working example"
    Write-Host ""
}

# ============================================================================
# Mode: Binary Fuzzing
# ============================================================================

if ($Mode -eq "binary") {
    Write-Step "Binary Fuzzing Setup"

    # Get target executable
    if (-not $TargetExecutable) {
        Write-Host ""
        Write-Host "Enter the path to your target executable:" -ForegroundColor White
        $TargetExecutable = Read-Host "Executable path"
    }

    if (-not (Test-Path $TargetExecutable)) {
        Write-Error "Executable not found: $TargetExecutable"
        exit 1
    }

    $TargetExecutable = Resolve-Path $TargetExecutable
    Write-Info "Target: $TargetExecutable"

    # Detect architecture
    try {
        $bytes = [System.IO.File]::ReadAllBytes($TargetExecutable)
        $peOffset = [BitConverter]::ToUInt16($bytes[0x3C..0x3D], 0)
        $machine = [BitConverter]::ToUInt16($bytes[($peOffset + 4)..($peOffset + 5)], 0)
        $is64Bit = ($machine -eq 0x8664)
        $arch = if ($is64Bit) { "64" } else { "32" }
    } catch {
        Write-Error "Failed to detect architecture"
        $arch = "64"
    }

    Write-Success "Detected: $arch-bit executable"

    # Set output directory
    if (-not $OutputDir) {
        $basePath = Split-Path $TargetExecutable -Parent
        $OutputDir = Join-Path $basePath "fuzz_output"
    }

    # Create fuzzing directory structure
    Write-Step "Creating fuzzing infrastructure..."

    $inputDir = Join-Path $OutputDir "input"
    $outputCorpus = Join-Path $OutputDir "output"

    New-Item -ItemType Directory -Path $inputDir -Force | Out-Null
    New-Item -ItemType Directory -Path $outputCorpus -Force | Out-Null

    Write-Success "Created directories"

    # Create fuzzing script
    $fuzzScript = @"
@echo off
REM Auto-generated fuzzing script

setlocal

set TARGET_EXE=$TargetExecutable
set INPUT_DIR=$inputDir
set OUTPUT_DIR=$outputCorpus
set WINAFL_DIR=C:\fuzzing\winafl
set DYNAMORIO_DIR=C:\fuzzing\DynamoRIO
set ARCH=$arch
set TIMEOUT=20000
set ITERATIONS=5000

echo ============================================
echo WinAFL Binary Fuzzing
echo ============================================
echo.
echo Target: %TARGET_EXE%
echo Architecture: %ARCH%-bit
echo.

REM Step 1: Find target function offset
echo [*] You need to identify the target function to fuzz
echo.
echo Using WinDbg:
echo   1. Load the executable: windbg "%TARGET_EXE%"
echo   2. Find the function: x module!function_name
echo   3. Calculate offset: ? function_addr - module_base
echo.
echo Using IDA Pro / Ghidra:
echo   1. Find the parsing/processing function
echo   2. Note its RVA (Relative Virtual Address)
echo.

set /p TARGET_MODULE="Enter target module name (e.g., target.exe or library.dll): "
set /p TARGET_OFFSET="Enter target offset (e.g., 0x1234): "
set /p COVERAGE_MODULE="Enter coverage module (usually same as target module): "

echo.
echo Configuration:
echo   Target Module:   %TARGET_MODULE%
echo   Target Offset:   %TARGET_OFFSET%
echo   Coverage Module: %COVERAGE_MODULE%
echo.

REM Step 2: Test in debug mode
echo [*] Testing in debug mode...
echo.

"%DYNAMORIO_DIR%\bin%ARCH%\drrun.exe" -c "%WINAFL_DIR%\winafl.dll" -debug ^
    -target_module %TARGET_MODULE% ^
    -target_offset %TARGET_OFFSET% ^
    -coverage_module %COVERAGE_MODULE% ^
    -fuzz_iterations 10 ^
    -nargs 1 ^
    -- "%TARGET_EXE%" "%INPUT_DIR%\sample.dat"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [!] Debug test failed
    echo [*] Check the .log file for details
    exit /b 1
)

echo.
echo [+] Debug test passed!
echo.

set /p CONTINUE="Continue to fuzzing? (y/n): "
if /i not "%CONTINUE%"=="y" exit /b 0

REM Step 3: Start fuzzing
echo.
echo [*] Starting fuzzing campaign...
echo [*] Press Ctrl+C to stop
echo.

"%WINAFL_DIR%\afl-fuzz.exe" ^
    -i "%INPUT_DIR%" ^
    -o "%OUTPUT_DIR%" ^
    -D "%DYNAMORIO_DIR%\bin%ARCH%" ^
    -t %TIMEOUT% ^
    -- ^
    -coverage_module %COVERAGE_MODULE% ^
    -target_module %TARGET_MODULE% ^
    -target_offset %TARGET_OFFSET% ^
    -fuzz_iterations %ITERATIONS% ^
    -nargs 1 ^
    -- ^
    "%TARGET_EXE%" @@

echo.
echo Fuzzing session ended
echo Results: %OUTPUT_DIR%
echo.

endlocal
"@

    $fuzzScriptPath = Join-Path $OutputDir "start_fuzzing.bat"
    $fuzzScript | Out-File -FilePath $fuzzScriptPath -Encoding ASCII
    Write-Success "Created fuzzing script: $fuzzScriptPath"

    # Instructions
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "  Binary Fuzzing Setup Complete!" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Files created:" -ForegroundColor Green
    Write-Info "$fuzzScriptPath"
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Add sample input files:" -ForegroundColor White
    Write-Info "   Copy valid input files to: $inputDir"
    Write-Host ""
    Write-Host "2. Find the target function:" -ForegroundColor White
    Write-Info "   Use WinDbg or IDA Pro to identify the function to fuzz"
    Write-Info "   See VULNERABILITY_HUNTING_GUIDE.md for instructions"
    Write-Host ""
    Write-Host "3. Run the fuzzing script:" -ForegroundColor White
    Write-Info "   cd `"$OutputDir`""
    Write-Info "   .\start_fuzzing.bat"
    Write-Host ""
    Write-Host "4. The script will prompt you for:" -ForegroundColor White
    Write-Info "   - Target module name"
    Write-Info "   - Target function offset"
    Write-Info "   - Coverage module"
    Write-Host ""
}

Write-Host ""
Write-Host "Deployment complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Additional resources:" -ForegroundColor Cyan
Write-Info "- FUZZING_INTEGRATION_GUIDE.md - Complete integration guide"
Write-Info "- VULNERABILITY_HUNTING_GUIDE.md - Finding vulnerabilities"
Write-Info "- examples/simple_parser/ - Working example"
Write-Info "- templates/harness_template.c - Harness template"
Write-Host ""
