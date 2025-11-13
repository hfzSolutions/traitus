import 'package:flutter/foundation.dart';
import 'package:traitus/services/app_config_service.dart';

/// Configuration for default AI assistants
class DefaultAIConfig {
  /// Get the model from database cache
  /// This is a synchronous method that uses cached value
  /// Falls back to a default model if cache is not available
  /// Use getModelAsync() to fetch from database if you need the actual configured value
  static String getModel([String? assistantType]) {
    try {
      return AppConfigService.instance.getCachedDefaultModel();
    } catch (e) {
      // Fallback to default model if cache not initialized yet
      // This can happen during app startup before initialization completes
      // The actual model will be fetched asynchronously when needed
      debugPrint('Warning: Model cache not initialized, using fallback model. Error: $e');
      return 'minimax/minimax-m2:free'; // Default fallback model
    }
  }
  
  /// Get the model asynchronously (fetches from database)
  static Future<String> getModelAsync([String? assistantType]) async {
    return await AppConfigService.instance.getDefaultModel();
  }

  /// Get all available AI chat configurations
  static Map<String, Map<String, dynamic>> getAvailableAIChats() {
    return {
      'coding': {
        'id': 'coding',
        'name': 'Coding Assistant',
        'shortDescription': 'Your programming companion for solving coding problems',
        'systemPrompt': 'You are an expert coding assistant specialized in helping developers solve programming problems, debug code, and understand technical concepts. Provide clear, accurate, and well-structured code examples and explanations.',
        'model': getModel(),
        'avatar': '💻',
        'preference': 'coding',
      },
      'creative': {
        'id': 'creative',
        'name': 'Creative Writer',
        'shortDescription': 'Spark your creativity with story ideas and writing help',
        'systemPrompt': 'You are a creative writing assistant that helps users with storytelling, creative writing, and generating ideas. You provide engaging and imaginative content, help with character development, plot ideas, and writing techniques.',
        'model': getModel(),
        'avatar': '✍️',
        'preference': 'creative',
      },
      'research': {
        'id': 'research',
        'name': 'Research Assistant',
        'shortDescription': 'Deep dive into topics and gather information',
        'systemPrompt': 'You are a research assistant that helps users gather information, analyze topics, and provide comprehensive insights. You present information in a clear, organized, and well-sourced manner.',
        'model': getModel(),
        'avatar': '🔍',
        'preference': 'research',
      },
      'productivity': {
        'id': 'productivity',
        'name': 'Productivity Coach',
        'shortDescription': 'Optimize your workflow and time management',
        'systemPrompt': 'You are a productivity coach that helps users improve their time management, workflow efficiency, and organizational skills. Provide actionable advice and strategies for better productivity.',
        'model': getModel(),
        'avatar': '📈',
        'preference': 'productivity',
      },
      'learning': {
        'id': 'learning',
        'name': 'Learning Tutor',
        'shortDescription': 'Master new concepts with personalized explanations',
        'systemPrompt': 'You are a patient and knowledgeable tutor that helps users learn new concepts. Break down complex topics into understandable parts, provide examples, and adapt your teaching style to the user\'s level.',
        'model': getModel(),
        'avatar': '🎓',
        'preference': 'learning',
      },
      'business': {
        'id': 'business',
        'name': 'Business Advisor',
        'shortDescription': 'Strategic insights for your business decisions',
        'systemPrompt': 'You are a business advisor with expertise in strategy, analysis, and business development. Help users make informed decisions, analyze markets, and develop business strategies.',
        'model': getModel(),
        'avatar': '💼',
        'preference': 'business',
      },
    };
  }

  /// Get configuration for a specific chat by ID
  static Map<String, dynamic>? getChatConfig(String chatId) {
    final chats = getAvailableAIChats();
    return chats[chatId];
  }

  /// Detect the AI category from chat name and description
  static String? detectChatCategory(String name, String description) {
    final lowerName = name.toLowerCase();
    final lowerDesc = description.toLowerCase();
    final chats = getAvailableAIChats();
    
    // Try to match by name or description keywords
    for (final entry in chats.entries) {
      final categoryId = entry.key;
      final config = entry.value;
      final configName = (config['name'] as String).toLowerCase();
      final configDesc = (config['shortDescription'] as String? ?? config['description'] as String? ?? '').toLowerCase();
      
      // Check if name or description contains category keywords
      if (lowerName.contains(configName) || 
          lowerDesc.contains(configDesc) ||
          lowerName.contains(categoryId) ||
          lowerDesc.contains(categoryId)) {
        return categoryId;
      }
    }
    
    // Fallback: try keyword matching
    if (lowerName.contains('coding') || lowerName.contains('program') || 
        lowerName.contains('code') || lowerDesc.contains('programming')) {
      return 'coding';
    }
    if (lowerName.contains('creative') || lowerName.contains('write') || 
        lowerName.contains('story') || lowerDesc.contains('writing')) {
      return 'creative';
    }
    if (lowerName.contains('research') || lowerDesc.contains('research')) {
      return 'research';
    }
    if (lowerName.contains('productivity') || lowerName.contains('time management') || 
        lowerDesc.contains('productivity')) {
      return 'productivity';
    }
    if (lowerName.contains('learning') || lowerName.contains('tutor') || 
        lowerName.contains('teach') || lowerDesc.contains('learning')) {
      return 'learning';
    }
    if (lowerName.contains('business') || lowerDesc.contains('business')) {
      return 'business';
    }
    
    return null;
  }

  /// Get example questions for a specific AI category
  static List<String> getExampleQuestions(String? category) {
    switch (category) {
      case 'coding':
        return [
          'How do I fix a memory leak in JavaScript?',
          'Explain async/await in Python',
          'What\'s the best way to structure a REST API?',
          'Help me debug this error',
        ];
      case 'creative':
        return [
          'Write a short story about a time traveler',
          'Help me brainstorm creative writing prompts',
          'Suggest plot ideas for a fantasy novel',
          'How can I improve my character development?',
        ];
      case 'research':
        return [
          'Summarize the latest developments in AI',
          'What are the main causes of climate change?',
          'Explain quantum computing in simple terms',
          'Find information about renewable energy',
        ];
      case 'productivity':
        return [
          'How can I improve my daily workflow?',
          'Suggest time management techniques',
          'Help me prioritize my tasks',
          'What are effective productivity habits?',
        ];
      case 'learning':
        return [
          'Explain photosynthesis step by step',
          'Help me understand calculus concepts',
          'Teach me about the history of Rome',
          'How does machine learning work?',
        ];
      case 'business':
        return [
          'How do I create a business plan?',
          'What are effective marketing strategies?',
          'Help me analyze market trends',
          'Advice on scaling a startup',
        ];
      default:
        // Generic questions that work for any AI
        return [
          'What can you help me with?',
          'Tell me about your capabilities',
          'How can I get started?',
          'What would you recommend?',
        ];
    }
  }

  /// Get quick reply snippets for lazy users
  /// Focus on questions and follow-up prompts that encourage conversation continuation
  static List<String> getQuickReplySnippets() {
    return [
      'Can you explain more?',
      'Tell me more about that',
      'What are some examples?',
      'How does that work?',
      'Can you elaborate?',
      'What do you think about...?',
      'What else should I know?',
      'Can you give me more details?',
      'What are the next steps?',
      'How can I apply this?',
      'What would you recommend?',
      'Can you break this down?',
      'What about...?',
      'Why is that important?',
      'How do I get started?',
      'What should I consider?',
      'Can you show me an example?',
      'What are the benefits?',
      'How does this compare?',
      'What questions should I ask?',
    ];
  }
}

