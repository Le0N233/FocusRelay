# Set awareness before creating the first HWND. EXE also declares it in its manifest.
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class GuardDpi {
 [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr context);
 [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr hwnd);
}
'@
try {$null=[GuardDpi]::SetProcessDpiAwarenessContext([IntPtr](-4))} catch {}
Add-Type -Path (Join-Path $PSScriptRoot 'forest-art.cs') -ReferencedAssemblies System.Drawing,System.Windows.Forms
