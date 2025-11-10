import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  /// Get the model for onboarding/assistant finding operations.
  /// Falls back to the default OPENROUTER_MODEL if ONBOARDING_MODEL is not set.
  String get _onboardingModel {
    final value = dotenv.env['ONBOARDING_MODEL'];
    if (value != null && value.isNotEmpty) {
      return value;
    }
    // Fallback to default model
    return _model;
  }

  /// Get the model for quick reply generation.
  /// Falls back to the default OPENROUTER_MODEL if QUICK_REPLY_MODEL is not set.
  String get _quickReplyModel {
    final value = dotenv.env['QUICK_REPLY_MODEL'];
    if (value != null && value.isNotEmpty) {
      return value;
    }
    // Fallback to default model
    return _model;
  }

  Uri _endpointUri(String path) {
    final baseUrl = dotenv.env['OPENROUTER_BASE_URL'] ?? _defaultBaseUrl;
    return Uri.parse('$baseUrl$path');
  }

  /// Get max_tokens from environment variable, with mobile-friendly default
  int get _maxTokens {
    final value = dotenv.env['OPENROUTER_MAX_TOKENS'];
    if (value != null && value.isNotEmpty) {
      return int.tryParse(value) ?? 800;
    }
    // Default to 800 tokens for mobile (roughly 600-1000 words)
    return 800;
  }

  /// Public getter for max_tokens (for use by ChatProvider)
  int get maxTokens => _maxTokens;

  /// Calculate appropriate max_tokens based on response length preference
  /// This helps prevent cut-off responses by setting appropriate limits
  static int getMaxTokensForResponseLength(String? responseLength, {int? baseMaxTokens}) {
    final base = baseMaxTokens ?? 800;
    
    switch (responseLength?.toLowerCase()) {
      case 'brief':
        // Brief responses: 300-400 tokens (roughly 200-300 words)
        return (base * 0.5).round().clamp(300, 500);
      case 'balanced':
        // Balanced responses: use base value
        return base;
      case 'detailed':
        // Detailed responses: allow more tokens (but still reasonable for mobile)
        return (base * 1.5).round().clamp(base, 1500);
      default:
        return base;
    }
  }

  Future<String> createChatCompletion({
    required List<Map<String, dynamic>> messages,
    String? model, // Deprecated - always uses OPENROUTER_MODEL from env
    double? temperature,
    int? maxTokens,
  }) async {
    final uri = _endpointUri('/chat/completions');

    final requestBody = <String, dynamic>{
      'model': _model, // Always use OPENROUTER_MODEL from env
      'messages': messages,
      'max_tokens': maxTokens ?? _maxTokens,
      if (temperature != null) 'temperature': temperature,
    };

    final headers = <String, String>{
      'Authorization': 'Bearer $_apiKey',
      'Content-Type': 'application/json',
      'HTTP-Referer': dotenv.env['OPENROUTER_SITE_URL'] ?? 'https://example.com',
      'X-Title': dotenv.env['OPENROUTER_APP_NAME'] ?? 'Traitus',
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

  /// Stream chat completion responses using Server-Sent Events (SSE).
  /// Yields content chunks as they arrive from the API.
  /// Returns a Stream of Map with 'content' and optionally 'model' (when available).
  Stream<Map<String, dynamic>> streamChatCompletion({
    required List<Map<String, dynamic>> messages,
    String? model, // Deprecated - always uses OPENROUTER_MODEL from env
    double? temperature,
    int? maxTokens,
  }) async* {
    final uri = _endpointUri('/chat/completions');

    final requestBody = <String, dynamic>{
      'model': _model, // Always use OPENROUTER_MODEL from env
      'messages': messages,
      'stream': true, // Enable streaming
      'max_tokens': maxTokens ?? _maxTokens,
      if (temperature != null) 'temperature': temperature,
    };

    final headers = <String, String>{
      'Authorization': 'Bearer $_apiKey',
      'Content-Type': 'application/json',
      'HTTP-Referer': dotenv.env['OPENROUTER_SITE_URL'] ?? 'https://example.com',
      'X-Title': dotenv.env['OPENROUTER_APP_NAME'] ?? 'Traitus',
    };

    final request = http.Request('POST', uri)
      ..headers.addAll(headers)
      ..body = jsonEncode(requestBody);

    final streamedResponse = await _client.send(request);

    if (streamedResponse.statusCode < 200 || streamedResponse.statusCode >= 300) {
      final errorBody = await streamedResponse.stream.bytesToString();
      throw http.ClientException(
        'OpenRouter error ${streamedResponse.statusCode}: $errorBody',
        uri,
      );
    }

    String buffer = '';
    String? actualModel; // Track the actual model used (important for openrouter/auto)
    
    await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
      buffer += chunk;
      
      // Process complete lines (SSE format uses \n\n as event separator)
      while (buffer.contains('\n')) {
        final lineEnd = buffer.indexOf('\n');
        final line = buffer.substring(0, lineEnd);
        buffer = buffer.substring(lineEnd + 1);
        
        // Skip empty lines and comment lines
        if (line.trim().isEmpty || line.startsWith(':')) continue;
        
        // SSE format: "data: {json}"
        if (line.startsWith('data: ')) {
          final data = line.substring(6).trim();
          
          // Stream finished
          if (data == '[DONE]') {
            return;
          }

          try {
            final decoded = jsonDecode(data) as Map<String, dynamic>;
            
            // Capture model from response (important for openrouter/auto)
            if (actualModel == null && decoded['model'] != null) {
              actualModel = decoded['model'] as String;
            }
            
            final choices = decoded['choices'] as List<dynamic>?;
            if (choices == null || choices.isEmpty) continue;
            
            final delta = choices.first['delta'] as Map<String, dynamic>?;
            final content = delta?['content'] as String?;
            
            if (content != null && content.isNotEmpty) {
              yield {
                'content': content,
                if (actualModel != null) 'model': actualModel,
              };
            }
          } catch (e) {
            // Ignore parsing errors for incomplete chunks
            continue;
          }
        }
      }
    }

    // Process any remaining buffer
    if (buffer.trim().isNotEmpty && buffer.startsWith('data: ')) {
      final data = buffer.substring(6).trim();
      if (data != '[DONE]') {
        try {
          final decoded = jsonDecode(data) as Map<String, dynamic>;
          
          // Capture model from response if not already captured
          if (actualModel == null && decoded['model'] != null) {
            actualModel = decoded['model'] as String;
          }
          
          final choices = decoded['choices'] as List<dynamic>?;
          if (choices == null || choices.isEmpty) return;
          
          final delta = choices.first['delta'] as Map<String, dynamic>?;
          final content = delta?['content'] as String?;
          
          if (content != null && content.isNotEmpty) {
            yield {
              'content': content,
              if (actualModel != null) 'model': actualModel,
            };
          }
        } catch (_) {
          // Ignore parsing errors
        }
      }
    }
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
      messages: [system, user],
      model: _onboardingModel,
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
    String? displayName,
    DateTime? dateOfBirth,
    String? experienceLevel,
    String? useContext,
  }) async {
    if (selectedPreferences.isEmpty) {
      return [];
    }

    // Calculate age group if date of birth is provided
    String? ageGroup;
    if (dateOfBirth != null) {
      final age = DateTime.now().difference(dateOfBirth).inDays ~/ 365;
      if (age < 13) {
        ageGroup = 'child';
      } else if (age < 18) {
        ageGroup = 'teen';
      } else if (age < 25) {
        ageGroup = 'young_adult';
      } else if (age < 40) {
        ageGroup = 'adult';
      } else if (age < 60) {
        ageGroup = 'middle_aged';
      } else {
        ageGroup = 'senior';
      }
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
          'Localize name and shortDescription in the target language if provided; systemPrompt may be localized too. '
          'If age_group is provided, tailor assistants appropriately (e.g., simpler explanations for younger users, more professional/advanced for older users). '
          'If display_name is provided, you may reference it for personalization, but keep it subtle. '
          'If experience_level is provided (beginner/intermediate/advanced), adjust the complexity and depth of assistance accordingly. '
          'For beginners: use simpler language, provide step-by-step guidance, explain concepts clearly. '
          'For intermediate: assume some knowledge, provide balanced guidance with examples. '
          'For advanced: use technical terminology, focus on optimization and best practices, less hand-holding. '
          'If use_context is provided (work/personal/both), tailor the assistant\'s tone and focus. '
          'Work context: professional, business-focused, productivity-oriented. '
          'Personal context: friendly, hobby-oriented, relaxed. '
          'Both: balanced approach that works in multiple contexts.'
    };
    final userData = <String, dynamic>{
      'selected_preferences': selectedPreferences,
      'max_suggestions': maxSuggestions,
      'language_code': languageCode,
      'instruction': 'Use language_code for the output language; if unsupported, default to English.',
    };
    if (displayName != null && displayName.isNotEmpty) {
      userData['display_name'] = displayName;
    }
    if (ageGroup != null) {
      userData['age_group'] = ageGroup;
    }
    if (experienceLevel != null && experienceLevel.isNotEmpty) {
      userData['experience_level'] = experienceLevel;
    }
    if (useContext != null && useContext.isNotEmpty) {
      userData['use_context'] = useContext;
    }
    final user = {
      'role': 'user',
      'content': jsonEncode(userData),
    };

    final content = await createChatCompletion(
      messages: [system, user],
      model: _onboardingModel,
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

            // Attach model - always uses OPENROUTER_MODEL from env
            final model = DefaultAIConfig.getModel();
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

  /// Generate a single AI chat configuration from a user's natural language description.
  ///
  /// Returns a map with: name, shortDescription, systemPrompt, and inferred preference.
  /// If generation fails, returns null and caller should fall back to manual input.
  Future<Map<String, dynamic>?> generateChatFromDescription({
    required String userDescription,
    String? languageCode,
  }) async {
    if (userDescription.trim().isEmpty) {
      return null;
    }

    final system = {
      'role': 'system',
      'content':
          'You are a helpful assistant that creates AI chat configurations from user descriptions. '
          'Design a chat-centric AI assistant for frequent, everyday use in a messaging-only app. '
          'It must be productive, positive, and broadly helpful through conversation (coaching, Q&A, brainstorming, planning, tutoring, reflection). '
          'It should NOT require executing external tasks, automations, scripts, device control, or account access—only dialogue. '
          'Avoid novelty-only, unsafe, harmful, explicit, illegal, or negative themes. '
          'Return ONLY a strict JSON object. No prose. Schema: '
          '{"name": string (human-friendly, 2-5 words), '
          ' "shortDescription": string (concise, <= 80 chars, user-facing value proposition), '
          ' "systemPrompt": detailed string (2-6 sentences) defining role, scope, constraints, and helpful behavior suitable as an AI system message, '
          ' "preference": string (one of: coding, creative, research, productivity, learning, business) - choose the best match}. '
          'Do NOT include any extra fields. '
          'Make the name human-friendly and clear. shortDescription must be concise and explain what the AI helps with. '
          'systemPrompt must be actionable, specific, and suitable as an AI system message. '
          'Localize name and shortDescription in the target language if provided; systemPrompt may be localized too.'
    };

    final userData = <String, dynamic>{
      'user_description': userDescription.trim(),
      'instruction': 'Create an AI assistant configuration based on the user_description. Return a JSON object matching the schema exactly.',
    };
    if (languageCode != null && languageCode.isNotEmpty) {
      userData['language_code'] = languageCode;
      userData['instruction'] += ' Use language_code for the output language; if unsupported, default to English.';
    }

    final user = {
      'role': 'user',
      'content': jsonEncode(userData),
    };

    try {
      final content = await createChatCompletion(
        messages: [system, user],
        model: _onboardingModel,
        temperature: 0.7,
      );

      // Try to parse JSON object
      final decoded = jsonDecode(content);
      if (decoded is Map) {
        final name = (decoded['name'] ?? '').toString().trim();
        final shortDescription = (decoded['shortDescription'] ?? decoded['description'] ?? '').toString().trim();
        final systemPrompt = (decoded['systemPrompt'] ?? decoded['description'] ?? '').toString().trim();
        final preference = (decoded['preference'] ?? '').toString().trim().toLowerCase();

        if (name.isEmpty || shortDescription.isEmpty || systemPrompt.isEmpty) {
          return null;
        }

        // Validate preference
        const validPreferences = ['coding', 'creative', 'research', 'productivity', 'learning', 'business'];
        final validPreference = validPreferences.contains(preference) ? preference : 'coding';

        // Basic safety filter
        final lowerName = name.toLowerCase();
        final lowerDesc = shortDescription.toLowerCase();
        const banned = [
          'prank', 'nsfw', 'adult', 'explicit', 'violent', 'weapon', 'hack', 'hacking',
          'cheat', 'gambling', 'betting', 'piracy', 'malware', 'phishing', 'deepfake',
          'scam', 'illegal', 'harm', 'self-harm', 'drug', 'narcotic'
        ];
        bool containsBanned = banned.any((w) => lowerName.contains(w) || lowerDesc.contains(w));
        if (containsBanned) return null;

        // Discourage novelty and external-action personas
        const novelty = ['joke', 'meme', 'pickup line', 'fortune', 'horoscope'];
        bool looksNovelty = novelty.any((w) => lowerName.contains(w) || lowerDesc.contains(w));
        if (looksNovelty) return null;

        const externalAction = [
          'automation', 'script', 'execute', 'run command', 'control device', 'control phone',
          'api call', 'integrate with', 'web scraping', 'scrape', 'deploy', 'file system',
          'shell', 'terminal', 'root', 'adb', 'keyboard macro', 'mouse macro'
        ];
        bool looksExternal = externalAction.any((w) => lowerName.contains(w) || lowerDesc.contains(w));
        if (looksExternal) return null;

        // Attach model - always uses OPENROUTER_MODEL from env
        final model = DefaultAIConfig.getModel();

        return {
          'name': name,
          'shortDescription': shortDescription,
          'systemPrompt': systemPrompt,
          'preference': validPreference,
          'model': model,
        };
      }
    } catch (e) {
      // If parsing fails, return null - caller should fall back to manual input
      return null;
    }

    return null;
  }

  /// Generate contextually relevant quick reply suggestions based on the conversation.
  /// Returns a list of 3 short reply suggestions (typically 1-5 words each).
  /// Falls back to empty list if generation fails.
  Future<List<String>> generateQuickReplies({
    required List<Map<String, dynamic>> conversationHistory,
    int count = 3,
  }) async {
    if (conversationHistory.isEmpty) {
      return [];
    }

    // Get the last assistant message for context
    String lastAssistantMessage = '';
    for (final msg in conversationHistory.reversed) {
      if (msg['role'] == 'assistant') {
        lastAssistantMessage = msg['content'] ?? '';
        break;
      }
    }

    if (lastAssistantMessage.isEmpty) {
      return [];
    }

    final system = {
      'role': 'system',
      'content':
          'You are a helpful assistant that generates short, contextually relevant quick reply suggestions for a chat interface. '
          'Based on the AI\'s last response, generate exactly $count short, natural reply suggestions that a user might want to send. '
          'Each suggestion should be 1-5 words, conversational, and directly relevant to the AI\'s response. '
          'Examples: "Thanks!", "Tell me more", "Can you explain?", "That makes sense", "I need help with this". '
          'Return ONLY a JSON array of strings. No prose, no explanations. Just the array of $count reply suggestions.',
    };

    final user = {
      'role': 'user',
      'content':
          'The AI just responded with: "${lastAssistantMessage.substring(0, lastAssistantMessage.length > 500 ? 500 : lastAssistantMessage.length)}"\n\n'
          'Generate exactly $count short, contextually relevant quick reply suggestions that a user might want to send in response. '
          'Return ONLY a JSON array of strings, e.g., ["Thanks!", "Tell me more", "Can you explain?"]',
    };

    try {
      final content = await createChatCompletion(
        messages: [system, user],
        model: _quickReplyModel,
        temperature: 0.7,
        maxTokens: 100, // Short responses only
      );

      // Try to parse JSON array
      try {
        final decoded = jsonDecode(content);
        if (decoded is List) {
          final replies = decoded
              .whereType<String>()
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty && s.length <= 50) // Filter out empty or too long replies
              .take(count)
              .toList();
          
          if (replies.length >= 2) {
            // Return at least 2 valid replies
            return replies;
          }
        }
      } catch (_) {
        // If JSON parsing fails, try to extract suggestions from text
        // Look for array-like patterns
        final arrayMatch = RegExp(r'\[(.*?)\]', dotAll: true).firstMatch(content);
        if (arrayMatch != null) {
          final arrayContent = arrayMatch.group(1) ?? '';
          final suggestions = arrayContent
              .split(',')
              .map((s) {
                final trimmed = s.trim();
                // Remove surrounding quotes (both single and double)
                var result = trimmed;
                if (result.startsWith('"') || result.startsWith("'")) {
                  result = result.substring(1);
                }
                if (result.endsWith('"') || result.endsWith("'")) {
                  result = result.substring(0, result.length - 1);
                }
                return result;
              })
              .where((s) => s.isNotEmpty && s.length <= 50)
              .take(count)
              .toList();
          
          if (suggestions.length >= 2) {
            return suggestions;
          }
        }
      }
    } catch (e) {
      // If generation fails, return empty list (caller will use fallback)
      debugPrint('Error generating quick replies: $e');
    }

    return [];
  }
}


