import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';

/// The message composer pinned to the bottom of the chat screen: a rounded
/// text field plus a send button that disables itself while a reply is in
/// flight or the field is empty.
class ChatInputBar extends StatefulWidget {
  const ChatInputBar({super.key, required this.onSend, required this.enabled});

  final ValueChanged<String> onSend;
  final bool enabled;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.enabled) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: AppShadows.card,
                ),
                child: TextField(
                  controller: _controller,
                  enabled: widget.enabled,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 1000,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submit(),
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'Ask about destinations, food, budgets…',
                    hintStyle: theme.textTheme.bodyMedium,
                    border: InputBorder.none,
                    counterText: '',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            InkWell(
              onTap: _submit,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.enabled ? theme.colorScheme.primary : theme.colorScheme.outline,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Symbols.send_rounded,
                  color: widget.enabled ? Colors.white : theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
