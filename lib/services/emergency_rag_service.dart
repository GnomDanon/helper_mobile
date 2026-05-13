import 'dart:convert';

import 'package:flutter/services.dart';

class PreparedResponse {
  const PreparedResponse({
    required this.groundedPrompt,
    required this.matchedSources,
  });

  final String groundedPrompt;
  final List<String> matchedSources;
}

class _TextDoc {
  const _TextDoc({
    required this.assetPath,
    required this.title,
    required this.content,
    required this.tokens,
  });

  final String assetPath;
  final String title;
  final String content;
  final Set<String> tokens;
}

class EmergencyRagService {
  static const String _instructionsDir = 'assets/instructions/';
  static const int _topK = 2;

  Future<List<_TextDoc>>? _loading;
  List<_TextDoc> _docs = const [];

  Future<void> ensureLoaded() {
    return _loading ??= _loadDocs();
  }

  Future<PreparedResponse> prepare(String userText) async {
    await ensureLoaded();
    final normalized = _normalize(userText);
    final queryTokens = _tokenize(normalized);
    final matches = _retrieveTop(queryTokens);

    final prompt = matches.isEmpty
        ? _fallbackPrompt(userText)
        : _groundedPrompt(userText, matches);

    return PreparedResponse(
      groundedPrompt: prompt,
      matchedSources: matches.map((d) => d.title).toList(growable: false),
    );
  }

  Future<List<_TextDoc>> _loadDocs() async {
    final manifestJson = await rootBundle.loadString('AssetManifest.json');
    final manifest = jsonDecode(manifestJson) as Map<String, dynamic>;
    final paths = manifest.keys
        .where(
          (p) =>
              p.startsWith(_instructionsDir) &&
              p.toLowerCase().endsWith('.txt'),
        )
        .toList()
      ..sort();

    final docs = <_TextDoc>[];
    for (final path in paths) {
      final content = (await rootBundle.loadString(path)).trim();
      if (content.isEmpty) continue;
      docs.add(
        _TextDoc(
          assetPath: path,
          title: _titleFromPath(path),
          content: content,
          tokens: _tokenize(_normalize(content)),
        ),
      );
    }
    _docs = docs;
    return docs;
  }

  List<_TextDoc> _retrieveTop(Set<String> queryTokens) {
    if (queryTokens.isEmpty || _docs.isEmpty) return const [];

    final scored = <({int score, _TextDoc doc})>[];
    for (final doc in _docs) {
      var score = 0;
      for (final token in queryTokens) {
        if (doc.tokens.contains(token)) {
          score += token.length >= 8 ? 3 : 1;
        }
      }
      if (score > 0) {
        scored.add((score: score, doc: doc));
      }
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.doc.assetPath.compareTo(b.doc.assetPath);
    });
    return scored.take(_topK).map((e) => e.doc).toList(growable: false);
  }

  String _groundedPrompt(String userText, List<_TextDoc> docs) {
    final sources = docs
        .map((d) => 'Источник: ${d.title}\n${d.content}')
        .join('\n\n-----\n\n');
    return '''
Ты — ассистент первой помощи.
Отвечай только на основе проверенных инструкций ниже.
Если риск для жизни возможен — явно укажи: "Немедленно звоните 112".
Ничего не выдумывай, не добавляй непроверенные препараты и дозировки.
Ответ делай кратким и понятным, сохраняя факты из источников.
Формат ответа:
1) Что делать прямо сейчас
2) Чего не делать
3) Когда срочно 112
4) Что сообщить диспетчеру

Проверенные инструкции:
$sources

Запрос пользователя:
$userText
''';
  }

  String _fallbackPrompt(String userText) {
    return '''
Ты — ассистент первой помощи.
Если не хватает данных, задай 2-3 коротких уточняющих вопроса.
При любой угрозе жизни укажи: "Немедленно звоните 112".
Не давай рискованных советов и не придумывай факты.
Отвечай коротко и структурно:
1) Что делать прямо сейчас
2) Чего не делать
3) Когда срочно 112
4) Что сообщить диспетчеру

Запрос пользователя:
$userText
''';
  }

  String _normalize(String text) {
    return text.toLowerCase().replaceAll('ё', 'е');
  }

  Set<String> _tokenize(String text) {
    final parts = text.split(RegExp(r'[^a-zа-я0-9]+', caseSensitive: false));
    return parts.where((p) => p.length >= 3).toSet();
  }

  String _titleFromPath(String path) {
    final fileName = path.split('/').last;
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0) return fileName;
    return fileName.substring(0, dot).replaceAll('_', ' ');
  }
}
