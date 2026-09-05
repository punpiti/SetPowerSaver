using System.Diagnostics;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using Microsoft.Win32;

namespace TemporaryLaptopModes;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        ApplicationConfiguration.Initialize();
        Application.Run(new TrayApplication());
    }
}

internal sealed class TrayApplication : ApplicationContext
{
    private const int FocusMinutes = 90;
    private const int PresentationMinutes = 120;
    private const int QuietMinutes = 480;
    private const int CompileBoostMinutes = 45;

    private readonly NotifyIcon _trayIcon;
    private readonly ContextMenuStrip _menu;
    private readonly ToolStripLabel _statusItem;
    private readonly System.Windows.Forms.Timer _timer;
    private readonly string _statePath;
    private ActiveMode? _active;
    private bool _restoring;

    public TrayApplication()
    {
        _statePath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "TemporaryLaptopModes", "active-mode.json");

        _menu = BuildMenu(out _statusItem);
        _trayIcon = new NotifyIcon
        {
            ContextMenuStrip = _menu,
            Visible = true,
            Text = "Temporary Laptop Modes · Normal",
            Icon = CreateIcon(Color.SlateGray, "N")
        };
        _trayIcon.DoubleClick += (_, _) => _trayIcon.ContextMenuStrip?.Show(Cursor.Position);
        SetNormalTrayState();

        _timer = new System.Windows.Forms.Timer { Interval = 20_000 };
        _timer.Tick += (_, _) => CheckForRestore();
        _timer.Start();

