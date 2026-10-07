enum Environment { development, staging, production }

class AppConfig {
  final Environment environment;
  final String apiBaseUrl;
  final String appName;

  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.appName,
  });

  static AppConfig current = const AppConfig(
    environment: Environment.production,
    apiBaseUrl: 'https://erp-backend-mskf.onrender.com/graphql/',
    appName: 'ERP Business POS',
  );
}
