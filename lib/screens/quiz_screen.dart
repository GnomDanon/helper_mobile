import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/quiz_question.dart';
import '../theme/app_colors.dart';
import '../widgets/emergency_footer.dart';
import '../widgets/orange_buttons.dart';
import '../widgets/rescue_header.dart';

/// Квиз как `QuizPage.vue` (данные из `public/quiz.json`).
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<QuizQuestion> _questions = [];
  bool _loading = true;
  int _index = 0;
  String? _selected;
  int _score = 0;
  bool _finished = false;
  bool _showExplanation = false;
  Timer? _explanationTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _explanationTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString('assets/quiz.json');
      final list = jsonDecode(raw) as List<dynamic>;
      final parsed =
          list.map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>)).toList();
      parsed.shuffle(Random());
      if (mounted) {
        setState(() {
          _questions = parsed;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  QuizQuestion? get _current =>
      _index >= 0 && _index < _questions.length ? _questions[_index] : null;

  String get _correctLetter {
    final c = _current;
    if (c == null) return '';
    for (final a in c.answers) {
      if (a.correct) return a.letter;
    }
    return '';
  }

  void _startExplanationTimer() {
    _explanationTimer?.cancel();
    _explanationTimer = Timer(const Duration(seconds: 15), () {
      if (mounted) setState(() => _showExplanation = false);
    });
  }

  void _selectAnswer(String letter) {
    if (_selected != null) return;
    setState(() {
      _selected = letter;
      if (letter == _correctLetter) _score++;
      _showExplanation = true;
    });
    _startExplanationTimer();
  }

  void _revealExplanation() {
    setState(() => _showExplanation = true);
    _startExplanationTimer();
  }

  void _next() {
    _explanationTimer?.cancel();
    setState(() {
      _showExplanation = false;
      _selected = null;
      if (_index + 1 >= _questions.length) {
        _finished = true;
      } else {
        _index++;
      }
    });
  }

  void _restart() {
    _explanationTimer?.cancel();
    setState(() {
      _questions = List<QuizQuestion>.from(_questions)..shuffle(Random());
      _index = 0;
      _selected = null;
      _score = 0;
      _finished = false;
      _showExplanation = false;
    });
  }

  String _resultText() {
    final n = _questions.length;
    if (n == 0) return '';
    if (_score == n) {
      return 'Отлично! Вы знаете, как действовать в опасных ситуациях.';
    }
    if (_score >= n * 0.7) {
      return 'Хороший результат. Повторите пропущенные темы.';
    }
    return 'Рекомендуем изучить правила поведения при ЧС подробнее.';
  }

  String _answerClass(String letter) {
    if (_selected == null) return 'default';
    if (letter == _correctLetter) return 'correct';
    if (letter == _selected) return 'wrong';
    return 'inactive';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const RescueHeader(mode: HeaderMode.main),
          Expanded(
            child: Container(
              width: double.infinity,
              color: AppColors.quizBackground,
              child: _loading
                  ? const Center(
                      child: Text(
                        'Загрузка вопросов...',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: _finished ? _buildResult() : _buildQuestion(),
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

  Widget _buildResult() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.verified, color: Colors.green, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Тест завершён',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Ваш результат:',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              '$_score / ${_questions.length}',
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: AppColors.orange,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _resultText(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: OrangeOutlineButton(
                    label: 'Пройти заново',
                    onPressed: _restart,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('На главную'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion() {
    final q = _current;
    if (q == null) {
      return const SizedBox.shrink();
    }
    final n = _questions.length;
    final progress = n > 0 ? _index / n : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Вопрос ${_index + 1} из $n',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      'Правильно: $_score',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: const Color(0xFFE9ECEF),
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  q.question,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                ...q.answers.map((a) {
                  final cls = _answerClass(a.letter);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _AnswerTile(
                      letter: a.letter,
                      text: a.text,
                      styleClass: cls,
                      disabled: _selected != null,
                      onTap: () => _selectAnswer(a.letter),
                    ),
                  );
                }),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _showExplanation && _selected != null
                      ? Container(
                          key: const ValueKey('exp'),
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8F0),
                            borderRadius: BorderRadius.circular(8),
                            border: const Border(
                              left: BorderSide(
                                color: AppColors.orange,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info,
                                color: AppColors.orange,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  q.explanation,
                                  style: const TextStyle(fontSize: 13, height: 1.35),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('noexp')),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_selected != null && !_showExplanation)
                      TextButton.icon(
                        onPressed: _revealExplanation,
                        icon: const Icon(Icons.info_outline, size: 18),
                        label: const Text('Пояснение'),
                      )
                    else
                      const Spacer(),
                    if (_selected != null)
                      ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          _index + 1 < n
                              ? 'Следующий вопрос'
                              : 'Завершить тест',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          icon: const Icon(Icons.arrow_back, size: 18, color: Colors.grey),
          label: const Text(
            'На главную',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({
    required this.letter,
    required this.text,
    required this.styleClass,
    required this.disabled,
    required this.onTap,
  });

  final String letter;
  final String text;
  final String styleClass;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color border = const Color(0xFFDEE2E6);
    Color bg = Colors.white;
    Color letterColor = const Color(0xFF495057);

    switch (styleClass) {
      case 'correct':
        border = const Color(0xFF28A745);
        bg = const Color(0xFFE8F5E9);
        letterColor = const Color(0xFF28A745);
        break;
      case 'wrong':
        border = const Color(0xFFDC3545);
        bg = const Color(0xFFFDE8E8);
        letterColor = const Color(0xFFDC3545);
        break;
      case 'inactive':
        border = const Color(0xFFDEE2E6);
        bg = Colors.white;
        letterColor = const Color(0xFF495057);
        break;
      default:
        break;
    }

    final opacity = styleClass == 'inactive' ? 0.5 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border, width: 2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: letterColor,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
