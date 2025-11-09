# CMake template for WinAFL fuzzing harness
# Copy this to your project and customize

cmake_minimum_required(VERSION 3.10)
project(FuzzingHarness)

# ============================================================================
# Configuration
# ============================================================================

# Set C/C++ standard
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 14)

# Enable debug symbols for better crash analysis
set(CMAKE_BUILD_TYPE RelWithDebInfo)

# ============================================================================
# Options
# ============================================================================

option(BUILD_FUZZING "Build fuzzing harness" ON)
option(ENABLE_ASAN "Enable AddressSanitizer" OFF)

# ============================================================================
# Compiler flags
# ============================================================================

if(MSVC)
    # Optimization + Debug symbols
    add_compile_options(/O2 /Zi /MD)

    # Enable all warnings
    add_compile_options(/W3)

    # Additional security features
    add_compile_options(/GS /sdl)

    # Address Sanitizer (if enabled)
    if(ENABLE_ASAN)
        add_compile_options(/fsanitize=address)
    endif()
endif()

# ============================================================================
# TODO: Your main library/application
# ============================================================================

# Add your source files here
set(TARGET_SOURCES
    # TODO: Add your .c or .cpp files
    # Example:
    # src/parser.c
    # src/utils.c
    # src/decoder.c
)

# Create a library from your code
if(TARGET_SOURCES)
    add_library(target_lib ${TARGET_SOURCES})

    # TODO: Add include directories
    # target_include_directories(target_lib PUBLIC include/)

    # TODO: Link libraries if needed
    # target_link_libraries(target_lib other_library)
endif()

# ============================================================================
# Fuzzing harness
# ============================================================================

if(BUILD_FUZZING)
    message(STATUS "Building fuzzing harness")

    # Fuzzing harness executable
    add_executable(fuzz_harness
        fuzz_harness.c
        # Add additional harness files if needed
    )

    # Link with your target library
    if(TARGET target_lib)
        target_link_libraries(fuzz_harness target_lib)
    endif()

    # Link with Windows libraries if needed
    if(WIN32)
        target_link_libraries(fuzz_harness
            # Common Windows libraries
            # ws2_32  # Winsock
            # gdi32   # GDI
            # ole32   # OLE/COM
        )
    endif()

    # Ensure debug symbols are included
    if(MSVC)
        target_link_options(fuzz_harness PRIVATE /DEBUG)
    endif()

    # Install target
    install(TARGETS fuzz_harness
        RUNTIME DESTINATION bin
    )
endif()

# ============================================================================
# Corpus setup
# ============================================================================

# Create corpus directories
file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/corpus/input)
file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/corpus/output)

# Copy sample inputs (if you have them)
# file(COPY ${CMAKE_SOURCE_DIR}/test_data/
#      DESTINATION ${CMAKE_BINARY_DIR}/corpus/input/)

# ============================================================================
# Helper: Create fuzzing scripts
# ============================================================================

# Generate run script
set(FUZZING_SCRIPT "${CMAKE_BINARY_DIR}/run_fuzzing.bat")
file(WRITE ${FUZZING_SCRIPT}
"@echo off
setlocal

set TARGET_EXE=%cd%\\bin\\fuzz_harness.exe
set INPUT_DIR=%cd%\\corpus\\input
set OUTPUT_DIR=%cd%\\corpus\\output
set WINAFL_DIR=C:\\fuzzing\\winafl
set DYNAMORIO_DIR=C:\\fuzzing\\DynamoRIO
set TIMEOUT=20000
set ITERATIONS=5000

echo ============================================
echo WinAFL Fuzzing - ${PROJECT_NAME}
echo ============================================
echo.
echo Target: %TARGET_EXE%
echo.

if not exist \"%TARGET_EXE%\" (
    echo [!] Target not found. Run 'cmake --build . --config RelWithDebInfo' first
    exit /b 1
)

set /p TARGET_OFFSET=\"Enter target offset (e.g., 0x1234): \"

echo.
echo [*] Testing in debug mode...

\"%DYNAMORIO_DIR%\\bin64\\drrun.exe\" -c \"%WINAFL_DIR%\\winafl.dll\" -debug ^
    -target_module fuzz_harness.exe ^
    -target_offset %TARGET_OFFSET% ^
    -fuzz_iterations 10 ^
    -nargs 1 ^
    -coverage_module fuzz_harness.exe ^
    -- \"%TARGET_EXE%\" \"%INPUT_DIR%\\sample.dat\"

if %ERRORLEVEL% NEQ 0 (
    echo [!] Debug test failed
    exit /b 1
)

echo [+] Debug test passed!
set /p CONTINUE=\"Continue to fuzzing? (y/n): \"
if /i not \"%CONTINUE%\"==\"y\" exit /b 0

echo [*] Starting fuzzing...

\"%WINAFL_DIR%\\afl-fuzz.exe\" ^
    -i \"%INPUT_DIR%\" ^
    -o \"%OUTPUT_DIR%\" ^
    -D \"%DYNAMORIO_DIR%\\bin64\" ^
    -t %TIMEOUT% ^
    -- ^
    -coverage_module fuzz_harness.exe ^
    -target_module fuzz_harness.exe ^
    -target_offset %TARGET_OFFSET% ^
    -fuzz_iterations %ITERATIONS% ^
    -nargs 1 ^
    -- ^
    \"%TARGET_EXE%\" @@

endlocal
")

message(STATUS "Created fuzzing script: ${FUZZING_SCRIPT}")

# ============================================================================
# Usage instructions
# ============================================================================

message(STATUS "")
message(STATUS "============================================")
message(STATUS "  Fuzzing Harness Configuration")
message(STATUS "============================================")
message(STATUS "")
message(STATUS "Build the harness:")
message(STATUS "  mkdir build")
message(STATUS "  cd build")
message(STATUS "  cmake ..")
message(STATUS "  cmake --build . --config RelWithDebInfo")
message(STATUS "")
message(STATUS "Add input files:")
message(STATUS "  Copy test files to: build/corpus/input/")
message(STATUS "")
message(STATUS "Run fuzzing:")
message(STATUS "  cd build")
message(STATUS "  run_fuzzing.bat")
message(STATUS "")
message(STATUS "Optional: Enable AddressSanitizer:")
message(STATUS "  cmake .. -DENABLE_ASAN=ON")
message(STATUS "")
