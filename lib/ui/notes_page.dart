import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:traitus/models/note.dart';
import 'package:traitus/models/note_section.dart';
import 'package:traitus/providers/notes_provider.dart';
import 'package:traitus/ui/widgets/haptic_modal.dart';

class NotesPage extends StatelessWidget {
  const NotesPage({super.key, this.isInTabView = false});
  
  final bool isInTabView;

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Notes'),
        automaticallyImplyLeading: !isInTabView,
      ),
      body: Consumer<NotesProvider>(
        builder: (context, notesProvider, _) {
          if (!notesProvider.hasNotes) {
            return _EmptyNotesState();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notesProvider.notes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final note = notesProvider.notes[index];
              return _NoteCard(
                note: note,
                timestamp: _formatTime(note.createdAt),
                onTap: () => _viewNoteDetail(context, note),
                onDelete: () => _deleteNote(context, notesProvider, note),
              );
            },
          );
        },
      ),
    );
  }

  void _viewNoteDetail(BuildContext context, Note note) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _NoteDetailPage(note: note),
      ),
    );
  }

  Future<void> _deleteNote(
    BuildContext context,
    NotesProvider notesProvider,
    Note note,
  ) async {
    final confirmed = await HapticModal.showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Are you sure you want to delete "${note.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await notesProvider.deleteNote(note.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

class _EmptyNotesState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bookmark_add_outlined,
                size: 72,
                color: theme.colorScheme.primary.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No notes yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Save messages from your chats to access them here.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.timestamp,
    required this.onTap,
    required this.onDelete,
  });

  final Note note;
  final String timestamp;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                note.content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                timestamp,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteDetailPage extends StatefulWidget {
  const _NoteDetailPage({required this.note});

  final Note note;

  @override
  State<_NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<_NoteDetailPage> {
  List<NoteSection> _sections = [];
  bool _isLoadingSections = false;
  bool _isEditingTitle = false;
  late TextEditingController _titleController;
  String _originalTitle = '';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _originalTitle = widget.note.title;
    _loadSections();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadSections() async {
    setState(() {
      _isLoadingSections = true;
    });

    try {
      final notesProvider = context.read<NotesProvider>();
      final sections = await notesProvider.fetchNoteSections(widget.note.id);
      if (mounted) {
        setState(() {
          _sections = sections;
          _isLoadingSections = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSections = false;
        });
      }
    }
  }

  void _copySection(BuildContext context, NoteSection section) {
    Clipboard.setData(ClipboardData(text: section.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Section copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _editSection(BuildContext context, NoteSection section) async {
    final notesProvider = context.read<NotesProvider>();

    await HapticModal.showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EditSectionBottomSheet(
        section: section,
        initialContent: section.content,
        onSave: (String content) async {
          try {
            final updatedSection = section.copyWith(content: content);
            await notesProvider.updateNoteSection(updatedSection);
            if (mounted) {
              await _loadSections();
            }
            return true;
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error updating section: $e'),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
            return false;
          }
        },
      ),
    );
  }

  Future<void> _deleteNote(BuildContext context) async {
    final notesProvider = context.read<NotesProvider>();
    final confirmed = await HapticModal.showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Are you sure you want to delete "${widget.note.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await notesProvider.deleteNote(widget.note.id);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Note deleted'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting note: $e'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _saveTitle(BuildContext context) async {
    final title = _titleController.text.trim();
    
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Title cannot be empty'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (title == _originalTitle) {
      setState(() {
        _isEditingTitle = false;
      });
      return;
    }

    try {
      final notesProvider = context.read<NotesProvider>();
      await notesProvider.updateNote(
        id: widget.note.id,
        title: title,
        content: widget.note.content, // Keep existing content
      );
      
      setState(() {
        _isEditingTitle = false;
        _originalTitle = title;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating title: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
        // Revert to original title on error
        setState(() {
          _isEditingTitle = false;
          _titleController.text = _originalTitle;
        });
      }
    }
  }

  Future<void> _deleteSection(BuildContext context, NoteSection section) async {
    final confirmed = await HapticModal.showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Section'),
        content: const Text('Are you sure you want to delete this section?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final notesProvider = context.read<NotesProvider>();
        await notesProvider.deleteNoteSection(section.id);
        await _loadSections();
        
        // Check if note has any sections or content left
        final remainingSections = await notesProvider.fetchNoteSections(widget.note.id);
        final currentNote = notesProvider.getNoteById(widget.note.id) ?? widget.note;
        if (remainingSections.isEmpty && currentNote.content.isEmpty) {
          // No sections and no content, go back to notes list
          if (mounted) {
            Navigator.pop(context);
          }
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Section deleted'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting section: $e'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notesProvider = context.watch<NotesProvider>();
    final currentNote = notesProvider.getNoteById(widget.note.id) ?? widget.note;

    // Update controller if note title changed externally
    if (_titleController.text != currentNote.title && !_isEditingTitle) {
      _titleController.text = currentNote.title;
      _originalTitle = currentNote.title;
    }

    return Scaffold(
      appBar: AppBar(
        title: _isEditingTitle
            ? TextField(
                controller: _titleController,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                autofocus: true,
                maxLines: 1,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _saveTitle(context),
                onEditingComplete: () => _saveTitle(context),
              )
            : GestureDetector(
                onTap: () {
                  setState(() {
                    _isEditingTitle = true;
                  });
                },
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        currentNote.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () {
                        setState(() {
                          _isEditingTitle = true;
                        });
                      },
                      tooltip: 'Edit title',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
        actions: _isEditingTitle
            ? [
                IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: () => _saveTitle(context),
                  tooltip: 'Save',
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _isEditingTitle = false;
                      _titleController.text = _originalTitle;
                    });
                  },
                  tooltip: 'Cancel',
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _deleteNote(context),
                  tooltip: 'Delete note',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: theme.colorScheme.outline.withOpacity(0.15),
          ),
        ),
      ),
      body: _isLoadingSections
          ? const Center(child: CircularProgressIndicator())
          : currentNote.content.isEmpty && _sections.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.note_outlined,
                          size: 72,
                          color: theme.colorScheme.onSurface.withOpacity(0.25),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No content yet',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Save messages from your chats to see them here',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Display original note content if it exists (backward compatibility)
                      if (currentNote.content.isNotEmpty) ...[
                        _NoteContentSection(
                          content: currentNote.content,
                          createdAt: currentNote.createdAt,
                          markdownStyleSheet: _getMarkdownStyleSheet(theme),
                        ),
                        if (_sections.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: theme.colorScheme.outline.withOpacity(0.15),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ],
                      // Display sections
                      ..._sections.asMap().entries.map((entry) {
                        final index = entry.key;
                        final section = entry.value;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _NoteContentSection(
                              content: section.content,
                              createdAt: section.createdAt,
                              markdownStyleSheet: _getMarkdownStyleSheet(theme),
                              onDelete: () => _deleteSection(context, section),
                              onEdit: () => _editSection(context, section),
                              onCopy: () => _copySection(context, section),
                            ),
                            if (index < _sections.length - 1) ...[
                              const SizedBox(height: 24),
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: theme.colorScheme.outline.withOpacity(0.15),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ],
                        );
                      }).toList(),
                      // Bottom padding for better scrolling
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
    );
  }

  MarkdownStyleSheet _getMarkdownStyleSheet(ThemeData theme) {
    return MarkdownStyleSheet.fromTheme(theme).copyWith(
                      p: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        color: theme.colorScheme.onSurface,
                        height: 1.6,
                      ),
                      h1: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 28,
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                      h2: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 22,
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                      h3: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 19,
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                      // Blockquote styling - ensure readable text on background
                      blockquote: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        color: theme.colorScheme.onSurface,
                        fontStyle: FontStyle.italic,
                      ),
                      blockquoteDecoration: BoxDecoration(
                        // Use a more visible background for better contrast
                        color: theme.brightness == Brightness.dark
                            ? theme.colorScheme.surfaceVariant.withOpacity(0.4)
                            : theme.colorScheme.surfaceVariant.withOpacity(0.6),
                        border: Border(
                          left: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 4,
                          ),
                        ),
                      ),
                      blockquotePadding: const EdgeInsets.all(16),
                      // Inline code styling
                      code: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                        fontFamily: 'monospace',
                        backgroundColor: theme.brightness == Brightness.dark
                            ? theme.colorScheme.surfaceVariant.withOpacity(0.4)
                            : theme.colorScheme.surfaceVariant.withOpacity(0.6),
                      ),
                      // Code block styling
                      codeblockDecoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? theme.colorScheme.surfaceVariant.withOpacity(0.4)
                            : theme.colorScheme.surfaceVariant.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      codeblockPadding: const EdgeInsets.all(12),
                      // List styling
                      listBullet: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                      // Link styling
                      a: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                      // Strong/bold styling
                      strong: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      // Emphasis/italic styling
                      em: theme.textTheme.bodyLarge?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurface,
                      ),
                    );
  }
}

