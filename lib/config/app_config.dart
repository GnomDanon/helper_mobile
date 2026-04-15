/// Базовый URL API, как `VITE_API_BASE_URL` / `VITE_API_DEV_URL` во Vue-клиенте.
///
/// Запуск с ключом:
/// `flutter run --dart-define=API_BASE_URL=https://example.com/api/`
abstract final class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get normalizedApiBase {
    final b = apiBaseUrl.trim();
    if (b.isEmpty) return '';
    return b.endsWith('/') ? b : '$b/';
  }
}
