import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:traitus/models/chat_message.dart';
import 'package:traitus/models/note.dart';
import 'package:traitus/providers/chat_provider.dart';
import 'package:traitus/providers/notes_provider.dart';
import 'package:traitus/providers/chats_list_provider.dart';
import 'package:traitus/ui/notes_page.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.chatId});

  final String chatId;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _submit(BuildContext context) async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    
    final chatProvider = context.read<ChatProvider>();
    await chatProvider.sendUserMessage(text);
    
    // Update the last message in the chat list
    final chatsListProvider = context.read<ChatsListProvider>();
    chatsListProvider.updateLastMessage(widget.chatId, text);
    
    await Future.delayed(const Duration(milliseconds: 100));
    _scrollToBottom();
  }

  void _copyMessage(String content) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _saveMessageAsNote(String content) async {
    final notesProvider = context.read<NotesProvider>();

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SaveNoteBottomSheet(
        existingNotes: notesProvider.notes,
        currentContent: content,
        onSaveToNote: (title) async {
          final existingNote = notesProvider.notes.firstWhere(
            (note) => note.title == title,
          );
          final separator = '\n\n---\n\n*Added ${_formatTimestamp(DateTime.now())}*\n\n';
          final updatedContent = existingNote.content + separator + content;
          
          await notesProvider.updateNote(
            id: existingNote.id,
            title: title,
            content: updatedContent,
          );
          
          return true;
        },
        onRemoveFromNote: (title) async {
          final existingNote = notesProvider.notes.firstWhere(
            (note) => note.title == title,
          );
          
          // Remove the content from the note
          String updatedContent = existingNote.content;
          
          // Try to find and remove the content with separator
          final contentWithSeparator = '\n\n---\n\n*Added ${_formatTimestamp(DateTime.now())}*\n\n$content';
          if (updatedContent.contains(contentWithSeparator)) {
            updatedContent = updatedContent.replaceFirst(contentWithSeparator, '');
          } else {
            // Try to find it with any timestamp
            final regexPattern = RegExp(
              r'\n\n---\n\n\*Added .*?\*\n\n' + RegExp.escape(content),
              dotAll: true,
            );
            updatedContent = updatedContent.replaceFirst(regexPattern, '');
          }
          
          // If content is at the beginning (no separator before it)
          if (updatedContent.isEmpty || updatedContent.trim().isEmpty) {
            // If note is now empty, delete the entire note
            await notesProvider.deleteNote(existingNote.id);
            return true;
          } else if (existingNote.content == content) {
            // This was the only content in the note
            await notesProvider.deleteNote(existingNote.id);
            return true;
          } else {
            // Update the note with content removed
            updatedContent = updatedContent.trim();
            await notesProvider.updateNote(
              id: existingNote.id,
              title: title,
              content: updatedContent,
            );
            return true;
          }
        },
        onCreateNewNote: (title) async {
          await notesProvider.addNote(
            title: title,
            content: content,
          );
          return true;
        },
      ),
    );

    if (result != null && mounted) {
      final action = result['action'] as String;
      final message = action == 'new'
          ? 'Saved to new note'
          : action == 'add'
              ? 'Added to existing note'
              : 'Removed from note';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _formatTimestamp(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth > 768 ? 768.0 : screenWidth;
    final chatsListProvider = context.watch<ChatsListProvider>();
    final chat = chatsListProvider.getChatById(widget.chatId);
    final chatName = chat?.name ?? 'AI Chat';

    return Scaffold(
      appBar: AppBar(
        title: Text(chatName),
        actions: [
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
          Consumer<ChatProvider>(
            builder: (context, chat, _) {
              if (chat.isSending) {
                return IconButton(
                  tooltip: 'Stop generating',
                  icon: const Icon(Icons.stop_circle_outlined),
                  onPressed: () => chat.stopGeneration(),
                );
              }
              if (chat.hasMessages) {
                return IconButton(
                  tooltip: 'New chat',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('New Chat'),
                        content: const Text('Start a new conversation?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              chat.resetConversation();
                              Navigator.pop(context);
                            },
                            child: const Text('New Chat'),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (context, chat, _) {
                  // Filter out system messages and pending messages that are no longer needed
                  final items = chat.messages
                      .where((m) => m.role != ChatRole.system)
                      .where((m) => !m.isPending || chat.isSending)
                      .toList();

                  if (items.isEmpty) {
                    return _EmptyState(
                      onSuggestionTap: (text) {
                        _controller.text = text;
                        _submit(context);
                      },
                    );
                  }

                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 24),
                        itemBuilder: (context, index) {
                          final message = items[index];
                          final isUser = message.role == ChatRole.user;
                          final isLast = index == items.length - 1;
                          final isLastAssistant = isLast &&
                              !isUser &&
                              !message.isPending &&
                              !message.hasError;

                          return _MessageBubble(
                            message: message,
                            isUser: isUser,
                            theme: theme,
                            onCopy: () => _copyMessage(message.content),
                            onSave: !isUser && !message.isPending && !message.hasError
                                ? () => _saveMessageAsNote(message.content)
                                : null,
                            onRegenerate: isLastAssistant
                                ? () => chat.regenerateLastResponse()
                                : null,
                            onRetry: message.hasError && isLast
                                ? () {
                                    final lastUserIndex = chat.messages
                                        .lastIndexWhere((m) => m.role == ChatRole.user);
                                    if (lastUserIndex != -1) {
                                      final lastUserMessage =
                                          chat.messages[lastUserIndex].content;
                                      chat.sendUserMessage(lastUserMessage);
                                    }
                                  }
                                : null,
                            timestamp: _formatTime(message.createdAt),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            _InputBar(
              controller: _controller,
              onSend: () => _submit(context),
              onStop: () {
                context.read<ChatProvider>().stopGeneration();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onSuggestionTap});

  final void Function(String) onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suggestions = [
      'What can you help me with?',
      'Write a short story about space exploration',
      'Explain quantum computing in simple terms',
      'Help me plan a weekend trip',
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
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
                'How can I help you today?',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Ask me anything or choose a suggestion below to get started.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: suggestions.map((suggestion) {
                  return ActionChip(
                    label: Text(suggestion),
                    onPressed: () => onSuggestionTap(suggestion),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isUser,
    required this.theme,
    required this.onCopy,
    this.onSave,
    this.onRegenerate,
    this.onRetry,
    required this.timestamp,
  });

  final ChatMessage message;
  final bool isUser;
  final ThemeData theme;
  final VoidCallback onCopy;
  final VoidCallback? onSave;
  final VoidCallback? onRegenerate;
  final VoidCallback? onRetry;
  final String timestamp;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Row(
                children: [
                  Text(
                    timestamp,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            if (isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, right: 4),
                child: Text(
                  timestamp,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ),
            isUser
                ? _UserBubble(
                    message: message,
                    theme: theme,
                    onCopy: onCopy,
                  )
                : _AssistantBubble(
                    message: message,
                    theme: theme,
                    onCopy: onCopy,
                    onSave: onSave,
                    onRegenerate: onRegenerate,
                    onRetry: onRetry,
                  ),
          ],
        ),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({
    required this.message,
    required this.theme,
    required this.onCopy,
  });

  final ChatMessage message;
  final ThemeData theme;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(0, -40),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: MarkdownBody(
            selectable: true,
            softLineBreak: true,
            data: message.content.trim(),
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              p: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 16,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              h1: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 24,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              h2: theme.textTheme.titleLarge?.copyWith(
                fontSize: 20,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              h3: theme.textTheme.titleMedium?.copyWith(
                fontSize: 18,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy, size: 18, color: theme.colorScheme.onSurface),
              const SizedBox(width: 8),
              const Text('Copy'),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'copy') onCopy();
      },
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({
    required this.message,
    required this.theme,
    required this.onCopy,
    this.onSave,
    this.onRegenerate,
    this.onRetry,
  });

  final ChatMessage message;
  final ThemeData theme;
  final VoidCallback onCopy;
  final VoidCallback? onSave;
  final VoidCallback? onRegenerate;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (message.isPending) {
      return _LoadingMessage(theme: theme);
    }

    if (message.hasError) {
      return Card(
        color: theme.colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 20,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Error',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                message.content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: MarkdownBody(
            selectable: true,
            softLineBreak: true,
            data: message.content.trim(),
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              p: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 16,
              ),
              h1: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 24,
              ),
              h2: theme.textTheme.titleLarge?.copyWith(
                fontSize: 20,
              ),
              h3: theme.textTheme.titleMedium?.copyWith(
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.content_copy,
                  size: 16,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                onPressed: onCopy,
                tooltip: 'Copy',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                visualDensity: VisualDensity.compact,
              ),
              if (onSave != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    Icons.bookmark_outline,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  onPressed: onSave,
                  tooltip: 'Save to notes',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                  visualDensity: VisualDensity.compact,
                ),
              ],
              if (onRegenerate != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  onPressed: onRegenerate,
                  tooltip: 'Regenerate',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadingMessage extends StatelessWidget {
  const _LoadingMessage({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Thinking…',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSending = context.watch<ChatProvider>().isSending;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth > 768 ? 768.0 : screenWidth;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 6,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  enabled: !isSending,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: isSending ? 'AI is thinking…' : 'Message…',
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (isSending)
                IconButton.filledTonal(
                  tooltip: 'Stop generating',
                  onPressed: onStop,
                  icon: const Icon(Icons.stop_circle_outlined),
                )
              else
                IconButton.filled(
                  tooltip: 'Send message',
                  onPressed: controller.text.trim().isEmpty ? null : onSend,
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveNoteBottomSheet extends StatefulWidget {
  const _SaveNoteBottomSheet({
    required this.existingNotes,
    required this.currentContent,
    required this.onSaveToNote,
    required this.onRemoveFromNote,
    required this.onCreateNewNote,
  });

  final List<Note> existingNotes;
  final String currentContent;
  final Future<bool> Function(String title) onSaveToNote;
  final Future<bool> Function(String title) onRemoveFromNote;
  final Future<bool> Function(String title) onCreateNewNote;

  @override
  State<_SaveNoteBottomSheet> createState() => _SaveNoteBottomSheetState();
}

class _SaveNoteBottomSheetState extends State<_SaveNoteBottomSheet> {
  bool _isCreatingNew = false;
  final TextEditingController _titleController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateNote() async {
    if (_formKey.currentState!.validate()) {
      final title = _titleController.text.trim();
      await widget.onCreateNewNote(title);
      if (mounted) {
        Navigator.pop(context, {'action': 'new'});
      }
    }
  }

  bool _noteContainsContent(Note note) {
    // Check if the note contains the current content
    return note.content.contains(widget.currentContent);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.7;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
          // Title with back button when creating new
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_isCreatingNew)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      setState(() {
                        _isCreatingNew = false;
                        _titleController.clear();
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                if (_isCreatingNew) const SizedBox(width: 8),
                Icon(
                  _isCreatingNew ? Icons.add : Icons.bookmark_outline,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  _isCreatingNew ? 'New Note' : 'Save to Note',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Content area
          if (_isCreatingNew)
            // Create new note form
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Form(
                    key: _formKey,
                    child: TextFormField(
                      controller: _titleController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Note title',
                        hintText: 'Enter a title for this note',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.title),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                      onFieldSubmitted: (value) => _handleCreateNote(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _handleCreateNote,
                    icon: const Icon(Icons.check),
                    label: const Text('Create Note'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ),
            )
          else
            // List of existing notes
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.existingNotes.isNotEmpty)
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: widget.existingNotes.length,
                        itemBuilder: (context, index) {
                          final note = widget.existingNotes[index];
                          final isAlreadySaved = _noteContainsContent(note);
                          
                          return ListTile(
                            leading: Icon(
                              isAlreadySaved ? Icons.bookmark : Icons.bookmark_outline,
                              color: isAlreadySaved 
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primary.withOpacity(0.7),
                            ),
                            title: Text(
                              note.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: isAlreadySaved ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                isAlreadySaved ? Icons.remove_circle : Icons.add_circle,
                                color: isAlreadySaved 
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.primary,
                                size: 28,
                              ),
                              onPressed: () async {
                                if (isAlreadySaved) {
                                  await widget.onRemoveFromNote(note.title);
                                  if (context.mounted) {
                                    Navigator.pop(context, {'action': 'remove'});
                                  }
                                } else {
                                  await widget.onSaveToNote(note.title);
                                  if (context.mounted) {
                                    Navigator.pop(context, {'action': 'add'});
                                  }
                                }
                              },
                              tooltip: isAlreadySaved ? 'Remove from this note' : 'Add to this note',
                            ),
                            onTap: () async {
                              if (isAlreadySaved) {
                                await widget.onRemoveFromNote(note.title);
                                if (context.mounted) {
                                  Navigator.pop(context, {'action': 'remove'});
                                }
                              } else {
                                await widget.onSaveToNote(note.title);
                                if (context.mounted) {
                                  Navigator.pop(context, {'action': 'add'});
                                }
                              }
                            },
                          );
                        },
                      ),
                    ),
                  // Empty state if no notes
                  if (widget.existingNotes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      child: Text(
                        'No saved notes yet. Create your first note below.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  // Add new note button
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                          width: 1,
                        ),
                      ),
                    ),
                    child: FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _isCreatingNew = true;
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add New Note'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Bottom padding for safe area
          SizedBox(height: mediaQuery.padding.bottom),
        ],
      ),
    );
  }
}
