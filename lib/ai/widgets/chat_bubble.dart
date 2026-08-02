import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/maps_launcher.dart';
import '../models/ai_message.dart';

/// A reply reads as a day-by-day plan (not just a single tip) once it lays
/// out at least two separate day headers — matches the "Day 1" / "Day 2"
/// shape `ChatPrompts.systemPrompt()` already asks the model to use for
/// multi-day answers, without depending on any structured data from the API.
final RegExp _dayHeaderPattern = RegExp(r'day\s*\d+', caseSensitive: false);

bool _looksLikeItinerary(String content) =>
    _dayHeaderPattern.allMatches(content).length >= 2;

/// One chat turn. User messages are a solid-primary bubble on the right;
/// assistant messages are a surface-colored bubble on the left with
/// markdown rendering (bold place names, bullet lists, headers for
/// multi-day plans). Error replies get a warning tint instead.
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message, this.onOpenPlanner});

  final AiChatMessage message;

  /// Set by `AiChatScreen` to resolve a real destination from the
  /// conversation and generate the itinerary directly — kept as a plain
  /// callback (rather than importing go_router/providers here) so this
  /// widget stays a presentational bubble. Only surfaced under day-by-day
  /// replies, where there's an actual trip here worth generating.
  final VoidCallback? onOpenPlanner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;
    final showPlannerCta =
        !isUser &&
        !message.isError &&
        onOpenPlanner != null &&
        _looksLikeItinerary(message.content);

    final bubbleColor = isUser
        ? theme.colorScheme.primary
        : message.isError
            ? theme.colorScheme.error.withValues(alpha: 0.08)
            : theme.colorScheme.surface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.lg),
            topRight: const Radius.circular(AppRadius.lg),
            bottomLeft: Radius.circular(isUser ? AppRadius.lg : AppRadius.sm),
            bottomRight: Radius.circular(isUser ? AppRadius.sm : AppRadius.lg),
          ),
          boxShadow: isUser ? null : AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.isError)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Symbols.error_rounded, size: 15, color: theme.colorScheme.error),
                    const SizedBox(width: 4),
                    Text('Couldn\'t reply', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error)),
                  ],
                ),
              ),
            isUser
                ? Text(message.content, style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white))
                : MarkdownBody(
                    data: message.content,
                    selectable: true,
                    onTapLink: (text, href, title) {
                      if (href != null) MapsLauncher.openUrl(href);
                    },
                    styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                      p: theme.textTheme.bodyLarge,
                      strong: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                      listBullet: theme.textTheme.bodyLarge,
                      h1: theme.textTheme.titleLarge,
                      h2: theme.textTheme.titleMedium,
                      h3: theme.textTheme.titleSmall,
                    ),
                  ),
            if (showPlannerCta) ...[
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onOpenPlanner,
                  icon: const Icon(Symbols.auto_awesome_rounded, size: 16),
                  label: const Text('Generate Full Itinerary'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    visualDensity: VisualDensity.compact,
                    textStyle: theme.textTheme.labelMedium,
                  ),
                ),
              ),
            ],
            if (!isUser && !message.isError)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => Share.share(message.content, subject: 'TripNest PH AI Recommendation'),
                  icon: const Icon(Symbols.ios_share_rounded, size: 16),
                  iconSize: 16,
                  color: theme.textTheme.bodyMedium?.color,
                  tooltip: 'Share this recommendation',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
