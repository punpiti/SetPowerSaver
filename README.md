# Temporary Laptop Modes

**Power settings for this moment.**

Temporary Laptop Modes is a small Windows system-tray utility for the moments
when normal laptop settings are not quite right: teaching, writing, coding,
travelling, a quiet overnight job, or a short demanding build.

Choose a temporary mode from the tray icon. The app saves the current Windows
power settings first and restores them automatically when the mode ends.

[Microsoft Store](https://apps.microsoft.com/detail/9MZJCVCWB1SH) ·
[Project website](https://punpiti.github.io/SetPowerSaver/)

> The first Microsoft Store release is currently in certification. The Store
> link becomes downloadable once publishing is complete.

## Modes

| Mode | For |
| --- | --- |
| Focus | Writing, reading, stocks, and dashboards |
| Coding | Editors, terminals, and moderate builds |
| Presentation | Teaching, meetings, and screen sharing |
| Battery | Saving power until the charger is connected |
| Quiet | Servers, downloads, and long-running work |
| Compile Boost | A short burst for demanding builds and tests |

The menu follows the Windows light/dark preference, shows the active mode and
restore condition, and offers **Restore normal** at any time.

## Also included: PowerShell CLI

For terminal users and automation, the repository keeps a command-line
companion: [`SetPowerMode.ps1`](SetPowerMode.ps1).

```powershell
.\SetPowerMode.ps1 -Mode Coding
.\SetPowerMode.ps1 -Mode Presentation
.\SetPowerMode.ps1 -Mode Quiet
.\SetPowerMode.ps1 -Mode Normal
```

Run PowerShell as Administrator when Windows policy requires elevated access
to change power settings.

## Build from source

Requires Windows and the .NET 8 SDK:

```powershell
dotnet run --project .\TemporaryLaptopModes\TemporaryLaptopModes.csproj
```

The packaging scripts are in [`scripts/`](scripts/). Store listing copy and the
privacy policy are in [`store/`](store/).

## Privacy

The app has no account, analytics, advertising, cloud sync, or network
services. It changes local Windows power settings only after the user selects a
mode. See the [privacy policy](store/PRIVACY_POLICY.md).

## License

[MIT](LICENSE) © 2026 Punpiti
