class AppConfig {
  static const String environment = String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');
  static const bool isProduction = environment == 'production';
  static const bool enableDebugLogs = !isProduction;
  
  // API Configuration
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  
  // Video Configuration
  static const int videoCacheMaxSize = 50; // MB
  static const int videoRetryAttempts = 3;
  static const Duration videoTimeout = Duration(seconds: 30);
  
  // Performance
  static const int maxConcurrentVideoLoads = 3;
  static const Duration cacheExpiration = Duration(hours: 24);
  
  // Security
  static const Duration sessionTimeout = Duration(hours: 24);
  static const int maxLoginAttempts = 5;
  
  static void validateConfig() {
    assert(supabaseUrl.isNotEmpty, 'SUPABASE_URL must be provided');
    assert(supabaseAnonKey.isNotEmpty, 'SUPABASE_ANON_KEY must be provided');
  }
}
