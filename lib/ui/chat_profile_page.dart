import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:traitus/models/ai_chat.dart';
import 'package:traitus/providers/chats_list_provider.dart';
import 'package:traitus/ui/widgets/app_avatar.dart';
import 'package:traitus/ui/widgets/chat_form_modal.dart';

class ChatProfilePage extends StatelessWidget {
  const ChatProfilePage({super.key, required this.chatId});

  final String chatId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatsListProvider = context.watch<ChatsListProvider>();
    final chat = chatsListProvider.getChatById(chatId);

    if (chat == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Chat Profile'),
        ),
        body: const Center(
          child: Text('Chat not found'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              _showEditChatDialog(context, chat);
            },
            tooltip: 'Edit Chat',
          ),
        ],
      ),
      body: ListView(
        children: [
          // Profile Header Section
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              children: [
                // Avatar
                AppAvatar(
                  size: 100,
                  name: chat.name,
                  imageUrl: chat.avatarUrl,
                ),
                const SizedBox(height: 8),
                Text(
                  chat.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (chat.shortDescription.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    chat.shortDescription,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),

          // Stats Section
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StatItem(
                  value: _formatCreatedDate(chat.createdAt),
                  label: 'Created',
                ),
              ],
            ),
          ),

          const Divider(),

          // Response Style Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Response Style',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _StyleItem(
                  label: 'Tone',
                  value: _formatTone(chat.responseTone),
                ),
                const SizedBox(height: 12),
                _StyleItem(
                  label: 'Length',
                  value: _formatLength(chat.responseLength),
                ),
                const SizedBox(height: 12),
                _StyleItem(
                  label: 'Writing Style',
                  value: _formatWritingStyle(chat.writingStyle),
                ),
                const SizedBox(height: 12),
                _StyleItem(
                  label: 'Emojis',
                  value: chat.useEmojis ? 'Enabled' : 'Disabled',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditChatDialog(BuildContext context, AiChat chat) {
    final chatsListProvider = context.read<ChatsListProvider>();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => ChatFormModal(
        chat: chat,
        isCreating: false,
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
          final updatedChat = chat.copyWith(
            name: name,
            shortDescription: shortDescription,
            systemPrompt: systemPrompt,
            model: model.isNotEmpty ? model : chat.model,
            avatarUrl: avatarUrl,
            responseTone: responseTone,
            responseLength: responseLength,
            writingStyle: writingStyle,
            useEmojis: useEmojis,
          );
          
          await chatsListProvider.updateChat(updatedChat);
          
          if (modalContext.mounted) {
            Navigator.pop(modalContext);
          }
        },
      ),
    );
  }

  String _formatCreatedDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays < 30) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else {
      return '${(difference.inDays / 365).floor()}y ago';
    }
  }

  String _formatTone(String tone) {
    return tone.substring(0, 1).toUpperCase() + tone.substring(1);
  }

  String _formatLength(String length) {
    return length.substring(0, 1).toUpperCase() + length.substring(1);
  }

  String _formatWritingStyle(String style) {
    return style.substring(0, 1).toUpperCase() + style.substring(1);
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _StyleItem extends StatelessWidget {
  const _StyleItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

