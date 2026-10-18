import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Strips the leading `Destination: <place>, <province>` line
/// `ChatPrompts.systemPrompt()` asks the model to open a day-by-day reply
/// with — it exists so `AiChatScreen._generateFromChat` can reliably parse
/// the exact place the AI committed to, not to be read by the traveler, so
/// it's hidden from both the rendered bubble and anything shared from it.
final RegExp _destinationLinePattern = RegExp(
  r'^Destination:.*\n?',
  multiLine: true,
);

String _visibleContent(String content) =>
    content.replaceFirst(_destinationLinePattern, '').trimLeft();

/// A markdown table row (`| a | b |`). A reply with a table gets a wider
/// bubble so a 3-4 column comparison fits before it has to scroll.
final RegExp _tableRowPattern = RegExp(r'^\s*\|.*\|\s*$', multiLine: true);

/// Sizes a table column to its content like [IntrinsicColumnWidth], but
/// caps it at [cap] so a long cell wraps onto a few lines instead of
/// stretching the whole table into one very wide row. Extends
/// [IntrinsicColumnWidth] on purpose: flutter_markdown only wraps a table in
/// a horizontal scroll view when its column width is Fixed or Intrinsic, so
/// a table that's still wider than the bubble scrolls instead of overflowing.
class _CappedIntrinsicColumnWidth extends IntrinsicColumnWidth {
  const _CappedIntrinsicColumnWidth(this.cap);

  final double cap;

  @override
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) => math.max(
        minIntrinsicWidth(cells, containerWidth),
        math.min(super.maxIntrinsicWidth(cells, containerWidth), cap),
      );
}

/// One chat turn. User messages are a solid-primary bubble on the right;
/// assistant messages are a surface-colored bubble on the left with
/// markdown rendering (bold place names, bullet lists, headers for
/// multi-day plans). Error replies get a warning tint instead.
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message, this.onOpenPlanner, this.onRegenerate});

  final AiChatMessage message;

  /// Asks for this reply again — shown as "Try again" on an error bubble
  /// and as a regenerate icon on a real answer. `AiChatScreen` only passes
  /// it for the chat's latest reply, since that's the one
  /// `AiChatProvider.regenerateLastReply` replaces.
  final VoidCallback? onRegenerate;

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
    final visibleContent = isUser ? message.content : _visibleContent(message.content);
    final showPlannerCta =
        !isUser &&
        !message.isError &&
        onOpenPlanner != null &&
        _looksLikeItinerary(message.content);
    final hasTable = !isUser && _tableRowPattern.hasMatch(visibleContent);
    final tableLine = BorderSide(color: theme.colorScheme.outlineVariant);

    final bubbleColor = isUser
        ? theme.colorScheme.primary
        : message.isError
            ? theme.colorScheme.error.withValues(alpha: 0.08)
            : theme.colorScheme.surface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: LayoutBuilder(
        builder: (context, constraints) => Container(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * (hasTable ? 0.95 : 0.8)),
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
                  ? SelectableText(visibleContent, style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white))
                  : MarkdownBody(
                      data: visibleContent,
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
                        tableHead: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                        tableBody: theme.textTheme.bodyMedium,
                        tableHeadAlign: TextAlign.left,
                        tableColumnWidth: const _CappedIntrinsicColumnWidth(170),
                        tableVerticalAlignment: TableCellVerticalAlignment.top,
                        tableCellsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        tableBorder: TableBorder(
                          top: tableLine,
                          bottom: tableLine,
                          left: tableLine,
                          right: tableLine,
                          horizontalInside: tableLine,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        tablePadding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        tableScrollbarThumbVisibility: true,
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
              if (message.isError && onRegenerate != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: OutlinedButton.icon(
                    onPressed: onRegenerate,
                    icon: const Icon(Symbols.refresh_rounded, size: 16),
                    label: const Text('Try again'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      visualDensity: VisualDensity.compact,
                      textStyle: theme.textTheme.labelMedium,
                    ),
                  ),
                ),
              if (!isUser && !message.isError)
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _BubbleAction(
                        icon: Symbols.content_copy_rounded,
                        tooltip: 'Copy',
                        onPressed: () => _copy(context, visibleContent),
                      ),
                      _BubbleAction(
                        icon: Symbols.ios_share_rounded,
                        tooltip: 'Share this recommendation',
                        onPressed: () => Share.share(visibleContent, subject: 'TripNest PH AI Recommendation'),
                      ),
                      if (onRegenerate != null)
                        _BubbleAction(
                          icon: Symbols.refresh_rounded,
                          tooltip: 'Regenerate reply',
                          onPressed: onRegenerate!,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Copied to clipboard.')));
  }
}

class _BubbleAction extends StatelessWidget {
  const _BubbleAction({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      iconSize: 16,
      color: Theme.of(context).textTheme.bodyMedium?.color,
      tooltip: tooltip,
    );
  }
}
