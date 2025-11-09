@echo off
REM Automated fuzzing script for simple_parser example

setlocal

echo ============================================
echo WinAFL Fuzzing - Simple Parser Example
echo ============================================
echo.

REM Configuration
set TARGET_EXE=%~dp0build\fuzz_harness.exe
set INPUT_DIR=%~dp0corpus\input
set OUTPUT_DIR=%~dp0corpus\output
set WINAFL_DIR=C:\fuzzing\winafl
set DYNAMORIO_DIR=C:\fuzzing\DynamoRIO
set TIMEOUT=20000
set ITERATIONS=5000

REM Check if target exists
if not exist "%TARGET_EXE%" (
    echo [!] Target not found: %TARGET_EXE%
    echo [*] Run build.bat first
    exit /b 1
)

REM Create input directory if needed
if not exist "%INPUT_DIR%" (
    echo [*] Creating input directory...
    mkdir "%INPUT_DIR%"

    REM Create a sample input file
    echo Creating sample input...
    powershell -Command "$bytes = [byte[]](5, 0x41, 0x41, 0x41, 0x41, 0x41, 0, 0, 0, 1, 10, 0x42, 0x42, 0x42, 0x42, 0x42, 0x42, 0x42, 0x42, 0x42, 0x42, 0xFF); [System.IO.File]::WriteAllBytes('%INPUT_DIR%\sample.dat', $bytes)"

    echo [+] Created sample input file
)

REM Create output directory
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

REM Check for WinAFL
if not exist "%WINAFL_DIR%\afl-fuzz.exe" (
    echo [!] WinAFL not found at: %WINAFL_DIR%
    echo [*] Run setup_winafl.ps1 first
    exit /b 1
)

REM Check for DynamoRIO
if not exist "%DYNAMORIO_DIR%\bin64\drrun.exe" (
    echo [!] DynamoRIO not found at: %DYNAMORIO_DIR%
    echo [*] Run setup_winafl.ps1 first
    exit /b 1
)

echo Configuration:
echo   Target:     %TARGET_EXE%
echo   Input:      %INPUT_DIR%
echo   Output:     %OUTPUT_DIR%
echo   WinAFL:     %WINAFL_DIR%
echo   DynamoRIO:  %DYNAMORIO_DIR%
echo   Timeout:    %TIMEOUT% ms
echo   Iterations: %ITERATIONS%
echo.

REM Step 1: Find the target offset
echo [*] Step 1: Finding target offset...
echo [*] You need to find the offset of fuzz_entry using WinDbg
echo.
echo Run these commands in WinDbg:
echo   windbg "%TARGET_EXE%"
echo   x fuzz_harness!fuzz_entry
echo   ? ^<address^> - ^<base^>
echo.
set /p TARGET_OFFSET="Enter the target offset (e.g., 0x1234): "

if "%TARGET_OFFSET%"=="" (
    echo [!] No offset provided, using default 0x1000
    set TARGET_OFFSET=0x1000
)

echo [+] Using offset: %TARGET_OFFSET%
echo.

REM Step 2: Test in debug mode
echo [*] Step 2: Testing in debug mode...
echo.

"%DYNAMORIO_DIR%\bin64\drrun.exe" -c "%WINAFL_DIR%\winafl.dll" -debug ^
    -target_module fuzz_harness.exe ^
    -target_offset %TARGET_OFFSET% ^
    -fuzz_iterations 10 ^
    -nargs 1 ^
    -coverage_module fuzz_harness.exe ^
    -- "%TARGET_EXE%" "%INPUT_DIR%\sample.dat"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [!] Debug test failed
    echo [*] Check the .log file for details
    echo [*] Verify the target offset is correct
    exit /b 1
)

echo.
echo [+] Debug test passed!
echo.

REM Ask user to continue
set /p CONTINUE="Continue to fuzzing? (y/n): "
if /i not "%CONTINUE%"=="y" (
    echo Aborted.
    exit /b 0
)

REM Step 3: Start fuzzing
echo.
echo [*] Step 3: Starting fuzzing campaign...
echo [*] Press Ctrl+C to stop
echo.

"%WINAFL_DIR%\afl-fuzz.exe" ^
    -i "%INPUT_DIR%" ^
    -o "%OUTPUT_DIR%" ^
    -D "%DYNAMORIO_DIR%\bin64" ^
    -t %TIMEOUT% ^
    -- ^
    -coverage_module fuzz_harness.exe ^
    -target_module fuzz_harness.exe ^
    -target_offset %TARGET_OFFSET% ^
    -fuzz_iterations %ITERATIONS% ^
    -nargs 1 ^
    -- ^
    "%TARGET_EXE%" @@

echo.
echo ============================================
echo Fuzzing session ended
echo ============================================
echo.
echo Results: %OUTPUT_DIR%
echo.
echo Check for crashes:
echo   dir "%OUTPUT_DIR%\crashes"
echo.

endlocal
