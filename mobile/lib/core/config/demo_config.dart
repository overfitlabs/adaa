/// Configuration for adaa demo access on web and desktop.
///
/// Values can be supplied at build time using Flutter's `--dart-define` flags:
/// `--dart-define=DEMO_EMAIL=...`
/// `--dart-define=DEMO_PASSWORD=...`
///
/// SECURITY NOTICE:
/// Any credentials compiled into Flutter Web via `--dart-define` become part
/// of the clientside JavaScript bundle and are publicly accessible.
/// Therefore, the demo credentials MUST ONLY correspond to a dedicated,
/// public demo account containing non-sensitive showcase data.
/// NEVER use personal account credentials or privileged administrative secrets.
class DemoConfig {
  static const String demoEmail = String.fromEnvironment('DEMO_EMAIL');
  static const String demoPassword = String.fromEnvironment('DEMO_PASSWORD');

  /// True if both demo email and password were provided at build time.
  static bool get isConfigured =>
      demoEmail.trim().isNotEmpty && demoPassword.trim().isNotEmpty;
}
