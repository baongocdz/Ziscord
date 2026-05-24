import 'dart:convert';

import 'package:http/http.dart' as http;

class AiMessage {
  final String role; // 'user' | 'assistant'
  final String text;

  AiMessage({required this.role, required this.text});

  Map<String, dynamic> toMap() => {'role': role, 'text': text};

  factory AiMessage.fromMap(Map<String, dynamic> m) =>
      AiMessage(role: m['role'] ?? 'user', text: m['text'] ?? '');
}

class AiService {
  static const String _apiKey =
      String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
  static const String _model = 'llama-3.3-70b-versatile';
  static const String _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';

  static const String _systemPrompt =
      'Bạn là một trợ lý AI thân thiện trong app chat Ziscord. '
      'Trả lời ngắn gọn, hữu ích, bằng tiếng Việt trừ khi người dùng dùng ngôn ngữ khác.';

  static bool get hasKey => _apiKey.isNotEmpty;

  Future<String> sendMessage(List<AiMessage> history) async {
    if (_apiKey.isEmpty) {
      throw Exception(
          'Thiếu GROQ_API_KEY. Chạy app với --dart-define=GROQ_API_KEY=gsk_... (xem README).');
    }

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': _systemPrompt},
      ...history.map((m) => {
            'role': m.role == 'model' ? 'assistant' : m.role,
            'content': m.text,
          }),
    ];

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': messages,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('AI lỗi (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('AI không trả lời');
    }
    return (choices.first['message']?['content'] as String?) ?? '';
  }
}
