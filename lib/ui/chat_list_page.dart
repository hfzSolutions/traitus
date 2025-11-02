import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:traitus/models/ai_chat.dart';
import 'package:traitus/providers/chat_provider.dart';
import 'package:traitus/providers/chats_list_provider.dart';
import 'package:traitus/ui/chat_page.dart';
import 'package:traitus/ui/notes_page.dart';
import 'package:traitus/ui/widgets/chat_form_modal.dart';

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
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotesPage(isInTabView: false),
                ),
              );
            },
            tooltip: 'Saved Notes',
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
                              systemPrompt: chat.getEnhancedSystemPrompt(),
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
      builder: (context) => ChatFormModal(
        chat: null,
        isCreating: true,
        onSave: ({
          required String name,
          required String description,
          String? avatarUrl,
          required String responseTone,
          required String responseLength,
          required String writingStyle,
          required bool useEmojis,
        }) async {
          final model = dotenv.env['OPENROUTER_MODEL'];
          if (model == null || model.isEmpty) {
            throw Exception('OPENROUTER_MODEL not configured');
          }

          final newChat = AiChat(
            name: name,
            description: description,
            model: model,
            avatarUrl: avatarUrl,
            responseTone: responseTone,
            responseLength: responseLength,
            writingStyle: writingStyle,
            useEmojis: useEmojis,
          );

          if (context.mounted) {
            await context.read<ChatsListProvider>().addChat(newChat);
            
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${newChat.name} created!'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        },
      ),
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
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
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
            // Chat item - tappable, no drag conflict
            Expanded(
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    children: [
                      // Avatar - serves as drag handle
                      ReorderableDragStartListener(
                        index: chatsProvider.chats.indexOf(chat),
                        child: Container(
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

}
