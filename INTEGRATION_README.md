# WinAFL Integration Toolkit

**Complete toolkit for integrating fuzzing into your Windows applications**

This toolkit provides everything you need to add fuzzing to your own code, whether you have source code or just binaries.

## 🚀 Getting Started (Choose Your Path)

### Path 1: Try the Example First (Recommended for Beginners)

**Time: 5 minutes**

```powershell
# Run the deployment wizard
.\deploy_fuzzing.ps1 -Mode example

# This will:
# - Build the example fuzzer
# - Show you how everything works
# - Find intentional bugs
# - Give you confidence to fuzz your own code
```

Then check `examples/simple_parser/README.md` for details.

### Path 2: Fuzz Your Source Code

**Time: 15 minutes**

```powershell
# Run the deployment wizard
.\deploy_fuzzing.ps1 -Mode source -Interactive

# This will:
# - Ask you about your project
# - Create a fuzzing harness template
# - Generate build scripts
# - Set up directory structure
```

Then:
1. Edit `fuzz/fuzz_harness.c` to call your functions
2. Run `fuzz/build.bat`
3. Start fuzzing!

### Path 3: Fuzz a Binary (No Source Code)

**Time: 10 minutes**

```powershell
# Run the deployment wizard
.\deploy_fuzzing.ps1 -Mode binary -TargetExecutable "C:\path\to\your.exe"

# This will:
# - Set up fuzzing infrastructure
# - Create fuzzing scripts
# - Generate instructions
```

Then follow the prompts to find the target function offset.

## 📚 Documentation

We've created comprehensive guides for every skill level:

### Quick References (Read These First!)

| Document | For | Time | Purpose |
|----------|-----|------|---------|
| **[INTEGRATION_QUICK_REFERENCE.md](INTEGRATION_QUICK_REFERENCE.md)** | Everyone | 2 min | One-page cheat sheet |
| **[QUICK_START.md](QUICK_START.md)** | Beginners | 5 min | Get fuzzing in 30 minutes |

### Comprehensive Guides

| Document | For | Purpose |
|----------|-----|---------|
| **[FUZZING_INTEGRATION_GUIDE.md](FUZZING_INTEGRATION_GUIDE.md)** | Developers | How to integrate fuzzing into your code |
| **[VULNERABILITY_HUNTING_GUIDE.md](VULNERABILITY_HUNTING_GUIDE.md)** | Security Researchers | Finding and reporting vulnerabilities |

### Examples & Templates

