import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:traitus/models/ai_chat.dart';
import 'package:traitus/providers/chat_provider.dart';
import 'package:traitus/providers/chats_list_provider.dart';
import 'package:traitus/ui/chat_page.dart';
import 'package:traitus/ui/notes_page.dart';
import 'package:traitus/ui/settings_page.dart';
import 'package:traitus/ui/widgets/chat_form_modal.dart';
import 'package:traitus/ui/widgets/app_avatar.dart';
import 'package:traitus/ui/widgets/haptic_modal.dart';
import 'package:traitus/services/notification_service.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key, this.isInTabView = false});
  
  final bool isInTabView;

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  @override
  void initState() {
    super.initState();
    // Set up notification deep linking callback
    NotificationService.onNotificationChatTap = _navigateToChat;
  }

  @override
  void dispose() {
    // Clear callback when page is disposed
    NotificationService.onNotificationChatTap = null;
    super.dispose();
  }

  /// Navigate to a specific chat (used for deep linking from notifications)
  void _navigateToChat(String chatId) {
    if (!mounted) return;
    
    final chatsProvider = context.read<ChatsListProvider>();
    final chat = chatsProvider.getChatById(chatId);
    
    if (chat == null) {
      debugPrint('ChatListPage: Chat $chatId not found, cannot navigate');
      // Show a snackbar or handle gracefully
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat not found'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    chatsProvider.setActiveChat(chatId);
    chatsProvider.markChatAsRead(chatId);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider(
          create: (_) => ChatProvider(
            chatId: chat.id,
            model: chat.model,
            systemPrompt: chat.getEnhancedSystemPrompt(),
            responseLength: chat.responseLength,
            chatsListProvider: chatsProvider,
          ),
          child: ChatPage(chatId: chat.id),
        ),
      ),
    ).then((_) {
      // Clear active chat when returning to chat list
      if (mounted) {
        chatsProvider.setActiveChat(null);
      }
    });
  }

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
        title: const Text('Traitus'),
        automaticallyImplyLeading: !widget.isInTabView,
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
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(isInTabView: false),
                ),
              );
            },
            tooltip: 'Settings',
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
            return RefreshIndicator(
              onRefresh: () => context.read<ChatsListProvider>().refreshChats(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 120),
                        Opacity(
                          opacity: 0.5,
                          child: Image.asset(
                            'assets/logo.png',
                            width: 64,
                            height: 64,
                            fit: BoxFit.contain,
                          ),
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
                          'Click the create button to add an AI assistant',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          // Separate pinned and unpinned chats for visual distinction
          final pinnedChats = chats.where((c) => c.isPinned).toList();
          final unpinnedChats = chats.where((c) => !c.isPinned).toList();
          final hasBothSections = pinnedChats.isNotEmpty && unpinnedChats.isNotEmpty;

          return RefreshIndicator(
            onRefresh: () => context.read<ChatsListProvider>().refreshChats(),
            child: ReorderableListView.builder(
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
                        final chatsProvider = context.read<ChatsListProvider>();
                        chatsProvider.setActiveChat(chat.id);
                        chatsProvider.markChatAsRead(chat.id);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChangeNotifierProvider(
                              create: (_) => ChatProvider(
                                chatId: chat.id,
                                model: chat.model,
                                systemPrompt: chat.getEnhancedSystemPrompt(),
                                responseLength: chat.responseLength,
                                chatsListProvider: chatsProvider, // Pass cache provider
                              ),
                              child: ChatPage(chatId: chat.id),
                            ),
                          ),
                        ).then((_) {
                          // Clear active chat when returning to chat list
                          if (context.mounted) {
                            chatsProvider.setActiveChat(null);
                          }
                        });
                      },
                      formatTime: _formatTime,
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateChatDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Create'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
    );
  }

  Future<void> _showCreateChatDialog(BuildContext context) async {
    await HapticModal.showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ChatFormModal(
        chat: null,
        isCreating: true,
        onSave: ({
          required String name,
          required String shortDescription,
          required String systemPrompt,
          required String model,
          String? avatarUrl,
          required String responseTone,
          required String responseLength,
          required String writingStyle,
          required bool useEmojis,
        }) async {
          final newChat = AiChat(
            name: name,
            shortDescription: shortDescription,
            systemPrompt: systemPrompt,
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
        return await HapticModal.showDialog<bool>(
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
                      // Avatar - serves as delayed drag handle (long-press only)
                      ReorderableDelayedDragStartListener(
                        index: chatsProvider.chats.indexOf(chat),
                        child: AppAvatar(
                          size: 56,
                          name: chat.name,
                          imageUrl: chat.avatarUrl,
                          isCircle: true,
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
                                            fontWeight: (chat.unreadCount > 0)
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
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
                                    if (chat.unreadCount > 0) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}',
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: theme.colorScheme.onPrimary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              chat.lastMessage ?? chat.shortDescription,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                                fontWeight: chat.unreadCount > 0 ? FontWeight.w600 : null,
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
