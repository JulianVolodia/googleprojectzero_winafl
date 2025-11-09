# Fuzzing Integration Guide - Source Code & Binary

This guide teaches you how to integrate WinAFL fuzzing into your own applications, whether you have source code or just binaries.

## Table of Contents

1. [Overview](#overview)
2. [Source Code Fuzzing](#source-code-fuzzing)
3. [Binary Fuzzing](#binary-fuzzing)
4. [Writing Fuzzing Harnesses](#writing-fuzzing-harnesses)
5. [Integration Patterns](#integration-patterns)
6. [Deployment & Automation](#deployment--automation)
7. [Best Practices](#best-practices)

## Overview

### Two Approaches

**Source Code Fuzzing (White-box)**
- You have the source code
- Can add instrumentation at compile time
- Better performance
- More control over what's fuzzed

**Binary Fuzzing (Black-box)**
- Only have compiled binaries
- Use DynamoRIO for runtime instrumentation
- No recompilation needed
- Slightly slower

### What You'll Learn

✅ How to write fuzzing harnesses
✅ How to integrate fuzzing into build process
✅ How to fuzz specific functions
✅ How to handle different input types
✅ How to automate deployment

## Source Code Fuzzing

### Method 1: AFL-style Persistent Fuzzing

#### Step 1: Add Fuzzing Harness to Your Code

Create a file `fuzz_harness.c`:

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>

// Include your target function header
#include "your_parser.h"

#define FUZZ_ITERATIONS 1000

// This is the function you want to fuzz
extern int parse_my_data(const char* filename);

int main(int argc, char** argv) {
    if (argc < 2) {
        printf("Usage: %s <input_file>\n", argv[0]);
        return 1;
    }

    // AFL persistent mode - run multiple times per process
    #ifdef __AFL_LOOP
    while (__AFL_LOOP(FUZZ_ITERATIONS)) {
    #endif

        // Your target function
        parse_my_data(argv[1]);

    #ifdef __AFL_LOOP
    }
    #endif

    return 0;
}
```

#### Step 2: Compile for Fuzzing

**With Visual Studio:**

```batch
REM Build the fuzzing harness
cl.exe /O2 /MD /Zi fuzz_harness.c your_parser.c /Fe:fuzz_target.exe

REM The binary is ready for WinAFL
```

**With CMake:**

```cmake
# CMakeLists.txt
cmake_minimum_required(VERSION 3.10)
project(MyFuzzTarget)

# Your main library/application
add_library(myparser
    your_parser.c
    your_parser.h
)

# Fuzzing harness executable
add_executable(fuzz_target
    fuzz_harness.c
)

target_link_libraries(fuzz_target myparser)

# Optional: Add debug symbols for better crash analysis
if(MSVC)
    target_compile_options(fuzz_target PRIVATE /Zi)
endif()
```

### Method 2: In-Process Function Fuzzing

For fuzzing a specific function without file I/O:

```c
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>

// Your target function
extern int process_buffer(unsigned char* data, size_t size);

// Global buffer for fuzzing
static unsigned char g_fuzz_buffer[65536];
static size_t g_fuzz_size = 0;

// Function that reads input file into buffer
void read_fuzz_input(const char* filename) {
    FILE* f = fopen(filename, "rb");
    if (!f) return;

    g_fuzz_size = fread(g_fuzz_buffer, 1, sizeof(g_fuzz_buffer), f);
    fclose(f);
}

// Fuzzing harness
int fuzz_entry(const char* filename) {
    read_fuzz_input(filename);

    if (g_fuzz_size > 0) {
        // Call your target function
        process_buffer(g_fuzz_buffer, g_fuzz_size);
    }

    return 0;
}

int main(int argc, char** argv) {
    if (argc < 2) {
        printf("Usage: %s <input_file>\n", argv[0]);
        return 1;
    }

    // This is the function WinAFL will target
    fuzz_entry(argv[1]);

    return 0;
}
```

### Method 3: Library Function Fuzzing

For fuzzing exported DLL functions:

**my_library.c:**
```c
#include <windows.h>

// Export the function you want to fuzz
__declspec(dllexport) int parse_image(const char* filename) {
    // Your parsing logic here
    FILE* f = fopen(filename, "rb");
    if (!f) return -1;

    // ... parsing code ...

    fclose(f);
    return 0;
}

// DLL entry point
BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpvReserved) {
    return TRUE;
}
```

**fuzz_dll_harness.c:**
```c
#include <windows.h>
#include <stdio.h>

typedef int (*ParseImageFunc)(const char*);

int main(int argc, char** argv) {
    if (argc < 2) return 1;

    // Load your DLL
    HMODULE hDll = LoadLibrary("my_library.dll");
    if (!hDll) {
        printf("Failed to load DLL\n");
        return 1;
    }

    // Get the function to fuzz
    ParseImageFunc parse_image = (ParseImageFunc)GetProcAddress(hDll, "parse_image");
    if (!parse_image) {
        printf("Failed to find function\n");
        return 1;
    }

    // Call the function with fuzzing input
    parse_image(argv[1]);

    FreeLibrary(hDll);
    return 0;
}
```

## Binary Fuzzing

### When You Only Have Binaries

If you don't have source code, you can still fuzz using DynamoRIO instrumentation.

#### Step 1: Identify the Target Function

Use WinDbg or IDA Pro:

```
# In WinDbg:
windbg target.exe

# Find the module base
lm

# Find the function you want to fuzz
x module!FunctionName

# Calculate offset
? function_address - module_base
```

#### Step 2: Create a Wrapper Application

Sometimes you need to create a small wrapper to call the target:

**wrapper.c:**
```c
#include <windows.h>
#include <stdio.h>

int main(int argc, char** argv) {
    if (argc < 2) return 1;

    // Load the target DLL/EXE
    HMODULE hMod = LoadLibrary("target.dll");
    if (!hMod) return 1;

    // Get function pointer (by ordinal or name)
    typedef int (*TargetFunc)(const char*);
    TargetFunc target = (TargetFunc)GetProcAddress(hMod, "ProcessFile");

    if (target) {
        target(argv[1]);
    }

    FreeLibrary(hMod);
    return 0;
}
```

## Writing Fuzzing Harnesses

### Anatomy of a Good Harness

```c
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>

// 1. Include your target headers
#include "target.h"

// 2. Define any global state
static unsigned char buffer[1024 * 1024]; // 1MB buffer

// 3. Setup function (called once)
void fuzz_setup() {
    // Initialize any global state
    // Load configuration
    // Allocate resources
}

// 4. Cleanup function (called after each iteration)
void fuzz_cleanup() {
    // Reset state
    // Free temporary resources
    // Clear buffers
    memset(buffer, 0, sizeof(buffer));
}

// 5. The actual fuzzing target
int fuzz_target(const char* input_file) {
    FILE* f = fopen(input_file, "rb");
    if (!f) return -1;

    size_t size = fread(buffer, 1, sizeof(buffer), f);
    fclose(f);

    if (size == 0) return -1;

    // Call your target function
    int result = process_data(buffer, size);

    // Cleanup after this iteration
    fuzz_cleanup();

    return result;
}

// 6. Main entry point
int main(int argc, char** argv) {
    if (argc < 2) {
        printf("Usage: %s <input_file>\n", argv[0]);
        return 1;
    }

    // One-time setup
    fuzz_setup();

    // Persistent mode for performance
    #ifdef PERSISTENT_MODE
    while (1) {
    #endif
        fuzz_target(argv[1]);
    #ifdef PERSISTENT_MODE
    }
    #endif

    return 0;
}
```

### Different Input Types

#### File Input (Standard)

```c
int fuzz_file_input(const char* filename) {
    FILE* f = fopen(filename, "rb");
    if (!f) return -1;

    unsigned char data[8192];
    size_t size = fread(data, 1, sizeof(data), f);
    fclose(f);

    return process_data(data, size);
}
```

#### Network Input

```c
int fuzz_network_input(const char* filename) {
    // Read fuzz input from file
    FILE* f = fopen(filename, "rb");
    if (!f) return -1;

    unsigned char packet[1500];
    size_t size = fread(packet, 1, sizeof(packet), f);
    fclose(f);

    // Simulate network input
    return process_network_packet(packet, size);
}
```

#### Structured Input (JSON/XML)

```c
int fuzz_json_input(const char* filename) {
    // Read file
    FILE* f = fopen(filename, "rb");
    if (!f) return -1;

    char json[16384];
    size_t size = fread(json, 1, sizeof(json) - 1, f);
    fclose(f);
    json[size] = '\0';

    // Parse JSON
    return parse_json(json);
}
```

#### Image/Media Input

```c
int fuzz_image_input(const char* filename) {
    // Your image decoder
    Image* img = load_image(filename);
    if (!img) return -1;

    // Process the image
    int result = process_image(img);

    // Cleanup
    free_image(img);

    return result;
}
```

## Integration Patterns

### Pattern 1: Drop-in Fuzzing Executable

Create a separate fuzzing executable alongside your main application:

```
MyApp/
├── src/
│   ├── main.c          # Your application
│   └── parser.c        # Code to fuzz
├── fuzz/
│   ├── harness.c       # Fuzzing harness
│   └── build_fuzz.bat  # Build script
└── CMakeLists.txt
```

**CMakeLists.txt:**
```cmake
# Main application
add_executable(myapp src/main.c src/parser.c)

# Fuzzing harness
option(BUILD_FUZZING "Build fuzzing harness" OFF)
if(BUILD_FUZZING)
    add_executable(fuzz_harness fuzz/harness.c src/parser.c)
endif()
```

### Pattern 2: Test-based Fuzzing

Integrate fuzzing into your test suite:

```c
// tests/test_parser.c
#include "parser.h"
#include <stdio.h>

// Regular unit test
void test_valid_input() {
    assert(parse_data("valid.dat") == 0);
}

// Fuzzing entry point
#ifdef FUZZING_MODE
int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    parse_buffer(data, size);
    return 0;
}
#endif
```

### Pattern 3: Continuous Fuzzing

Integrate into CI/CD:

**fuzz_ci.bat:**
```batch
@echo off
REM Build fuzzing harness
cmake -DBUILD_FUZZING=ON ..
cmake --build . --config Release

REM Run fuzzing for 1 hour
timeout /t 3600 /nobreak > nul & taskkill /im afl-fuzz.exe /f

REM Check for crashes
if exist output\crashes\* (
    echo Crashes found!
    exit 1
)
```

## Deployment & Automation

### Quick Deployment Script

See `deploy_fuzzing.ps1` for a complete automated deployment script.

### Build Automation

**build_for_fuzzing.bat:**
```batch
@echo off
echo Building fuzzing harness...

REM Set Visual Studio environment
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" x64

REM Build with debug symbols and optimization
cl.exe /O2 /Zi /MD ^
    fuzz_harness.c ^
    your_source.c ^
    /Fe:fuzz_target.exe ^
    /link /DEBUG

echo Build complete: fuzz_target.exe
```

### One-Click Fuzzing

**start_fuzzing.bat:**
```batch
@echo off
setlocal

set TARGET_EXE=fuzz_target.exe
set INPUT_DIR=corpus\input
set OUTPUT_DIR=corpus\output
set TIMEOUT=20000

echo Starting fuzzing campaign...
echo Target: %TARGET_EXE%
echo Input: %INPUT_DIR%
echo Output: %OUTPUT_DIR%

REM Start fuzzing
C:\fuzzing\winafl\afl-fuzz.exe ^
    -i %INPUT_DIR% ^
    -o %OUTPUT_DIR% ^
    -D C:\fuzzing\DynamoRIO\bin64 ^
    -t %TIMEOUT% ^
    -- ^
    -coverage_module %TARGET_EXE% ^
    -target_module %TARGET_EXE% ^
    -target_offset 0x1000 ^
    -fuzz_iterations 5000 ^
    -nargs 1 ^
    -- ^
    %TARGET_EXE% @@

endlocal
```

## Best Practices

### DO ✅

1. **Keep harnesses simple**
   ```c
   // Good: Simple, focused
   int harness(const char* file) {
       return parse_file(file);
   }
   ```

2. **Reset state between iterations**
   ```c
   int harness(const char* file) {
       reset_parser_state();
       int result = parse_file(file);
       cleanup_parser();
       return result;
   }
   ```

3. **Use persistent mode for speed**
   ```c
   while (1) {
       fuzz_one_iteration();
   }
   ```

4. **Add assertions**
   ```c
   int harness(const char* file) {
       assert(global_state == CLEAN);
       int result = parse_file(file);
       assert(no_memory_leaks());
       return result;
   }
   ```

5. **Export symbols**
   ```c
   __declspec(dllexport) int fuzz_entry(const char* file);
   ```

### DON'T ❌

1. **Don't use random functions**
   ```c
   // Bad: Non-deterministic
   int harness() {
       int val = rand(); // Don't do this!
       return process(val);
   }
   ```

2. **Don't rely on external state**
   ```c
   // Bad: Depends on files/network
   int harness() {
       load_config_from_internet(); // Don't do this!
       return process();
   }
   ```

3. **Don't ignore return values**
   ```c
   // Bad: Errors are lost
   void harness(const char* file) {
       parse_file(file); // Errors ignored!
   }
   ```

4. **Don't use timeouts in code**
   ```c
   // Bad: Slows down fuzzing
   int harness(const char* file) {
       Sleep(100); // Don't do this!
       return parse_file(file);
   }
   ```

## Complete Example

See the `examples/` directory for complete working examples:

- `examples/image_parser/` - Image parser fuzzing
- `examples/json_parser/` - JSON parser fuzzing
- `examples/network_protocol/` - Network protocol fuzzing
- `examples/binary_format/` - Binary format fuzzing

Each example includes:
- Source code
- Fuzzing harness
- Build scripts
- Sample corpus
- Deployment automation

## Troubleshooting

### Issue: Harness crashes immediately

**Solution:** Check your initialization:
```c
// Add error checking
FILE* f = fopen(filename, "rb");
if (!f) {
    printf("Failed to open: %s\n", filename);
    return -1;
}
```

### Issue: Very slow fuzzing (< 10 exec/s)

**Solution:** Reduce per-iteration work:
```c
// Bad: Too much work
int harness(const char* file) {
    init_everything();      // Slow!
    parse_file(file);
    cleanup_everything();   // Slow!
}

// Good: Do init once
void main() {
    init_everything();
    while (1) {
        parse_file(file);
    }
}
```

### Issue: No new paths discovered

**Solution:** Check if your function is actually being called:
```c
int harness(const char* file) {
    printf("Called with: %s\n", file); // Debug output
    return parse_file(file);
}
```

## Resources

- Complete examples: `examples/`
- Deployment script: `deploy_fuzzing.ps1`
- Build templates: `templates/`
- Sample corpus: `corpus/`

---

**Next Steps:**

1. Run `deploy_fuzzing.ps1` to set up automated fuzzing
2. Check `examples/` for working code
3. Modify the harness template for your code
4. Start fuzzing!
