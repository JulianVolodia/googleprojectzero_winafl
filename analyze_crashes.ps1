# WinAFL Crash Analysis and Triage Script
# This script helps analyze crashes found during fuzzing
# Run with: PowerShell -ExecutionPolicy Bypass -File analyze_crashes.ps1

param(
    [Parameter(Mandatory=$false)]
    [string]$OutputDir = "C:\fuzzing\output",

    [Parameter(Mandatory=$false)]
    [string]$TargetExe = "",

    [Parameter(Mandatory=$false)]
    [switch]$GenerateReport,

    [Parameter(Mandatory=$false)]
    [string]$ReportPath = "vulnerability_report.md",

    [Parameter(Mandatory=$false)]
    [switch]$InstallWinDbg
)

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "   WinAFL Crash Analysis Script" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Function to install WinDbg
function Install-WinDbg {
    Write-Host "[*] Checking for WinDbg installation..." -ForegroundColor Yellow

    $windbgPaths = @(
        "C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\windbg.exe",
        "C:\Program Files\Windows Kits\10\Debuggers\x64\windbg.exe",
        "C:\Program Files (x86)\Windows Kits\10\Debuggers\x86\windbg.exe",
        "${env:ProgramFiles(x86)}\Windows Kits\10\Debuggers\x64\cdb.exe"
    )

    foreach ($path in $windbgPaths) {
        if (Test-Path $path) {
            Write-Host "[+] Found WinDbg: $path" -ForegroundColor Green
            return $path
        }
    }

    Write-Host "[!] WinDbg not found" -ForegroundColor Red
    Write-Host "[*] To install WinDbg, download the Windows SDK from:" -ForegroundColor Yellow
    Write-Host "    https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/" -ForegroundColor White
    Write-Host ""
    Write-Host "    Or install via winget:" -ForegroundColor White
    Write-Host "    winget install Microsoft.WindowsSDK" -ForegroundColor Gray
    Write-Host ""

    if ($InstallWinDbg) {
        Write-Host "[*] Attempting to install via winget..." -ForegroundColor Yellow
        try {
            winget install Microsoft.WindowsSDK --accept-source-agreements --accept-package-agreements
            Write-Host "[+] WinDbg installed successfully" -ForegroundColor Green
        } catch {
            Write-Host "[!] Failed to install WinDbg: $_" -ForegroundColor Red
        }
    }

    return $null
}

# Function to get crash hash (basic deduplication)
function Get-CrashHash {
    param([string]$FilePath)

    try {
        $content = [System.IO.File]::ReadAllBytes($FilePath)
        $md5 = [System.Security.Cryptography.MD5]::Create()
        $hash = $md5.ComputeHash($content)
        return [BitConverter]::ToString($hash).Replace("-", "")
    } catch {
        return "UNKNOWN"
    }
}

# Function to analyze crash with WinDbg
function Analyze-WithWinDbg {
    param(
        [string]$WinDbgPath,
        [string]$TargetExe,
        [string]$CrashFile
    )

    Write-Host "  [*] Analyzing with WinDbg..." -ForegroundColor Yellow

    $windbgScript = @"
.loadby sos clr
.ecxr
kv
!analyze -v
q
"@

    $scriptFile = [System.IO.Path]::GetTempFileName()
    $windbgScript | Out-File -FilePath $scriptFile -Encoding ASCII

    $output = & $WinDbgPath -c "`$<$scriptFile" -z $TargetExe -y srv*c:\symbols*http://msdl.microsoft.com/download/symbols $CrashFile 2>&1

    Remove-Item -Path $scriptFile -Force

    return $output -join "`n"
}

# Check for output directory
if (-not (Test-Path $OutputDir)) {
    Write-Host "[!] Error: Output directory not found: $OutputDir" -ForegroundColor Red
    exit 1
}

# Find crash directories
$crashDirs = @(
    (Join-Path $OutputDir "crashes"),
    (Join-Path $OutputDir "hangs")
)

$crashFiles = @()
$hangFiles = @()

foreach ($dir in $crashDirs) {
    if (Test-Path $dir) {
        $files = Get-ChildItem -Path $dir -File
        if ($dir -like "*crashes*") {
            $crashFiles += $files
        } else {
            $hangFiles += $files
        }
    }
}

