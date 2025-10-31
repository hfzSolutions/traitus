import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:traitus/models/ai_chat.dart';
import 'package:traitus/providers/chat_provider.dart';
import 'package:traitus/providers/chats_list_provider.dart';
import 'package:traitus/ui/chat_page.dart';
import 'package:traitus/ui/settings_page.dart';
import 'package:traitus/ui/notes_page.dart';

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

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
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Saved notes',
            icon: const Icon(Icons.bookmark_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotesPage(),
                ),
              );
            },
          ),
        ],
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

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              return _ChatListItem(
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
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _showEditChatDialog(context, chat, chatsProvider),
        child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            // Avatar
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
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
                        child: Text(
                          chat.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
          ],
        ),
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

  void _saveChanges() {
    if (_formKey.currentState!.validate()) {
      final updatedChat = widget.chat.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
      );
      
      context.read<ChatsListProvider>().updateChat(updatedChat);
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI settings updated!'),
          duration: Duration(seconds: 2),
        ),
      );
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
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: _saveChanges,
                            icon: const Icon(Icons.check),
                            label: const Text('Save Changes'),
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

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _createChat() {
    if (_formKey.currentState!.validate()) {
      final newChat = AiChat(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        model: 'openrouter/auto',
      );
      
      context.read<ChatsListProvider>().addChat(newChat);
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${newChat.name} created!'),
          duration: const Duration(seconds: 2),
        ),
      );
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
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: _createChat,
                            icon: const Icon(Icons.add),
                            label: const Text('Create AI'),
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

