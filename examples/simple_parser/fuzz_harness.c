/*
 * Fuzzing Harness for Simple Parser
 *
 * This harness shows how to integrate fuzzing into your application.
 * It's designed to be used with WinAFL for maximum fuzzing speed.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>

// Define this to use the harness instead of standalone mode
#define FUZZING_HARNESS

// Include the target code
#include "simple_parser.c"

// Configuration
#define FUZZ_ITERATIONS 5000

// Global state for persistent fuzzing
static int g_initialized = 0;

/*
 * One-time initialization
 * Called once at program start
 */
void fuzz_init(void) {
    if (g_initialized) {
        return;
    }

    // Initialize any global state here
    printf("[HARNESS] Fuzzing harness initialized\n");

    g_initialized = 1;
}

/*
 * Per-iteration cleanup
 * Called after each fuzzing iteration
 */
void fuzz_cleanup(void) {
    // Reset any global state
    // Free temporary allocations
    // Clear buffers
}

/*
 * Main fuzzing entry point
 * This is the function WinAFL will repeatedly call
 */
__declspec(dllexport) int fuzz_entry(const char* input_file) {
    // Ensure initialization
    if (!g_initialized) {
        fuzz_init();
    }

    // Call the target function
    int result = parse_file(input_file);

    // Cleanup after this iteration
    fuzz_cleanup();

    return result;
}

/*
 * Main function
 * Sets up the fuzzing environment
 */
int main(int argc, char** argv) {
    if (argc < 2) {
        printf("WinAFL Fuzzing Harness for Simple Parser\n");
        printf("Usage: %s <input_file>\n", argv[0]);
        printf("\n");
        printf("To fuzz with WinAFL:\n");
        printf("  1. Find the offset of fuzz_entry() using WinDbg:\n");
        printf("     windbg fuzz_harness.exe\n");
        printf("     x fuzz_harness!fuzz_entry\n");
        printf("     ? <address> - <base>\n");
        printf("\n");
        printf("  2. Run in debug mode:\n");
        printf("     drrun.exe -c winafl.dll -debug \\\n");
        printf("       -target_module fuzz_harness.exe \\\n");
        printf("       -target_offset 0x<OFFSET> \\\n");
        printf("       -fuzz_iterations 10 -nargs 1 \\\n");
        printf("       -- fuzz_harness.exe input.dat\n");
        printf("\n");
        printf("  3. Start fuzzing:\n");
        printf("     afl-fuzz.exe -i in -o out -D C:\\fuzzing\\DynamoRIO\\bin64 -t 20000 -- \\\n");
        printf("       -coverage_module fuzz_harness.exe \\\n");
        printf("       -target_module fuzz_harness.exe \\\n");
        printf("       -target_offset 0x<OFFSET> \\\n");
        printf("       -fuzz_iterations 5000 -nargs 1 \\\n");
        printf("       -- fuzz_harness.exe @@\n");
        return 1;
    }

    // Initialize
    fuzz_init();

    // For testing: just run once
    printf("[HARNESS] Testing with input: %s\n", argv[1]);
    int result = fuzz_entry(argv[1]);
    printf("[HARNESS] Result: %d\n", result);

    return result;
}
