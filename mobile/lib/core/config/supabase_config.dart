/// Supabase client configuration.
/// 
/// IMPORTANT SECURITY RULE:
/// Only the public `anonKey` should ever be stored on the client side.
/// The `service_role` key and JWT secrets must NEVER be added to Flutter.
class SupabaseConfig {
  /// Supabase project URL (e.g. 'https://your-project.supabase.co')
  static String supabaseUrl = 'https://gehuuvotncxpkwpvvbbv.supabase.co';

  /// Supabase public anonymous/publishable key
  static String supabaseAnonKey = 'sb_publishable_cUlg5COpGAahygm9sqxbig_xs-WIxxd';

  /// Standard Deep Link Redirect URL for Supabase Auth (Email Confirmation & OAuth)
  static const String authCallbackUrl = 'io.supabase.wardrobelens://login-callback/';
  static const String authCallbackHost = 'login-callback';
  static const String authCallbackScheme = 'io.supabase.wardrobelens';

  /// Returns true if valid Supabase configuration is present.
  static bool get isConfigured =>
      supabaseUrl.trim().isNotEmpty &&
      supabaseAnonKey.trim().isNotEmpty &&
      supabaseUrl.startsWith('http');
}
