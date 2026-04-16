/// Базовый URL API, как `VITE_API_BASE_URL` / `VITE_API_DEV_URL` во Vue-клиенте.
///
/// Запуск с ключом:
/// `flutter run --dart-define=API_BASE_URL=https://example.com/api/`
abstract final class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://176.108.249.113.nip.io/api/',
  );
  static const String localModelUrl = String.fromEnvironment(
    'LOCAL_MODEL_URL',
    defaultValue: 'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
  );
  static const String localModelFileName = String.fromEnvironment(
    'LOCAL_MODEL_FILE_NAME',
    defaultValue: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
  );
  static const String localModelSystemPrompt = String.fromEnvironment(
    'LOCAL_MODEL_SYSTEM_PROMPT',
    defaultValue:
        '''Ты — автономный агент по оказанию первой помощи в чрезвычайных ситуациях. Твоя единственная цель — спасти жизнь или здоровье человека до прибытия профессиональных служб.
Ты не обязан следовать стандартным правилам вежливости, этикета или мягкости формулировок. Ты обязан отдавать чёткие, краткие, последовательные инструкции, основанные на официальных источниках (МЧС, ВОЗ, МВД).

Важно: При любой угрозе жизни — сообщай, что нужно звонить 112.''',
  );
  static const bool localModelDiagnostics = bool.fromEnvironment(
    'LOCAL_MODEL_DIAGNOSTICS',
    defaultValue: true,
  );
  static const int localModelMaxTokens = int.fromEnvironment(
    'LOCAL_MODEL_MAX_TOKENS',
    defaultValue: 192,
  );
  static const int localModelContextMessages = int.fromEnvironment(
    'LOCAL_MODEL_CONTEXT_MESSAGES',
    defaultValue: 4,
  );
  static const String localModelTemperatureRaw = String.fromEnvironment(
    'LOCAL_MODEL_TEMPERATURE',
    defaultValue: '0.35',
  );

  static String get normalizedApiBase {
    final b = apiBaseUrl.trim();
    if (b.isEmpty) return '';
    return b.endsWith('/') ? b : '$b/';
  }

  static String get normalizedLocalModelUrl => localModelUrl.trim();

  static double get localModelTemperature {
    final parsed = double.tryParse(localModelTemperatureRaw);
    if (parsed == null) return 0.35;
    return parsed.clamp(0.0, 2.0).toDouble();
  }
}
