import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/chat_message.dart';

/// Соответствует `ChatService` + `apiService.post` из Vue-клиента.
class ChatApiService {
  ChatApiService({http.Client? httpClient}) : _client = httpClient ?? http.Client();

  final http.Client _client;

  static String _historyPayload(List<ChatMessage> history) {
    final br = RegExp(r'<br\s*/?>', caseSensitive: false);
    return history
        .map((m) {
          final plain = m.text.replaceAll(br, '\n');
          return '${m.sender.name}: $plain';
        })
        .join('\n');
  }

  static String _formatAssistantText(String text) {
    return text.replaceAll('\n', '<br/>');
  }

  Future<ChatMessage?> sendMessage(
    String text,
    List<ChatMessage> history,
  ) async {
    final base = AppConfig.normalizedApiBase;
    if (base.isEmpty) {
      return null;
    }

    final uri = Uri.parse('${base}gpt/ask');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    try {
      final response = await _client.post(
        uri,
        headers: headers,
        body: jsonEncode({
          'text': text,
          'history': _historyPayload(history),
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final body = response.body;
      if (body.isEmpty) {
        return const ChatMessage(text: '', sender: MessageSender.system);
      }

      final map = jsonDecode(body) as Map<String, dynamic>;
      final reply = map['text'] as String? ?? '';
      return ChatMessage(
        text: _formatAssistantText(reply),
        sender: MessageSender.system,
      );
    } catch (_) {
      return null;
    }
  }
}
