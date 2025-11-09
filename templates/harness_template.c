/*
 * WinAFL Fuzzing Harness Template
 *
 * This is a template for creating your own fuzzing harness.
 * Replace the TODOs with your actual code.
 *
 * Usage:
 *   1. Copy this file to your project
 *   2. Replace TODOs with your code
 *   3. Compile with Visual Studio
 *   4. Run with WinAFL
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>

// ============================================================================
// TODO: Include your target headers
// ============================================================================
// #include "your_library.h"
// #include "your_parser.h"

// ============================================================================
// Configuration
// ============================================================================
#define FUZZ_ITERATIONS 5000      // Number of iterations per process
#define MAX_INPUT_SIZE (1024*1024) // 1MB max input

// ============================================================================
// Global state
// ============================================================================
static int g_initialized = 0;
static unsigned char g_buffer[MAX_INPUT_SIZE];

// ============================================================================
// TODO: Add your global variables here
// ============================================================================
// static YourContext* g_context = NULL;

// ============================================================================
// Initialization (called once at program start)
// ============================================================================
void fuzz_init(void) {
    if (g_initialized) {
        return;
    }

    printf("[HARNESS] Initializing fuzzing harness...\n");

    // TODO: Initialize your library/module
    // Example:
    // g_context = create_context();
    // init_your_library();

    g_initialized = 1;
    printf("[HARNESS] Initialization complete\n");
}

// ============================================================================
// Cleanup (called after each fuzzing iteration)
// ============================================================================
void fuzz_cleanup(void) {
    // TODO: Reset state between iterations
    // Example:
    // reset_context(g_context);
    // clear_caches();
    // free_temporary_allocations();

    // Clear the input buffer
    memset(g_buffer, 0, sizeof(g_buffer));
}

// ============================================================================
// Shutdown (called once at program exit)
// ============================================================================
void fuzz_shutdown(void) {
    // TODO: Cleanup global resources
    // Example:
    // destroy_context(g_context);
    // shutdown_your_library();

    printf("[HARNESS] Shutdown complete\n");
}

// ============================================================================
// Main fuzzing entry point
// This is the function WinAFL will repeatedly call
// ============================================================================
__declspec(dllexport) int fuzz_entry(const char* input_file) {
    int result = 0;

    // Ensure initialization
    if (!g_initialized) {
        fuzz_init();
    }

    // Read input file
    FILE* f = fopen(input_file, "rb");
    if (!f) {
        return -1;
    }

    size_t input_size = fread(g_buffer, 1, sizeof(g_buffer), f);
    fclose(f);

    if (input_size == 0) {
        return -1;
    }

    // TODO: Call your target function
    // Choose ONE of these patterns:

    // ---- Pattern 1: File-based API ----
    // If your function takes a filename:
    // result = your_parse_file(input_file);

    // ---- Pattern 2: Buffer-based API ----
    // If your function takes a buffer:
    // result = your_parse_buffer(g_buffer, input_size);

    // ---- Pattern 3: Stream-based API ----
    // If your function takes a stream:
    // FILE* stream = fopen(input_file, "rb");
    // result = your_parse_stream(stream);
    // fclose(stream);

    // ---- Pattern 4: Context-based API ----
    // If your function uses a context:
    // result = your_parse_with_context(g_context, g_buffer, input_size);

    // ---- Pattern 5: Multiple functions ----
    // If you want to fuzz multiple functions in sequence:
    // result = your_init_parser(g_buffer, input_size);
    // if (result == 0) {
    //     result = your_parse_data();
    // }
    // your_cleanup_parser();

    // EXAMPLE: Replace this with your actual function call
    // For demonstration, we'll just return success
    result = 0;  // TODO: Replace with actual function call

    // Cleanup after this iteration
    fuzz_cleanup();

    return result;
}

// ============================================================================
// Main function
// ============================================================================
int main(int argc, char** argv) {
    if (argc < 2) {
        printf("================================================================================\n");
        printf("WinAFL Fuzzing Harness Template\n");
        printf("================================================================================\n");
        printf("\n");
        printf("Usage: %s <input_file>\n", argv[0]);
        printf("\n");
        printf("Quick Start:\n");
        printf("  1. Edit this file and replace TODOs with your code\n");
        printf("  2. Build: cl.exe /O2 /Zi harness.c your_code.c /Fe:fuzz.exe\n");
        printf("  3. Find offset:\n");
        printf("     windbg fuzz.exe\n");
        printf("     x fuzz!fuzz_entry\n");
        printf("     ? <address> - <base>\n");
        printf("  4. Test:\n");
        printf("     drrun.exe -c winafl.dll -debug \\\n");
        printf("       -target_module fuzz.exe -target_offset 0x<OFFSET> \\\n");
        printf("       -fuzz_iterations 10 -nargs 1 \\\n");
        printf("       -- fuzz.exe test_input.dat\n");
        printf("  5. Fuzz:\n");
        printf("     afl-fuzz.exe -i in -o out -D DynamoRIO\\bin64 -t 20000 -- \\\n");
        printf("       -coverage_module fuzz.exe -target_module fuzz.exe \\\n");
        printf("       -target_offset 0x<OFFSET> -fuzz_iterations 5000 -nargs 1 \\\n");
        printf("       -- fuzz.exe @@\n");
        printf("\n");
        return 1;
    }

    // Initialize
    fuzz_init();

    // Register cleanup handler
    atexit(fuzz_shutdown);

    // Test mode: run once
    printf("[HARNESS] Testing with input: %s\n", argv[1]);

    int result = fuzz_entry(argv[1]);

    printf("[HARNESS] Result: %d\n", result);
    printf("[HARNESS] If result is 0 and no crash, your harness is working!\n");

    return result;
}

// ============================================================================
// Template Checklist
// ============================================================================
/*

Before fuzzing, make sure you've completed:

[ ] Included your target headers at the top
[ ] Implemented fuzz_init() with your initialization code
[ ] Implemented fuzz_cleanup() to reset state
[ ] Implemented fuzz_entry() to call your target function
[ ] Compiled successfully with debug symbols (/Zi flag)
[ ] Tested the harness with a valid input file
[ ] Found the offset of fuzz_entry() with WinDbg
[ ] Ran in debug mode (10 iterations) successfully
[ ] Created a corpus of valid input files
[ ] Started fuzzing!

Common Issues:

1. Harness crashes immediately
   → Check your initialization code
   → Verify input file exists and is valid
   → Make sure you're handling errors properly

2. Very slow fuzzing (< 10 exec/s)
   → Reduce work in fuzz_cleanup()
   → Move initialization from fuzz_entry() to fuzz_init()
   → Check if you're doing unnecessary I/O

3. No new paths discovered
   → Verify your target function is actually being called
   → Check that input is being read correctly
   → Make sure coverage_module is set correctly

4. Can't find offset
   → Make sure function is exported (__declspec(dllexport))
   → Build with debug symbols (/Zi)
   → Check if function name is mangled (use dumpbin /exports)

Need Help?

- See FUZZING_INTEGRATION_GUIDE.md for detailed examples
- Check examples/simple_parser/ for a working example
- Review VULNERABILITY_HUNTING_GUIDE.md for best practices

*/
