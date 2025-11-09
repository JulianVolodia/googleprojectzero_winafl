# Simple Parser Fuzzing Example

This is a complete, ready-to-run example showing how to integrate WinAFL fuzzing into your own C/C++ application.

## What This Example Demonstrates

- ✅ Writing a fuzzing harness for your code
- ✅ Building with Visual Studio
- ✅ Running in debug mode to verify setup
- ✅ Launching a full fuzzing campaign
- ✅ Finding real bugs (intentional vulnerabilities included!)

## Files

- `simple_parser.c` - Target code with intentional bugs
- `fuzz_harness.c` - Fuzzing harness that wraps the target
- `build.bat` - Build script for Windows
- `run_fuzzing.bat` - Automated fuzzing script

## Quick Start (5 minutes)

### Step 1: Build

```batch
REM Open Visual Studio Developer Command Prompt
cd examples\simple_parser
build.bat
```

This creates `build\fuzz_harness.exe`

### Step 2: Find Target Offset

You need to find the memory offset of the `fuzz_entry` function:

```batch
REM Install WinDbg from Windows SDK if not already installed

REM Open WinDbg
windbg build\fuzz_harness.exe

REM In WinDbg, type:
x fuzz_harness!fuzz_entry

REM You'll see something like:
REM 00007ff7`12341234 fuzz_harness!fuzz_entry

REM Calculate offset (function address - module base):
lm m fuzz_harness
REM You'll see:
REM start             end                 module name
REM 00007ff7`12340000 00007ff7`12350000   fuzz_harness

REM The offset is: 0x1234 (last 4 digits in this example)
```

**Quick Method:** The offset is usually around `0x1000` to `0x2000` for simple programs.

### Step 3: Run Fuzzing

```batch
run_fuzzing.bat
```

The script will:
1. Ask you for the target offset
2. Test in debug mode (10 iterations)
3. Ask if you want to continue
4. Start fuzzing!

### Step 4: Check Results

After a few minutes, check for crashes:

```batch
dir corpus\output\crashes
```

If you see files there - you found bugs! 🎉

## Understanding the Code

### The Vulnerable Target (`simple_parser.c`)

This parser reads a custom binary format with records:

```
[name_len][name...][value][desc_len][desc...][0xFF]
```

**Intentional Bugs:**

1. **Buffer Overflow in name field** (line 28-31):
   ```c
   int name_len = data[0];
   // BUG: No check if name_len > sizeof(rec->name)
   memcpy(rec->name, data + 1, name_len);
   ```
   If `name_len > 64`, this overflows the `name` buffer.

2. **Buffer Overflow in description** (line 43-46):
   ```c
   int desc_len = data[name_len + 5];
   // BUG: No check if desc_len > sizeof(rec->description)
   memcpy(rec->description, data + name_len + 6, desc_len);
   ```
   If `desc_len > 256`, this overflows the `description` buffer.

### The Fuzzing Harness (`fuzz_harness.c`)

The harness provides an entry point for WinAFL:

```c
__declspec(dllexport) int fuzz_entry(const char* input_file) {
    // Call the target function
    int result = parse_file(input_file);
    return result;
}
```

Key features:
- `__declspec(dllexport)` makes the function visible to WinDbg
- Initializes state once
- Cleans up after each iteration
- Returns result for error tracking

## How WinAFL Works

1. **Instrumentation**: DynamoRIO instruments your code to track coverage
2. **Fuzzing Loop**: AFL mutates inputs and measures coverage
3. **Persistent Mode**: The function runs 5000 times per process for speed
4. **Crash Detection**: When your code crashes, the input is saved

## Customizing for Your Code

### 1. Replace the Target Function

Edit `simple_parser.c` with your actual code:

```c
// Your code
int my_parser(const char* filename) {
    // ... your parsing logic ...
}
```

### 2. Update the Harness

Edit `fuzz_harness.c`:

```c
__declspec(dllexport) int fuzz_entry(const char* input_file) {
    return my_parser(input_file);  // Call your function
}
```

### 3. Rebuild

```batch
build.bat
```

### 4. Fuzz

```batch
run_fuzzing.bat
```

That's it!

## Advanced: Creating Sample Inputs

The fuzzer works better with valid sample inputs. Create some in `corpus/input/`:

```batch
mkdir corpus\input

REM Create a valid record file
REM Format: [name_len][name][value][desc_len][desc][0xFF]
powershell -Command "
$bytes = [byte[]](
    5,                          # name_len = 5
    0x41, 0x41, 0x41, 0x41, 0x41, # name = 'AAAAA'
    0, 0, 0, 1,                 # value = 1
    10,                         # desc_len = 10
    0x42, 0x42, 0x42, 0x42, 0x42, # desc = 'BBBBBBBBBB'
    0x42, 0x42, 0x42, 0x42, 0x42,
    0xFF                        # end marker
);
[System.IO.File]::WriteAllBytes('corpus\input\sample.dat', $bytes)
"
```

## Troubleshooting

### "Build failed"

Make sure you're in Visual Studio Developer Command Prompt:
```batch
"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" x64
```

### "WinAFL not found"

Run the main setup script first:
```batch
cd ..\..
.\setup_winafl.ps1
```

### "Debug test failed"

1. Check the `.log` file in current directory
2. Verify your target offset is correct
3. Make sure the input file exists
4. Try offset `0x1000` if unsure

### "No crashes found"

If you don't find the intentional bugs:
1. Let it run longer (hours/days)
2. Check exec speed (should be > 50/sec)
3. Verify your input corpus is valid

## Expected Results

With this example, you should find crashes within **30 minutes to 2 hours** of fuzzing.

The fuzzer will discover:
- Buffer overflow when name_len > 64
- Buffer overflow when desc_len > 256
- Various parsing edge cases

Example crash:
```
EXCEPTION_ACCESS_VIOLATION
Read from 0x000000000000XXXX

Call stack:
fuzz_harness!parse_record+0x42
fuzz_harness!parse_file+0x123
fuzz_harness!fuzz_entry+0x15
```

## Next Steps

1. **Analyze crashes** with `analyze_crashes.ps1`
2. **Minimize test cases** to smallest reproducing input
3. **Fix the bugs** (see `parse_record_safe` for correct implementation)
4. **Re-fuzz** to verify fixes

## Learning More

- [FUZZING_INTEGRATION_GUIDE.md](../../FUZZING_INTEGRATION_GUIDE.md) - Complete integration guide
- [VULNERABILITY_HUNTING_GUIDE.md](../../VULNERABILITY_HUNTING_GUIDE.md) - Finding real bugs
- [WinAFL Documentation](../../README) - Full WinAFL docs

---

**This is a complete, working example. Everything you need is included!**

Start fuzzing in under 5 minutes. No external dependencies except Visual Studio and WinAFL setup.
