import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../data/repositories/favorites_repository.dart';
import '../../../domain/models/favorite_collection.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Bottom sheet letting a traveler assign an already-saved favorite to a
/// named [FavoriteCollection] — pick an existing one, create a new one
/// inline, or clear back to "Unsorted". Writes directly via [repository];
/// [SavedScreen]'s own live streams pick the change up, nothing to return.
Future<void> showAddToCollectionSheet(
  BuildContext context, {
  required List<FavoriteCollection> collections,
  required String? currentCollectionId,
  required FavoritesRepository repository,
  required String userId,
  required FavoriteType type,
  required String itemId,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _AddToCollectionSheet(
      collections: collections,
      currentCollectionId: currentCollectionId,
      repository: repository,
      userId: userId,
      type: type,
      itemId: itemId,
    ),
  );
}

class _AddToCollectionSheet extends StatefulWidget {
  const _AddToCollectionSheet({
    required this.collections,
    required this.currentCollectionId,
    required this.repository,
    required this.userId,
    required this.type,
    required this.itemId,
  });

  final List<FavoriteCollection> collections;
  final String? currentCollectionId;
  final FavoritesRepository repository;
  final String userId;
  final FavoriteType type;
  final String itemId;

  @override
  State<_AddToCollectionSheet> createState() => _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends State<_AddToCollectionSheet> {
  bool _creatingNew = false;
  bool _busy = false;
  final _nameController = TextEditingController();

  Future<void> _select(String? collectionId) async {
    setState(() => _busy = true);
    try {
      await widget.repository.setCollection(widget.userId, widget.type, widget.itemId, collectionId);
    } catch (_) {
      // Best-effort — the sheet just stays open on failure rather than
      // silently claiming success; the traveler can retry the tap.
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _createAndSelect() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    try {
      final id = await widget.repository.createCollection(widget.userId, name);
      await _select(id);
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(AppRadius.pill)),
                ),
              ),
              Text('Add to List', style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              _CollectionOption(
                label: 'Unsorted',
                selected: widget.currentCollectionId == null,
                onTap: _busy ? null : () => _select(null),
              ),
              for (final collection in widget.collections)
                _CollectionOption(
                  label: collection.name,
                  selected: widget.currentCollectionId == collection.id,
                  onTap: _busy ? null : () => _select(collection.id),
                ),
              const SizedBox(height: AppSpacing.sm),
              if (_creatingNew)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        autofocus: true,
                        maxLength: 60,
                        enabled: !_busy,
                        decoration: const InputDecoration(hintText: 'New list name', counterText: ''),
                        onSubmitted: (_) => _createAndSelect(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Symbols.check_rounded),
                      onPressed: _busy ? null : _createAndSelect,
                    ),
                  ],
                )
              else
                TextButton.icon(
                  onPressed: _busy ? null : () => setState(() => _creatingNew = true),
                  icon: const Icon(Symbols.add_rounded, size: 18),
                  label: const Text('New List'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionOption extends StatelessWidget {
  const _CollectionOption({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Icon(
        selected ? Symbols.check_circle_rounded : Symbols.radio_button_unchecked_rounded,
        color: selected ? theme.colorScheme.primary : AppColors.textTertiary,
      ),
      title: Text(label),
    );
  }
}
