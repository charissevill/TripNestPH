import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/widgets/dialogs/confirmation_dialog.dart';
import '../providers/ai_chat_provider.dart';

/// Lists every saved AI Chat conversation with "New Chat" pinned at the top
/// — tap a chat to switch to it, or its trash icon to delete it.
Future<void> showChatSessionsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _ChatSessionsSheet(),
  );
}

String _relativeLabel(DateTime time) {
  final now = DateTime.now();
  final diff = now.difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (now.year == time.year && now.month == time.month && now.day == time.day) {
    return '${diff.inHours}h ago';
  }
  if (diff.inDays < 7) return DateFormat.E().format(time);
  return DateFormat.yMMMd().format(time);
}

class _ChatSessionsSheet extends StatelessWidget {
  const _ChatSessionsSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chat = context.watch<AiChatProvider>();
    final sessions = chat.sessions;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Material(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Chats', style: theme.textTheme.headlineSmall),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: InkWell(
                  onTap: () {
                    context.read<AiChatProvider>().startNewChat();
                    Navigator.of(context).pop();
                  },
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Row(
                      children: [
                        Icon(Symbols.add_comment_rounded, color: theme.colorScheme.primary),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'New Chat',
                          style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: sessions.isEmpty
                    ? Center(
                        child: Text('No past chats yet', style: theme.textTheme.bodyMedium),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                        itemCount: sessions.length,
                        itemBuilder: (context, i) {
                          final session = sessions[i];
                          final isActive = session.id == chat.currentSessionId;
                          return ListTile(
                            onTap: () {
                              context.read<AiChatProvider>().switchToSession(session.id);
                              Navigator.of(context).pop();
                            },
                            selected: isActive,
                            selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.06),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                            leading: Icon(
                              Symbols.forum_rounded,
                              color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                            ),
                            title: Text(
                              session.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                            subtitle: Text(_relativeLabel(session.updatedAt)),
                            trailing: IconButton(
                              icon: const Icon(Symbols.delete_outline_rounded, size: 20),
                              tooltip: 'Delete chat',
                              onPressed: () async {
                                final confirmed = await showConfirmationDialog(
                                  context,
                                  title: 'Delete this chat?',
                                  message: '"${session.title}" will be permanently deleted.',
                                  confirmLabel: 'Delete',
                                  isDestructive: true,
                                );
                                if (confirmed && context.mounted) {
                                  context.read<AiChatProvider>().deleteSession(session.id);
                                }
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