        RestoreInterruptedMode();
        Notify("Temporary Laptop Modes is ready", "Right-click the tray icon to choose a temporary mode.");
    }

    private ContextMenuStrip BuildMenu(out ToolStripLabel statusItem)
    {
        var menu = new ContextMenuStrip();
        menu.ShowImageMargin = true;
        menu.ShowCheckMargin = false;
        menu.Padding = new Padding(7, 7, 7, 6);
        menu.ImageScalingSize = new Size(22, 22);
        menu.Opening += (_, _) => ApplyMenuTheme(menu);

        statusItem = new ToolStripLabel
        {
            AutoSize = false,
            Size = new Size(300, 52),
            Font = new Font(FontFamily.GenericSansSerif, 10, FontStyle.Bold),
            TextAlign = ContentAlignment.MiddleLeft,
            ImageAlign = ContentAlignment.MiddleLeft,
            TextImageRelation = TextImageRelation.ImageBeforeText,
            Margin = new Padding(3, 1, 3, 5)
        };
        menu.Items.Add(CreateSectionLabel("CURRENT STATUS"));
        menu.Items.Add(statusItem);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(CreateSectionLabel("START A TEMPORARY MODE"));
        menu.Items.Add(CreateModeItem("Focus", "Write · read · stocks", Color.MediumSlateBlue, "F", ModeKind.Focus));
        menu.Items.Add(CreateModeItem("Coding", "Editor · terminal · builds", Color.RoyalBlue, "C", ModeKind.Coding));
        menu.Items.Add(CreateModeItem("Presentation", "Keep screen on · 2 hours", Color.DarkOrange, "P", ModeKind.Presentation));
        menu.Items.Add(CreateModeItem("Battery", "Save power until plugged in", Color.SeaGreen, "B", ModeKind.Battery));
        menu.Items.Add(CreateModeItem("Quiet", "Server / long job · 8 hours", Color.MidnightBlue, "Q", ModeKind.Quiet));
        menu.Items.Add(CreateModeItem("Compile Boost", "High performance · 45 min", Color.Crimson, "+", ModeKind.CompileBoost));
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(CreateActionItem("Restore normal now", "Return to the saved power settings", Color.SlateGray, "N", (_, _) => Restore("Restored by you")));
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(CreateActionItem("Exit", "Restore first, then close", Color.IndianRed, "×", (_, _) => ExitThread()));
        ApplyMenuTheme(menu);
        return menu;
    }

    private ToolStripLabel CreateSectionLabel(string text) => new()
    {
        Text = text,
        AutoSize = false,
        Size = new Size(300, 24),
        Font = new Font(FontFamily.GenericSansSerif, 7.5f, FontStyle.Bold),
        TextAlign = ContentAlignment.MiddleLeft,
        Margin = new Padding(8, 2, 3, 2)
    };

    private ToolStripMenuItem CreateModeItem(string title, string description, Color color, string glyph, ModeKind mode) =>
        CreateActionItem(title, description, color, glyph, (_, _) => StartMode(mode));

    private ToolStripMenuItem CreateActionItem(string title, string description, Color color, string glyph, EventHandler action) => new ToolStripMenuItem()
    {
        Text = $"{title}\n{description}",
        Image = CreateMenuGlyph(color, glyph),
        AutoSize = false,
        Size = new Size(300, 46),
        Font = new Font(FontFamily.GenericSansSerif, 9, FontStyle.Regular),
        TextImageRelation = TextImageRelation.ImageBeforeText,
        ImageAlign = ContentAlignment.MiddleLeft,
        TextAlign = ContentAlignment.MiddleLeft,
        Margin = new Padding(1),
        Padding = new Padding(4, 1, 4, 1),
        ToolTipText = description
    }.Also(item => item.Click += action);

    private void StartMode(ModeKind mode)
    {
        try
        {
            Restore(null, announce: false);
            var snapshot = PowerManager.Capture();
            var active = ActiveMode.Create(mode, snapshot);
            // Persist before changing settings, so a later restart can restore
            // the baseline even if applying a mode is interrupted.
            _active = active;
            SaveState(active);

            switch (mode)
            {
                case ModeKind.Focus:
                    PowerManager.SetProcessorLimits(60, 50, disableBoost: true);
                    PowerManager.KeepAwake(keepDisplayOn: true);
                    break;
                case ModeKind.Coding:
                    PowerManager.SetProcessorLimits(75, 60, disableBoost: true);
                    break;
                case ModeKind.Presentation:
                    PowerManager.SetProcessorLimits(75, 60, disableBoost: true);
                    PowerManager.KeepAwake(keepDisplayOn: true);
                    break;
                case ModeKind.Battery:
                    PowerManager.SetProcessorLimits(50, 40, disableBoost: true);
                    PowerManager.SetTimeouts(5, 15, 60, 2, 10, 30);
                    break;
                case ModeKind.Quiet:
                    PowerManager.SetProcessorLimits(50, 40, disableBoost: true);
                    PowerManager.SetTimeouts(1, 0, 0, 1, 0, 0);
                    PowerManager.KeepAwake(keepDisplayOn: false);
                    break;
                case ModeKind.CompileBoost:
                    PowerManager.SetActiveScheme("SCHEME_MIN");
                    PowerManager.KeepAwake(keepDisplayOn: true);
                    break;
            }

            PowerManager.ApplyCurrentScheme();
            SetTrayState(active);
            Notify($"{active.DisplayName} is active", active.EndDescription);
        }
        catch (Exception ex)
        {
            Notify("Could not apply mode", $"{ex.Message} Try running the app as Administrator.");
            Restore("Restored after an error", announce: false);
        }
    }

    private void CheckForRestore()
    {
        if (_active is null || _restoring) return;

        if (_active.Mode == ModeKind.Battery && SystemInformation.PowerStatus.PowerLineStatus == PowerLineStatus.Online)
        {
            Restore("Battery mode ended because power was connected");
        }
        else if (_active.EndAtUtc is { } endAt && DateTimeOffset.UtcNow >= endAt)
        {
            Restore($"{_active.DisplayName} time ended");
        }
        else
        {
            SetTrayState(_active);
        }
    }

    private void Restore(string? reason, bool announce = true)
    {
        if (_active is null || _restoring) return;
        _restoring = true;
        try
        {
            PowerManager.ClearKeepAwake();
            PowerManager.Restore(_active.Snapshot);
            DeleteState();
            _active = null;
            SetNormalTrayState();
            if (announce && reason is not null)
                Notify("Power settings restored", reason + ". Your previous settings are back.");
        }
        catch (Exception ex)
        {
            Notify("Restore needs attention", ex.Message + ". Keep this app open and try Restore normal now.");
        }
        finally
        {
            _restoring = false;
        }
    }

    private void RestoreInterruptedMode()
    {
        if (!File.Exists(_statePath)) return;
        try
        {
            var state = JsonSerializer.Deserialize<ActiveMode>(File.ReadAllText(_statePath));
            if (state is null) return;
            _active = state;
            Restore("A previous session was restored");
        }
        catch
        {
            DeleteState();
        }
    }

    private void SetTrayState(ActiveMode active)
    {
        var remaining = active.EndAtUtc is { } end
            ? $" · {Math.Max(0, Math.Ceiling((end - DateTimeOffset.UtcNow).TotalMinutes))} min left"
            : " · until plugged in";
        _trayIcon.Icon = CreateIcon(active.Color, active.Glyph);
        _trayIcon.Text = TrimTooltip($"Temporary Laptop Modes · {active.DisplayName}{remaining}");
        SetMenuStatus(active.DisplayName, active.EndDescription, active.Color, active.Glyph);
    }

    private void SetNormalTrayState()
    {
        _trayIcon.Icon = CreateIcon(Color.SlateGray, "N");
        _trayIcon.Text = "Temporary Laptop Modes · Normal";
        SetMenuStatus("Normal", "Ready for your next moment", Color.SlateGray, "N");
    }

    private void Notify(string title, string message) =>
        // ToolTipIcon.Info produces Windows' blue information badge. None lets
        // the notification stay visually associated with the current tray icon.
        _trayIcon.ShowBalloonTip(7_000, title, message, ToolTipIcon.None);

    private void SaveState(ActiveMode state)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(_statePath)!);
        File.WriteAllText(_statePath, JsonSerializer.Serialize(state));
    }

    private void DeleteState()
    {
        if (File.Exists(_statePath)) File.Delete(_statePath);
    }

    protected override void ExitThreadCore()
    {
        Restore("The app closed", announce: false);
        _timer.Dispose();
        _trayIcon.Visible = false;
        _trayIcon.Dispose();
        base.ExitThreadCore();
    }

    private static string TrimTooltip(string text) => text.Length <= 63 ? text : text[..63];

    private static Icon CreateIcon(Color color, string glyph)
    {
        using var bitmap = new Bitmap(32, 32);
        using (var graphics = Graphics.FromImage(bitmap))
        {
            graphics.SmoothingMode = SmoothingMode.AntiAlias;
            graphics.Clear(Color.Transparent);
            using var brush = new SolidBrush(color);
            graphics.FillEllipse(brush, 1, 1, 30, 30);
            using var font = new Font(FontFamily.GenericSansSerif, 18, FontStyle.Bold, GraphicsUnit.Pixel);
            var size = graphics.MeasureString(glyph, font);
            graphics.DrawString(glyph, font, Brushes.White, (32 - size.Width) / 2, (32 - size.Height) / 2 - 1);
        }
        var handle = bitmap.GetHicon();
        using var temporary = Icon.FromHandle(handle);
        return (Icon)temporary.Clone();
    }

    private void SetMenuStatus(string title, string subtitle, Color color, string glyph)
    {
        _statusItem.Text = $"{title}\n{subtitle}";
        _statusItem.Image = CreateMenuGlyph(color, glyph);
    }

    private static Bitmap CreateMenuGlyph(Color color, string glyph)
    {
        var bitmap = new Bitmap(28, 28);
        using var graphics = Graphics.FromImage(bitmap);
        graphics.SmoothingMode = SmoothingMode.AntiAlias;
        graphics.Clear(Color.Transparent);
        using var brush = new SolidBrush(color);
        graphics.FillEllipse(brush, 1, 1, 26, 26);
        using var font = new Font(FontFamily.GenericSansSerif, 14, FontStyle.Bold, GraphicsUnit.Pixel);
        var size = graphics.MeasureString(glyph, font);
        graphics.DrawString(glyph, font, Brushes.White, (28 - size.Width) / 2, (28 - size.Height) / 2 - 1);
        return bitmap;
    }

    private void ApplyMenuTheme(ContextMenuStrip menu)
    {
        var dark = IsWindowsDarkMode();
        var background = dark ? Color.FromArgb(35, 35, 38) : Color.FromArgb(252, 252, 253);
        var foreground = dark ? Color.FromArgb(242, 242, 245) : Color.FromArgb(31, 31, 34);
        var muted = dark ? Color.FromArgb(166, 166, 176) : Color.FromArgb(105, 105, 114);

        menu.Renderer = new ThemedMenuRenderer(dark);
        menu.BackColor = background;
        menu.ForeColor = foreground;
        foreach (ToolStripItem item in menu.Items)
        {
            item.BackColor = background;
            item.ForeColor = item is ToolStripLabel ? muted : foreground;
        }
        _statusItem.ForeColor = foreground;
    }

    private static bool IsWindowsDarkMode()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
            return Convert.ToInt32(key?.GetValue("AppsUseLightTheme", 1)) == 0;
        }
        catch { return false; }
    }
}

