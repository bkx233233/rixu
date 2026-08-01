class SupabaseConfig {
  const SupabaseConfig._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const legacyAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get apiKey =>
      publishableKey.isNotEmpty ? publishableKey : legacyAnonKey;

  static bool get isConfigured => url.isNotEmpty && apiKey.isNotEmpty;
}
