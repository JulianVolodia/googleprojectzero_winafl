# Quick Start Guide - WinAFL for Windows Vulnerability Hunting

This guide will get you fuzzing Microsoft Windows targets in under 30 minutes.

## Prerequisites

- Windows 10/11 (64-bit)
- Administrator access
- PowerShell 5.0+
- 50GB free disk space

## Installation (5 minutes)

### Step 1: Open PowerShell as Administrator

Right-click PowerShell → "Run as Administrator"

### Step 2: Enable Script Execution

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Step 3: Navigate to WinAFL Directory

```powershell
cd C:\path\to\winafl
```

### Step 4: Run Setup Script

```powershell
.\setup_winafl.ps1
```

This will:
- Download DynamoRIO
- Set up directory structure
- Configure environment variables
- Create sample input files

### Step 5: Restart PowerShell

Close and reopen PowerShell as Administrator to apply PATH changes.

## Your First Fuzzing Campaign (10 minutes)

Let's fuzz Microsoft Paint!

### Step 1: Create Input Corpus

```powershell
# Create directory for BMP files
New-Item -ItemType Directory -Path "C:\fuzzing\input\bmp" -Force

# Copy a small valid BMP file to the input directory
# You can create one in Paint: 100x100 pixels, save as BMP
Copy-Item "C:\path\to\small_valid.bmp" "C:\fuzzing\input\bmp\"
```

### Step 2: Find Target Function

We need to find which function in gdiplus.dll handles BMP parsing.

**Option A: Use provided test target**
```powershell
# The repository includes test_gdiplus.exe with a known offset
$targetExe = "C:\fuzzing\winafl\test_gdiplus.exe"
$targetOffset = "0x1270"
```

**Option B: Find it yourself with WinDbg**
```powershell
# Open WinDbg
windbg "C:\Windows\System32\mspaint.exe"

# In WinDbg, run:
# lm m gdiplus
# x gdiplus!GdipLoadImageFromFile
# ? <address> - <gdiplus_base>
```

### Step 3: Test Configuration

```powershell
.\fuzz_target.ps1 `
    -TargetExe "C:\Windows\System32\mspaint.exe" `
    -TargetModule "gdiplus.dll" `
    -TargetOffset "0x1270" `
    -CoverageModule "gdiplus.dll" `
    -InputDir "C:\fuzzing\input\bmp" `
    -OutputDir "C:\fuzzing\output\mspaint_test" `
    -Debug
```

Look for:
- ✅ "In OpenFileW, reading" messages
- ✅ Input file opened 10 times
- ✅ No errors
- ✅ .log file created

If you see these, you're ready to fuzz!

### Step 4: Start Fuzzing

```powershell
.\fuzz_target.ps1 `
    -TargetExe "C:\Windows\System32\mspaint.exe" `
    -TargetModule "gdiplus.dll" `
    -TargetOffset "0x1270" `
    -CoverageModule "gdiplus.dll,WindowsCodecs.dll" `
    -InputDir "C:\fuzzing\input\bmp" `
    -OutputDir "C:\fuzzing\output\mspaint_campaign"
```

### Step 5: Monitor Progress

You'll see the AFL status screen:

```
american fuzzy lop 1.96b (default)

┌─ process timing ─────────────────────────────────────┐
│        run time : 0 days, 2 hrs, 15 min, 32 sec      │
│   last new path : 0 days, 0 hrs, 5 min, 12 sec       │
│ last uniq crash : none seen yet                      │
│  last uniq hang : none seen yet                      │
└───────────────────────────────────────────────────────┘

┌─ overall results ────────────────────────────────────┐
│  cycles done : 5                                      │
│  total paths : 142                                    │
│ uniq crashes : 0                                      │
│   uniq hangs : 0                                      │
└───────────────────────────────────────────────────────┘

┌─ cycle progress ─────────────────────────────────────┐
│  now processing : 45 (31.7%)                         │
│ paths timed out : 0 (0.0%)                           │
└───────────────────────────────────────────────────────┘

┌─ map coverage ───────────────────────────────────────┐
│    map density : 2.15% / 2.87%                       │
│ count coverage : 2.02 bits/tuple                     │
└───────────────────────────────────────────────────────┘

┌─ stage progress ─────────────────────────────────────┐
│  now trying : havoc                                   │
│ stage execs : 2847/5000 (56%)                        │
│ total execs : 1.2M                                    │
│  exec speed : 145.2/sec                              │
└───────────────────────────────────────────────────────┘

