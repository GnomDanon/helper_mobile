import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:llamadart/llamadart.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import '../models/chat_message.dart';

enum LocalModelStatus {
  idle,
  preparing,
  downloading,
  loading,
  ready,
  skipped,
  error,
}

class LocalModelProgress {
  const LocalModelProgress({
    required this.status,
    required this.message,
    this.receivedBytes,
    this.totalBytes,
  });

  final LocalModelStatus status;
  final String message;
  final int? receivedBytes;
  final int? totalBytes;

  bool get isActive =>
      status == LocalModelStatus.preparing ||
      status == LocalModelStatus.downloading ||
      status == LocalModelStatus.loading;

  double? get fraction {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    final received = receivedBytes ?? 0;
    final value = received / total;
    if (value.isNaN || value.isInfinite) return null;
    return value.clamp(0, 1).toDouble();
  }
}

class LocalLlmService {
  LocalLlmService._();

  static final LocalLlmService instance = LocalLlmService._();

  final LlamaEngine _engine = LlamaEngine(LlamaBackend());
  final http.Client _http = http.Client();
  final ValueNotifier<LocalModelProgress> progress = ValueNotifier(
    const LocalModelProgress(
      status: LocalModelStatus.idle,
      message: 'Ожидание запуска локальной модели',
    ),
  );
  Future<void>? _initialization;
  bool _initialized = false;

  Future<void> ensureReady() {
    return _initialization ??= _initialize();
  }

  Future<ChatMessage> generateResponse(
    String userText,
    List<ChatMessage> history,
  ) async {
    final buffer = StringBuffer();

    await for (final token in streamResponse(userText, history)) {
      buffer.write(token);
    }

    final raw = buffer.toString().trim();
    final response = raw.isEmpty ? 'Не удалось получить ответ локально.' : raw;
    return ChatMessage(
      text: response.replaceAll('\n', '<br/>'),
      sender: MessageSender.system,
    );
  }

  Stream<String> streamResponse(
    String userText,
    List<ChatMessage> history,
  ) async* {
    await ensureReady();
    final prompt = _buildPrompt(userText, history);
    final params = GenerationParams(
      maxTokens: AppConfig.localModelMaxTokens,
      temp: AppConfig.localModelTemperature,
      topP: 0.9,
      topK: 30,
      penalty: 1.05,
      stopSequences: const ['Пользователь:', '\nПользователь:'],
    );

    await for (final token in _engine.generate(prompt, params: params)) {
      yield token;
    }
  }

  Future<void> _initialize() async {
    if (_initialized) {
      _setProgress(
        const LocalModelProgress(
          status: LocalModelStatus.skipped,
          message: 'Скачивание не запущено: модель уже инициализирована',
        ),
      );
      return;
    }
    _setProgress(
      const LocalModelProgress(
        status: LocalModelStatus.preparing,
        message: 'Проверка локальной модели',
      ),
    );
    try {
      final modelFile = await _ensureModelFile();
      _setProgress(
        const LocalModelProgress(
          status: LocalModelStatus.loading,
          message: 'Загрузка модели в память устройства',
        ),
      );
      await _engine.loadModel(modelFile.path);
      _initialized = true;
      _setProgress(
        const LocalModelProgress(
          status: LocalModelStatus.ready,
          message: 'Локальная модель готова',
        ),
      );
    } catch (e) {
      if (progress.value.status == LocalModelStatus.skipped) {
        rethrow;
      }
      _setProgress(
        LocalModelProgress(
          status: LocalModelStatus.error,
          message: 'Ошибка инициализации локальной модели: $e',
        ),
      );
      rethrow;
    }
  }

  Future<File> _ensureModelFile() async {
    final supportDir = await getApplicationSupportDirectory();
    final modelDir = Directory('${supportDir.path}${Platform.pathSeparator}models');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }

    final modelFile = File(
      '${modelDir.path}${Platform.pathSeparator}${AppConfig.localModelFileName}',
    );
    if (await modelFile.exists()) {
      _setProgress(
        const LocalModelProgress(
          status: LocalModelStatus.skipped,
          message: 'Скачивание не запущено: модель уже есть на устройстве',
        ),
      );
      return modelFile;
    }

    final remoteUrl = AppConfig.normalizedLocalModelUrl;
    if (remoteUrl.isEmpty) {
      _setProgress(
        const LocalModelProgress(
          status: LocalModelStatus.skipped,
          message: 'Скачивание не запущено: не задан LOCAL_MODEL_URL',
        ),
      );
      throw StateError(
        'LOCAL_MODEL_URL не задан. Укажите ссылку на GGUF через --dart-define.',
      );
    }

    final request = http.Request('GET', Uri.parse(remoteUrl));
    final response = await _http.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Не удалось скачать модель. HTTP ${response.statusCode}',
      );
    }

    final length = response.contentLength;
    final total = (length != null && length > 0) ? length : null;
    _setProgress(
      LocalModelProgress(
        status: LocalModelStatus.downloading,
        message: 'Скачивание локальной модели',
        receivedBytes: 0,
        totalBytes: total,
      ),
    );

    final sink = modelFile.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        _setProgress(
          LocalModelProgress(
            status: LocalModelStatus.downloading,
            message: 'Скачивание локальной модели',
            receivedBytes: received,
            totalBytes: total,
          ),
        );
      }
      await sink.flush();
    } catch (_) {
      await sink.close();
      if (await modelFile.exists()) {
        await modelFile.delete();
      }
      rethrow;
    }
    await sink.close();

    return modelFile;
  }

  void _setProgress(LocalModelProgress value) {
    progress.value = value;
  }

  String _buildPrompt(String userText, List<ChatMessage> history) {
    return '''
${AppConfig.localModelSystemPrompt}

Текущий запрос:
Пользователь: $userText
Ассистент:
''';
  }
}
