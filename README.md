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

| Mode | For | What it changes | Ends after |
| --- | --- | --- | --- |
| Focus | Writing, reading, stocks, and dashboards | CPU capped at 60% AC / 50% battery, Turbo Boost off, screen and PC stay awake | 90 min |
| Coding | Editors, terminals, and moderate builds | CPU capped at 75% AC / 60% battery, Turbo Boost off; timeouts untouched | 90 min |
| Presentation | Teaching, meetings, and screen sharing | CPU capped at 75% AC / 60% battery, Turbo Boost off, screen and PC stay awake | 2 hours |
| Battery | Saving power until the charger is connected | CPU capped at 50% AC / 40% battery, Turbo Boost off, display/sleep/hibernate at 5/15/60 min | Plugging in |
| Quiet | Servers, downloads, and long-running work | CPU capped at 50% AC / 40% battery, Turbo Boost off, display off after 1 min, no sleep | 8 hours |
| Compile Boost | A short burst for demanding builds and tests | High performance plan with every CPU cap cleared: 100% minimum and maximum, Turbo Boost aggressive, no frequency ceiling, active cooling; screen stays on | 45 min |

Turbo Boost is off in the quieter modes because it is the usual cause of sudden
fan noise. Compile Boost is the one mode that turns it back on.

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
