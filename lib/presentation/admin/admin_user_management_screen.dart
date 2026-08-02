import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/widgets/dialogs/confirmation_dialog.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/models/app_user.dart';

const int _pageSize = 20;

/// Admin-only: search and suspend/activate traveler accounts. Previously
/// this was only possible directly in the Firebase Console even though
/// `firestore.rules` already grants an admin the exact status-only write
/// needed here (see `AuthProvider`'s live-suspension check — flipping this
/// field force-signs the traveler out immediately, everywhere).
class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key, this.userRepository});

  // Test-only override — production call sites never pass this.
  final UserRepository? userRepository;

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

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      if (!mounted) return;
      setState(() {
        _users = [..._users, ...result.items];
        _cursor = result.lastDoc;
        _hasMore = result.items.length == _pageSize;
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

  List<AppUser> get _filteredUsers {
    final normalized = _query.trim().toLowerCase();
    if (normalized.isEmpty) return _users;
    return _users
        .where(
          (u) =>
              u.name.toLowerCase().contains(normalized) ||
              u.email.toLowerCase().contains(normalized),
        )
        .toList();
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Travelers'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  labelText: 'Search by name or email',
                  prefixIcon: Icon(Symbols.search_rounded),
                ),
              ),
            ),
            Expanded(
              child: _users.isEmpty && _loading
                  ? LoadingWidget.block(height: 400)
                  : users.isEmpty
                  ? EmptyStateWidget(
                      icon: Symbols.group_off_rounded,
                      title: _query.isEmpty ? 'No travelers yet' : 'No matches',
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
                            '${user.email}${user.isSuspended ? ' · suspended' : ''}',
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (_) => _toggleSuspend(user),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'toggle',
                                child: Text(
                                  user.isSuspended ? 'Reactivate' : 'Suspend',
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
