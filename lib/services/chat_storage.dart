import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/chat_message.dart';

const _boxName = 'chat_db';
const _messagesKey = 'messages';

/// Локальное хранение истории чата (аналог IndexedDB во Vue `ChatPage.vue`).
class ChatStorage {
  ChatStorage._();

  static final ChatStorage instance = ChatStorage._();

  Box<dynamic>? _box;

  Future<void> ensureOpen() async {
    _box ??= await Hive.openBox<dynamic>(_boxName);
  }

  Future<List<ChatMessage>> loadMessages() async {
    await ensureOpen();
    final raw = _box!.get(_messagesKey) as String?;
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveMessages(List<ChatMessage> messages) async {
    await ensureOpen();
    final encoded = jsonEncode(messages.map((m) => m.toJson()).toList());
    await _box!.put(_messagesKey, encoded);
  }

  Future<void> clear() async {
    await ensureOpen();
    await _box!.delete(_messagesKey);
  }
}