class _NoteContentSection extends StatelessWidget {
  const _NoteContentSection({
    required this.content,
    required this.createdAt,
    required this.markdownStyleSheet,
    this.onDelete,
    this.onEdit,
    this.onCopy,
  });

  final String content;
  final DateTime createdAt;
  final MarkdownStyleSheet markdownStyleSheet;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onCopy;

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasActions = onDelete != null && onEdit != null && onCopy != null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              _formatTime(createdAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.45),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
            if (hasActions) ...[
              const Spacer(),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  size: 20,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'copy':
                      onCopy?.call();
                      break;
                    case 'edit':
                      onEdit?.call();
                      break;
                    case 'delete':
                      onDelete?.call();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'copy',
                    child: Row(
                      children: [
                        Icon(Icons.copy_outlined, size: 20),
                        const SizedBox(width: 12),
                        const Text('Copy'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 20),
                        const SizedBox(width: 12),
                        const Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20, color: theme.colorScheme.error),
                        const SizedBox(width: 12),
                        Text('Delete', style: TextStyle(color: theme.colorScheme.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        MarkdownBody(
          selectable: true,
          data: content.trim(),
          styleSheet: markdownStyleSheet,
        ),
      ],
    );
  }
}



class _EditSectionBottomSheet extends StatefulWidget {
  const _EditSectionBottomSheet({
    required this.section,
    required this.initialContent,
    required this.onSave,
  });

  final NoteSection section;
  final String initialContent;
  final Future<bool> Function(String content) onSave;

  @override
  State<_EditSectionBottomSheet> createState() => _EditSectionBottomSheetState();
}

class _EditSectionBottomSheetState extends State<_EditSectionBottomSheet> {
  late TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!mounted) return;
    
    // Capture the content before any async operations or state changes
    String content;
    try {
      content = _controller.text.trim();
    } catch (e) {
      // Controller might be disposed, return early
      return;
    }
    
    if (content.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Content cannot be empty'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSaving = true;
    });

    try {
      final success = await widget.onSave(content);
      
      if (!mounted) return;
      
      setState(() {
        _isSaving = false;
      });
      
      if (success) {
        if (!mounted) return;
        Navigator.pop(context, true);
        // Don't show snackbar here as the widget is being disposed
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating section: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
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
        constraints: BoxConstraints(
          maxHeight: mediaQuery.size.height * 0.85,
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
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Edit Section',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            
            // Content area
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Edit the section content below.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        hintText: 'Section content',
                        alignLabelWithHint: true,
                      ),
                      maxLines: null,
                      minLines: 10,
                      textAlignVertical: TextAlignVertical.top,
                      autofocus: true,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _handleSave,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
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

