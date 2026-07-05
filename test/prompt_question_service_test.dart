import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_cards/services/prompt_question_service.dart';

void main() {
  test('returns a question from the local pool', () {
    const service = PromptQuestionService();

    final question = service.questionForPhoto('photo_001', random: Random(1));

    expect(PromptQuestionService.defaultQuestions, contains(question));
  });

  test('can be deterministic with injected Random', () {
    const service = PromptQuestionService(questions: ['A', 'B', 'C']);

    final first = service.questionForPhoto('photo_001', random: Random(3));
    final second = service.questionForPhoto('photo_001', random: Random(3));

    expect(first, second);
  });
}
