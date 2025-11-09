import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:traitus/models/ai_chat.dart';
import 'package:traitus/ui/widgets/app_avatar.dart';
import 'package:traitus/services/storage_service.dart';
import 'package:traitus/services/openrouter_api.dart';
import 'package:traitus/services/models_service.dart';
import 'package:traitus/services/entitlements_service.dart';
import 'package:traitus/ui/pro_upgrade_page.dart';

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
  
  String? _selectedImagePath;
  bool _isSaving = false;
  bool _showAdvancedSettings = false;
  bool _useQuickCreate = false; // Only for creating new chats
  bool _isGenerating = false;
  bool _hasGeneratedConfig = false; // Track if we've generated config from quick create
  String? _selectedModelSlug;
  List<AiModelInfo> _models = const [];
  UserPlan _plan = UserPlan.free;
  Key _dropdownKey = UniqueKey(); // Key to force dropdown rebuild when premium is selected
  
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
    
    // Initialize response style preferences
    _selectedTone = chat?.responseTone ?? 'friendly';
    _selectedLength = chat?.responseLength ?? 'balanced';
    _selectedStyle = chat?.writingStyle ?? 'simple';
    _useEmojis = chat?.useEmojis ?? false;
    
    // Quick create is only available when creating new chats
    _useQuickCreate = widget.isCreating && chat == null;
    _initModels();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shortDescriptionController.dispose();
    _systemPromptController.dispose();
    _quickDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _initModels() async {
    try {
      final catalog = ModelCatalogService();
      final ent = EntitlementsService();
      final results = await Future.wait([
        catalog.listEnabledModels(),
        ent.getCurrentUserPlan(),
      ]);
      _models = (results[0] as List<AiModelInfo>);
      _plan = results[1] as UserPlan;

      // Determine initial model: existing chat.model or first basic
      final existing = widget.chat?.model;
      if (existing != null && existing.isNotEmpty) {
        _selectedModelSlug = existing;
      } else {
        final basic = _models.firstWhere(
          (m) => !m.isPremium,
          orElse: () => _models.isNotEmpty ? _models.first : AiModelInfo(
            id: '00000000-0000-0000-0000-000000000000',
            slug: 'openrouter:env-default',
            displayName: 'Basic Model',
            tier: 'basic',
          enabled: true,
          supportsImageInput: false, // Default to false for fallback
        ),
        );
        _selectedModelSlug = basic.slug;
      }
    } catch (_) {
      // leave defaults; _selectedModelSlug stays null
    }
    if (mounted) setState(() {});
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
    });

    try {
      final result = await _openRouterApi.generateChatFromDescription(
        userDescription: description,
      );

      if (result != null && mounted) {
        // Auto-fill the form with generated values
        _nameController.text = result['name'] as String;
        _shortDescriptionController.text = result['shortDescription'] as String;
        _systemPromptController.text = result['systemPrompt'] as String;
        
        // Show preview in quick create mode, don't switch to manual
        setState(() {
          _hasGeneratedConfig = true;
          _isGenerating = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('AI configuration generated! Review and create, or customize further.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _isGenerating = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to generate configuration. Please try again or use manual setup.'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
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

      await widget.onSave(
        name: _nameController.text.trim(),
        shortDescription: _shortDescriptionController.text.trim(),
        systemPrompt: _systemPromptController.text.trim(),
        model: (_selectedModelSlug ?? widget.chat?.model ?? ''),
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
      child: SafeArea(
        top: false,
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
                          TextButton(
                            onPressed: _isGenerating ? null : () {
                              setState(() {
                                _useQuickCreate = false;
                              });
                            },
                            child: const Text('Advanced Setup'),
                            style: TextButton.styleFrom(
                              foregroundColor: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ] else ...[
                          // Preview after generation - allow quick create or customize
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.colorScheme.primary.withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _nameController.text,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _shortDescriptionController.text,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isSaving ? null : () {
                                    setState(() {
                                      _hasGeneratedConfig = false;
                                      _quickDescriptionController.clear();
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
                                _useQuickCreate = false;
                              });
                            },
                            child: const Text('Customize'),
                            style: TextButton.styleFrom(
                              foregroundColor: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
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
                        
                        // Model selector (DB-driven) - shows all models, disables premium for Free
                        if (_models.isEmpty)
                          const SizedBox.shrink()
                        else ...[
                          Builder(builder: (context) {
                            // Determine allowed models (for value validation)
                            final allowed = _plan == UserPlan.pro
                                ? _models
                                : _models.where((m) => !m.isPremium).toList();
                            
                            if (allowed.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            
                            // Ensure selected value exists in allowed list to avoid assertion errors
                            final allowedSlugs = allowed.map((m) => m.slug).toSet();
                            final currentValue = (_selectedModelSlug != null && allowedSlugs.contains(_selectedModelSlug))
                                ? _selectedModelSlug!
                                : allowed.first.slug;

                            // Build items list - show all models with visual indicators
                            // Premium items are enabled but will open upgrade page when selected by Free users
                            final dropdownItems = <DropdownMenuItem<String>>[];
                            for (final m in _models) {
                              final isPremium = m.isPremium;
                              final isLockedForUser = isPremium && _plan == UserPlan.free;
                              dropdownItems.add(
                                DropdownMenuItem<String>(
                                  value: m.slug,
                                  enabled: true, // Always enabled so users can tap it
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isLockedForUser) ...[
                                        Icon(
                                          Icons.lock_outline,
                                          size: 16,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Flexible(
                                        child: Text(
                                          m.displayName,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: isLockedForUser
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme.onSurface,
                                            fontWeight: isLockedForUser ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      if (isPremium && !isLockedForUser) ...[
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.workspace_premium,
                                          size: 16,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ],
                                      if (isLockedForUser) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          'Pro',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.primary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }

                            return DropdownButtonFormField<String>(
                              key: _dropdownKey,
                              value: currentValue,
                              decoration: const InputDecoration(
                                labelText: 'Model',
                                border: OutlineInputBorder(),
                              ),
                              items: dropdownItems,
                              onChanged: (v) {
                                if (v == null) return;
                                try {
                                  final selectedModel = _models.firstWhere(
                                    (m) => m.slug == v,
                                    orElse: () => _models.first,
                                  );
                                  // If Free user selects premium model, prevent selection and open upgrade page
                                  if (selectedModel.isPremium && _plan == UserPlan.free) {
                                    // Force dropdown to rebuild with original value by changing key
                                    setState(() {
                                      _dropdownKey = UniqueKey();
                                    });
                                    // Small delay to let dropdown close smoothly
                                    Future.delayed(const Duration(milliseconds: 300), () {
                                      if (context.mounted) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const ProUpgradePage(),
                                          ),
                                        );
                                      }
                                    });
                                    return;
                                  }
                                  setState(() {
                                    _selectedModelSlug = v;
                                  });
                                } catch (e) {
                                  // Silently handle errors
                                }
                              },
                              validator: (v) {
                                if ((v == null || v.trim().isEmpty) && widget.isCreating) {
                                  return 'Please select a model';
                                }
                                return null;
                              },
                            );
                          }),
                        ],
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
                                    onPressed: _isSaving ? null : () => Navigator.pop(context),
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
          ],
        ),
        ),
      ),
    );
  }
}