| Resource | Purpose |
|----------|---------|
| **examples/simple_parser/** | Complete working example with intentional bugs |
| **templates/harness_template.c** | Copy-paste template for your harness |
| **templates/CMakeLists.txt** | CMake template for building |

## 🎯 What You Get

### Automated Tools

✅ **setup_winafl.ps1** - One-click WinAFL environment setup
✅ **deploy_fuzzing.ps1** - Interactive deployment wizard
✅ **fuzz_target.ps1** - Guided fuzzing for common targets
✅ **analyze_crashes.ps1** - Automated crash analysis

### Pre-configured Targets

✅ 8+ Microsoft application targets (Paint, WordPad, Media Player, etc.)
✅ 6+ system library targets (GDI+, font rendering, etc.)
✅ Ready-to-use fuzzing configurations
✅ Sample corpus files

### Integration Templates

✅ C/C++ harness template with TODOs
✅ Visual Studio build scripts
✅ CMake configuration
✅ Batch script automation

### Complete Example

✅ Vulnerable parser code (educational)
✅ Working fuzzing harness
✅ Build and run scripts
✅ Expected crashes documented

## 📁 Directory Structure

```
winafl/
├── setup_winafl.ps1              # Initial WinAFL setup
├── deploy_fuzzing.ps1            # Interactive deployment wizard
├── fuzz_target.ps1               # Fuzz Microsoft targets
├── analyze_crashes.ps1           # Crash analysis tool
│
├── Documentation/
│   ├── INTEGRATION_QUICK_REFERENCE.md  ⭐ Start here!
│   ├── QUICK_START.md                  # 30-min tutorial
│   ├── FUZZING_INTEGRATION_GUIDE.md    # Complete guide
│   └── VULNERABILITY_HUNTING_GUIDE.md  # Advanced techniques
│
├── examples/
│   └── simple_parser/                  # Working example
│       ├── simple_parser.c             # Vulnerable code
│       ├── fuzz_harness.c              # Fuzzing harness
│       ├── build.bat                   # Build script
│       ├── run_fuzzing.bat             # Automated fuzzing
│       └── README.md                   # Example documentation
│
├── templates/
│   ├── harness_template.c              # Copy-paste harness
│   └── CMakeLists.txt                  # CMake template
│
├── bin32/ & bin64/                     # Pre-built binaries
└── targets.json                        # Target database
```

## 🎓 Learning Path

### Level 1: Absolute Beginner (1 hour)

1. Read [INTEGRATION_QUICK_REFERENCE.md](INTEGRATION_QUICK_REFERENCE.md) (2 min)
2. Run `.\deploy_fuzzing.ps1 -Mode example` (5 min)
3. Follow the simple_parser example (30 min)
4. See it find real bugs! (20+ min)

**You'll learn:** How fuzzing works, what a harness is, how to find crashes

### Level 2: Integrate Into Your Code (2-4 hours)

1. Read [FUZZING_INTEGRATION_GUIDE.md](FUZZING_INTEGRATION_GUIDE.md)
2. Run `.\deploy_fuzzing.ps1 -Mode source`
3. Customize the harness for your code
4. Build and test in debug mode
5. Start your first fuzzing campaign

**You'll learn:** Writing harnesses, building for fuzzing, configuration

### Level 3: Hunt Vulnerabilities (Ongoing)

1. Read [VULNERABILITY_HUNTING_GUIDE.md](VULNERABILITY_HUNTING_GUIDE.md)
2. Fuzz Microsoft or third-party applications
3. Analyze crashes with WinDbg
4. Report to vendors (Microsoft MSRC, etc.)
5. Claim bug bounties!

**You'll learn:** Target selection, crash analysis, responsible disclosure

## 🛠️ Common Workflows

### Workflow 1: "I have source code and want to fuzz it"

```powershell
# 1. Deploy
.\deploy_fuzzing.ps1 -Mode source -ProjectPath "C:\my\project"

# 2. Edit harness
notepad C:\my\project\fuzz\fuzz_harness.c
# → Replace TODOs with your function calls

# 3. Build
cd C:\my\project\fuzz
.\build.bat

# 4. Add input files
copy test_data\* corpus\input\

# 5. Fuzz
.\run_fuzzing.bat
```

### Workflow 2: "I want to find bugs in Microsoft software"

```powershell
# 1. Setup (one-time)
.\setup_winafl.ps1

# 2. Choose target
.\fuzz_target.ps1
# → Select from menu (Paint, WordPad, etc.)

# 3. Let it run (hours/days)
# → Press Ctrl+C when done

# 4. Analyze results
.\analyze_crashes.ps1 -OutputDir "C:\fuzzing\output\..." -GenerateReport

# 5. Report to Microsoft
# → Visit https://msrc.microsoft.com/create-report
```

### Workflow 3: "I only have a .exe file"

```powershell
# 1. Deploy
.\deploy_fuzzing.ps1 -Mode binary -TargetExecutable "target.exe"

# 2. Find target offset
# → Use WinDbg or IDA Pro (instructions provided)

# 3. Add input samples
copy samples\* fuzz_output\input\

# 4. Run
cd fuzz_output
.\start_fuzzing.bat
# → Enter offset when prompted
```

## ⚡ Quick Commands

```powershell
# Setup WinAFL (first time only)
.\setup_winafl.ps1

# Try the example
.\deploy_fuzzing.ps1 -Mode example

# Fuzz your source code
.\deploy_fuzzing.ps1 -Mode source -Interactive

# Fuzz a binary
.\deploy_fuzzing.ps1 -Mode binary -Interactive

# Fuzz Microsoft Paint
.\fuzz_target.ps1 -TargetExe "C:\Windows\System32\mspaint.exe"

# Analyze crashes
.\analyze_crashes.ps1 -OutputDir "output\path" -GenerateReport
```

## 💡 Tips for Success

### Before You Start

1. **Start with the example** - Build confidence first
2. **Read INTEGRATION_QUICK_REFERENCE.md** - One-page cheat sheet
3. **Use small input files** - Faster fuzzing
4. **Have valid samples** - Better coverage

### During Fuzzing

1. **Monitor exec speed** - Higher is better (aim for 100+/sec)
2. **Let it run** - Fuzzing takes time (hours to days)
3. **Check periodically** - Look for crashes
4. **Run multiple instances** - Use all CPU cores

### After Finding Crashes

1. **Verify manually** - Open crash file in target app
2. **Analyze with WinDbg** - Understand the bug
3. **Minimize test case** - Make it smaller
4. **Report responsibly** - Give vendor 90 days

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| Can't build example | Use Visual Studio Developer Command Prompt |
| Low exec speed | Reduce iterations, optimize harness |
| No crashes found | Fuzz longer, try different targets |
| Fuzzer crashes | Check offset, verify in debug mode |
| Need help | Check INTEGRATION_QUICK_REFERENCE.md |

## 📞 Getting Help

### Documentation (Start Here!)

- **Quick help**: [INTEGRATION_QUICK_REFERENCE.md](INTEGRATION_QUICK_REFERENCE.md)
- **Tutorial**: [QUICK_START.md](QUICK_START.md)
- **Integration**: [FUZZING_INTEGRATION_GUIDE.md](FUZZING_INTEGRATION_GUIDE.md)
- **Advanced**: [VULNERABILITY_HUNTING_GUIDE.md](VULNERABILITY_HUNTING_GUIDE.md)

### Examples

- **Working code**: `examples/simple_parser/`
- **Templates**: `templates/`

### External Resources

- **WinAFL**: https://github.com/googleprojectzero/winafl
- **AFL**: http://lcamtuf.coredump.cx/afl/
- **DynamoRIO**: http://dynamorio.org/

## 🎯 Success Stories (What You Can Find)

Using this toolkit, you can find:

- **Buffer overflows** - Classic memory corruption
- **Use-after-free** - Dangling pointer bugs
- **Integer overflows** - Math errors leading to crashes
- **Denial of Service** - Hangs and crashes
- **Logic errors** - Unexpected behavior

**Real examples from our test target:**
- Buffer overflow in name field (30 min to find)
- Buffer overflow in description (1 hour to find)
- Out-of-bounds read (2 hours to find)

## 📜 License

This toolkit is released under the Apache License 2.0, same as WinAFL.

## ⚠️ Responsible Use

**This toolkit is for:**
- ✅ Authorized security testing
- ✅ Testing your own code
- ✅ Educational purposes
- ✅ Bug bounty programs

**NOT for:**
- ❌ Unauthorized testing
- ❌ Malicious purposes
- ❌ Public exploitation

**Always:**
- Report vulnerabilities responsibly
- Give vendors time to patch (90 days)
- Follow bug bounty program rules

## 🚦 What's Next?

### Immediate Actions (Next 30 Minutes)

1. ✅ Read [INTEGRATION_QUICK_REFERENCE.md](INTEGRATION_QUICK_REFERENCE.md)
2. ✅ Run `.\deploy_fuzzing.ps1 -Mode example`
3. ✅ See the example work

### Short Term (This Week)

1. ✅ Integrate fuzzing into your project
2. ✅ Run your first campaign (24+ hours)
3. ✅ Find and fix your first bug

### Long Term (Ongoing)

1. ✅ Make fuzzing part of your workflow
2. ✅ Fuzz before each release
3. ✅ Hunt vulnerabilities in other software
4. ✅ Report to vendors and earn bounties

---

**Ready to find some bugs? Start with the example!**

```powershell
.\deploy_fuzzing.ps1 -Mode example
```

Good luck and happy fuzzing! 🐛🔍