┌─ findings in depth ──────────────────────────────────┐
│ favored paths : 28 (19.7%)                           │
│  new edges on : 45 (31.7%)                           │
│ total crashes : 0 (0 unique)                         │
│  total tmouts : 0 (0 unique)                         │
└───────────────────────────────────────────────────────┘
```

**Key metrics to watch:**
- **exec speed:** Aim for 100+ executions/sec
- **uniq crashes:** Any number > 0 is good!
- **cycles done:** Let it run for at least 10 cycles

### Step 6: Let It Run

Fuzzing takes time. Recommendations:
- **Minimum:** 24 hours
- **Good:** 3-7 days
- **Thorough:** 2-4 weeks

Press `Ctrl+C` to stop at any time.

## Analyzing Results (5 minutes)

### Step 1: Check for Crashes

```powershell
.\analyze_crashes.ps1 `
    -OutputDir "C:\fuzzing\output\mspaint_campaign" `
    -TargetExe "C:\Windows\System32\mspaint.exe" `
    -GenerateReport
```

### Step 2: Review Report

Open `vulnerability_report.md` to see:
- Number of unique crashes
- Crash file locations
- Preliminary analysis
- Impact assessment

### Step 3: Manually Verify

Try to reproduce a crash:

```powershell
# Open Paint with crash file
& "C:\Windows\System32\mspaint.exe" "C:\fuzzing\output\mspaint_campaign\crashes\id:000000,sig:06,src:000000,op:havoc,rep:2"
```

If Paint crashes → You found a bug! 🎉

## Reporting to Microsoft (10 minutes)

### Step 1: Gather Information

You need:
- ✅ Crash file (test case)
- ✅ Steps to reproduce
- ✅ Windows version
- ✅ WinDbg analysis (optional but recommended)

### Step 2: Submit to MSRC

Go to: https://msrc.microsoft.com/create-report

Fill out:
1. **Product:** Windows 10 [or your version]
2. **Component:** Microsoft Paint / GDI+
3. **Description:** Heap buffer overflow in BMP parsing
4. **Reproduction:**
   ```
   1. Open Microsoft Paint
   2. Open attached crash.bmp file
   3. Application crashes
   ```
5. **Attach:** Minimized crash file
6. **Impact:** Potential remote code execution

### Step 3: Wait for Response

Microsoft will:
- Acknowledge receipt (1-7 days)
- Assess severity (7-30 days)
- Develop patch (30-90 days)
- Release patch and credit you!

## What's Next?

### More Targets to Try

Easy targets for beginners:

```powershell
# Windows Media Player
.\fuzz_target.ps1 -TargetExe "C:\Program Files\Windows Media Player\wmplayer.exe" ...

# WordPad
.\fuzz_target.ps1 -TargetExe "C:\Program Files\Windows NT\Accessories\wordpad.exe" ...

# Internet Explorer
.\fuzz_target.ps1 -TargetExe "C:\Program Files\Internet Explorer\iexplore.exe" ...
```

### Advanced Techniques

- **Parallel fuzzing:** Run multiple instances
- **Custom dictionaries:** Target specific formats
- **Long campaigns:** Weeks or months
- **Different file formats:** Images, documents, media

See [VULNERABILITY_HUNTING_GUIDE.md](VULNERABILITY_HUNTING_GUIDE.md) for details.

## Troubleshooting

### "Low execution speed"

**Problem:** Only 10-20 exec/sec

**Solutions:**
```powershell
# Reduce timeout
-Timeout 10000

# Reduce iterations
-Iterations 1000

# Use smaller input files
```

### "No crashes after 24 hours"

**Problem:** No vulnerabilities found

**Normal!** Security is improving. Try:
- Different targets
- Different file formats
- Longer campaigns (1+ weeks)
- More complex inputs

### "Error connecting to pipe"

**Problem:** AFL can't start

**Solution:**
```powershell
# Kill existing fuzzers
Get-Process afl-fuzz | Stop-Process -Force

# Restart
```

## Tips for Success

1. **Start simple:** Use test targets first
2. **Good corpus:** Use diverse, valid input files
3. **Be patient:** Fuzzing takes time
4. **Save everything:** Keep all crash files
5. **Document well:** Take notes on your process
6. **Verify crashes:** Ensure they're reproducible
7. **Report responsibly:** Give Microsoft time to patch

## Getting Help

- **Detailed guide:** [VULNERABILITY_HUNTING_GUIDE.md](VULNERABILITY_HUNTING_GUIDE.md)
- **WinAFL docs:** [README](README)
- **Issues:** https://github.com/googleprojectzero/winafl/issues
- **MSRC:** https://www.microsoft.com/en-us/msrc

## Checklist

Before you start fuzzing:

- [ ] PowerShell running as Administrator
- [ ] setup_winafl.ps1 completed successfully
- [ ] Valid input files in input directory
- [ ] Tested with -Debug flag
- [ ] Enough disk space (50GB+)
- [ ] Fuzzing command ready
- [ ] Time allocated (24+ hours)

Ready to find some bugs! 🐛🔍

---

**Remember:** Always practice responsible disclosure. Report vulnerabilities to Microsoft before public disclosure.
