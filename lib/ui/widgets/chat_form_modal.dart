import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:traitus/models/ai_chat.dart';
import 'package:traitus/models/model.dart';
import 'package:traitus/ui/widgets/app_avatar.dart';
import 'package:traitus/services/storage_service.dart';
import 'package:traitus/services/openrouter_api.dart';
import 'package:traitus/services/notification_service.dart';
import 'package:traitus/services/database_service.dart';
import 'package:traitus/services/app_config_service.dart';

/// Reusable modal for creating or editing AI chats
/// 
/// Handles:
/// - Chat name and system prompt
/// - Avatar upload
/// - Response style settings (collapsible)
/// - Scrollable content to prevent overflow
class ChatFormModal extends StatefulWidget {
  const ChatFormModal({
    super.key,
    this.chat,
    required this.onSave,
    this.isCreating = false,
  });

  /// Existing chat to edit (null for create mode)
  final AiChat? chat;
  
  /// Callback when save button is pressed
  /// Returns the updated/new chat data
  final Future<void> Function({
    required String name,
    required String shortDescription,
    required String systemPrompt,
    required String model,
    String? avatarUrl,
    required String responseTone,
    required String responseLength,
    required String writingStyle,
    required bool useEmojis,
  }) onSave;
  
  /// Whether this is creating a new chat (true) or editing (false)
  final bool isCreating;

  @override
  State<ChatFormModal> createState() => _ChatFormModalState();
}

