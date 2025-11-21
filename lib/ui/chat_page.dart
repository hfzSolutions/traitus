import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:traitus/config/default_ai_config.dart';
import 'package:traitus/models/ai_chat.dart';
import 'package:traitus/models/chat_message.dart';
import 'package:traitus/models/note.dart';
import 'package:traitus/providers/chat_provider.dart';
import 'package:traitus/providers/notes_provider.dart';
import 'package:traitus/providers/chats_list_provider.dart';
import 'package:traitus/ui/widgets/chat_form_modal.dart';
import 'package:traitus/ui/widgets/app_avatar.dart';
import 'package:traitus/ui/widgets/haptic_modal.dart';
import 'package:traitus/ui/notes_page.dart';
import 'package:traitus/ui/chat_profile_page.dart';
import 'package:traitus/services/notification_service.dart';
import 'package:traitus/services/storage_service.dart';
import 'package:traitus/services/tts_service.dart';

const _uuid = Uuid();

/// Represents an attached image with its upload state
class _AttachedImage {
  _AttachedImage({
    required this.filePath,
    this.uploadedUrl,
    this.isUploading = false,
    this.hasError = false,
    required this.id,
  });

  final String filePath;
  String? uploadedUrl;
  bool isUploading;
  bool hasError;
  final String id; // Unique ID for this attachment
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.chatId});

  final String chatId;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<_InputBarState> _inputBarKey = GlobalKey<_InputBarState>();
  late final ChatProvider _chatProvider;
  bool _isInitialScroll = true;
  bool _hasInitialMessagesLoaded = false;
  int _previousMessageCount = 0;

  @override
  void initState() {
    super.initState();
    // Store a reference to ChatProvider to use in dispose()
    _chatProvider = context.read<ChatProvider>();
    _chatProvider.addListener(_onChatUpdate);
    _scrollController.addListener(_onScroll);
    
    // Listen to app lifecycle changes (e.g., when app goes to background)
    WidgetsBinding.instance.addObserver(this);
    
    // Mark chat as read when page opens - do this after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final chatsListProvider = context.read<ChatsListProvider>();
        chatsListProvider.setActiveChat(widget.chatId);
        chatsListProvider.markChatAsRead(widget.chatId);
      } catch (e) {
        // Provider might be disposed, ignore
        debugPrint('Could not mark chat as read: $e');
      }
    });
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Stop TTS when app goes to background or becomes inactive
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      try {
        final ttsService = TtsService();
        ttsService.stop();
      } catch (e) {
        debugPrint('Error stopping TTS on app lifecycle change: $e');
      }
    }
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    
    try {
      context.read<ChatsListProvider>().setActiveChat(null);
    } catch (_) {}
    _chatProvider.removeListener(_onChatUpdate);
    _scrollController.removeListener(_onScroll);
    _controller.dispose();
    _scrollController.dispose();
    
    // Stop TTS playback when leaving the chat screen
    try {
      final ttsService = TtsService();
      ttsService.stop();
    } catch (e) {
      debugPrint('Error stopping TTS on dispose: $e');
    }
    
    super.dispose();
  }
  
  void _onChatUpdate() {
    if (!mounted) return;
    
    try {
      // Check if initial messages have finished loading
      if (!_hasInitialMessagesLoaded && !_chatProvider.isLoading) {
        _hasInitialMessagesLoaded = true;
        final currentMessageCount = _chatProvider.messages
            .where((m) => m.role != ChatRole.system)
            .length;
        _previousMessageCount = currentMessageCount;
        
        // With reverse: true, ListView naturally starts at bottom (position 0)
        // No need to scroll - messages are already positioned correctly!
        return;
      }
      
      // Only auto-scroll with animation when NEW messages arrive
      // (not during initial load, not when loading older messages)
      if (_hasInitialMessagesLoaded && 
          !_chatProvider.isLoading && 
          !_chatProvider.isLoadingOlder) {
        // Track total messages (including pending) to detect new additions
        final currentMessageCount = _chatProvider.messages
            .where((m) => m.role != ChatRole.system)
            .length;
        
        if (currentMessageCount > _previousMessageCount) {
          _previousMessageCount = currentMessageCount;
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _scrollController.hasClients) {
              // With reverse: true, position 0 is at bottom (latest messages)
              // Only scroll if user is near the bottom (within 300px from position 0)
              final position = _scrollController.position;
              final currentScroll = position.pixels;
              
              // Distance from bottom (position 0)
              if (currentScroll < 300) {
                _scrollToBottom();
              }
            }
          });
        }
      }
    } catch (e) {
      // Provider might be disposed, ignore
      debugPrint('Error in _onChatUpdate: $e');
    }
  }

  void _onScroll() {
    if (!mounted || !_scrollController.hasClients) return;
    
    try {
      final position = _scrollController.position;
      // With reverse: true, scrolling up means scrolling toward maxScrollExtent
      // Check if user has scrolled near the top (maxScrollExtent) to load older messages
      final distanceFromTop = position.maxScrollExtent - position.pixels;
      if (distanceFromTop <= 200 && 
          !_chatProvider.isLoadingOlder &&
          _chatProvider.hasMoreMessages &&
          !_isInitialScroll) {
        _loadOlderMessages();
      }
    } catch (e) {
      // Provider might be disposed, ignore
      debugPrint('Error in _onScroll: $e');
    }
  }

  Future<void> _loadOlderMessages() async {
    if (!mounted) return;
    try {
      if (_chatProvider.isLoadingOlder) return;
    } catch (e) {
      debugPrint('Error accessing provider in _loadOlderMessages: $e');
      return;
    }
    
    // With reverse: true, we need to preserve scroll position differently
    // Save current scroll position and max extent
    final scrollOffset = _scrollController.offset;
    final maxExtent = _scrollController.position.maxScrollExtent;
    
    try {
      await _chatProvider.loadOlderMessages();
    } catch (e) {
      debugPrint('Error loading older messages: $e');
      return;
    }
    
    // Restore scroll position after loading older messages
    // With reverse: true, older messages are added at the end (top visually)
    // We need to maintain the same visual position
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        final newMaxExtent = _scrollController.position.maxScrollExtent;
        final difference = newMaxExtent - maxExtent;
        // Adjust scroll to maintain visual position
        _scrollController.jumpTo(scrollOffset + difference);
      }
    });
  }

  void _scrollToBottom() {
    // With reverse: true, position 0 is at the bottom (latest messages)
    // Scroll to position 0 to show the latest messages
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _submit(BuildContext context, {List<String>? imageUrls}) async {
    final text = _controller.text;
    // Allow sending if there's text OR images
    if ((text.trim().isEmpty && (imageUrls == null || imageUrls.isEmpty)) || !mounted) return;
    
    // Stop listening if microphone is active
    _inputBarKey.currentState?.stopListening();
    
    _controller.clear();
    
    try {
      final chatProvider = context.read<ChatProvider>();
      
      // Update last message immediately with user's message (so it shows in chat list right away)
      if (mounted) {
        try {
          final chatsListProvider = context.read<ChatsListProvider>();
          final previewText = text.trim().isNotEmpty 
              ? text 
              : (imageUrls != null && imageUrls.isNotEmpty 
                  ? '📷 Image${imageUrls.length > 1 ? 's' : ''}' 
                  : '');
          chatsListProvider.updateLastMessage(widget.chatId, previewText);
        } catch (e) {
          debugPrint('Could not update last message: $e');
        }
      }
      
      // Start sending the message (this will add user message immediately)
      final sendFuture = chatProvider.sendUserMessage(text, imageUrls: imageUrls);
      
      // Scroll to show the user's message immediately after it's added
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollToBottom();
        }
      });
      
      // Wait for the response to complete
      // Note: The last message will be updated again in chat_provider.dart when bot responds
      await sendFuture;
    } catch (e) {
      debugPrint('Error submitting message: $e');
    }
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
    
    // Ensure notes are loaded before opening the modal
    await notesProvider.refreshNotes();

    final result = await HapticModal.showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SaveNoteBottomSheet(
        existingNotes: notesProvider.notes,
        currentContent: content,
        onSaveToNote: (title) async {
          final existingNote = notesProvider.notes.firstWhere(
            (note) => note.title == title,
          );
          
          // Create a new section instead of combining content
          await notesProvider.addSectionToNote(
            noteId: existingNote.id,
            content: content,
          );
          
          return true;
        },
        onRemoveFromNote: (title) async {
          final existingNote = notesProvider.notes.firstWhere(
            (note) => note.title == title,
          );
          
          // Try to find and delete the section with matching content
          try {
            final sections = await notesProvider.fetchNoteSections(existingNote.id);
            final matchingSection = sections.firstWhere(
              (section) => section.content == content,
              orElse: () => throw Exception('Section not found'),
            );
            
            await notesProvider.deleteNoteSection(matchingSection.id);
            
            // Check if note has any sections or content left
            final remainingSections = await notesProvider.fetchNoteSections(existingNote.id);
            if (remainingSections.isEmpty && existingNote.content.isEmpty) {
              // No sections and no content, delete the note
              await notesProvider.deleteNote(existingNote.id);
            }
          } catch (e) {
            // If section not found, try old method (backward compatibility)
            // Remove the content from the note's content field
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
          }
          
          return true;
        },
        onCreateNewNote: (title) async {
          // Create note with empty content, then add a section
          final note = await notesProvider.addNote(
            title: title,
            content: '', // Empty content, we'll use sections
          );
          
          // Add the content as a section
          await notesProvider.addSectionToNote(
            noteId: note.id,
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
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotesPage(isInTabView: false),
                ),
              );
            },
          ),
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

  void _showEditChatDialog(BuildContext context) {
    final chatsListProvider = context.read<ChatsListProvider>();
    final chatProvider = context.read<ChatProvider>(); // Get provider before showing modal
    final chat = chatsListProvider.getChatById(widget.chatId);
    
    if (chat == null) return;
    
    HapticModal.showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
          
          // Update ChatProvider with new model and system prompt
          // Use the captured provider reference, not the modal context
          chatProvider.updateFromChat(
            model: updatedChat.model,
            systemPrompt: updatedChat.getEnhancedSystemPrompt(),
          );
          
          if (modalContext.mounted) {
            ScaffoldMessenger.of(modalContext).showSnackBar(
              const SnackBar(
                content: Text('Chat settings updated!'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
      ),
    );
  }

  void _duplicateBot(BuildContext context) {
    final chatsListProvider = context.read<ChatsListProvider>();
    final chat = chatsListProvider.getChatById(widget.chatId);
    
    if (chat == null) return;
    
    // Create a copy of the chat with "(Copy)" appended to the name
    // This will be used to pre-populate the form
    final chatCopy = chat.copyWith(
      name: '${chat.name} (Copy)',
      // Reset fields that shouldn't be copied
      lastMessage: null,
      lastMessageTime: null,
      isPinned: false,
      sortOrder: 0,
      lastReadAt: null,
      unreadCount: 0,
    );
    
    HapticModal.showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ChatFormModal(
        chat: chatCopy, // Pre-populate with copied chat data
        isCreating: true, // This is creating a new chat, not editing
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
          try {
            // Create the new duplicated chat with user's edits
            final duplicatedChat = AiChat(
              name: name,
              shortDescription: shortDescription,
              systemPrompt: systemPrompt,
              model: model.isNotEmpty ? model : chat.model,
              avatarUrl: avatarUrl ?? chat.avatarUrl, // Use new avatar if uploaded, otherwise keep original
              responseTone: responseTone,
              responseLength: responseLength,
              writingStyle: writingStyle,
              useEmojis: useEmojis,
            );
            
            await chatsListProvider.addChat(duplicatedChat);
            
            if (context.mounted) {
              Navigator.pop(context); // Close the modal
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Bot "${name}" created successfully!'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } catch (e) {
            debugPrint('Error duplicating bot: $e');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to duplicate bot: ${e.toString()}'),
                  duration: const Duration(seconds: 3),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
            rethrow; // Re-throw so the modal doesn't close on error
          }
        },
      ),
    );
  }

  // Model picker removed - app now uses OPENROUTER_MODEL from env only

  void _sendQuickReply(String text) {
    _controller.text = text;
    _submit(context);
  }

  void _showClearChatDialog(BuildContext context) {
    final theme = Theme.of(context);
    HapticModal.showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Messages'),
        content: const Text('Delete all messages in this chat? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _chatProvider.resetConversation();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All messages cleared'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                debugPrint('Error resetting conversation: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to clear messages: ${e.toString()}'),
                      duration: const Duration(seconds: 3),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                }
              }
            },
            child: Text(
              'Clear',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
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
        title: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatProfilePage(chatId: widget.chatId),
              ),
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                // Avatar
                AppAvatar(
                  size: 40,
                  name: chatName,
                  imageUrl: chat?.avatarUrl,
                  isCircle: true,
                ),
                const SizedBox(width: 12),
                // Chat name
                Expanded(
                  child: Text(
                    chatName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          Consumer<ChatProvider>(
            builder: (context, chat, _) {
              // Only show stop button when AI is generating
              if (chat.isSending) {
                return IconButton(
                  tooltip: 'Stop generating',
                  icon: const Icon(Icons.stop_circle_outlined),
                  onPressed: () => chat.stopGeneration(),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'More options',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'edit') {
                _showEditChatDialog(context);
              } else if (value == 'clear') {
                _showClearChatDialog(context);
              } else if (value == 'duplicate') {
                _duplicateBot(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined),
                    SizedBox(width: 12),
                    Text('Edit Chat Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'duplicate',
                child: Row(
                  children: [
                    Icon(Icons.copy_outlined),
                    SizedBox(width: 12),
                    Text('Duplicate Bot'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_outlined),
                    SizedBox(width: 12),
                    Text('Clear All Messages'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  // Dismiss keyboard when tapping on the message area
                  FocusScope.of(context).unfocus();
                },
                behavior: HitTestBehavior.opaque,
                child: Consumer<ChatProvider>(
                  builder: (context, chat, _) {
                    // Show loading indicator while messages are being loaded
                    if (chat.isLoading) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Loading messages...',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Filter out system messages and pending messages that are no longer needed
                    // Also exclude old empty pending messages (but keep current one if actively sending)
                    final items = chat.messages
                        .where((m) => m.role != ChatRole.system)
                        .where((m) {
                          // If pending and empty, only show if we're actively sending (it's the current message)
                          if (m.isPending && m.content.trim().isEmpty) {
                            return chat.isSending; // Only show if currently sending (current message)
                          }
                          // Show pending messages only when actively sending
                          return !m.isPending || chat.isSending;
                        })
                        .toList();

                    if (items.isEmpty) {
                      // Get the AiChat object for category detection
                      final aiChat = context.read<ChatsListProvider>().getChatById(widget.chatId);
                      return _EmptyState(
                        chatName: aiChat?.name ?? '',
                        chatDescription: aiChat?.shortDescription ?? '',
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
                        reverse: true, // Standard chat behavior: show latest messages at bottom
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: items.length + (chat.hasMoreMessages ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 24),
                        itemBuilder: (context, index) {
                          // Show loading indicator at the end (top when reversed) if there are more messages
                          if (chat.hasMoreMessages && index == items.length) {
                            return _LoadMoreIndicator(
                              isLoading: chat.isLoadingOlder,
                              theme: theme,
                            );
                          }
                          
                          // Get message index (reverse order: last item is at highest index)
                          final messageIndex = items.length - 1 - index;
                          final message = items[messageIndex];
                          final isUser = message.role == ChatRole.user;
                          final isLast = messageIndex == items.length - 1; // Last item in array is newest message
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
                            onQuickReply: isLastAssistant
                                ? (text) => _sendQuickReply(text)
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
            ),
            const Divider(height: 1),
            _InputBar(
              key: _inputBarKey,
              controller: _controller,
              onSend: (imageUrls) => _submit(context, imageUrls: imageUrls),
              onStop: () {
                context.read<ChatProvider>().stopGeneration();
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'AI can make mistakes. Please verify important information.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Model picker removed; tune icon now opens the edit modal
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.chatName,
    required this.chatDescription,
    required this.onSuggestionTap,
  });

  final String chatName;
  final String chatDescription;
  final void Function(String) onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Detect category and get relevant example questions
    final category = DefaultAIConfig.detectChatCategory(chatName, chatDescription);
    final suggestions = DefaultAIConfig.getExampleQuestions(category);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
    this.onQuickReply,
    required this.timestamp,
  });

  final ChatMessage message;
  final bool isUser;
  final ThemeData theme;
  final VoidCallback onCopy;
  final VoidCallback? onSave;
  final VoidCallback? onRegenerate;
  final VoidCallback? onRetry;
  final void Function(String)? onQuickReply;
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
                    onQuickReply: onQuickReply,
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
    final hasImages = message.imageUrls.isNotEmpty;
    final hasText = message.content.trim().isNotEmpty;

    return PopupMenuButton<String>(
      offset: const Offset(0, -40),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Display images if any
              if (hasImages) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: message.imageUrls.map((imageUrl) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl,
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 200,
                            height: 200,
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 200,
                            height: 200,
                            color: theme.colorScheme.errorContainer,
                            child: Icon(
                              Icons.broken_image,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
                ),
                if (hasText) const SizedBox(height: 12),
              ],
              // Display text if any
              if (hasText)
                MarkdownBody(
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
            ],
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

class _AssistantBubble extends StatefulWidget {
  const _AssistantBubble({
    required this.message,
    required this.theme,
    required this.onCopy,
    this.onSave,
    this.onRegenerate,
    this.onRetry,
    this.onQuickReply,
  });

  final ChatMessage message;
  final ThemeData theme;
  final VoidCallback onCopy;
  final VoidCallback? onSave;
  final VoidCallback? onRegenerate;
  final VoidCallback? onRetry;
  final void Function(String)? onQuickReply;

  @override
  State<_AssistantBubble> createState() => _AssistantBubbleState();
}

class _AssistantBubbleState extends State<_AssistantBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  List<Animation<double>> _buttonAnimations = [];
  List<String> _previousQuickReplies = [];
  final TtsService _ttsService = TtsService();
  bool _isPlayingThisMessage = false;
  bool _isTtsAvailable = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    
    // Initialize TTS service and check availability
    _initializeTts();
    
    // Listen to TTS state changes
    _ttsService.addListener(_onTtsStateChanged);
    
    // Check if this message is currently playing
    _checkTtsState();
  }
  
  Future<void> _initializeTts() async {
    await _ttsService.initialize();
    if (mounted) {
      setState(() {
        _isTtsAvailable = _ttsService.isAvailable;
      });
    }
  }
  
  void _onTtsStateChanged() {
    if (mounted) {
      _checkTtsState();
    }
  }
  
  void _checkTtsState() {
    final wasPlaying = _isPlayingThisMessage;
    _isPlayingThisMessage = _ttsService.isPlayingMessage(widget.message.id);
    if (wasPlaying != _isPlayingThisMessage && mounted) {
      setState(() {});
    }
  }
  
  Future<void> _toggleTts() async {
    if (!_isTtsAvailable) {
      // Show helpful message if TTS isn't available (e.g., on simulator)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice playback is not available on this device. Try testing on a physical device.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    if (_isPlayingThisMessage) {
      // Stop if currently playing this message
      await _ttsService.stop();
    } else {
      // Stop any other message that might be playing
      await _ttsService.stop();
      // Start playing this message
      final success = await _ttsService.speak(widget.message.content, widget.message.id);
      if (!success && mounted) {
        // If speak failed, TTS might have become unavailable
        setState(() {
          _isTtsAvailable = _ttsService.isAvailable;
        });
        if (!_isTtsAvailable) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Voice playback is not available on this device.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }
    // Update state after a short delay to allow TTS service to update
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _checkTtsState();
      }
    });
  }

  @override
  void didUpdateWidget(_AssistantBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If message just completed, reset animation
    if (oldWidget.message.isPending && !widget.message.isPending) {
      _animationController.reset();
    }
    // Check TTS state when widget updates
    _checkTtsState();
  }

  @override
  void dispose() {
    _ttsService.removeListener(_onTtsStateChanged);
    _animationController.dispose();
    super.dispose();
  }

  void _startAnimation() {
    if (!_animationController.isAnimating) {
      _animationController.forward();
    }
  }

  bool _listsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator only if pending and no content yet
    if (widget.message.isPending && widget.message.content.isEmpty) {
      return _LoadingMessage(theme: widget.theme);
    }

    if (widget.message.hasError) {
      return Card(
        color: widget.theme.colorScheme.errorContainer,
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
                    color: widget.theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Error',
                      style: widget.theme.textTheme.titleSmall?.copyWith(
                        color: widget.theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.message.content,
                style: widget.theme.textTheme.bodyMedium?.copyWith(
                  color: widget.theme.colorScheme.onErrorContainer,
                ),
              ),
              if (widget.onRetry != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: widget.onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        // Get quick replies - wait for API suggestions first
        final aiGeneratedReplies = chatProvider.quickReplies;
        final shouldWait = chatProvider.shouldWaitForQuickReplies;
        
        // Only show defaults if:
        // 1. We're not waiting for API suggestions (timeout passed or generation failed)
        // 2. We have no AI-generated replies
        // 3. Message is complete (not pending)
        final shouldShowDefaults = !shouldWait && 
            aiGeneratedReplies.isEmpty && 
            !widget.message.isPending;
        
        final quickReplies = aiGeneratedReplies.isNotEmpty
            ? aiGeneratedReplies.take(2).toList()
            : (shouldShowDefaults 
                ? DefaultAIConfig.getQuickReplySnippets().take(2).toList().cast<String>()
                : <String>[]);

        // Update button animations when quick replies change
        final repliesChanged = _previousQuickReplies.length != quickReplies.length ||
            !_listsEqual(_previousQuickReplies, quickReplies);
        
        if (quickReplies.isNotEmpty) {
          // Check if we need to update animations (new replies or content changed)
          if (repliesChanged) {
            _previousQuickReplies = List.from(quickReplies);
            _buttonAnimations = List.generate(
              quickReplies.length,
              (index) {
                // Calculate stagger delay - distribute evenly across animation
                // Each button gets a portion of the animation timeline
                final totalButtons = quickReplies.length;
                final staggerDelay = 0.1; // 10% delay between buttons
                final buttonDuration = (1.0 - (totalButtons - 1) * staggerDelay) / totalButtons;
                final start = (index * (staggerDelay + buttonDuration)).clamp(0.0, 1.0);
                final end = (start + buttonDuration).clamp(0.0, 1.0);
                
                return Tween<double>(
                  begin: 0.0,
                  end: 1.0,
                ).animate(
                  CurvedAnimation(
                    parent: _animationController,
                    curve: Interval(
                      start,
                      end,
                      curve: Curves.easeOut,
                    ),
                  ),
                );
              },
            );
            // Reset and start animation when quick replies become available
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _animationController.reset();
                _startAnimation();
              }
            });
          }
        } else {
          // Clear animations when no quick replies
          _buttonAnimations = [];
          _previousQuickReplies = [];
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display text content
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: widget.message.content.trim().isNotEmpty
                            ? MarkdownBody(
                                selectable: true,
                                softLineBreak: true,
                                data: widget.message.content.trim(),
                                styleSheet: MarkdownStyleSheet.fromTheme(widget.theme).copyWith(
                                  p: widget.theme.textTheme.bodyLarge?.copyWith(
                                    fontSize: 16,
                                  ),
                                  h1: widget.theme.textTheme.headlineMedium?.copyWith(
                                    fontSize: 24,
                                  ),
                                  h2: widget.theme.textTheme.titleLarge?.copyWith(
                                    fontSize: 20,
                                  ),
                                  h3: widget.theme.textTheme.titleMedium?.copyWith(
                                    fontSize: 18,
                                  ),
                                ),
                              )
                            : const Text('...'),
                      ),
                      // Show blinking cursor when message is still pending
                      if (widget.message.isPending && widget.message.content.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: _StreamingCursor(theme: widget.theme),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Row(
                children: [
                  // TTS Play/Pause button - only show for completed messages with content and if TTS is available
                  if (_isTtsAvailable &&
                      !widget.message.isPending && 
                      !widget.message.hasError && 
                      widget.message.content.trim().isNotEmpty) ...[
                    IconButton(
                      icon: Icon(
                        _isPlayingThisMessage ? Icons.pause : Icons.volume_up,
                        size: 20,
                        color: _isPlayingThisMessage
                            ? widget.theme.colorScheme.primary
                            : widget.theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      onPressed: _toggleTts,
                      tooltip: _isPlayingThisMessage ? 'Pause voice' : 'Play voice',
                      padding: const EdgeInsets.all(8),
                    ),
                    const SizedBox(width: 4),
                  ],
                  IconButton(
                    icon: Icon(
                      Icons.content_copy,
                      size: 20,
                      color: widget.theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    onPressed: widget.onCopy,
                    tooltip: 'Copy',
                    padding: const EdgeInsets.all(8),
                  ),
                  if (widget.onSave != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        Icons.bookmark_outline,
                        size: 20,
                        color: widget.theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      onPressed: widget.onSave,
                      tooltip: 'Save to notes',
                      padding: const EdgeInsets.all(8),
                    ),
                  ],
                  if (widget.onRegenerate != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        Icons.refresh,
                        size: 20,
                        color: widget.theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      onPressed: widget.onRegenerate,
                      tooltip: 'Regenerate',
                      padding: const EdgeInsets.all(8),
                    ),
                  ],
                ],
              ),
            ),
            // Quick reply buttons - show up to 2 suggestions (only when message is complete)
            // Placed below action buttons following standard chat UI patterns
            if (widget.onQuickReply != null && quickReplies.isNotEmpty && !widget.message.isPending) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: quickReplies.asMap().entries.map((entry) {
                        final index = entry.key;
                        final reply = entry.value;
                        final animation = index < _buttonAnimations.length
                            ? _buttonAnimations[index]
                            : _fadeAnimation;
                        
                        // Use the same animation for slide to keep them in sync
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.2),
                              end: Offset.zero,
                            ).animate(animation),
                            child: OutlinedButton(
                              onPressed: () => widget.onQuickReply!(reply),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                minimumSize: const Size(0, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                reply,
                                style: widget.theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 13,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.left,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
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

class _StreamingCursor extends StatefulWidget {
  const _StreamingCursor({required this.theme});

  final ThemeData theme;

  @override
  State<_StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<_StreamingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 2,
        height: 20,
        margin: const EdgeInsets.only(top: 2),
        color: widget.theme.colorScheme.primary,
      ),
    );
  }
}

class _LoadMoreIndicator extends StatelessWidget {
  const _LoadMoreIndicator({
    required this.isLoading,
    required this.theme,
  });

  final bool isLoading;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              )
            else
              Icon(
                Icons.keyboard_arrow_up,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
                size: 20,
              ),
            const SizedBox(height: 8),
            Text(
              isLoading ? 'Loading older messages…' : 'Scroll up for older messages',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatefulWidget {
  const _InputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final void Function(List<String>?) onSend; // Now accepts optional image paths
  final VoidCallback onStop;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  static const int _maxImagesPerMessage = 5; // Maximum number of images per message
  
  final stt.SpeechToText _speech = stt.SpeechToText();
  final ImagePicker _imagePicker = ImagePicker();
  final StorageService _storageService = StorageService();
  final FocusNode _focusNode = FocusNode();
  bool _isListening = false;
  bool _isStarting = false; // Prevent multiple simultaneous starts
  bool _isAvailable = false;
  bool _isHoldToTalkMode = false; // Toggle between text input and hold-to-talk mode
  String _baseText = '';
  String _partialText = '';
  bool _isUpdatingFromSpeech = false;
  double _soundLevel = 0.0; // Current sound level (0.0 to 1.0)
  DateTime? _lastStartTime; // Track last start time to prevent abuse
  Future<void>? _currentStartOperation; // Track current start operation to prevent overlapping
  DateTime? _pointerDownTime; // Track when pointer was pressed down
  bool _hasStartedFromPointer = false; // Track if we started from this pointer press
  final List<_AttachedImage> _attachedImages = []; // Store attached images with upload state

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _initializeSpeech();
  }
  
  Future<void> _removeImage(int index) async {
    if (index < 0 || index >= _attachedImages.length) return;
    
    final image = _attachedImages[index];
    
    // Delete from storage if already uploaded
    if (image.uploadedUrl != null && image.uploadedUrl!.isNotEmpty) {
      try {
        await _storageService.deleteChatImage(image.uploadedUrl!);
      } catch (e) {
        debugPrint('Failed to delete image from storage: $e');
        // Continue to remove from UI even if deletion fails
      }
    }
    
    setState(() {
      _attachedImages.removeAt(index);
    });
  }
  
  Future<void> _uploadImage(_AttachedImage image) async {
    // Mark as uploading
    setState(() {
      image.isUploading = true;
      image.hasError = false;
    });
    
    try {
      // Upload to Supabase Storage
      final uploadedUrl = await _storageService.uploadChatImage(
        image.filePath,
        image.id,
      );
      
      // Update with uploaded URL
      if (mounted) {
        setState(() {
          image.uploadedUrl = uploadedUrl;
          image.isUploading = false;
          image.hasError = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to upload image: $e');
      if (mounted) {
        setState(() {
          image.isUploading = false;
          image.hasError = true;
        });
        
        // Show error toast
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: ${e.toString()}'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _uploadImage(image),
            ),
          ),
        );
      }
    }
  }
  
  Future<void> _handleSend() async {
    final text = widget.controller.text.trim();
    // Allow sending if there's text OR images
    if (text.isEmpty && _attachedImages.isEmpty) return;
    
    // If there are images, validate model support before sending
    final hasImages = _attachedImages.any((img) => img.uploadedUrl != null && !img.hasError);
    if (hasImages) {
      try {
        final chatProvider = context.read<ChatProvider>();
        final supportsImageInput = await chatProvider.getCurrentModelSupportsImageInput();
        
        if (!supportsImageInput && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Current model does not support image inputs. Please switch to a multimodal model.'),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'OK',
                onPressed: () {},
              ),
            ),
          );
          return;
        }
      } catch (e) {
        debugPrint('Error checking model support: $e');
        // Continue anyway - let the API handle the error
      }
    }
    
    // Get uploaded URLs (only send images that are successfully uploaded)
    final uploadedUrls = _attachedImages
        .where((img) => img.uploadedUrl != null && img.uploadedUrl!.isNotEmpty && !img.hasError)
        .map((img) => img.uploadedUrl!)
        .toList();
    
    // Check if there are images still uploading
    final hasUploadingImages = _attachedImages.any((img) => img.isUploading);
    if (hasUploadingImages && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for images to finish uploading before sending.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    // Check if there are failed uploads
    final hasFailedUploads = _attachedImages.any((img) => img.hasError);
    if (hasFailedUploads && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Some images failed to upload. Please remove them or retry before sending.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    
    // Send with both text and images (using uploaded URLs, not file paths)
    widget.onSend(uploadedUrls.isEmpty ? null : uploadedUrls);
    
    // Clear text and images after sending
    widget.controller.clear();
    setState(() {
      _attachedImages.clear();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _speech.stop();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  Future<void> _initializeSpeech() async {
    bool available = await _speech.initialize(
      onError: (error) {
        debugPrint('Speech recognition error: $error');
        setState(() {
          _isListening = false;
        });
      },
      onStatus: (status) {
        debugPrint('Speech recognition status: $status');
        if (status == 'done' || status == 'notListening') {
          setState(() {
            _isListening = false;
            _partialText = '';
          });
        }
      },
    );
    setState(() {
      _isAvailable = available;
    });
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Take Photo'),
            subtitle: const Text('Capture a new photo with camera'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from Gallery'),
            subtitle: const Text('Select an image from your gallery'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Check if we've reached the maximum number of images
      if (_attachedImages.length >= _maxImagesPerMessage) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Maximum $_maxImagesPerMessage images per message. Please remove some images first.'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      
      if (image != null) {
        // Create attached image object
        final attachedImage = _AttachedImage(
          filePath: image.path,
          id: _uuid.v4(),
        );
        
        setState(() {
          _attachedImages.add(attachedImage);
        });
        
        // Start uploading immediately
        _uploadImage(attachedImage);
        
        // Show toast if maximum limit reached
        if (_attachedImages.length >= _maxImagesPerMessage && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Maximum $_maxImagesPerMessage images reached. You can send this message or remove some images to add more.'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        
        // Check and warn if model doesn't support images (but still allow attachment)
        final chatProvider = context.read<ChatProvider>();
        final supportsImageInput = await chatProvider.getCurrentModelSupportsImageInput();
        
        if (!supportsImageInput && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Current model does not support image inputs. Please switch to a multimodal model before sending.'),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'OK',
                onPressed: () {},
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('permission') || errorString.contains('denied')) {
          // Show appropriate dialog based on source
          if (source == ImageSource.camera) {
            await NotificationService.showEnableCameraDialog(context);
          } else {
            await NotificationService.showEnablePhotoLibraryDialog(context);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to pick image: ${e.toString()}'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  void _showInputOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Add Image'),
              subtitle: const Text('Take photo or choose from gallery'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showImageSourcePicker();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Toggle between text input mode and hold-to-talk mode
  Future<void> _toggleHoldToTalkMode() async {
    if (!_isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speech recognition is not available on this device'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Stop any active recording when toggling mode
    if (_isListening) {
      await _speech.stop();
      setState(() {
        _isListening = false;
        _partialText = '';
      });
    }

    // Toggle the mode
    setState(() {
      _isHoldToTalkMode = !_isHoldToTalkMode;
    });
  }

  /// Start recording when user starts holding the button
  Future<void> _startHoldToTalk() async {
    // Prevent abuse: check if already starting or listening
    if (!_isAvailable || _isListening || _isStarting) return;
    
    // Prevent rapid clicking: debounce with 500ms minimum interval (more aggressive)
    final now = DateTime.now();
    if (_lastStartTime != null && now.difference(_lastStartTime!).inMilliseconds < 500) {
      return;
    }
    
    // If there's already a start operation in progress, wait for it or return
    if (_currentStartOperation != null) {
      try {
        await _currentStartOperation;
      } catch (e) {
        debugPrint('Previous start operation error: $e');
      }
      // After waiting, check again if we should proceed
      if (!_isAvailable || _isListening || _isStarting) return;
    }

    // Set flags immediately to prevent other calls from proceeding
    _isStarting = true;
    _lastStartTime = now;
    
    // Create and track the start operation with timeout to prevent hanging
    _currentStartOperation = _performStartHoldToTalk().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint('Timeout starting speech recognition');
        if (mounted) {
          setState(() {
            _isStarting = false;
            _isListening = false;
          });
        }
      },
    );
    
    try {
      await _currentStartOperation;
    } catch (e) {
      debugPrint('Start operation error: $e');
      // Ensure flags are reset on any error to prevent hanging
      if (mounted) {
        setState(() {
          _isStarting = false;
          _isListening = false;
        });
      }
    } finally {
      _currentStartOperation = null;
    }
  }

  /// Internal method to perform the actual start operation
  Future<void> _performStartHoldToTalk() async {
    // Stop any existing session first to prevent conflicts
    if (_speech.isListening) {
      try {
        await _speech.stop();
        // Wait a bit longer for proper cleanup to prevent conflicts
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        debugPrint('Error stopping existing speech session: $e');
        // Continue anyway, but reset state
        _isStarting = false;
        return;
      }
    }

    // Double-check we're still in a valid state after cleanup
    if (!mounted || !_isAvailable) {
      _isStarting = false;
      return;
    }

    // Provide haptic feedback when recording starts
    HapticFeedback.mediumImpact();

    if (mounted) {
      setState(() {
        _isListening = true;
        _baseText = widget.controller.text;
        _partialText = '';
        _soundLevel = 0.0; // Reset sound level
      });
    }
    
    try {
      await _speech.listen(
        onResult: (result) {
          // Don't update if we're no longer listening
          if (!_isListening) return;
          
          setState(() {
            _isUpdatingFromSpeech = true;
            if (result.finalResult) {
              // Final result: append to base text
              final newText = _baseText.isEmpty
                  ? result.recognizedWords
                  : '$_baseText ${result.recognizedWords}';
              widget.controller.text = newText;
              _baseText = newText;
              _partialText = '';
            } else {
              // Partial result: show base text + partial text
              _partialText = result.recognizedWords;
              final displayText = _baseText.isEmpty
                  ? _partialText
                  : '$_baseText $_partialText';
              widget.controller.text = displayText;
            }
            _isUpdatingFromSpeech = false;
          });
        },
        onSoundLevelChange: (level) {
          // Update sound level for real-time visualization
          // Sound level is typically between -160 (silence) and 0 (max) in dB
          // Normalize to 0.0 - 1.0 range with better sensitivity
          if (mounted && _isListening) {
            setState(() {
              // Convert from dB scale (-160 to 0) to 0.0-1.0
              // Speech typically ranges from -60dB (quiet) to -20dB (loud)
              // Use exponential curve for better sensitivity to speech variations
              final normalized = ((level + 160) / 160).clamp(0.0, 1.0);
              // Apply exponential curve: makes quiet speech more visible, prevents saturation
              _soundLevel = (normalized * normalized * 1.3).clamp(0.0, 1.0);
            });
          }
        },
        listenFor: const Duration(seconds: 60), // Longer duration for hold-to-talk
        pauseFor: const Duration(seconds: 3),
        localeId: 'en_US',
        cancelOnError: true,
        partialResults: true,
      );
      // Only reset _isStarting if we successfully started
      if (mounted) {
        _isStarting = false;
      }
    } catch (e) {
      debugPrint('Error starting speech recognition: $e');
      // Always reset flags on error
      if (mounted) {
        setState(() {
          _isListening = false;
          _partialText = '';
          _soundLevel = 0.0;
          _isStarting = false;
        });
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('permission') || errorString.contains('denied') || errorString.contains('microphone')) {
          await NotificationService.showEnableMicrophoneDialog(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to start voice input: ${e.toString()}'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  /// Stop recording when user releases the button
  Future<void> _stopHoldToTalk() async {
    // Prevent stopping if not actually listening or if still starting
    if (!_isListening && !_isStarting) return;
    
    // CRITICAL: Update state IMMEDIATELY (synchronously) before async operations
    // This ensures the UI updates right away, even if stop() takes time
    final wasListening = _isListening;
    _isStarting = false;
    
    if (mounted) {
      setState(() {
        _isListening = false;
        _partialText = '';
        _soundLevel = 0.0; // Reset sound level
      });
    }
    
    // Provide haptic feedback when recording stops
    HapticFeedback.lightImpact();
    
    // Stop speech recognition if it was listening (with timeout to prevent hanging)
    if (wasListening && _speech.isListening) {
      try {
        await _speech.stop().timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            debugPrint('Timeout stopping speech recognition');
          },
        );
      } catch (e) {
        debugPrint('Error stopping speech recognition: $e');
      }
    }
    
    // Automatically send the message if there's transcribed text
    // Keep the hold-to-talk mode active so user can continue using it
    final text = widget.controller.text.trim();
    if (text.isNotEmpty) {
      // Small delay to ensure speech recognition has finished processing
      await Future.delayed(const Duration(milliseconds: 100));
      // Send the message automatically
      await _handleSend();
    }
  }

  /// Stop listening to microphone input
  /// This is called when a message is sent to ensure the microphone stops
  void stopListening() {
    if (_isListening || _isStarting) {
      _isStarting = false;
      // Set listening to false first to prevent any pending callbacks from updating the controller
      setState(() {
        _isListening = false;
        _partialText = '';
        _soundLevel = 0.0; // Reset sound level
      });
      if (_speech.isListening) {
        _speech.stop();
      }
    }
  }

  /// Build the hold-to-talk button widget
  Widget _buildHoldToTalkButton(ThemeData theme, bool isSending) {
    return Container(
      key: const ValueKey('hold-to-talk-button'),
      child: Listener(
        // Use Listener for more reliable pointer events
        // Add slight delay to prevent accidental triggers (less sensitive)
        onPointerDown: (_) {
          _pointerDownTime = DateTime.now();
          _hasStartedFromPointer = false;
          // Start after a small delay (100ms) to require deliberate press
          Future.delayed(const Duration(milliseconds: 100), () {
            // Only start if pointer is still down and we haven't started yet
            if (_pointerDownTime != null && !_hasStartedFromPointer && mounted) {
              _hasStartedFromPointer = true;
              _startHoldToTalk();
            }
          });
        },
        onPointerUp: (_) {
          _pointerDownTime = null;
          if (_hasStartedFromPointer) {
            _stopHoldToTalk();
          }
          _hasStartedFromPointer = false;
        },
        onPointerCancel: (_) {
          _pointerDownTime = null;
          if (_hasStartedFromPointer) {
            _stopHoldToTalk();
          }
          _hasStartedFromPointer = false;
        },
        child: GestureDetector(
          // GestureDetector as backup - but Listener handles the main events
          // Only trigger if Listener didn't already handle it
          onTapDown: (_) {
            // Only start if pointer wasn't already tracked by Listener
            if (_pointerDownTime == null) {
              _pointerDownTime = DateTime.now();
              _hasStartedFromPointer = false;
              Future.delayed(const Duration(milliseconds: 100), () {
                if (_pointerDownTime != null && !_hasStartedFromPointer && mounted) {
                  _hasStartedFromPointer = true;
                  _startHoldToTalk();
                }
              });
            }
          },
          onTapUp: (_) {
            if (_hasStartedFromPointer) {
              _stopHoldToTalk();
            }
            _pointerDownTime = null;
            _hasStartedFromPointer = false;
          },
          onTapCancel: () {
            if (_hasStartedFromPointer) {
              _stopHoldToTalk();
            }
            _pointerDownTime = null;
            _hasStartedFromPointer = false;
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: _isListening
              ? theme.colorScheme.errorContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: _isListening
                ? theme.colorScheme.error
                : theme.colorScheme.outline.withOpacity(0.2),
            width: _isListening ? 2 : 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing animation when recording
            if (_isListening)
              _PulsingCircle(
                color: theme.colorScheme.error,
              ),
            // Main button content
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isListening)
                  _SoundWaveform(
                    soundLevel: _soundLevel,
                    color: theme.colorScheme.onErrorContainer,
                  )
                else
                  Icon(
                    Icons.record_voice_over,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    size: 24,
                  ),
                const SizedBox(width: 12),
                Text(
                  _isListening ? 'Release to send' : 'Hold to talk',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 16,
                    color: _isListening
                        ? theme.colorScheme.onErrorContainer
                        : theme.colorScheme.onSurface.withOpacity(0.7),
                    fontWeight: _isListening ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
            // Back button on the right (only show when not recording)
            if (!_isListening)
              Positioned(
                right: 8,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.3, 0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOut,
                        )),
                        child: child,
                      ),
                    );
                  },
                  child: IconButton(
                    key: const ValueKey('back-button'),
                    tooltip: 'Back to text input',
                    onPressed: () {
                      setState(() {
                        _isHoldToTalkMode = false;
                      });
                      // Focus the text input after switching back to text mode
                      // Use a small delay to ensure the TextField is visible after AnimatedSwitcher
                      Future.delayed(const Duration(milliseconds: 250), () {
                        if (mounted) {
                          _focusNode.requestFocus();
                        }
                      });
                    },
                    icon: const Icon(Icons.keyboard),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.surfaceContainerHigh,
                      shape: const CircleBorder(),
                      fixedSize: const Size(44, 44),
                      foregroundColor: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
              ),
          ],
        ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSending = context.watch<ChatProvider>().isSending;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth > 768 ? 768.0 : screenWidth;
    final hasText = widget.controller.text.trim().isNotEmpty;
    final hasUploadedImages = _attachedImages.any((img) => img.uploadedUrl != null && !img.hasError);
    final hasUploadingImages = _attachedImages.any((img) => img.isUploading);
    final hasFailedUploads = _attachedImages.any((img) => img.hasError);
    final hasContent = hasText || hasUploadedImages;
    final canSend = hasContent && !hasUploadingImages && !hasFailedUploads;


    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show attached image previews
              if (_attachedImages.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _attachedImages.length,
                    itemBuilder: (context, index) {
                      final image = _attachedImages[index];
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: image.hasError
                                ? theme.colorScheme.error.withOpacity(0.5)
                                : theme.colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Show image preview or loading/error state
                            if (image.isUploading)
                              // Loading state
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              )
                            else if (image.hasError)
                              // Error state
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 20,
                                      color: theme.colorScheme.onErrorContainer,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Failed',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontSize: 10,
                                        color: theme.colorScheme.onErrorContainer,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (image.uploadedUrl != null)
                              // Successfully uploaded - show from URL
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  image.uploadedUrl!,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      width: 80,
                                      height: 80,
                                      color: theme.colorScheme.surfaceContainerHighest,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                                  loadingProgress.expectedTotalBytes!
                                              : null,
                                          strokeWidth: 2,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 80,
                                      height: 80,
                                      color: theme.colorScheme.errorContainer,
                                      child: Icon(
                                        Icons.broken_image,
                                        color: theme.colorScheme.onErrorContainer,
                                      ),
                                    );
                                  },
                                ),
                              )
                            else
                              // Fallback: show local file
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(image.filePath),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 80,
                                      height: 80,
                                      color: theme.colorScheme.errorContainer,
                                      child: Icon(
                                        Icons.broken_image,
                                        color: theme.colorScheme.onErrorContainer,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            // Remove button
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Material(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  onTap: () => _removeImage(index),
                                  borderRadius: BorderRadius.circular(12),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Retry button for failed uploads
                            if (image.hasError)
                              Positioned(
                                bottom: 4,
                                left: 4,
                                child: Material(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    onTap: () => _uploadImage(image),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.refresh,
                                        size: 16,
                                        color: theme.colorScheme.onPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              // Text input field or hold-to-talk button
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.95,
                        end: 1.0,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOut,
                      )),
                      child: child,
                    ),
                  );
                },
                child: _isHoldToTalkMode
                    ? _buildHoldToTalkButton(theme, isSending)
                    : TextField(
                key: const ValueKey('text-input'),
                controller: widget.controller,
                focusNode: _focusNode,
                minLines: 1,
                maxLines: 6,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSend(),
            enabled: !isSending,
            onChanged: (text) {
              // If user manually edits text while listening, update base text
              // Only update if this change wasn't from speech recognition
              if (_isListening && !_isUpdatingFromSpeech) {
                // Check if the text doesn't match our expected pattern
                final expectedText = _baseText.isEmpty
                    ? _partialText
                    : '$_baseText $_partialText';
                if (text != expectedText) {
                  // User manually edited - update base text
                  _baseText = text;
                  _partialText = '';
                }
              }
            },
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: _isListening
                  ? 'Listening...'
                  : isSending
                      ? 'AI is thinking…'
                      : 'Message…',
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.fromLTRB(
                12,
                16,
                20,
                16,
              ),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: animation,
                        child: child,
                      ),
                    );
                  },
                  child: isSending
                      ? IconButton(
                          key: const ValueKey('stop-button'),
                          tooltip: 'Stop generating',
                          onPressed: widget.onStop,
                          icon: Icon(
                            Icons.stop_circle_outlined,
                            color: theme.colorScheme.error,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: theme.colorScheme.errorContainer,
                          ),
                        )
                      : Row(
                          key: const ValueKey('action-buttons-row'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Mic button - toggle between text and hold-to-talk mode
                            // Hide when user starts typing
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(
                                    scale: Tween<double>(
                                      begin: 0.8,
                                      end: 1.0,
                                    ).animate(CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOut,
                                    )),
                                    child: child,
                                  ),
                                );
                              },
                              child: (_isAvailable && !hasText)
                                  ? Padding(
                                      key: const ValueKey('mic-button'),
                                      padding: const EdgeInsets.only(right: 2),
                                      child: IconButton(
                                        tooltip: _isHoldToTalkMode 
                                            ? 'Switch to text input' 
                                            : 'Switch to voice input',
                                        onPressed: _toggleHoldToTalkMode,
                                        icon: Icon(_isHoldToTalkMode ? Icons.keyboard : Icons.record_voice_over),
                                        style: IconButton.styleFrom(
                                          backgroundColor:
                                              theme.colorScheme.surfaceContainerHigh,
                                          shape: const CircleBorder(),
                                          fixedSize: const Size(44, 44),
                                          side: BorderSide(
                                            color: theme.colorScheme.outlineVariant.withOpacity(0.4),
                                            width: 1,
                                          ),
                                          foregroundColor: _isHoldToTalkMode
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.onSurface.withOpacity(0.7),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(key: ValueKey('mic-button-hidden')),
                            ),
                            // Send or Plus button
                            canSend
                                ? IconButton(
                                    key: const ValueKey('send-button'),
                                    tooltip: hasUploadingImages
                                        ? 'Waiting for images to upload...'
                                        : hasFailedUploads
                                            ? 'Some images failed to upload'
                                            : 'Send message',
                                    onPressed: _handleSend,
                                    icon: Icon(
                                      Icons.arrow_upward_rounded,
                                      color: theme.colorScheme.onPrimary,
                                    ),
                                    style: IconButton.styleFrom(
                                      backgroundColor: theme.colorScheme.primary,
                                      shape: const CircleBorder(),
                                      fixedSize: const Size(44, 44),
                                    ),
                                  )
                                : IconButton(
                                    key: const ValueKey('plus-button'),
                                    tooltip: 'More actions',
                                    onPressed: () => _showInputOptions(context),
                                    icon: Icon(Icons.add),
                                    style: IconButton.styleFrom(
                                      backgroundColor:
                                          theme.colorScheme.surfaceContainerHigh,
                                      shape: const CircleBorder(),
                                      fixedSize: const Size(44, 44),
                                      side: BorderSide(
                                        color: theme.colorScheme.outlineVariant.withOpacity(0.4),
                                        width: 1,
                                      ),
                                      foregroundColor:
                                          theme.colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                          ],
                        ),
                ),
              ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
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

    return Padding(
      padding: EdgeInsets.only(
        bottom: mediaQuery.viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          minHeight: 300,
          maxHeight: mediaQuery.size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Consumer<NotesProvider>(
          builder: (context, notesProvider, _) {
            final notes = notesProvider.notes;
            
            return Column(
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
                
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
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
                          tooltip: 'Back',
                        ),
                      Expanded(
                        child: Text(
                          (_isCreatingNew || notes.isEmpty) ? 'Create New Note' : 'Save to Note',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!_isCreatingNew && notes.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _isCreatingNew = true;
                            });
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('New'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      if (!_isCreatingNew || notes.isEmpty)
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'Close',
                        ),
                    ],
                  ),
                ),
                
                // Content area
                Flexible(
                  child: (_isCreatingNew || notes.isEmpty)
                      ? _buildCreateNoteForm(theme)
                      : _buildNotesList(theme, notes),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCreateNoteForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Enter a title for your new note',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _titleController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Note Title',
                      hintText: 'e.g., Meeting Notes, Ideas',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                    onFieldSubmitted: (value) => _handleCreateNote(),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
            child: FilledButton.icon(
              onPressed: _handleCreateNote,
              icon: const Icon(Icons.check),
              label: const Text('Create & Save'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesList(ThemeData theme, List<Note> notes) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Notes list
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 200),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: notes.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final note = notes[index];
                final isAlreadySaved = _noteContainsContent(note);
                
                return _buildNoteCard(theme, note, isAlreadySaved);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoteCard(ThemeData theme, Note note, bool isAlreadySaved) {
    return InkWell(
      onTap: () async {
        if (isAlreadySaved) {
          await widget.onRemoveFromNote(note.title);
        } else {
          await widget.onSaveToNote(note.title);
        }
        if (mounted) {
          Navigator.pop(
            context,
            {'action': isAlreadySaved ? 'remove' : 'add'},
          );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isAlreadySaved
              ? theme.colorScheme.primaryContainer.withOpacity(0.3)
              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAlreadySaved
                ? theme.colorScheme.primary.withOpacity(0.3)
                : theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isAlreadySaved
                    ? theme.colorScheme.primary.withOpacity(0.1)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isAlreadySaved ? Icons.bookmark : Icons.bookmark_border,
                size: 20,
                color: isAlreadySaved
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            
            // Note info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          note.title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isAlreadySaved
                                ? theme.colorScheme.primary
                                : null,
                          ),
                        ),
                      ),
                      if (isAlreadySaved)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Saved',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (note.content.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      note.content.length > 60
                          ? '${note.content.substring(0, 60)}...'
                          : note.content,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            
            // Action icon
            const SizedBox(width: 8),
            Icon(
              isAlreadySaved ? Icons.remove_circle_outline : Icons.add_circle_outline,
              color: isAlreadySaved
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

/// A pulsing circle animation widget for visual feedback during recording
class _PulsingCircle extends StatefulWidget {
  const _PulsingCircle({
    required this.color,
  });

  final Color color;

  @override
  State<_PulsingCircle> createState() => _PulsingCircleState();
}

class _PulsingCircleState extends State<_PulsingCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withOpacity(0.15 * _animation.value),
          ),
          width: 80 * _animation.value,
          height: 80 * _animation.value,
        );
      },
    );
  }
}

/// Widget that displays a real-time waveform visualization that responds to voice input
/// Common practice: smooth, responsive bars with slight phase offsets for natural wave effect
class _SoundWaveform extends StatefulWidget {
  const _SoundWaveform({
    required this.soundLevel,
    required this.color,
  });

  final double soundLevel; // 0.0 to 1.0
  final Color color;

  @override
  State<_SoundWaveform> createState() => _SoundWaveformState();
}

class _SoundWaveformState extends State<_SoundWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final int _barCount = 5;
  final List<double> _currentLevels = [0.2, 0.2, 0.2, 0.2, 0.2]; // Current smoothed levels
  final List<double> _targetLevels = [0.2, 0.2, 0.2, 0.2, 0.2]; // Target levels from sound input

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 50), // Fast updates for real-time feel
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_SoundWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update target levels when sound level changes
    // Each bar responds to different frequency ranges for natural variation
    for (int i = 0; i < _barCount; i++) {
      // Create variation: bars at different positions respond differently
      // This simulates how different frequencies are picked up
      final frequencyResponse = 0.6 + (i * 0.2); // Varies from 0.6 to 1.4
      // Add slight phase offset for wave effect
      final phaseOffset = (i * 0.1) % 1.0;
      final adjustedLevel = widget.soundLevel * frequencyResponse;
      _targetLevels[i] = (adjustedLevel + phaseOffset * 0.2).clamp(0.15, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Smooth interpolation for real-time updates
        // Use exponential smoothing for natural movement
        for (int i = 0; i < _barCount; i++) {
          // Fast response (0.3 damping) for real-time feel, but smooth enough to avoid jitter
          _currentLevels[i] = _currentLevels[i] * 0.7 + _targetLevels[i] * 0.3;
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_barCount, (index) {
            final barHeight = _currentLevels[index];
            
            return Container(
              margin: EdgeInsets.only(
                left: index == 0 ? 0 : 3,
                right: index == _barCount - 1 ? 0 : 3,
              ),
              width: 3,
              height: 20 * barHeight,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(1.5),
              ),
            );
          }),
        );
      },
    );
  }
}

// Model picker removed - app now uses OPENROUTER_MODEL from env only

