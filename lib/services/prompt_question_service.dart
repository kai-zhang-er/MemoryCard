import 'dart:math';

class PromptQuestionService {
  const PromptQuestionService({this.questions = defaultQuestions});

  static const List<String> defaultQuestions = [
    '这张照片你还记得吗？',
    '这是在哪里？',
    '这张照片里最重要的人是谁？',
    '这一天后来发生了什么？',
    '现在再看这张照片，你是什么感觉？',
    '这张照片值得保留的原因是什么？',
  ];

  final List<String> questions;

  String questionForPhoto(String assetId, {Random? random}) {
    final pool = questions.isEmpty ? defaultQuestions : questions;
    final picker = random ?? Random(assetId.hashCode);
    return pool[picker.nextInt(pool.length)];
  }
}