internal sealed class ThemedMenuRenderer : ToolStripProfessionalRenderer
{
    public ThemedMenuRenderer(bool dark) : base(new ThemedColorTable(dark)) { }
}

internal sealed class ThemedColorTable : ProfessionalColorTable
{
    private readonly Color _background;
    private readonly Color _selected;
    private readonly Color _border;

    public ThemedColorTable(bool dark)
    {
        UseSystemColors = false;
        _background = dark ? Color.FromArgb(35, 35, 38) : Color.FromArgb(252, 252, 253);
        _selected = dark ? Color.FromArgb(63, 63, 70) : Color.FromArgb(229, 241, 255);
        _border = dark ? Color.FromArgb(78, 78, 86) : Color.FromArgb(216, 216, 224);
    }

    public override Color ToolStripDropDownBackground => _background;
    public override Color MenuBorder => _border;
    public override Color MenuItemBorder => Color.Transparent;
    public override Color MenuItemSelected => _selected;
    public override Color MenuItemSelectedGradientBegin => _selected;
    public override Color MenuItemSelectedGradientEnd => _selected;
    public override Color ImageMarginGradientBegin => _background;
    public override Color ImageMarginGradientMiddle => _background;
    public override Color ImageMarginGradientEnd => _background;
    public override Color SeparatorDark => _border;
    public override Color SeparatorLight => _background;
}

