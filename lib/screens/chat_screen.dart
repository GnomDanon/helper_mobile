import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../config/app_config.dart';
import '../models/chat_message.dart';
import '../services/chat_api_service.dart';
import '../services/local_llm_service.dart';
import '../services/chat_storage.dart';
import '../theme/app_colors.dart';
import '../widgets/emergency_footer.dart';
import '../widgets/rescue_header.dart';

/// Экран чата как `ChatPage.vue` (GPT, локальное сохранение, голосовой ввод).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  static const _welcome = ChatMessage(
    text: 'Опишите ситуацию. Я помогу.',
    sender: MessageSender.system,
  );

  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _api = ChatApiService();
  final _localLlm = LocalLlmService.instance;
  final _storage = ChatStorage.instance;
  final stt.SpeechToText _speech = stt.SpeechToText();

  final List<ChatMessage> _messages = [_welcome];
  bool _loading = false;
  bool _listening = false;
  bool _speechReady = false;
  bool _modelPreparing = false;
  LocalModelProgress _localModelProgress = const LocalModelProgress(
    status: LocalModelStatus.idle,
    message: 'Ожидание запуска локальной модели',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _localModelProgress = _localLlm.progress.value;
    _localLlm.progress.addListener(_onLocalModelProgress);
    _init();
  }

  Future<void> _init() async {
    await _storage.ensureOpen();
    final saved = await _storage.loadMessages();
    if (saved.isNotEmpty && mounted) {
      setState(() {
        _messages
          ..clear()
          ..addAll(saved);
      });
      _scrollToBottom();
    }

    _speechReady = await _speech.initialize(
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          if (mounted) setState(() => _listening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (mounted) setState(() {});
    _warmupLocalModel();
  }

  Future<void> _warmupLocalModel() async {
    if (mounted) setState(() => _modelPreparing = true);
    try {
      await _localLlm.ensureReady();
    } catch (_) {
      // Не блокируем чат: модель можно попробовать инициализировать повторно при отправке.
    } finally {
      if (mounted) setState(() => _modelPreparing = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _localLlm.progress.removeListener(_onLocalModelProgress);
    _persist();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onLocalModelProgress() {
    if (!mounted) return;
    setState(() {
      _localModelProgress = _localLlm.progress.value;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _persist();
    }
  }

  Future<void> _persist() async {
    await _storage.saveMessages(_messages);
  }

  Future<void> _scrollToBottom() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!_scroll.hasClients) return;
    await _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _loading) return;

    _input.clear();
    setState(() {
      _messages.add(ChatMessage(text: text, sender: MessageSender.user));
      _loading = true;
    });
    await _persist();
    await _scrollToBottom();

    ChatMessage? reply;
    if (AppConfig.normalizedApiBase.isNotEmpty) {
      reply = await _api.sendMessage(text, _messages);
    }

    if (reply == null) {
      final localHistory = List<ChatMessage>.from(_messages);
      var streamMessageIndex = -1;
      var streamedText = '';
      try {
        if (mounted) {
          setState(() {
            _messages.add(
              const ChatMessage(
                text: 'Генерирую локальный ответ...',
                sender: MessageSender.system,
              ),
            );
            streamMessageIndex = _messages.length - 1;
          });
          await _scrollToBottom();
        }

        await for (final token in _localLlm.streamResponse(text, localHistory)) {
          streamedText += token;
          if (!mounted || streamMessageIndex < 0) continue;
          setState(() {
            _messages[streamMessageIndex] = ChatMessage(
              text: streamedText.isEmpty
                  ? 'Генерирую локальный ответ...'
                  : streamedText.replaceAll('\n', '<br/>'),
              sender: MessageSender.system,
            );
          });
        }

        if (streamMessageIndex >= 0) {
          reply = _messages[streamMessageIndex];
        } else {
          reply = ChatMessage(
            text: streamedText.isEmpty
                ? 'Не удалось получить ответ локально.'
                : streamedText.replaceAll('\n', '<br/>'),
            sender: MessageSender.system,
          );
        }
      } catch (_) {
        if (mounted && streamMessageIndex >= 0) {
          setState(() {
            _messages[streamMessageIndex] = const ChatMessage(
              text: 'Сервер недоступен и локальная модель не готова. '
                  'Проверьте LOCAL_MODEL_URL и подключение.',
              sender: MessageSender.system,
            );
          });
          reply = _messages[streamMessageIndex];
        }
      }

      reply ??= const ChatMessage(
        text: 'Сервер недоступен и локальная модель не готова. '
            'Проверьте LOCAL_MODEL_URL и подключение.',
        sender: MessageSender.system,
      );
    }

    if (!mounted) return;

    setState(() {
      _loading = false;
      final isAlreadyStreamed =
          _messages.isNotEmpty && identical(_messages.last, reply);
      if (!isAlreadyStreamed) {
        _messages.add(
          reply ??
              const ChatMessage(
                text: 'Ошибка получения ответа.',
                sender: MessageSender.system,
              ),
        );
      }
    });
    await _persist();
    await _scrollToBottom();
  }

  Future<void> _toggleMic() async {
    if (!_speechReady || _loading) return;

    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }

    setState(() => _listening = true);
    try {
      await _speech.listen(
        onResult: (r) {
          if (r.finalResult) {
            final t = r.recognizedWords.trim();
            if (t.isNotEmpty) {
              _input.text = t;
            }
            if (mounted) setState(() => _listening = false);
          }
        },
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 60),
        localeId: 'ru_RU',
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
          cancelOnError: true,
          partialResults: false,
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _listening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          RescueHeader(
            mode: HeaderMode.chat,
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    children: [
                      if (_modelPreparing ||
                          _localModelProgress.isActive ||
                          AppConfig.localModelDiagnostics)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _progressTitle(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const SizedBox(height: 6),
                              if (_localModelProgress.isActive)
                                LinearProgressIndicator(
                                  value: _localModelProgress.fraction,
                                  color: AppColors.orange,
                                  minHeight: 4,
                                )
                              else
                                Text(
                                  'Диагностика: ${_diagnosticReason()}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black45,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.all(12),
                          itemCount: _messages.length + (_loading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_loading && index == _messages.length) {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: _bubbleShell(
                                  child: const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.orange,
                                    ),
                                  ),
                                  user: false,
                                ),
                              );
                            }
                            final msg = _messages[index];
                            final user = msg.sender == MessageSender.user;
                            return Align(
                              alignment: user
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: _bubbleShell(
                                user: user,
                                child: user
                                    ? SelectableText(
                                        msg.text,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          height: 1.35,
                                        ),
                                      )
                                    : Html(
                                        data: msg.text,
                                        shrinkWrap: true,
                                        style: {
                                          'body': Style(
                                            margin: Margins.zero,
                                            padding: HtmlPaddings.zero,
                                            color: const Color(0xFF212529),
                                            fontSize: FontSize(15),
                                          ),
                                          'p': Style(
                                            margin: Margins.zero,
                                            padding: HtmlPaddings.zero,
                                          ),
                                        },
                                      ),
                              ),
                            );
                          },
                        ),
                      ),
                      Material(
                        color: const Color(0xFFF8F9FA),
                        child: Container(
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Color(0xFFDEE2E6)),
                            ),
                          ),
                          padding: EdgeInsets.fromLTRB(
                            12,
                            12,
                            12,
                            12,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _input,
                                  minLines: 1,
                                  maxLines: 4,
                                  enabled: !_listening && !_loading,
                                  decoration: InputDecoration(
                                    hintText: _loading
                                        ? 'Пожалуйста, подождите...'
                                        : 'Введите сообщение...',
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: AppColors.orange,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  onSubmitted: (_) => _send(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 48,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: (_listening || _loading)
                                      ? null
                                      : _send,
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    backgroundColor: AppColors.orange,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Icon(Icons.send, size: 22),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 48,
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: _loading || !_speechReady
                                      ? null
                                      : _toggleMic,
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    backgroundColor: _listening
                                        ? AppColors.orange
                                        : null,
                                    foregroundColor:
                                        _listening ? Colors.white : null,
                                    side: BorderSide(
                                      color: _listening
                                          ? AppColors.orange
                                          : Colors.grey.shade400,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.mic,
                                    color: _listening ? Colors.white : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const EmergencyFooter(),
        ],
      ),
    );
  }

  Widget _bubbleShell({required Widget child, required bool user}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.75,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: user ? AppColors.orange : AppColors.systemBubble,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(user ? 18 : 4),
          bottomRight: Radius.circular(user ? 4 : 18),
        ),
      ),
      child: child,
    );
  }

  String _progressTitle() {
    final fraction = _localModelProgress.fraction;
    final percent = fraction == null ? null : (fraction * 100).toStringAsFixed(1);
    if (percent == null) {
      return _localModelProgress.message;
    }
    return '${_localModelProgress.message} ($percent%)';
  }

  String _diagnosticReason() {
    switch (_localModelProgress.status) {
      case LocalModelStatus.skipped:
      case LocalModelStatus.error:
      case LocalModelStatus.ready:
      case LocalModelStatus.idle:
        return _localModelProgress.message;
      case LocalModelStatus.preparing:
      case LocalModelStatus.downloading:
      case LocalModelStatus.loading:
        return 'Скачивание запущено';
    }
  }
}
