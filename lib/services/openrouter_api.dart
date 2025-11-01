import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class OpenRouterApi {
  OpenRouterApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _defaultBaseUrl = 'https://openrouter.ai/api/v1';

  String get _apiKey {
    final value = dotenv.env['OPENROUTER_API_KEY'];
    if (value == null || value.isEmpty) {
      throw StateError('Missing OPENROUTER_API_KEY. Add it to a .env file.');
    }
    return value;
  }

  String get _model {
    final value = dotenv.env['OPENROUTER_MODEL'];
    if (value == null || value.isEmpty) {
      throw StateError('Missing OPENROUTER_MODEL. Add it to a .env file.');
    }
    return value;
  }

  Uri _endpointUri(String path) {
    final baseUrl = dotenv.env['OPENROUTER_BASE_URL'] ?? _defaultBaseUrl;
    return Uri.parse('$baseUrl$path');
  }

  Future<String> createChatCompletion({
    required List<Map<String, String>> messages,
    String? model,
    double? temperature,
  }) async {
    final uri = _endpointUri('/chat/completions');

    final requestBody = <String, dynamic>{
      'model': model ?? _model,
      'messages': messages,
      if (temperature != null) 'temperature': temperature,
    };

    final headers = <String, String>{
      'Authorization': 'Bearer ${_apiKey}',
      'Content-Type': 'application/json',
      'HTTP-Referer': dotenv.env['OPENROUTER_SITE_URL'] ?? 'https://example.com',
      'X-Title': dotenv.env['OPENROUTER_APP_NAME'] ?? 'Traitus AI Chat',
    };

    final response = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode(requestBody),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'OpenRouter error ${response.statusCode}: ${response.body}',
        uri,
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    final content = choices?.first?['message']?['content'] as String?;
    if (content == null || content.isEmpty) {
      throw StateError('No content returned by model');
    }
    return content;
  }
}