internal static class FluentExtensions
{
    public static T Also<T>(this T value, Action<T> action)
    {
        action(value);
        return value;
    }
}

internal enum ModeKind { Focus, Coding, Presentation, Battery, Quiet, CompileBoost }

internal sealed class ActiveMode
{
    public ModeKind Mode { get; set; }
    public DateTimeOffset? EndAtUtc { get; set; }
    public PowerSnapshot Snapshot { get; set; } = new();
    [JsonIgnore]
    public string DisplayName => Mode switch
    {
        ModeKind.CompileBoost => "Compile Boost",
        _ => Mode.ToString()
    };
    [JsonIgnore]
    public string Glyph => Mode switch
    {
        ModeKind.Focus => "F", ModeKind.Coding => "C", ModeKind.Presentation => "P",
        ModeKind.Battery => "B", ModeKind.Quiet => "Q", _ => "+"
    };
    [JsonIgnore]
    public Color Color => Mode switch
    {
        ModeKind.Focus => Color.MediumSlateBlue, ModeKind.Coding => Color.RoyalBlue,
        ModeKind.Presentation => Color.DarkOrange, ModeKind.Battery => Color.SeaGreen,
        ModeKind.Quiet => Color.MidnightBlue, _ => Color.Crimson
    };
    [JsonIgnore]
    public string EndDescription => EndAtUtc is { } end
        ? $"It will restore automatically at {end.LocalDateTime:t}"
        : "It will restore automatically when you plug in";

    public static ActiveMode Create(ModeKind mode, PowerSnapshot snapshot) => new()
    {
        Mode = mode,
        Snapshot = snapshot,
        EndAtUtc = mode switch
        {
            ModeKind.Focus or ModeKind.Coding => DateTimeOffset.UtcNow.AddMinutes(90),
            ModeKind.Presentation => DateTimeOffset.UtcNow.AddMinutes(120),
            ModeKind.Quiet => DateTimeOffset.UtcNow.AddMinutes(480),
            ModeKind.CompileBoost => DateTimeOffset.UtcNow.AddMinutes(45),
            _ => null
        }
    };
}

internal sealed class PowerSnapshot
{
    public string ActiveScheme { get; set; } = "SCHEME_BALANCED";
    public Dictionary<string, PowerValue> Values { get; set; } = new();
}

internal sealed class PowerValue
{
    public uint Ac { get; set; }
    public uint Dc { get; set; }
}

internal static class PowerManager
{
    private const string Processor = "SUB_PROCESSOR";
    private static readonly (string Group, string Setting)[] Settings =
    [
        (Processor, "PROCTHROTTLEMIN"), (Processor, "PROCTHROTTLEMAX"), (Processor, "PERFBOOSTMODE"),
        ("SUB_VIDEO", "VIDEOIDLE"), ("SUB_SLEEP", "STANDBYIDLE"), ("SUB_SLEEP", "HIBERNATEIDLE")
    ];

    [Flags]
    private enum ExecutionState : uint { Continuous = 0x80000000, SystemRequired = 0x1, DisplayRequired = 0x2 }

    [DllImport("kernel32.dll")]
    private static extern ExecutionState SetThreadExecutionState(ExecutionState flags);