$totalCrashes = $crashFiles.Count
$totalHangs = $hangFiles.Count

Write-Host "Fuzzing Results Summary:" -ForegroundColor Cyan
Write-Host "  Output Directory: $OutputDir" -ForegroundColor White
Write-Host "  Crashes Found:    $totalCrashes" -ForegroundColor $(if ($totalCrashes -gt 0) { "Red" } else { "Green" })
Write-Host "  Hangs Found:      $totalHangs" -ForegroundColor $(if ($totalHangs -gt 0) { "Yellow" } else { "Green" })
Write-Host ""

if ($totalCrashes -eq 0 -and $totalHangs -eq 0) {
    Write-Host "[*] No crashes or hangs found. Continue fuzzing!" -ForegroundColor Green
    exit 0
}

# Install/Find WinDbg
$windbgPath = Install-WinDbg

# Analyze crashes
$crashAnalysis = @()

if ($totalCrashes -gt 0) {
    Write-Host "Analyzing Crashes:" -ForegroundColor Red
    Write-Host "==================" -ForegroundColor Red
    Write-Host ""

    $uniqueCrashes = @{}

    foreach ($crash in $crashFiles) {
        $crashHash = Get-CrashHash -FilePath $crash.FullName

        Write-Host "Crash: $($crash.Name)" -ForegroundColor Yellow
        Write-Host "  Path: $($crash.FullName)" -ForegroundColor White
        Write-Host "  Size: $($crash.Length) bytes" -ForegroundColor White
        Write-Host "  Hash: $crashHash" -ForegroundColor White

        if ($uniqueCrashes.ContainsKey($crashHash)) {
            Write-Host "  Status: Duplicate of $($uniqueCrashes[$crashHash])" -ForegroundColor Gray
        } else {
            $uniqueCrashes[$crashHash] = $crash.Name
            Write-Host "  Status: Unique crash" -ForegroundColor Red

            $analysis = @{
                File = $crash.Name
                Path = $crash.FullName
                Size = $crash.Length
                Hash = $crashHash
                Type = "Crash"
                WinDbgOutput = ""
            }

            # Analyze with WinDbg if available
            if ($windbgPath -and $TargetExe) {
                $windbgOutput = Analyze-WithWinDbg -WinDbgPath $windbgPath -TargetExe $TargetExe -CrashFile $crash.FullName
                $analysis.WinDbgOutput = $windbgOutput
                Write-Host "  Analysis: Complete" -ForegroundColor Green
            } else {
                Write-Host "  Analysis: Skipped (WinDbg not available or no target specified)" -ForegroundColor Gray
            }

            $crashAnalysis += $analysis
        }

        Write-Host ""
    }

    Write-Host "[+] Found $($uniqueCrashes.Count) unique crashes" -ForegroundColor Green
    Write-Host ""
}

# Analyze hangs
if ($totalHangs -gt 0) {
    Write-Host "Analyzing Hangs:" -ForegroundColor Yellow
    Write-Host "================" -ForegroundColor Yellow
    Write-Host ""

    foreach ($hang in $hangFiles) {
        $hangHash = Get-CrashHash -FilePath $hang.FullName

        Write-Host "Hang: $($hang.Name)" -ForegroundColor Yellow
        Write-Host "  Path: $($hang.FullName)" -ForegroundColor White
        Write-Host "  Size: $($hang.Length) bytes" -ForegroundColor White
        Write-Host "  Hash: $hangHash" -ForegroundColor White
        Write-Host ""

        $crashAnalysis += @{
            File = $hang.Name
            Path = $hang.FullName
            Size = $hang.Length
            Hash = $hangHash
            Type = "Hang"
            WinDbgOutput = ""
        }
    }
}

