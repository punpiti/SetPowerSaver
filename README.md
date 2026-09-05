# Temporary Laptop Modes — temporary power settings for Windows

Choose a power mode for the moment you are in, then return safely to your
previous settings when it ends. This project includes two ways to use the same
idea:

- **Temporary Laptop Modes** — a Windows system-tray app for everyday use.
- **SetPowerMode.ps1** — a PowerShell command-line companion for developers
  and automation.

The first Store release is **v0.1.0**.

## System tray app

The tray app is for moments rather than permanent laptop tuning: writing,
coding, presenting, travelling, a quiet overnight job, or a short intensive
build. Choose a mode from the notification-area icon; it snapshots the current
settings and restores them automatically when the mode ends.

Available temporary modes: Focus, Coding, Presentation, Battery, Quiet, and
Compile Boost. The menu follows Windows light/dark preference and clearly shows
the active mode and restoration time.

### Run from source

On Windows with the .NET 8 SDK:

```powershell
dotnet build .\TemporaryLaptopModes\TemporaryLaptopModes.csproj -c Release
dotnet run --project .\TemporaryLaptopModes\TemporaryLaptopModes.csproj
```

The app has no main window. Find its gray `N` icon in the Windows notification
area (possibly under the `^` overflow menu), then right-click it to choose a
mode. Use **Exit** from that menu so an active mode can be restored safely.

Some PC policies require Administrator rights for `powercfg` changes. In that
case, start the built executable with **Run as administrator**. Some laptop/OEM
plans do not expose a configurable Turbo Boost setting; the app still applies
the CPU-limit portion of a mode.

## PowerShell command-line version

**EN**
One Windows PowerShell 5.x script for switching power behavior quickly.

`SetPowerMode.ps1` supports these human-centered modes:

- `Focus` — For writing, reading, watching stocks, or dashboards. The screen
  stays on and the PC stays awake even when you do not touch the keyboard;
  CPU is capped at 60% on AC / 50% on battery for quiet operation.
- `Coding` — For editors, terminals, and moderate builds. CPU is capped at
  75% on AC (60% on battery), Turbo Boost is disabled, and normal sleep
  timeouts remain enabled.
- `Presentation` — Keeps the display and PC awake for teaching, meetings, or
  screen sharing, while retaining moderate CPU limits.
- `Battery` — Power Saver, CPU capped at 50% on AC / 40% on battery, Turbo
  Boost disabled, and shorter display/sleep timeouts.
- `Quiet` *(advanced)* — For a server, download, or long-running job. The PC
  never sleeps, but the display turns off after one minute; CPU is capped at
  50% on AC / 40% on battery for quiet/cool operation.
- `Normal` — Restore standard timeouts, a 100% CPU limit, and Turbo Boost.
- `CompileBoost` — Prevent idle sleep/display-off and temporarily switch to
  High performance for a large build or test. Ctrl+C stops it and restores
  the prior plan. `KeepAliveMaxPerf` remains as a compatible alias.
- `PowerSaver` *(advanced)* — The original energy-saving configuration,
  retained for compatibility.

**TH**
สคริปต์ PowerShell 5.x ไฟล์เดียว สำหรับสลับพฤติกรรมการจัดการพลังงานของ
Windows ตามลักษณะการใช้งาน: `SetPowerMode.ps1`

- `Focus` — สำหรับเขียนงาน อ่านเอกสาร ดูหุ้น หรือ dashboard: จอและเครื่อง
  ไม่หลับ แม้ไม่ได้แตะคีย์บอร์ด; จำกัด CPU ที่ 60% เมื่อเสียบปลั๊ก / 50%
  บนแบตเตอรี่เพื่อความเงียบ
- `Coding` — สำหรับ editor, terminal และ build ระดับทั่วไป: จำกัด CPU ที่
  75% เมื่อเสียบปลั๊ก (60% บนแบตเตอรี่), ปิด Turbo Boost แต่ยังให้ sleep
  ตามเวลาปกติ
- `Presentation` — กันจอดับและเครื่องหลับสำหรับสอน ประชุม หรือแชร์จอ โดยยัง
  จำกัด CPU ระดับกลางเพื่อลดความร้อน
- `Battery` — Power Saver จำกัด CPU ที่ 50% เมื่อเสียบปลั๊ก / 40% บนแบตเตอรี่
  ปิด Turbo Boost และตั้งเวลาแสดงผล/สลีปให้สั้น
- `Quiet` *(advanced)* — สำหรับรัน server, download หรือ job นาน ๆ: เครื่อง
  ไม่ sleep แต่จอดับใน 1 นาที; จำกัด CPU ที่ 50% เมื่อเสียบปลั๊ก / 40% บน
  แบตเตอรี่เพื่อให้เงียบและเย็น
- `Normal` — คืน timeout มาตรฐาน ปลด CPU กลับเป็น 100% และเปิด Turbo Boost
- `CompileBoost` — กันเครื่องไม่ให้หลับ/ปิดจอ และเปลี่ยนเป็น High performance
  ชั่วคราวสำหรับ build/test ใหญ่ กด Ctrl+C เพื่อหยุดและคืนแผนพลังงานเดิม
  (ยังเรียก `KeepAliveMaxPerf` เพื่อความเข้ากันได้)
- `PowerSaver` *(advanced)* — ค่าประหยัดพลังงานแบบดั้งเดิม เก็บไว้เพื่อให้
  ใช้คำสั่งเดิมได้

## Usage / วิธีใช้

Open **PowerShell as Administrator**, then choose a mode:

```powershell
.\SetPowerMode.ps1 -Mode Coding   # recommended for programming
.\SetPowerMode.ps1 -Mode Focus
.\SetPowerMode.ps1 -Mode Presentation
.\SetPowerMode.ps1 -Mode Battery
.\SetPowerMode.ps1 -Mode Quiet
.\SetPowerMode.ps1 -Mode Normal
.\SetPowerMode.ps1 -Mode PowerSaver
.\SetPowerMode.ps1 -Mode CompileBoost
```

## Distribution / การแจกจ่าย

Two release paths are included:

### Portable ZIP — test users and GitHub Releases

Build a self-contained ZIP; users extract it and run the EXE without installing
.NET. This is ideal for a small test group and GitHub Releases.

```powershell
.\scripts\Publish-Portable.ps1 -Version 0.1.0
```

### MSIX — Microsoft Store

MSIX provides a clean install, updates, package identity, and is the preferred
path for Microsoft Store publishing. First reserve the app name in Partner
Center, which gives the exact **Identity name** and **Publisher** values. Then
install the Windows SDK (for `makeappx.exe`) and build the package:

```powershell
.\scripts\New-Msix.ps1 `
  -IdentityName 'PartnerCenterIdentityName' `
  -Publisher 'CN=PartnerCenterPublisher' `
  -PublisherDisplayName 'Your Publisher Name' `
  -Version 0.1.0.0
```

If the Windows SDK is installed outside its default `C:` location, add its
installation root, for example: `-WindowsSdkRoot 'D:\DevTools\Windows Kits\10'`.

Submit the generated `artifacts\msix\TemporaryLaptopModes-0.1.0.0.msix` to
Microsoft Store. Store distribution re-signs MSIX packages; for direct MSIX
downloads outside the Store, provide `-CertificatePath` for a CA-trusted code
signing certificate.

The Store-submission copy, privacy policy, release notes, and a real-screenshot
plan are in [`store/`](store/).
