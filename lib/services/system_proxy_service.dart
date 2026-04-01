import 'dart:io';

/// Manages the Windows system-wide proxy settings via the Windows Registry.
///
/// Uses `reg.exe` to write to:
///   HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings
///
/// Then calls `InternetSetOption` via PowerShell so the change takes effect
/// immediately without requiring a reboot or re-login.
///
/// This affects Chrome, Edge, Internet Explorer, and most applications that
/// rely on WinINET. Firefox requires its own proxy setting.
class SystemProxyService {
  SystemProxyService._();

  static const String _regKey =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';

  /// Writes the SOCKS5 proxy to the registry and enables it system-wide.
  static Future<bool> enableProxy(String ip, int port) async {
    if (!Platform.isWindows) return false;
    try {
      // Set proxy server string (socks=IP:PORT)
      await Process.run('reg', [
        'add',
        _regKey,
        '/v', 'ProxyServer',
        '/t', 'REG_SZ',
        '/d', 'socks=$ip:$port',
        '/f',
      ]);

      // Enable proxy (ProxyEnable = 1)
      await Process.run('reg', [
        'add',
        _regKey,
        '/v', 'ProxyEnable',
        '/t', 'REG_DWORD',
        '/d', '1',
        '/f',
      ]);

      // Notify WinINET to re-read proxy settings immediately
      await _refreshWinInet();

      return true;
    } catch (e) {
      _log('Error enabling proxy: $e');
      return false;
    }
  }

  /// Clears the system proxy and disables it.
  static Future<bool> disableProxy() async {
    if (!Platform.isWindows) return false;
    try {
      // Disable proxy (ProxyEnable = 0)
      await Process.run('reg', [
        'add',
        _regKey,
        '/v', 'ProxyEnable',
        '/t', 'REG_DWORD',
        '/d', '0',
        '/f',
      ]);

      // Clear proxy server string
      await Process.run('reg', [
        'add',
        _regKey,
        '/v', 'ProxyServer',
        '/t', 'REG_SZ',
        '/d', '',
        '/f',
      ]);

      // Notify WinINET to re-read proxy settings immediately
      await _refreshWinInet();

      return true;
    } catch (e) {
      _log('Error disabling proxy: $e');
      return false;
    }
  }

  /// Returns `true` if the Windows system proxy is currently enabled.
  static Future<bool> isProxyEnabled() async {
    if (!Platform.isWindows) return false;
    try {
      final result = await Process.run('reg', [
        'query',
        _regKey,
        '/v', 'ProxyEnable',
      ]);
      return result.stdout.toString().contains('0x1');
    } catch (_) {
      return false;
    }
  }

  /// Calls `InternetSetOption` via a small inline PowerShell snippet so that
  /// changes written to the registry take effect immediately for all running
  /// processes, without requiring a reboot.
  static Future<void> _refreshWinInet() async {
    final result = await Process.run('powershell', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      r'''
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class WinInet {
    [DllImport("wininet.dll", SetLastError=true)]
    public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int lpdwBufferLength);
    public const int INTERNET_OPTION_SETTINGS_CHANGED = 39;
    public const int INTERNET_OPTION_REFRESH = 37;
}
"@
[WinInet]::InternetSetOption([IntPtr]::Zero, [WinInet]::INTERNET_OPTION_SETTINGS_CHANGED, [IntPtr]::Zero, 0)
[WinInet]::InternetSetOption([IntPtr]::Zero, [WinInet]::INTERNET_OPTION_REFRESH, [IntPtr]::Zero, 0)
''',
    ]);
    if (result.exitCode != 0) {
      _log('WinInet refresh failed (exit ${result.exitCode}): ${result.stderr}');
    }
  }

  static void _log(String msg) {
    // ignore: avoid_print
    print('[SystemProxyService] $msg');
  }
}
