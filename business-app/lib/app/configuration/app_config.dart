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
    environment: Environment.development,
    apiBaseUrl: 'http://127.0.0.1:8000/graphql/', // Routed via adb reverse tcp:8000 tcp:8000
    appName: 'ERP Business POS',
  );
}
