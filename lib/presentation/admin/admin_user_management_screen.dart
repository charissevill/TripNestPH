import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/breakpoints.dart';
import '../../core/utils/app_exception.dart';
import '../../core/widgets/buttons/selectable_chip.dart';
import '../../core/widgets/dialogs/confirmation_dialog.dart';
import '../../core/widgets/layout/scroll_aware_search_header.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/models/admin_user.dart';
import '../../domain/models/app_user.dart';
import 'widgets/admin_page_header.dart';

const int _pageSize = 20;

enum _UserSort { newest, oldest, name }

extension on _UserSort {
  String get label {
    switch (this) {
      case _UserSort.newest:
        return 'Newest first';
      case _UserSort.oldest:
        return 'Oldest first';
      case _UserSort.name:
        return 'Name (A–Z)';
    }
  }
}

/// The role filter's options, in the order they're offered.
const List<String> _roles = ['Traveler', 'Business Owner', 'LGU', 'Admin'];

const Map<String?, IconData> _roleIcons = {
  'Traveler': Symbols.person_rounded,
  'Business Owner': Symbols.storefront_rounded,
  'LGU': Symbols.account_balance_rounded,
  'Admin': Symbols.shield_person_rounded,
};

/// Admin-only: search and suspend/activate traveler accounts. Previously
/// this was only possible directly in the Firebase Console even though
/// `firestore.rules` already grants an admin the exact status-only write
/// needed here (see `AuthProvider`'s live-suspension check — flipping this
/// field force-signs the traveler out immediately, everywhere).
class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({
    super.key,
    this.userRepository,
    this.adminRepository,
  });

  // Test-only overrides — production call sites never pass these.
  final UserRepository? userRepository;
  final AdminRepository? adminRepository;

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  late final UserRepository _repository =
      widget.userRepository ?? UserRepository();
  final TextEditingController _searchController = TextEditingController();

  List<AppUser> _users = [];
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;
  String _query = '';
  _UserSort _sort = _UserSort.newest;

  /// One of [_roles], or null for every account.
  String? _roleFilter;

  // A server-side lookup to back up the local-page filter below, which only
  // ever searched whatever had already been scrolled into _users — a
  // traveler beyond the first page showed as "No matches" even though the
  // account genuinely existed.
  List<AppUser> _serverSearchResults = [];
  Timer? _searchDebounce;

  // Every account has a `users` doc, whatever its role — what makes one a
  // business owner/LGU/admin is a second doc in `admin_users` under the same
  // uid. Keyed by uid so each row can show which kind of account it is.
  Map<String, AdminUser> _adminsByUid = const {};
  StreamSubscription<List<AdminUser>>? _adminsSubscription;

  @override
  void initState() {
    super.initState();
    _loadMore();
    try {
      _adminsSubscription = (widget.adminRepository ?? AdminRepository())
          .streamAll()
          .listen((admins) {
            if (!mounted) return;
            setState(() => _adminsByUid = {for (final a in admins) a.uid: a});
          }, onError: (_) {});
    } catch (_) {
      // Best-effort — without it every row just reads as a traveler.
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    _adminsSubscription?.cancel();
    super.dispose();
  }

  /// "Traveler" unless [user] also holds an Admin Portal role.
  String _roleLabel(AppUser user) {
    final admin = _adminsByUid[user.uid];
    if (admin == null) return 'Traveler';
    switch (admin.role) {
      case AdminRole.businessOwner:
        return 'Business Owner';
      case AdminRole.lgu:
        return 'LGU';
      case AdminRole.admin:
        return 'Admin';
      default:
        return 'Traveler';
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);
    _searchDebounce?.cancel();
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      setState(() => _serverSearchResults = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await _repository.searchByEmailPrefix(normalized);
        if (mounted) setState(() => _serverSearchResults = results);
      } catch (_) {
        // Best-effort — the local-page filter below still works either way.
      }
    });
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _repository.getPage(
        pageSize: _pageSize,
        startAfter: _cursor,
      );
      final lastPage = result.items.length < _pageSize;
      // The dated pages leave out any account with no sign-up date at all,
      // so those are picked up after the last one and listed at the end.
      var undated = const <AppUser>[];
      if (lastPage) {
        try {
          undated = await _repository.getUndated();
        } catch (_) {
          // Best-effort — the dated accounts above still loaded.
        }
      }
      if (!mounted) return;
      setState(() {
        final seen = {..._users, ...result.items}.map((u) => u.uid).toSet();
        _users = [
          ..._users,
          ...result.items,
          for (final u in undated)
            if (seen.add(u.uid)) u,
        ];
        _cursor = result.lastDoc;
        _hasMore = !lastPage;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// Pages arrive newest-first, so that order needs nothing more. Any other
  /// one is only right across every account, so the rest of the pages are
  /// fetched before it's applied.
  Future<void> _setSort(_UserSort sort) async {
    setState(() => _sort = sort);
    if (sort == _UserSort.newest) return;
    await _loadAll();
  }

  /// A role's accounts can sit on any page, so — same as a non-default sort
  /// — the rest are fetched before the filter can be trusted.
  Future<void> _setRoleFilter(String? role) async {
    setState(() => _roleFilter = role);
    if (role == null) return;
    await _loadAll();
  }

  Future<void> _loadAll() async {
    while (mounted && _hasMore && _error == null) {
      if (_loading) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        continue;
      }
      await _loadMore();
    }
  }

  String _displayName(AppUser user) =>
      (user.name.isNotEmpty ? user.name : user.email).toLowerCase();

  List<AppUser> _sorted(List<AppUser> users) {
    int byName(AppUser a, AppUser b) {
      final names = _displayName(a).compareTo(_displayName(b));
      return names != 0 ? names : a.email.compareTo(b.email);
    }

    switch (_sort) {
      case _UserSort.newest:
        return users;
      case _UserSort.oldest:
        // An account with no recorded date counts as the oldest.
        final epoch = DateTime.fromMillisecondsSinceEpoch(0);
        return [...users]..sort(
          (a, b) => (a.createdAt ?? epoch).compareTo(b.createdAt ?? epoch),
        );
      case _UserSort.name:
        return [...users]..sort(byName);
    }
  }

  List<AppUser> get _filteredUsers {
    final role = _roleFilter;
    final matching = _matchingUsers;
    return _sorted(
      role == null
          ? matching
          : matching.where((u) => _roleLabel(u) == role).toList(),
    );
  }

  List<AppUser> get _matchingUsers {
    final normalized = _query.trim().toLowerCase();
    if (normalized.isEmpty) return _users;
    final localMatches = _users
        .where(
          (u) =>
              u.name.toLowerCase().contains(normalized) ||
              u.email.toLowerCase().contains(normalized),
        )
        .toList();
    final seenUids = localMatches.map((u) => u.uid).toSet();
    return [
      ...localMatches,
      for (final u in _serverSearchResults)
        if (seenUids.add(u.uid)) u,
    ];
  }

  Future<void> _toggleSuspend(AppUser user) async {
    final suspending = !user.isSuspended;
    final confirmed = await showConfirmationDialog(
      context,
      title: suspending ? 'Suspend this account?' : 'Reactivate this account?',
      message: suspending
          ? '${user.name.isNotEmpty ? user.name : user.email} will be immediately signed out and unable to use the app.'
          : '${user.name.isNotEmpty ? user.name : user.email} will regain access to the app.',
      confirmLabel: suspending ? 'Suspend' : 'Reactivate',
      isDestructive: suspending,
    );
    if (!confirmed || !mounted) return;
    try {
      final newStatus = suspending ? 'suspended' : 'active';
      await _repository.setStatus(user.uid, newStatus);
      if (!mounted) return;
      setState(() {
        _users = _users
            .map(
              (u) => u.uid == user.uid
                  ? AppUser(
                      uid: u.uid,
                      name: u.name,
                      email: u.email,
                      photoUrl: u.photoUrl,
                      travelPreferences: u.travelPreferences,
                      favoriteCategories: u.favoriteCategories,
                      emailVerified: u.emailVerified,
                      createdAt: u.createdAt,
                      status: newStatus,
                    )
                  : u,
            )
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            suspending
                ? '${user.name.isNotEmpty ? user.name : user.email} suspended.'
                : '${user.name.isNotEmpty ? user.name : user.email} reactivated.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _filteredUsers;
    final shortViewport = MediaQuery.sizeOf(context).height < 480;
    final roleChips = SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final role in <String?>[null, ..._roles])
                          Padding(
                            padding: const EdgeInsets.only(
                              right: AppSpacing.sm,
                            ),
                            // Not a ChoiceChip: the app's chip theme squeezed
                            // its label, cutting every name short.
                            child: SelectableChip(
                              label: role ?? 'All',
                              icon: _roleIcons[role] ?? Symbols.groups_rounded,
                              selected: _roleFilter == role,
                              onTap: () => _setRoleFilter(role),
                            ),
                          ),
                      ],
                    ),
                  );
    return Scaffold(
      appBar: adminPageHeader(
        context,
        title: 'Users',
      ),
      body: SafeArea(
        // Search slides away while scrolling and returns on scroll-up.
        child: CollapsibleSearchHeader(
          header: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          decoration: const InputDecoration(
                            labelText: 'Search by name or email',
                            prefixIcon: Icon(Symbols.search_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _SortMenu(
                        value: _sort,
                        showLabel: !context.isCompact,
                        onChanged: _setSort,
                      ),
                      // A landscape phone has width to spare and no height:
                      // the role chips share the search row there instead
                      // of taking a line of their own from the list.
                      if (shortViewport) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(child: roleChips),
                      ],
                    ],
                  ),
                  if (!shortViewport) ...[
                    const SizedBox(height: AppSpacing.sm),
                    roleChips,
                  ],
                ],
              ),
            ),
          // Also covers a role filter still fetching the remaining pages —
          // nothing matching *yet* isn't "no matches".
          body: users.isEmpty && _loading
                  ? LoadingWidget.block(height: 400)
                  // A failed first load isn't "no travelers" — say what
                  // went wrong instead of an empty list that looks final.
                  : _users.isEmpty && _error != null
                  ? EmptyStateWidget(
                      icon: Symbols.error_outline_rounded,
                      title: 'Couldn\'t load users',
                      message: AppException.from(_error!).message,
                    )
                  : users.isEmpty
                  ? EmptyStateWidget(
                      icon: Symbols.group_off_rounded,
                      title: _query.isNotEmpty
                          ? 'No matches'
                          : _roleFilter != null
                          ? 'No $_roleFilter accounts'
                          : 'No users yet',
                      message: _query.isEmpty
                          ? ''
                          : 'Try a different name or email.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.huge,
                      ),
                      itemCount: users.length + 1,
                      itemBuilder: (context, i) {
                        if (i == users.length) {
                          if (_error != null) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.md,
                              ),
                              child: Text(
                                AppException.from(_error!).message,
                                style: const TextStyle(color: AppColors.error),
                              ),
                            );
                          }
                          if (!_hasMore || _query.isNotEmpty)
                            return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            child: Center(
                              child: _loading
                                  ? const CircularProgressIndicator()
                                  : TextButton(
                                      onPressed: _loadMore,
                                      child: const Text('Load more'),
                                    ),
                            ),
                          );
                        }
                        final user = users[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            user.isSuspended
                                ? Symbols.block_rounded
                                : Symbols.account_circle_rounded,
                            color: user.isSuspended
                                ? AppColors.error
                                : Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(
                            user.name.isNotEmpty ? user.name : user.email,
                          ),
                          subtitle: Text(
                            '${user.email}'
                            '${_adminsByUid[user.uid]?.provinceName != null ? ' · ${_adminsByUid[user.uid]!.provinceName}' : ''}'
                            '${user.isSuspended ? ' · suspended' : ''}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _RoleBadge(
                                label: _roleLabel(user),
                                highlighted: _adminsByUid.containsKey(user.uid),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (_) => _toggleSuspend(user),
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Text(
                                      user.isSuspended
                                          ? 'Reactivate'
                                          : 'Suspend',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}

/// The account type shown on each row — tinted when it's anything other
/// than a plain traveler, so business owners/LGUs/admins stand out.
class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label, required this.highlighted});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: highlighted
            ? scheme.primary.withValues(alpha: 0.12)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: highlighted ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({
    required this.value,
    required this.onChanged,
    required this.showLabel,
  });

  final _UserSort value;
  final ValueChanged<_UserSort> onChanged;

  /// False where there's only room for the icon; the tooltip and the menu's
  /// own checked item still say which sort is active.
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<_UserSort>(
      tooltip: 'Sort by: ${value.label}',
      initialValue: value,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      itemBuilder: (context) => [
        for (final sort in _UserSort.values)
          PopupMenuItem(value: sort, child: Text(sort.label)),
      ],
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.sort_rounded,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            if (showLabel) ...[
              const SizedBox(width: AppSpacing.xs),
              Text(
                value.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Icon(
                Symbols.expand_more_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
