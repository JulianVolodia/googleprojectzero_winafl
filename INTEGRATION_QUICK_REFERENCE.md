# Fuzzing Integration Quick Reference

One-page guide for integrating WinAFL into your code. Keep this handy!

## 🚀 Ultra Quick Start

### Option 1: Try the Example (5 minutes)

```powershell
# Run the deployment wizard
.\deploy_fuzzing.ps1 -Mode example

# Follow the prompts, then:
cd examples\simple_parser
.\run_fuzzing.bat
```

### Option 2: Your Source Code (15 minutes)

```powershell
# Run deployment wizard for your code
.\deploy_fuzzing.ps1 -Mode source -ProjectPath "C:\your\project"

# Edit the generated harness
notepad C:\your\project\fuzz\fuzz_harness.c

# Build and run
cd C:\your\project\fuzz
.\build.bat
.\run_fuzzing.bat
```

### Option 3: Your Binary (10 minutes)

```powershell
# Run deployment wizard for binary
.\deploy_fuzzing.ps1 -Mode binary -TargetExecutable "C:\path\to\your.exe"

# Add input files
copy test_files\* C:\path\to\fuzz_output\input\

# Run
cd C:\path\to\fuzz_output
.\start_fuzzing.bat
```

## 📋 Checklist: Before You Start

- [ ] Windows 10/11
- [ ] Administrator privileges
- [ ] Visual Studio 2019+ (for source fuzzing)
- [ ] WinDbg (for finding offsets)
- [ ] Ran `setup_winafl.ps1`
- [ ] 50GB+ free disk space

## 🔧 Writing a Harness (Minimal Example)

```c
#include <stdio.h>
#include <stdlib.h>

// Your function to fuzz
extern int parse_my_data(const char* filename);

// Fuzzing entry point
__declspec(dllexport) int fuzz_entry(const char* input_file) {
    return parse_my_data(input_file);
}

// Main
int main(int argc, char** argv) {
    if (argc < 2) return 1;
    return fuzz_entry(argv[1]);
}
```

**That's it!** Build and fuzz.

## 🏗️ Building Your Harness

### Visual Studio Command Line

```batch
cl.exe /O2 /Zi /MD fuzz_harness.c your_code.c /Fe:fuzz.exe /link /DEBUG
```

### CMake

```cmake
add_executable(fuzz_harness fuzz_harness.c your_code.c)
target_compile_options(fuzz_harness PRIVATE /Zi)
```

## 🎯 Finding the Target Offset

### Method 1: WinDbg (Most Reliable)

```
1. windbg fuzz.exe
2. x fuzz!fuzz_entry
   → Shows: 00007ff712341234 fuzz!fuzz_entry
3. lm m fuzz
   → Shows: start=00007ff712340000 end=...
4. Offset = 0x1234 (last digits)
```

### Method 2: dumpbin (Quick)

```batch
dumpbin /exports fuzz.exe | findstr fuzz_entry
```

### Method 3: Common Offsets

Try these first:
- `0x1000` - Most common
- `0x1100` - Common for small programs
- `0x2000` - If above don't work

## ⚙️ Running WinAFL

### Step 1: Debug Mode (ALWAYS DO THIS FIRST!)

```batch
drrun.exe -c winafl.dll -debug ^
  -target_module fuzz.exe ^
  -target_offset 0x1234 ^
  -fuzz_iterations 10 ^
  -nargs 1 ^
  -coverage_module fuzz.exe ^
  -- fuzz.exe test.dat
```

**✅ Success if:**
- File opened 10 times
- No errors in .log file
- Program exits normally

### Step 2: Start Fuzzing

```batch
afl-fuzz.exe -i input -o output -D DynamoRIO\bin64 -t 20000 -- ^
  -coverage_module fuzz.exe ^
  -target_module fuzz.exe ^
  -target_offset 0x1234 ^
  -fuzz_iterations 5000 ^
  -nargs 1 ^
  -- fuzz.exe @@
```

## 📊 AFL Status Screen

```
┌─ process timing ────────────────┐
│  run time : 0 days, 2 hrs       │ ← How long it's been running
│  last new path : 5 min          │ ← When it last found something
└──────────────────────────────────┘

┌─ overall results ────────────────┐
│  cycles done : 5                 │ ← Completion count (>10 is good)
│  uniq crashes : 3                │ ← 🎯 BUGS FOUND!
│  exec speed : 125.2/sec          │ ← Higher is better (>100 is good)
└──────────────────────────────────┘
```