class _ChatFormModalState extends State<ChatFormModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _shortDescriptionController;
  late final TextEditingController _systemPromptController;
  late final TextEditingController _quickDescriptionController;
  final _imagePicker = ImagePicker();
  final _storageService = StorageService();
  final _openRouterApi = OpenRouterApi();
  final _dbService = DatabaseService();
  
  String? _selectedImagePath;
  bool _isSaving = false;
  bool _showAdvancedSettings = false;
  bool _useQuickCreate = false; // Only for creating new chats
  bool _isGenerating = false;
  bool _hasGeneratedConfig = false; // Track if we've generated config from quick create
  bool _isCustomizingFromVariation = false; // Track if we're customizing from variation selection
  List<Map<String, dynamic>> _generatedVariations = []; // Store multiple variations
  int? _selectedVariationIndex; // Track which variation is selected
  
  // Model selection
  List<Model> _models = [];
  String? _selectedModelId;
  bool _isLoadingModels = false;
  
  // Response style preferences
  late String _selectedTone;
  late String _selectedLength;
  late String _selectedStyle;
  late bool _useEmojis;

  @override
  void initState() {
    super.initState();
    final chat = widget.chat;
    
    _nameController = TextEditingController(text: chat?.name ?? '');
    _shortDescriptionController = TextEditingController(text: chat?.shortDescription ?? '');
    _systemPromptController = TextEditingController(text: chat?.systemPrompt ?? '');
    _quickDescriptionController = TextEditingController();
    
    // Initialize model selection
    _selectedModelId = chat?.model;
    _loadModels();
    
    // Initialize response style preferences
    _selectedTone = chat?.responseTone ?? 'friendly';
    _selectedLength = chat?.responseLength ?? 'balanced';
    _selectedStyle = chat?.writingStyle ?? 'simple';
    _useEmojis = chat?.useEmojis ?? false;
    
    // Quick create is only available when creating new chats
    _useQuickCreate = widget.isCreating && chat == null;
  }

  Future<void> _loadModels() async {
    setState(() {
      _isLoadingModels = true;
    });

    try {
      // CRITICAL: Ensure AppConfigService is initialized before loading models
      // This is especially important after fresh login when cache might not be ready
      await AppConfigService.instance.initialize();
      
      final models = await _dbService.fetchModels();
      if (mounted) {
        setState(() {
          _models = models;
          _isLoadingModels = false;
        });
        
        // If no model selected, get default_model from app_config
        if (_selectedModelId == null) {
          try {
            // Use safe method to ensure it fetches from DB if cache not available
            final defaultModel = await AppConfigService.instance.getDefaultModelSafe();
            if (mounted) {
              setState(() {
                _selectedModelId = defaultModel;
              });
            }
          } catch (e) {
            // Only fallback to first model from list if default_model not available
            if (models.isNotEmpty && mounted) {
              setState(() {
                _selectedModelId = models.first.modelId;
              });
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingModels = false;
        });
        // Try to get default model as fallback
        if (_selectedModelId == null) {
          try {
            final defaultModel = await AppConfigService.instance.getDefaultModelSafe();
            if (mounted) {
              setState(() {
                _selectedModelId = defaultModel;
              });
            }
          } catch (e) {
            // If cache not available and no models loaded, leave as null
            // User will need to select a model or will see error when saving
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shortDescriptionController.dispose();
    _systemPromptController.dispose();
    _quickDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _generateFromDescription() async {
    final description = _quickDescriptionController.text.trim();
    
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe what AI you want to create'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _generatedVariations = [];
      _selectedVariationIndex = null;
    });

    try {
      final variations = await _openRouterApi.generateChatFromDescription(
        userDescription: description,
        variationCount: 3,
      );
      
      if (variations.isNotEmpty && mounted) {
        setState(() {
          _generatedVariations = variations;
          _selectedVariationIndex = 0; // Select first variation by default
          _hasGeneratedConfig = true;
          _isGenerating = false;
        });
        
        // Auto-fill with first variation
        _applyVariation(0);
      } else {
        if (mounted) {
          setState(() {
            _isGenerating = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to generate configurations. Please try again or use manual setup.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _applyVariation(int index) {
    if (index < 0 || index >= _generatedVariations.length) return;
    
    final variation = _generatedVariations[index];
    _nameController.text = variation['name'] as String;
    _shortDescriptionController.text = variation['shortDescription'] as String;
    _systemPromptController.text = variation['systemPrompt'] as String;
    
    setState(() {
      _selectedVariationIndex = index;
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImagePath = image.path;
        });
      }
    } catch (e) {
      if (mounted) {
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('permission') || errorString.contains('denied')) {
          await NotificationService.showEnablePhotoLibraryDialog(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to pick image: $e'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleSave() async {
    // In quick create preview mode, validate manually since form fields aren't rendered
    final isQuickCreatePreview = _useQuickCreate && _hasGeneratedConfig && widget.isCreating;
    
    if (isQuickCreatePreview) {
      // Manual validation for quick create preview
      final name = _nameController.text.trim();
      final shortDesc = _shortDescriptionController.text.trim();
      final systemPrompt = _systemPromptController.text.trim();
      
      if (name.isEmpty || shortDesc.isEmpty || systemPrompt.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please ensure all required fields are filled'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
    } else {
      // Normal form validation for manual mode
      if (!_formKey.currentState!.validate()) {
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String? avatarUrl = widget.chat?.avatarUrl;

      // Upload new avatar if selected
      if (_selectedImagePath != null) {
        if (widget.isCreating) {
          // For new chats, we'll need a temporary ID
          avatarUrl = await _storageService.uploadAvatar(
            _selectedImagePath!,
            DateTime.now().millisecondsSinceEpoch.toString(),
          );
        } else {
          avatarUrl = await _storageService.updateAvatar(
            _selectedImagePath!,
            widget.chat!.id,
            widget.chat!.avatarUrl,
          );
        }
      }

      // Ensure AppConfigService is initialized before getting model
      // This handles the case where user logs in and immediately tries to create a chat
      try {
        await AppConfigService.instance.initialize();
      } catch (e) {
        // Continue anyway, getDefaultModelSafe() will try to fetch from DB
      }
      
      // Always use default_model from app_config for new chats (especially quick create)
      // For editing existing chats, use the selected model or default
      String modelToUse;
      if (widget.isCreating && widget.chat == null) {
        // For new chats, always use default_model from app_config
        // Use getDefaultModelSafe() to ensure it fetches from DB if cache not available
        try {
          modelToUse = await AppConfigService.instance.getDefaultModelSafe();
        } catch (e) {
          // Fallback to selected model if available
          modelToUse = _selectedModelId ?? '';
          if (modelToUse.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Unable to get default model. Please try again or contact support.'),
                  duration: Duration(seconds: 3),
                ),
              );
            }
            return;
          }
        }
      } else {
        // For editing existing chats, use selected model or default
        modelToUse = _selectedModelId ?? '';
        if (modelToUse.isEmpty) {
          // Try to get from database as last resort
          try {
            modelToUse = await AppConfigService.instance.getDefaultModelSafe();
          } catch (e) {
            // If still empty, show error
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select a model or try again later.'),
                  duration: Duration(seconds: 3),
                ),
              );
            }
            return;
          }
        }
      }

      final name = _nameController.text.trim();
      final shortDescription = _shortDescriptionController.text.trim();
      final systemPrompt = _systemPromptController.text.trim();

      await widget.onSave(
        name: name,
        shortDescription: shortDescription,
        systemPrompt: systemPrompt,
        model: modelToUse,
        avatarUrl: avatarUrl,
        responseTone: _selectedTone,
        responseLength: _selectedLength,
        writingStyle: _selectedStyle,
        useEmojis: _useEmojis,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final isCreating = widget.isCreating;

    return Padding(
      padding: EdgeInsets.only(
        bottom: mediaQuery.viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: mediaQuery.size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Text(
                isCreating ? 'Create AI Chat' : 'Edit Settings',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(height: 1),
            
            // Scrollable Form content
            Flexible(
              child: GestureDetector(
                onTap: () {
                  // Dismiss keyboard when tapping on empty space (not on text fields or buttons)
                  FocusScope.of(context).unfocus();
                },
                behavior: HitTestBehavior.opaque,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Quick Create Mode (primary interface for creating)
                      if (_useQuickCreate && isCreating) ...[
                        // Show input form if not generated yet, or preview if generated
                        if (!_hasGeneratedConfig) ...[
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _quickDescriptionController,
                            autofocus: true,
                            decoration: InputDecoration(
                              labelText: 'What AI do you want?',
                              hintText: 'e.g., A fitness coach, A cooking assistant, A study buddy',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                            ),
                            maxLines: 3,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _generateFromDescription(),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _isGenerating ? null : _generateFromDescription,
                            icon: _isGenerating
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome),
                            label: const Text('Create'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: TextButton(
                              onPressed: _isGenerating ? null : () {
                                setState(() {
                                  _useQuickCreate = false;
                                });
                              },
                              child: const Text('Advanced Setup'),
                              style: TextButton.styleFrom(
                                foregroundColor: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ] else ...[
                          // Show multiple variations for selection
                          if (_generatedVariations.isNotEmpty) ...[
                            // List of variations
                            ...List.generate(_generatedVariations.length, (index) {
                              final variation = _generatedVariations[index];
                              final isSelected = _selectedVariationIndex == index;
                              final name = variation['name'] as String;
                              final shortDescription = variation['shortDescription'] as String;
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: InkWell(
                                  onTap: () => _applyVariation(index),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                                          : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.outlineVariant.withOpacity(0.5),
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Avatar
                                        AppAvatar(
                                          size: 48,
                                          name: name.isEmpty ? 'A' : name,
                                          imageUrl: widget.chat?.avatarUrl,
                                          isCircle: true,
                                        ),
                                        const SizedBox(width: 12),
                                        // Chat info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: theme.textTheme.titleSmall?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                shortDescription,
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Selection indicator
                                        if (isSelected)
                                          Icon(
                                            Icons.check_circle,
                                            color: theme.colorScheme.primary,
                                            size: 24,
                                          )
                                        else
                                          Icon(
                                            Icons.radio_button_unchecked,
                                            color: theme.colorScheme.onSurface.withOpacity(0.3),
                                            size: 24,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _isSaving ? null : () {
                                      setState(() {
                                        _hasGeneratedConfig = false;
                                        _generatedVariations = [];
                                        _selectedVariationIndex = null;
                                        _quickDescriptionController.clear();
                                        _isCustomizingFromVariation = false;
                                      });
                                    },
                                    child: const Text('Recreate'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _isSaving ? null : _handleSave,
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _isSaving
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('Confirm'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isCustomizingFromVariation = true;
                                  _useQuickCreate = false;
                                });
                              },
                              child: const Text('Customize'),
                              style: TextButton.styleFrom(
                                foregroundColor: theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ],
                      ] else ...[
                        // Manual Setup Mode (existing form)
                        // Avatar picker
                      Center(
                        child: GestureDetector(
                          onTap: _isSaving ? null : _pickImage,
                          child: Stack(
                            children: [
                              ClipOval(
                                child: SizedBox(
                                  width: 100,
                                  height: 100,
                                  child: _selectedImagePath != null
                                      ? Image.file(
                                          File(_selectedImagePath!),
                                          fit: BoxFit.cover,
                                          width: 100,
                                          height: 100,
                                        )
                                      : AppAvatar(
                                          size: 100,
                                          name: _nameController.text.isEmpty
                                              ? (widget.chat?.name ?? 'A')
                                              : _nameController.text,
                                          imageUrl: widget.chat?.avatarUrl,
                                          isCircle: true,
                                        ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.camera_alt,
                                    size: 20,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Tap to change avatar',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Chat Name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Chat Name',
                          hintText: 'e.g., Code Assistant, Writing Helper',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Short Description (for user view)
                      TextFormField(
                        controller: _shortDescriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Short Description',
                          hintText: 'e.g., Your programming companion for coding help',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a short description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // System Prompt (for AI)
                      TextFormField(
                        controller: _systemPromptController,
                        decoration: const InputDecoration(
                          labelText: 'System Prompt',
                          hintText: 'e.g., You are an expert coding assistant specialized in Flutter and Dart',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 4,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a system prompt';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      
                      // Advanced Settings Toggle
                      InkWell(
                        onTap: () {
                          setState(() {
                            _showAdvancedSettings = !_showAdvancedSettings;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.tune_outlined,
                                color: theme.colorScheme.primary,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Advanced Settings',
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Customize response style and preferences',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                _showAdvancedSettings 
                                    ? Icons.keyboard_arrow_up 
                                    : Icons.keyboard_arrow_down,
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Expandable Advanced Settings Section
                      if (_showAdvancedSettings) ...[
                        const SizedBox(height: 16),
                        
                        // Model selector
                        if (_isLoadingModels)
                          const Center(child: CircularProgressIndicator())
                        else
                          DropdownButtonFormField<String>(
                            value: _selectedModelId,
                            decoration: const InputDecoration(
                              labelText: 'AI Model',
                              border: OutlineInputBorder(),
                              helperText: 'All models use OpenRouter',
                            ),
                            items: _models.map((model) {
                              return DropdownMenuItem<String>(
                                value: model.modelId,
                                child: Text(
                                  model.name,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedModelId = value;
                                });
                              }
                            },
                          ),
                        const SizedBox(height: 16),
                        
                        // Response Tone
                        DropdownButtonFormField<String>(
                          initialValue: _selectedTone,
                          decoration: const InputDecoration(
                            labelText: 'Tone',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'friendly', child: Text('Friendly & Warm')),
                            DropdownMenuItem(value: 'professional', child: Text('Professional')),
                            DropdownMenuItem(value: 'casual', child: Text('Casual & Relaxed')),
                            DropdownMenuItem(value: 'formal', child: Text('Formal')),
                            DropdownMenuItem(value: 'enthusiastic', child: Text('Enthusiastic')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedTone = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Response Length
                        DropdownButtonFormField<String>(
                          initialValue: _selectedLength,
                          decoration: const InputDecoration(
                            labelText: 'Response Length',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'brief', child: Text('Brief - Quick answers')),
                            DropdownMenuItem(value: 'balanced', child: Text('Balanced - Moderate detail')),
                            DropdownMenuItem(value: 'detailed', child: Text('Detailed - Comprehensive')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedLength = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Writing Style
                        DropdownButtonFormField<String>(
                          initialValue: _selectedStyle,
                          decoration: const InputDecoration(
                            labelText: 'Writing Style',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'simple', child: Text('Simple - Easy to understand')),
                            DropdownMenuItem(value: 'technical', child: Text('Technical - Use terminology')),
                            DropdownMenuItem(value: 'creative', child: Text('Creative - Engaging language')),
                            DropdownMenuItem(value: 'analytical', child: Text('Analytical - Structured')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedStyle = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Use Emojis Switch
                        SwitchListTile(
                          value: _useEmojis,
                          onChanged: (value) {
                            setState(() {
                              _useEmojis = value;
                            });
                          },
                          title: const Text('Use Emojis'),
                          subtitle: const Text('Allow AI to use emojis in responses'),
                          secondary: Icon(
                            _useEmojis ? Icons.emoji_emotions : Icons.emoji_emotions_outlined,
                            color: theme.colorScheme.primary,
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                      
                      const SizedBox(height: 20),
                      
                      // Action Buttons (show in manual mode or when editing)
                      if (!_useQuickCreate || !isCreating)
                        Column(
                          children: [
                            // Show "Back to Quick Create" link when in manual mode for new chats
                            if (isCreating && widget.chat == null) ...[
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _useQuickCreate = true;
                                    _hasGeneratedConfig = false;
                                    _isCustomizingFromVariation = false;
                                  });
                                },
                                child: const Text('Quick Create'),
                                style: TextButton.styleFrom(
                                  foregroundColor: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _isSaving ? null : () {
                                      // If customizing from variation, go back to variation list
                                      // Otherwise, close the modal
                                      if (_isCustomizingFromVariation) {
                                        setState(() {
                                          _isCustomizingFromVariation = false;
                                          _useQuickCreate = true;
                                        });
                                      } else {
                                        Navigator.pop(context);
                                      }
                                    },
                                    child: const Text('Cancel'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _isSaving ? null : _handleSave,
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                    ),
                                    child: _isSaving
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            _isSaving 
                                                ? (isCreating ? 'Creating...' : 'Saving...')
                                                : (isCreating ? 'Create' : 'Save'),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}

