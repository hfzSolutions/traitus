import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:traitus/services/app_config_service.dart';
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
    // Try to get from cache first, but this might fail if not initialized
    // In that case, we'll need to handle it at runtime
    try {
      return AppConfigService.instance.getCachedDefaultModel();
    } catch (e) {
      // Cache not available - this shouldn't happen if initialize() was called
      // But we'll throw a more helpful error
      throw StateError('Model cache not initialized. Ensure AppConfigService.instance.initialize() is called during app startup.');
    }
  }

  /// Get the model for onboarding/assistant finding operations.
  /// Falls back to default model if not set in database.
  String get _onboardingModel {
    // Try to get from cached config first
    final cached = AppConfigService.instance.getCachedConfig('onboarding_model');
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    
    // Fallback to default model
    return _model;
  }

  /// Get the model for quick reply generation.
  /// Falls back to default model if not set in database.
  String get _quickReplyModel {
    // Try to get from cached config first
    final cached = AppConfigService.instance.getCachedConfig('quick_reply_model');
    if (cached != null && cached.isNotEmpty) {
      return cached;
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
    String? model, // Optional override; falls back to OPENROUTER_MODEL
    double? temperature,
    int? maxTokens,
  }) async {
    final uri = _endpointUri('/chat/completions');
    final modelToUse = model?.isNotEmpty == true ? model : _model;

    final requestBody = <String, dynamic>{
      'model': modelToUse,
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

    try {
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
    } catch (e) {
      rethrow;
    }
  }

  /// Stream chat completion responses using Server-Sent Events (SSE).
  /// Yields content chunks as they arrive from the API.
  /// Returns a Stream of Map with 'content' and optionally 'model' (when available).
  Stream<Map<String, dynamic>> streamChatCompletion({
    required List<Map<String, dynamic>> messages,
    String? model, // Optional override; falls back to OPENROUTER_MODEL
    double? temperature,
    int? maxTokens,
  }) async* {
    final uri = _endpointUri('/chat/completions');

    final requestBody = <String, dynamic>{
      'model': model?.isNotEmpty == true ? model : _model,
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
          'Return ONLY a strict JSON array of objects. No prose, no markdown code blocks, no explanations. Just the raw JSON array. Schema: '
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

    // Clean markdown code blocks if present (some models wrap JSON in ```json ... ```)
    String cleanedContent = content.trim();
    if (cleanedContent.startsWith('```')) {
      // Remove opening markdown code block (```json or ```)
      final lines = cleanedContent.split('\n');
      if (lines.first.trim().startsWith('```')) {
        lines.removeAt(0);
      }
      // Remove closing markdown code block (```)
      if (lines.isNotEmpty && lines.last.trim() == '```') {
        lines.removeLast();
      }
      cleanedContent = lines.join('\n').trim();
    }

    List<Map<String, dynamic>> results = [];
    try {
      final decoded = jsonDecode(cleanedContent);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            final id = (item['id'] ?? '').toString();
            final name = (item['name'] ?? '').toString();
            // Support both new and legacy fields
            final shortDescription = (item['shortDescription'] ?? item['description'] ?? '').toString();
            final systemPrompt = (item['systemPrompt'] ?? item['description'] ?? '').toString();
            var preference = (item['preference'] ?? '').toString();
            
            // Validate required fields
            if (id.isEmpty || name.isEmpty) {
              continue;
            }
            
            // If preference is missing, assign the first selected preference as fallback
            if (preference.isEmpty) {
              if (selectedPreferences.isNotEmpty) {
                preference = selectedPreferences.first;
              } else {
                continue;
              }
            }
            
            // Validate preference is in selected list
            if (!selectedPreferences.contains(preference)) {
              continue;
            }
            // Basic safety and usefulness filter
            final lowerName = name.toLowerCase();
            final lowerDesc = shortDescription.toLowerCase();
            const banned = [
              'prank', 'nsfw', 'adult', 'explicit', 'violent', 'weapon', 'hack', 'hacking',
              'cheat', 'gambling', 'betting', 'piracy', 'malware', 'phishing', 'deepfake',
              'scam', 'illegal', 'harm', 'self-harm', 'drug', 'narcotic'
            ];
            bool containsBanned = banned.any((w) => lowerName.contains(w) || lowerDesc.contains(w));
            if (containsBanned) {
              continue;
            }
            // Discourage one-off novelty and external-action personas
            const novelty = ['joke', 'meme', 'pickup line', 'fortune', 'horoscope'];
            bool looksNovelty = novelty.any((w) => lowerName.contains(w) || lowerDesc.contains(w));
            if (looksNovelty) {
              continue;
            }
            const externalAction = [
              'automation', 'script', 'execute', 'run command', 'control device', 'control phone',
              'api call', 'integrate with', 'web scraping', 'scrape', 'deploy', 'file system',
              'shell', 'terminal', 'root', 'adb', 'keyboard macro', 'mouse macro'
            ];
            bool looksExternal = externalAction.any((w) => lowerName.contains(w) || lowerDesc.contains(w));
            if (looksExternal) {
              continue;
            }

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

  /// Generate multiple AI chat configuration variations from a user's natural language description.
  ///
  /// Returns a list of maps, each with: name, shortDescription, systemPrompt, and inferred preference.
  /// If generation fails, returns an empty list and caller should fall back to manual input.
  Future<List<Map<String, dynamic>>> generateChatFromDescription({
    required String userDescription,
    String? languageCode,
    int variationCount = 3,
  }) async {
    if (userDescription.trim().isEmpty) {
      return [];
    }

    final system = {
      'role': 'system',
      'content':
          'You are a helpful assistant that creates AI chat configurations from user descriptions. '
          'Design chat-centric AI assistants for frequent, everyday use in a messaging-only app. '
          'They must be productive, positive, and broadly helpful through conversation (coaching, Q&A, brainstorming, planning, tutoring, reflection). '
          'They should NOT require executing external tasks, automations, scripts, device control, or account access—only dialogue. '
          'Avoid novelty-only, unsafe, harmful, explicit, illegal, or negative themes. '
          'Return ONLY a strict JSON array of $variationCount different variations. No prose. Each item in the array must match this schema: '
          '{"name": string (human-friendly, 2-5 words), '
          ' "shortDescription": string (concise, <= 80 chars, user-facing value proposition), '
          ' "systemPrompt": detailed string (2-6 sentences) defining role, scope, constraints, and helpful behavior suitable as an AI system message, '
          ' "preference": string (one of: coding, creative, research, productivity, learning, business) - choose the best match}. '
          'Do NOT include any extra fields. '
          'Make each variation unique with different approaches, tones, or focuses while still matching the user description. '
          'Make the names human-friendly and clear. shortDescription must be concise and explain what the AI helps with. '
          'systemPrompt must be actionable, specific, and suitable as an AI system message. '
          'Localize names and shortDescriptions in the target language if provided; systemPrompts may be localized too.'
    };

    final userData = <String, dynamic>{
      'user_description': userDescription.trim(),
      'instruction': 'Create $variationCount different AI assistant configuration variations based on the user_description. Return a JSON array with $variationCount items, each matching the schema exactly. Make each variation unique with different approaches, tones, or focuses.',
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
        temperature: 0.8, // Slightly higher temperature for more variation
      );

      // Strip markdown code block markers if present (```json ... ```)
      String jsonContent = content.trim();
      if (jsonContent.startsWith('```')) {
        // Remove opening ```json or ```
        final firstNewline = jsonContent.indexOf('\n');
        if (firstNewline != -1) {
          jsonContent = jsonContent.substring(firstNewline + 1);
        } else {
          // No newline, just remove the opening ```
          jsonContent = jsonContent.replaceFirst(RegExp(r'^```[a-z]*\s*'), '');
        }
        
        // Remove closing ```
        jsonContent = jsonContent.replaceFirst(RegExp(r'\s*```\s*$'), '');
        jsonContent = jsonContent.trim();
      }

      // Try to parse JSON array
      List<dynamic> decodedArray;
      try {
        final decoded = jsonDecode(jsonContent);
        if (decoded is List) {
          decodedArray = decoded;
        } else if (decoded is Map) {
          // Fallback: if single object returned, wrap it in array
          decodedArray = [decoded];
        } else {
          return [];
        }
      } catch (parseError) {
        return [];
      }
      
      if (decodedArray.isEmpty) {
        return [];
      }

      // Attach model - uses default_model from app_config table
      String model;
      try {
        model = AppConfigService.instance.getCachedDefaultModel();
      } catch (e) {
        // Fallback to DefaultAIConfig if cache not available (shouldn't happen if initialized)
        model = DefaultAIConfig.getModel();
      }

      final List<Map<String, dynamic>> validConfigs = [];

      for (final item in decodedArray) {
        if (item is! Map<String, dynamic>) continue;

        final name = (item['name'] ?? '').toString().trim();
        final shortDescription = (item['shortDescription'] ?? item['description'] ?? '').toString().trim();
        final systemPrompt = (item['systemPrompt'] ?? item['description'] ?? '').toString().trim();
        final preference = (item['preference'] ?? '').toString().trim().toLowerCase();

        if (name.isEmpty || shortDescription.isEmpty || systemPrompt.isEmpty) {
          continue;
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
        if (containsBanned) {
          continue;
        }

        // Discourage novelty and external-action personas
        const novelty = ['joke', 'meme', 'pickup line', 'fortune', 'horoscope'];
        bool looksNovelty = novelty.any((w) => lowerName.contains(w) || lowerDesc.contains(w));
        if (looksNovelty) {
          continue;
        }

        const externalAction = [
          'automation', 'script', 'execute', 'run command', 'control device', 'control phone',
          'api call', 'integrate with', 'web scraping', 'scrape', 'deploy', 'file system',
          'shell', 'terminal', 'root', 'adb', 'keyboard macro', 'mouse macro'
        ];
        bool looksExternal = externalAction.any((w) => lowerName.contains(w) || lowerDesc.contains(w));
        if (looksExternal) {
          continue;
        }

        validConfigs.add({
          'name': name,
          'shortDescription': shortDescription,
          'systemPrompt': systemPrompt,
          'preference': validPreference,
          'model': model,
        });
      }

      return validConfigs;
    } catch (e) {
      // If parsing fails, return empty list - caller should fall back to manual input
      return [];
    }
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

    // Get the last user message to detect their language and if it's a question
    String lastUserMessage = '';
    for (final msg in conversationHistory.reversed) {
      if (msg['role'] == 'user') {
        // Handle both string content and content array (for multimodal messages)
        final content = msg['content'];
        if (content is String) {
          lastUserMessage = content;
        } else if (content is List) {
          // For multimodal messages, extract text from content array
          for (final item in content) {
            if (item is Map && item['type'] == 'text') {
              lastUserMessage = item['text'] ?? '';
              break;
            }
          }
        }
        break;
      }
    }
    
    // Detect if the user's last message is a question
    final isQuestion = lastUserMessage.trim().endsWith('?') || 
        RegExp(r'\b(what|how|why|when|where|who|which|can|could|would|should|is|are|do|does|did|will|may|might)\b', caseSensitive: false)
            .hasMatch(lastUserMessage.trim().split(RegExp(r'[.!?]')).last);

    // Get recent conversation context (last 3-4 exchanges) for better understanding
    final recentConversation = <Map<String, String>>[];
    int messageCount = 0;
    for (final msg in conversationHistory.reversed) {
      if (messageCount >= 8) break; // Get last 4 exchanges (user + assistant pairs)
      
      final role = msg['role'] as String?;
      if (role == 'user' || role == 'assistant') {
        String content = '';
        final msgContent = msg['content'];
        if (msgContent is String) {
          content = msgContent;
        } else if (msgContent is List) {
          // For multimodal messages, extract text
          for (final item in msgContent) {
            if (item is Map && item['type'] == 'text') {
              content = item['text'] ?? '';
              break;
            }
          }
        }
        
        if (content.isNotEmpty) {
          recentConversation.insert(0, {
            'role': role == 'user' ? 'User' : 'Assistant',
            'content': content.length > 400 ? '${content.substring(0, 400)}...' : content,
          });
          messageCount++;
        }
      }
    }

    final system = {
      'role': 'system',
      'content':
          'You are a helpful assistant that generates clear, conversational quick reply suggestions for a chat interface. '
          'Your goal is to create suggestions that are SPECIFIC to the conversation context but also CLEAR and EASY TO UNDERSTAND. '
          'Analyze the ENTIRE conversation context provided - identify specific topics, ideas, concepts, examples, or points mentioned across the conversation. '
          'Understand the conversation flow: what was asked, what was discussed, what themes emerged. '
          'IMPORTANT: If the user\'s last message is a QUESTION, generate suggestions that help ANSWER that question or provide answer options. '
          'If the user\'s last message is NOT a question, generate follow-up questions that continue the conversation. '
          'Generate exactly $count natural, conversational reply suggestions that: '
          '(1) Are SPECIFIC to the conversation context - reference actual topics, ideas, or points discussed, '
          '(2) Are CLEAR and EASY TO UNDERSTAND - written like natural responses a person would give, not cryptic titles or fragments, '
          '(3) Sound conversational and natural - use complete thoughts that make immediate sense, '
          '(4) If user asked a question: provide answer suggestions or ways to answer that question, '
          '(5) If user made a statement: ask follow-up questions that spark curiosity and continue the conversation, '
          '(6) Reference things from earlier in the conversation if relevant, or build on the latest points. '
          'CRITICAL: Make suggestions that are COMPLETE and CLEAR, not title-like or cryptic. '
          'If user asked a question, examples: "Yes, that\'s correct", "Here\'s how to do it", "Let me explain that", "I can help with that" '
          'If user made a statement, examples: "How do those algorithms work?", "What are the other benefits?", "Can you explain that example?" '
          'Each suggestion should be 5-10 words (approximately 30-60 characters), written as a complete, natural response that anyone can immediately understand. '
          'Keep them concise but clear - long enough to be specific and understandable, but short enough to fit nicely in a button. '
          'Write them like you\'re having a natural conversation - clear, specific, and easy to understand. '
          'DO NOT create suggestions that sound like titles, headlines, or fragments. They should be full, conversational responses. '
          'DO NOT make suggestions too long - aim for a length that fits comfortably in a button without wrapping too much. '
          'Avoid simple acknowledgments like "Thanks!", "Got it", "Okay". '
          'IMPORTANT: Generate suggestions in the SAME LANGUAGE as the user\'s last message. If the user wrote in Spanish, respond in Spanish. If they wrote in French, respond in French. Match the language exactly. '
          'Return ONLY a JSON array of strings. No prose, no explanations. Just the array of $count clear, conversational reply suggestions in the user\'s language.',
    };

    // Include more context from the assistant's message for better specificity
    final assistantContext = lastAssistantMessage.length > 800 
        ? lastAssistantMessage.substring(0, 800) 
        : lastAssistantMessage;

    final userContent = StringBuffer();
    
    // Include recent conversation context if available
    if (recentConversation.length > 2) {
      userContent.write('Recent conversation context:\n');
      for (final msg in recentConversation) {
        userContent.write('${msg['role']}: ${msg['content']}\n\n');
      }
    } else {
      // Fallback if we don't have enough context
      userContent.write('The AI just responded with:\n"$assistantContext"\n\n');
      if (lastUserMessage.isNotEmpty) {
        userContent.write('The user\'s last message was: "${lastUserMessage.substring(0, lastUserMessage.length > 200 ? 200 : lastUserMessage.length)}"\n\n');
      }
    }
    
    userContent.write('Analyze the conversation context above carefully. Identify specific topics, ideas, concepts, examples, or points mentioned throughout the conversation. '
        'Understand the conversation flow and what has been discussed. ');
    
    if (isQuestion && lastUserMessage.isNotEmpty) {
      userContent.write('IMPORTANT: The user\'s last message is a QUESTION: "${lastUserMessage.substring(0, lastUserMessage.length > 200 ? 200 : lastUserMessage.length)}" '
          'Generate exactly $count clear, conversational quick reply suggestions that HELP ANSWER this question or provide answer options. '
          'These should be responses the AI could give to answer the user\'s question, not more questions. '
          'Examples: "Yes, that\'s correct", "Here\'s how to do it", "Let me explain that", "I can help with that", "That depends on...", "Here are the steps...". '
          'Make them specific to the question asked and the conversation context. ');
    } else {
      userContent.write('The user\'s last message is a STATEMENT, not a question. '
          'Generate exactly $count clear, conversational quick reply suggestions that are FOLLOW-UP QUESTIONS to continue the conversation: '
          '(1) Reference SPECIFIC things from the conversation context - mention actual topics, examples, or points discussed, '
          '(2) Are written as COMPLETE, NATURAL questions that are immediately clear and easy to understand, '
          '(3) Sound like something a person would naturally ask in conversation - not titles, headlines, or fragments, '
          '(4) Spark curiosity about specific aspects discussed in the conversation, '
          '(5) Make the user want to explore deeper into the specific content. '
          'For example, if the conversation mentioned "machine learning algorithms", write "How do those algorithms work?" (concise) not "Machine Learning Algorithms" (too short/cryptic) or "How do those machine learning algorithms actually work in practice?" (too long). '
          'If the conversation mentioned "three benefits" but only discussed one, write "What are the other benefits?" (concise) not "Other Benefits" (too short) or "What are the other two benefits that you mentioned earlier in our conversation?" (too long). ');
    }
    
    userContent.write('CRITICAL: Write suggestions as full, conversational responses. They should be clear and easy to understand, not cryptic or title-like. '
        'Make them sound natural and conversational - like responses you\'d give to a friend, not search keywords or article titles. '
        'Keep them at a nice length - clear and complete, but not too long. Aim for 5-10 words (30-60 characters). '
        'IMPORTANT: Generate suggestions in the EXACT SAME LANGUAGE as the user\'s last message above. Match the language precisely.\n\n');
    
    if (isQuestion) {
      userContent.write('Return ONLY a JSON array of strings with clear, conversational answer suggestions (5-10 words each, 30-60 characters ideal), e.g., ["Yes, that\'s correct", "Here\'s how to do it", "Let me explain that"]');
    } else {
      userContent.write('Return ONLY a JSON array of strings with clear, conversational, context-aware follow-up questions (5-10 words each, 30-60 characters ideal), e.g., ["How do those algorithms work?", "What are the other benefits?", "Can you explain that example?"]');
    }

    final user = {
      'role': 'user',
      'content': userContent.toString(),
    };

    try {
      final content = await createChatCompletion(
        messages: [system, user],
        model: _quickReplyModel,
        temperature: 0.7,
        maxTokens: 150, // Allow for longer, clearer suggestions
      );

      // Try to parse JSON array
      try {
        final decoded = jsonDecode(content);
        if (decoded is List) {
          final replies = decoded
              .whereType<String>()
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty && s.length <= 80) // Keep suggestions concise (30-60 chars ideal, max 80)
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
              .where((s) => s.isNotEmpty && s.length <= 80) // Keep suggestions concise (30-60 chars ideal, max 80)
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


