class QuizAnswer {
  const QuizAnswer({
    required this.letter,
    required this.text,
    this.correct = false,
  });

  final String letter;
  final String text;
  final bool correct;

  factory QuizAnswer.fromJson(Map<String, dynamic> json) {
    return QuizAnswer(
      letter: json['letter'] as String,
      text: json['text'] as String,
      correct: json['correct'] as bool? ?? false,
    );
  }
}

class QuizQuestion {
  const QuizQuestion({
    required this.question,
    required this.answers,
    required this.explanation,
  });

  final String question;
  final List<QuizAnswer> answers;
  final String explanation;

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final list = json['answers'] as List<dynamic>? ?? [];
    return QuizQuestion(
      question: json['question'] as String,
      answers: list
          .map((e) => QuizAnswer.fromJson(e as Map<String, dynamic>))
          .toList(),
      explanation: json['explanation'] as String? ?? '',
    );
  }
}