# Generate report
if ($GenerateReport) {
    Write-Host "[*] Generating vulnerability report..." -ForegroundColor Green

    $report = @"
# Vulnerability Report - WinAFL Fuzzing Results

**Generated:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Target:** $TargetExe
**Output Directory:** $OutputDir

## Executive Summary

- **Total Crashes:** $totalCrashes
- **Total Hangs:** $totalHangs
- **Unique Crashes:** $($uniqueCrashes.Count)

## Findings

"@

    $severity = "High"
    $cvss = "Unknown"

    if ($totalCrashes -gt 0) {
        $report += @"

### Crashes

"@
        foreach ($crash in $crashAnalysis | Where-Object { $_.Type -eq "Crash" }) {
            $report += @"

#### $($crash.File)

- **Type:** Crash
- **File Path:** `$($crash.Path)`
- **File Size:** $($crash.Size) bytes
- **Hash:** $($crash.Hash)
- **Severity:** $severity

**Description:**

A crash was discovered during fuzzing that may indicate a memory corruption vulnerability.
This could potentially be exploited for code execution or denial of service.

**Reproduction Steps:**

1. Run the target application: ``$TargetExe``
2. Provide the crash file as input: ``$($crash.Path)``
3. Observe the crash

**WinDbg Analysis:**

``````
$($crash.WinDbgOutput)
``````

**Impact:**

- Potential for denial of service
- Possible memory corruption
- May lead to arbitrary code execution

**Recommendation:**

- Investigate the root cause of the crash
- Implement input validation
- Use memory-safe functions
- Consider fuzzing with AddressSanitizer for better diagnostics

"@
        }
    }

    if ($totalHangs -gt 0) {
        $report += @"

### Hangs

"@
        foreach ($hang in $crashAnalysis | Where-Object { $_.Type -eq "Hang" }) {
            $report += @"

#### $($hang.File)

- **Type:** Hang/Timeout
- **File Path:** `$($hang.Path)`
- **File Size:** $($hang.Size) bytes
- **Hash:** $($hang.Hash)
- **Severity:** Medium

**Description:**

A hang/timeout was discovered during fuzzing that indicates a potential denial of service vulnerability.

**Reproduction Steps:**

1. Run the target application: ``$TargetExe``
2. Provide the hang file as input: ``$($hang.Path)``
3. Observe the application hang/timeout

"@
        }
    }

    $report += @"

## Proof of Concept

All crash/hang test cases are located in:
- Crashes: ``$(Join-Path $OutputDir "crashes")``
- Hangs: ``$(Join-Path $OutputDir "hangs")``

## Reporting to Microsoft

### Microsoft Security Response Center (MSRC)

To report these vulnerabilities to Microsoft:

1. Visit: https://msrc.microsoft.com/create-report
2. Select the affected product
3. Provide:
   - Detailed description of the vulnerability
   - Steps to reproduce
   - Crash files (attach or provide hash)
   - WinDbg analysis output
   - Potential impact assessment

### Responsible Disclosure Timeline

- **Day 0:** Report submitted to Microsoft MSRC
- **Day 1-7:** Microsoft acknowledges receipt
- **Day 7-90:** Microsoft investigates and develops fix
- **Day 90:** Public disclosure (if fix not available, coordinate with Microsoft)

### Bug Bounty

If eligible, these findings may qualify for Microsoft's Bug Bounty program:
- https://www.microsoft.com/en-us/msrc/bounty

### Additional Resources

- Microsoft Security Response Center: https://www.microsoft.com/en-us/msrc
- Coordinated Vulnerability Disclosure: https://www.microsoft.com/en-us/msrc/cvd

## References

- WinAFL: https://github.com/googleprojectzero/winafl
- AFL: http://lcamtuf.coredump.cx/afl/
- DynamoRIO: http://dynamorio.org/

---

**Disclaimer:** This report is for authorized security research purposes only.
All testing was conducted in a controlled environment on authorized systems.

"@

    $report | Out-File -FilePath $ReportPath -Encoding UTF8
    Write-Host "[+] Report saved to: $ReportPath" -ForegroundColor Green
    Write-Host ""
}

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "   Analysis Complete" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

if ($totalCrashes -gt 0 -or $totalHangs -gt 0) {
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Review crash files in: $(Join-Path $OutputDir 'crashes')" -ForegroundColor White
    Write-Host "  2. Reproduce crashes manually to verify" -ForegroundColor White
    Write-Host "  3. Analyze with WinDbg for detailed crash information" -ForegroundColor White
    Write-Host "  4. Minimize test cases with afl-tmin" -ForegroundColor White
    Write-Host "  5. Report to Microsoft MSRC: https://msrc.microsoft.com/create-report" -ForegroundColor White
    Write-Host ""
    Write-Host "For detailed reporting guidance, see: VULNERABILITY_HUNTING_GUIDE.md" -ForegroundColor Cyan
}