**Key metrics:**
- **exec speed**: > 50/sec is acceptable, > 100/sec is good
- **uniq crashes**: Any number > 0 means you found bugs!
- **cycles done**: Let it run for at least 10 cycles

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| "Can't connect to pipe" | Kill other AFL processes: `taskkill /f /im afl-fuzz.exe` |
| Low exec speed (< 10/sec) | Reduce `-fuzz_iterations` to 1000, reduce timeout to 10000 |
| "Module not found" | Run debug mode, check .log for actual module names |
| Crashes immediately | Check your harness initialization, verify input file exists |
| No new paths | Verify target function is called, check debug mode output |
| Can't find offset | Make sure function is `__declspec(dllexport)`, build with `/Zi` |

## 📁 Directory Structure

```
your_project/
├── src/
│   └── your_code.c
└── fuzz/
    ├── fuzz_harness.c       ← Your harness
    ├── build.bat            ← Build script
    ├── build/
    │   └── fuzz_target.exe  ← Built harness
    └── corpus/
        ├── input/           ← Put sample files here
        │   ├── test1.dat
        │   └── test2.dat
        └── output/          ← AFL output
            ├── crashes/     ← 🎯 Found bugs!
            ├── hangs/
            └── queue/
```

## 🎓 Common Patterns

### Pattern 1: File-Based Input

```c
__declspec(dllexport) int fuzz_entry(const char* filename) {
    return parse_file(filename);
}
```

### Pattern 2: Buffer-Based Input

```c
__declspec(dllexport) int fuzz_entry(const char* filename) {
    unsigned char buf[65536];
    FILE* f = fopen(filename, "rb");
    size_t len = fread(buf, 1, sizeof(buf), f);
    fclose(f);
    return process_buffer(buf, len);
}
```

### Pattern 3: With Initialization

```c
static int initialized = 0;

__declspec(dllexport) int fuzz_entry(const char* filename) {
    if (!initialized) {
        init_library();
        initialized = 1;
    }
    return parse_file(filename);
}
```

### Pattern 4: With Cleanup

```c
__declspec(dllexport) int fuzz_entry(const char* filename) {
    reset_state();
    int result = parse_file(filename);
    cleanup();
    return result;
}
```

## ⏱️ How Long to Fuzz?

| Target Complexity | Minimum Time | Recommended |
|-------------------|--------------|-------------|
| Simple parser | 1 hour | 24 hours |
| Complex parser | 24 hours | 3-7 days |
| Image/media | 24 hours | 1-2 weeks |
| Critical target | 1 week | 1 month+ |

**Tip:** Run overnight/weekends for best results.

## 📝 Common Mistakes

❌ **Don't:**
```c
// Slow - reopens file every time
int fuzz_entry(const char* file) {
    init_everything();    // TOO SLOW!
    parse_file(file);
    cleanup_everything(); // TOO SLOW!
}
```

✅ **Do:**
```c
// Fast - init once
static int init_done = 0;

int fuzz_entry(const char* file) {
    if (!init_done) {
        init_everything();
        init_done = 1;
    }
    parse_file(file);
    reset_state(); // Fast cleanup only
}
```

## 🎯 Next Steps After Finding Crashes

1. **Verify**:
   ```batch
   your_app.exe output\crashes\id:000000,sig:06,src:000000,...
   ```

2. **Analyze** with WinDbg:
   ```
   windbg your_app.exe crash_file
   g           # Run until crash
   .ecxr       # Show exception
   kv          # Call stack
   !analyze -v # Detailed analysis
   ```

3. **Minimize**:
   ```batch
   afl-tmin.exe -i crash.dat -o min.dat -- your_app.exe @@
   ```

4. **Report** to vendor (if not your code)

## 📚 Quick Links

- **Full guide**: [FUZZING_INTEGRATION_GUIDE.md](FUZZING_INTEGRATION_GUIDE.md)
- **Examples**: `examples/simple_parser/`
- **Templates**: `templates/harness_template.c`
- **Deploy script**: `deploy_fuzzing.ps1`

## 💡 Pro Tips

1. **Start with the example** - Build confidence first
2. **Use small input files** (< 10KB) for faster fuzzing
3. **Run multiple instances** in parallel for speed
4. **Monitor exec speed** - higher is always better
5. **Save your configuration** - document offsets and settings
6. **Be patient** - fuzzing takes time but finds real bugs

## 🆘 Need Help?

```powershell
# Run the example
.\deploy_fuzzing.ps1 -Mode example

# See it working, then adapt for your code!
```

For detailed help:
- Read [FUZZING_INTEGRATION_GUIDE.md](FUZZING_INTEGRATION_GUIDE.md)
- Check [examples/simple_parser/README.md](examples/simple_parser/README.md)
- Review [VULNERABILITY_HUNTING_GUIDE.md](VULNERABILITY_HUNTING_GUIDE.md)

---

**Remember**: Fuzzing is an art AND a science. Start simple, iterate, and don't give up!
