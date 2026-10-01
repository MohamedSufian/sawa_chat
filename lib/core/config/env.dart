/// Build-time configuration, injected with `--dart-define-from-file=env.json`.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// Optional TURN relay for calls on networks that block direct peer-to-peer
  /// (common on mobile data). Comma-separated URLs, e.g. "turn:host:80,turns:host:443".
  static const turnUrls = String.fromEnvironment('TURN_URLS');
  static const turnUsername = String.fromEnvironment('TURN_USERNAME');
  static const turnCredential = String.fromEnvironment('TURN_CREDENTIAL');

  static List<Map<String, dynamic>> get iceServers => [
    {
      'urls': ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302'],
    },
    if (turnUrls.isNotEmpty) {'urls': turnUrls.split(','), 'username': turnUsername, 'credential': turnCredential},
  ];

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  static const setupHint =
      'Missing Supabase config. Copy env.example.json to env.json, fill it in, '
      'and run with: flutter run --dart-define-from-file=env.json';
}
