import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:traitus/models/ai_chat.dart';
import 'package:traitus/providers/chat_provider.dart';
import 'package:traitus/providers/chats_list_provider.dart';
import 'package:traitus/ui/chat_page.dart';
import 'package:traitus/services/storage_service.dart';

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key, this.isInTabView = false});
  
  final bool isInTabView;

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Traitus AI'),
        automaticallyImplyLeading: !isInTabView,
      ),
      body: Consumer<ChatsListProvider>(
        builder: (context, chatsProvider, _) {
          if (!chatsProvider.isLoaded) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final chats = chatsProvider.chats;

          if (chats.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 64,
                      color: theme.colorScheme.primary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No chats yet',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start a conversation with your AI assistant',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          // Separate pinned and unpinned chats for visual distinction
          final pinnedChats = chats.where((c) => c.isPinned).toList();
          final unpinnedChats = chats.where((c) => !c.isPinned).toList();
          final hasBothSections = pinnedChats.isNotEmpty && unpinnedChats.isNotEmpty;

          return ReorderableListView.builder(
            itemCount: chats.length,
            onReorder: (oldIndex, newIndex) {
              chatsProvider.reorderChats(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final chat = chats[index];
              
              // Add section header for unpinned chats if there are pinned chats
              Widget? sectionHeader;
              if (hasBothSections && index == pinnedChats.length) {
                sectionHeader = _SectionHeader(title: 'All Chats');
              } else if (hasBothSections && index == 0) {
                sectionHeader = _SectionHeader(title: 'Pinned');
              }

              return Column(
                key: Key(chat.id),
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (sectionHeader != null) sectionHeader,
                  _ChatListItem(
                    chat: chat,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChangeNotifierProvider(
                            create: (_) => ChatProvider(
                              chatId: chat.id,
                              model: chat.model,
                              systemPrompt: chat.description,
                            ),
                            child: ChatPage(chatId: chat.id),
                          ),
                        ),
                      );
                    },
                    formatTime: _formatTime,
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateChatDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New AI Chat'),
      ),
    );
  }

  Future<void> _showCreateChatDialog(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _CreateChatModal(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatListItem extends StatelessWidget {
  const _ChatListItem({
    required this.chat,
    required this.onTap,
    required this.formatTime,
  });

  final AiChat chat;
  final VoidCallback onTap;
  final String Function(DateTime?) formatTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatsProvider = context.read<ChatsListProvider>();

    return Dismissible(
      key: Key(chat.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: theme.colorScheme.error,
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onError,
          size: 28,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Chat'),
            content: Text('Delete "${chat.name}"? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Delete',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        chatsProvider.deleteChat(chat.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${chat.name} deleted'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                chatsProvider.addChat(chat);
              },
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outlineVariant.withOpacity(0.5),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Drag handle - separate from InkWell to avoid gesture conflicts
            Container(
              color: Colors.transparent,
              child: ReorderableDragStartListener(
                index: chatsProvider.chats.indexOf(chat),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
                  child: Tooltip(
                    message: 'Hold to drag and reorder',
                    child: Icon(
                      Icons.drag_handle,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
            // Rest of the chat item with tap and long press
            Expanded(
              child: InkWell(
                onTap: onTap,
                onLongPress: () => _showEditChatDialog(context, chat, chatsProvider),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: chat.avatarUrl != null && chat.avatarUrl!.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  chat.avatarUrl!,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  cacheWidth: 112,
                                  cacheHeight: 112,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.smart_toy_outlined,
                                      size: 28,
                                      color: theme.colorScheme.onPrimaryContainer,
                                    );
                                  },
                                ),
                              )
                            : Icon(
                                Icons.smart_toy_outlined,
                                size: 28,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                      ),
                      const SizedBox(width: 12),
                      // Chat info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      if (chat.isPinned) ...[
                                        Icon(
                                          Icons.push_pin,
                                          size: 16,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Expanded(
                                        child: Text(
                                          chat.name,
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (chat.lastMessageTime != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    formatTime(chat.lastMessageTime),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              chat.lastMessage ?? chat.description,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Pin button
            IconButton(
              icon: Icon(
                chat.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: chat.isPinned 
                    ? theme.colorScheme.primary 
                    : theme.colorScheme.onSurface.withOpacity(0.3),
              ),
              onPressed: () {
                chatsProvider.togglePin(chat.id);
              },
              tooltip: chat.isPinned ? 'Unpin' : 'Pin',
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  void _showEditChatDialog(BuildContext context, AiChat chat, ChatsListProvider chatsProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EditChatModal(chat: chat),
    );
  }
}

class _EditChatModal extends StatefulWidget {
  const _EditChatModal({required this.chat});

  final AiChat chat;

  @override
  State<_EditChatModal> createState() => _EditChatModalState();
}

class _EditChatModalState extends State<_EditChatModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  final _imagePicker = ImagePicker();
  final _storageService = StorageService();
  String? _selectedImagePath;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.chat.name);
    _descriptionController = TextEditingController(text: widget.chat.description);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
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

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isUploading = true;
      });

      try {
        String? avatarUrl = widget.chat.avatarUrl;

        // Upload new avatar if selected
        if (_selectedImagePath != null) {
          avatarUrl = await _storageService.updateAvatar(
            _selectedImagePath!,
            widget.chat.id,
            widget.chat.avatarUrl,
          );
        }

        final updatedChat = widget.chat.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          avatarUrl: avatarUrl,
        );

        if (mounted) {
          context.read<ChatsListProvider>().updateChat(updatedChat);
          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('AI settings updated!'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update: $e'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: mediaQuery.viewInsets.bottom,
      ),
      child: Container(
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
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, color: theme.colorScheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Edit AI Settings',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Form content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Avatar picker
                    Center(
                      child: GestureDetector(
                        onTap: _isUploading ? null : _pickImage,
                        child: Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                              child: _selectedImagePath != null
                                  ? ClipOval(
                                      child: Image.file(
                                        File(_selectedImagePath!),
                                        fit: BoxFit.cover,
                                        width: 100,
                                        height: 100,
                                      ),
                                    )
                                  : (widget.chat.avatarUrl != null && widget.chat.avatarUrl!.isNotEmpty)
                                      ? ClipOval(
                                          child: Image.network(
                                            widget.chat.avatarUrl!,
                                            fit: BoxFit.cover,
                                            width: 100,
                                            height: 100,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Icon(
                                                Icons.smart_toy_outlined,
                                                size: 48,
                                                color: theme.colorScheme.onPrimaryContainer,
                                              );
                                            },
                                          ),
                                        )
                                      : Icon(
                                          Icons.smart_toy_outlined,
                                          size: 48,
                                          color: theme.colorScheme.onPrimaryContainer,
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
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'AI Name',
                        hintText: 'e.g., Code Assistant, Writing Helper',
                        prefixIcon: Icon(Icons.person_outline),
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
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'System Prompt',
                        hintText: 'e.g., You are an expert coding assistant specialized in Flutter and Dart',
                        helperText: 'Define the AI\'s personality and expertise',
                        helperMaxLines: 2,
                        prefixIcon: Icon(Icons.psychology_outlined),
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
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isUploading ? null : () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: _isUploading ? null : _saveChanges,
                            icon: _isUploading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check),
                            label: Text(_isUploading ? 'Saving...' : 'Save Changes'),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: mediaQuery.padding.bottom + 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateChatModal extends StatefulWidget {
  const _CreateChatModal();

  @override
  State<_CreateChatModal> createState() => _CreateChatModalState();
}

class _CreateChatModalState extends State<_CreateChatModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _storageService = StorageService();
  String? _selectedImagePath;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
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

  Future<void> _createChat() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isCreating = true;
      });

      try {
        final model = dotenv.env['OPENROUTER_MODEL'];
        if (model == null || model.isEmpty) {
          throw Exception('OPENROUTER_MODEL not configured');
        }

        final newChat = AiChat(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          model: model,
        );

        // Upload avatar if selected
        String? avatarUrl;
        if (_selectedImagePath != null) {
          avatarUrl = await _storageService.uploadAvatar(
            _selectedImagePath!,
            newChat.id,
          );
        }

        final chatWithAvatar = avatarUrl != null
            ? newChat.copyWith(avatarUrl: avatarUrl)
            : newChat;

        if (mounted) {
          context.read<ChatsListProvider>().addChat(chatWithAvatar);
          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${chatWithAvatar.name} created!'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create chat: $e'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isCreating = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: mediaQuery.viewInsets.bottom,
      ),
      child: Container(
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
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.smart_toy_outlined, color: theme.colorScheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Create New AI Chat',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Form content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Avatar picker
                    Center(
                      child: GestureDetector(
                        onTap: _isCreating ? null : _pickImage,
                        child: Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                              child: _selectedImagePath != null
                                  ? ClipOval(
                                      child: Image.file(
                                        File(_selectedImagePath!),
                                        fit: BoxFit.cover,
                                        width: 100,
                                        height: 100,
                                      ),
                                    )
                                  : Icon(
                                      Icons.smart_toy_outlined,
                                      size: 48,
                                      color: theme.colorScheme.onPrimaryContainer,
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
                        'Tap to add avatar (optional)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'AI Name',
                        hintText: 'e.g., Code Assistant, Writing Helper',
                        prefixIcon: Icon(Icons.person_outline),
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
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'System Prompt',
                        hintText: 'e.g., You are an expert coding assistant specialized in Flutter and Dart',
                        helperText: 'Define the AI\'s personality and expertise',
                        helperMaxLines: 2,
                        prefixIcon: Icon(Icons.psychology_outlined),
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
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isCreating ? null : () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: _isCreating ? null : _createChat,
                            icon: _isCreating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.add),
                            label: Text(_isCreating ? 'Creating...' : 'Create AI'),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: mediaQuery.padding.bottom + 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

