import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:traitus/config/default_ai_config.dart';
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
      'Authorization': 'Bearer $_apiKey',
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

  /// Recommend chat IDs (from a fixed allowed set) ranked by suitability
  /// given the user's selected preference/category IDs.
  ///
  /// The model must return a plain JSON array of strings, e.g.:
  /// ["coding", "research", "productivity"]
  Future<List<String>> recommendChatIds({
    required List<String> selectedPreferences,
    required List<String> allowedChatIds,
  }) async {
    final system = {
      'role': 'system',
      'content':
          'You rank assistant categories for everyday, repeatable usefulness in a chat-only app. '
          'Prioritize conversational helpers that work purely via dialogue: coaching, tutoring, brainstorming, Q&A, planning, reflection. '
          'Avoid suggestions that depend on executing external tasks/tools, automations, device control, or accounts. '
          'Favor productive, positive, broadly helpful assistants (e.g., productivity coaching, learning tutor, research Q&A, coding helper, business advisor). '
          'Avoid novelty-only, harmful, unsafe, or negative topics. '
          'Only use IDs from the allowed list. Return strictly a JSON array of strings (no prose).',
    };
    final user = {
      'role': 'user',
      'content': jsonEncode({
        'selected_preferences': selectedPreferences,
        'allowed_chat_ids': allowedChatIds,
        'instruction': 'Rank allowed_chat_ids for chat-centric, everyday usefulness (dialogue-only; no external actions). Avoid unsafe/negative topics. Return ONLY a JSON array of ids.'
      }),
    };

    final content = await createChatCompletion(
      messages: [system.cast<String, String>(), user.cast<String, String>()],
      temperature: 0.2,
    );

    // Try to parse JSON array; fallback to extracting with lenient parse
    try {
      final decoded = jsonDecode(content);
      if (decoded is List) {
        final ids = decoded
            .whereType<String>()
            .where((id) => allowedChatIds.contains(id))
            .toList();
        // Deduplicate while preserving order
        final seen = <String>{};
        final unique = <String>[];
        for (final id in ids) {
          if (!seen.contains(id)) {
            seen.add(id);
            unique.add(id);
          }
        }
        return unique;
      }
    } catch (_) {
      // ignore and fallback below
    }

    // If parsing fails, just return the allowed list unchanged
    return allowedChatIds;
  }

  /// Dynamically suggest assistant definitions tailored to the user's preferences.
  ///
  /// Returns a list of objects with fields: id, name, shortDescription, systemPrompt, preference, model.
  /// If the model cannot comply, callers should fall back to hardcoded configs.
  Future<List<Map<String, dynamic>>> recommendChatDefinitions({
    required List<String> selectedPreferences,
    required String languageCode,
    int maxSuggestions = 5,
  }) async {
    if (selectedPreferences.isEmpty) {
      return [];
    }

    final system = {
      'role': 'system',
      'content':
          'Design chat-centric AI assistants for frequent, everyday use in a messaging-only app. '
          'They must be productive, positive, and broadly helpful through conversation (coaching, Q&A, brainstorming, planning, tutoring, reflection). '
          'They should NOT require executing external tasks, automations, scripts, device control, or account access—only dialogue. '
          'Avoid novelty-only, unsafe, harmful, explicit, illegal, or negative themes. '
          'Return ONLY a strict JSON array of objects. No prose. Schema: '
          '{"id": string kebab-case unique, '
          ' "name": string, '
          ' "shortDescription": string <= 80 chars, '
          ' "systemPrompt": detailed string (2-6 sentences) defining role, scope, constraints, and helpful behavior, '
          ' "preference": one of selected_preferences}. '
          'Do NOT include any extra fields. Limit to max_suggestions items. '
          'Make names human-friendly. shortDescription must be concise, user-facing value text. '
          'systemPrompt must be actionable, specific, and suitable as an AI system message. '
          'Localize name and shortDescription in the target language if provided; systemPrompt may be localized too.'
    };
    final user = {
      'role': 'user',
      'content': jsonEncode({
        'selected_preferences': selectedPreferences,
        'max_suggestions': maxSuggestions,
        'language_code': languageCode,
        'instruction': 'Use language_code for the output language; if unsupported, default to English.'
      }),
    };

    final content = await createChatCompletion(
      messages: [system.cast<String, String>(), user.cast<String, String>()],
      temperature: 0.7,
    );

    List<Map<String, dynamic>> results = [];
    try {
      final decoded = jsonDecode(content);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            final id = (item['id'] ?? '').toString();
            final name = (item['name'] ?? '').toString();
            // Support both new and legacy fields
            final shortDescription = (item['shortDescription'] ?? item['description'] ?? '').toString();
            final systemPrompt = (item['systemPrompt'] ?? item['description'] ?? '').toString();
            final preference = (item['preference'] ?? '').toString();
            if (id.isEmpty || name.isEmpty || preference.isEmpty) continue;
            if (!selectedPreferences.contains(preference)) continue;
            // Basic safety and usefulness filter
            final lowerName = name.toLowerCase();
            final lowerDesc = shortDescription.toLowerCase();
            const banned = [
              'prank', 'nsfw', 'adult', 'explicit', 'violent', 'weapon', 'hack', 'hacking',
              'cheat', 'gambling', 'betting', 'piracy', 'malware', 'phishing', 'deepfake',
              'scam', 'illegal', 'harm', 'self-harm', 'drug', 'narcotic'
            ];
            bool containsBanned = banned.any((w) => lowerName.contains(w) || lowerDesc.contains(w));
            if (containsBanned) continue;
            // Discourage one-off novelty and external-action personas
            const novelty = ['joke', 'meme', 'pickup line', 'fortune', 'horoscope'];
            bool looksNovelty = novelty.any((w) => lowerName.contains(w) || lowerDesc.contains(w));
            if (looksNovelty) continue;
            const externalAction = [
              'automation', 'script', 'execute', 'run command', 'control device', 'control phone',
              'api call', 'integrate with', 'web scraping', 'scrape', 'deploy', 'file system',
              'shell', 'terminal', 'root', 'adb', 'keyboard macro', 'mouse macro'
            ];
            bool looksExternal = externalAction.any((w) => lowerName.contains(w) || lowerDesc.contains(w));
            if (looksExternal) continue;

            // Attach model based on preference using our defaults/env
            final model = DefaultAIConfig.getModel(preference);
            results.add({
              'id': id,
              'name': name,
              'shortDescription': shortDescription,
              'systemPrompt': systemPrompt,
              'preference': preference,
              'model': model,
            });
          }
        }
      }
    } catch (_) {
      // ignore and let caller fallback
    }

    return results;
  }
}


