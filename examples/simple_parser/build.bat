@echo off
REM Build script for simple_parser fuzzing example
REM Requires Visual Studio installed

echo ============================================
echo Building Simple Parser Fuzzing Example
echo ============================================
echo.

REM Check for Visual Studio
where cl.exe >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [!] Visual Studio not found in PATH
    echo [*] Run this from Visual Studio Developer Command Prompt
    echo [*] Or run: "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" x64
    exit /b 1
)

REM Create build directory
if not exist build mkdir build
cd build

echo [*] Compiling fuzzing harness...

REM Build the fuzzing harness with debug symbols and optimizations
cl.exe /O2 /Zi /MD /W3 ^
    ..\fuzz_harness.c ^
    /Fe:fuzz_harness.exe ^
    /link /DEBUG

if %ERRORLEVEL% NEQ 0 (
    echo [!] Build failed
    exit /b 1
)

echo.
echo [+] Build successful!
echo [+] Output: build\fuzz_harness.exe
echo.
echo Next steps:
echo   1. Create input corpus: mkdir corpus\input
echo   2. Add sample input files to corpus\input\
echo   3. Run: ..\run_fuzzing.bat
echo.

cd ..