    public static PowerSnapshot Capture()
    {
        var snapshot = new PowerSnapshot { ActiveScheme = GetActiveScheme() };
        foreach (var (group, setting) in Settings)
        {
            try
            {
                snapshot.Values[$"{group}/{setting}"] = ReadValue(group, setting);
            }
            catch (InvalidOperationException) when (setting == "PERFBOOSTMODE")
            {
                // Some OEM plans hide or omit the Turbo Boost setting. CPU
                // maximum limits still work, so this must not block a mode.
            }
        }
        return snapshot;
    }

    public static void Restore(PowerSnapshot snapshot)
    {
        foreach (var (group, setting) in Settings)
        {
            if (!snapshot.Values.TryGetValue($"{group}/{setting}", out var value)) continue;
            SetValue(group, setting, value.Ac, value.Dc);
        }
        SetActiveScheme(snapshot.ActiveScheme);
    }

    public static void SetProcessorLimits(uint acMaximum, uint dcMaximum, bool disableBoost)
    {
        SetValue(Processor, "PROCTHROTTLEMIN", 5, 5);
        SetValue(Processor, "PROCTHROTTLEMAX", acMaximum, dcMaximum);
        if (disableBoost) TrySetValue(Processor, "PERFBOOSTMODE", 0, 0);
    }

    public static void SetTimeouts(uint monitorAc, uint standbyAc, uint hibernateAc, uint monitorDc, uint standbyDc, uint hibernateDc)
    {
        SetValue("SUB_VIDEO", "VIDEOIDLE", monitorAc * 60, monitorDc * 60);
        SetValue("SUB_SLEEP", "STANDBYIDLE", standbyAc * 60, standbyDc * 60);
        SetValue("SUB_SLEEP", "HIBERNATEIDLE", hibernateAc * 60, hibernateDc * 60);
    }

    public static void KeepAwake(bool keepDisplayOn) =>
        SetThreadExecutionState(ExecutionState.Continuous | ExecutionState.SystemRequired |
            (keepDisplayOn ? ExecutionState.DisplayRequired : 0));

    public static void ClearKeepAwake() => SetThreadExecutionState(ExecutionState.Continuous);
    public static void ApplyCurrentScheme() => SetActiveScheme("SCHEME_CURRENT");
    public static void SetActiveScheme(string scheme) => Run("/setactive", scheme);

    private static string GetActiveScheme()
    {
        var output = Run("/getactivescheme");
        var match = Regex.Match(output, "[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}");
        if (!match.Success) throw new InvalidOperationException("Could not read the active power plan.");
        return match.Value;
    }

    private static PowerValue ReadValue(string group, string setting)
    {
        var output = Run("/query", "SCHEME_CURRENT", group, setting);
        var ac = Regex.Match(output, "Current AC Power Setting Index:\\s+0x([0-9a-fA-F]+)");
        var dc = Regex.Match(output, "Current DC Power Setting Index:\\s+0x([0-9a-fA-F]+)");
        if (!ac.Success || !dc.Success)
            throw new InvalidOperationException($"Could not read {setting} from the active power plan.");
        return new PowerValue
        {
            Ac = Convert.ToUInt32(ac.Groups[1].Value, 16),
            Dc = Convert.ToUInt32(dc.Groups[1].Value, 16)
        };
    }

    private static void SetValue(string group, string setting, uint ac, uint dc)
    {
        Run("/setacvalueindex", "SCHEME_CURRENT", group, setting, ac.ToString());
        Run("/setdcvalueindex", "SCHEME_CURRENT", group, setting, dc.ToString());
    }

    private static void TrySetValue(string group, string setting, uint ac, uint dc)
    {
        try { SetValue(group, setting, ac, dc); }
        catch (InvalidOperationException) when (setting == "PERFBOOSTMODE")
        {
            // Optional on some laptops and OEM power plans.
        }
    }

    private static string Run(params string[] arguments)
    {
        var startInfo = new ProcessStartInfo("powercfg.exe") { RedirectStandardOutput = true, RedirectStandardError = true, UseShellExecute = false, CreateNoWindow = true };
        foreach (var argument in arguments) startInfo.ArgumentList.Add(argument);
        using var process = Process.Start(startInfo) ?? throw new InvalidOperationException("Could not start powercfg.exe.");
        var output = process.StandardOutput.ReadToEnd();
        var error = process.StandardError.ReadToEnd();
        process.WaitForExit();
        if (process.ExitCode != 0) throw new InvalidOperationException(string.IsNullOrWhiteSpace(error) ? "powercfg.exe failed." : error.Trim());
        return output;
    }
}
