import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../ai/providers/ai_chat_provider.dart';
import '../../ai/widgets/chat_bubble.dart';
import '../../ai/widgets/chat_input_bar.dart';
import '../../ai/widgets/prompt_suggestion_chips.dart';
import '../../ai/widgets/suggestion_pill.dart';
import '../../ai/widgets/typing_indicator.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/branding/app_logo.dart';
import '../../data/repositories/destination_repository.dart';
import '../../data/repositories/province_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../domain/models/destination.dart';
import '../../domain/models/province.dart';
import '../../domain/models/restaurant.dart';

/// The AI Travel Assistant: a conversational chat surface that also serves
/// destination recommendations, budget estimates, smart travel tips,
/// hidden gems, food recommendations and emergency advice through natural
/// conversation and quick-tap suggestions (features 2–10), reachable from
/// the floating action button on every tab.
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final ScrollController _scrollController = ScrollController();

  /// Real featured destinations + provinces with a full guide, loaded once
  /// per chat session — grounds "destination recommendations" answers in
  /// names that actually exist in the app, the same "give it real names,
  /// never invent others" approach `ItineraryPrompts` already uses for
  /// itinerary generation. Best-effort: a load failure just means the chat
  /// falls back to profile-only context, same as before this existed.
  String? _realDataContext;

  @override
  void initState() {
    super.initState();
    _loadRealDataContext();
  }

  /// The same Google Maps search URL shape `MapsLauncher.openDirections`
  /// builds — inlined here (rather than launching anything) so it can be
  /// handed to the AI as literal markdown link text.
  String _mapsSearchUrl({required double latitude, required double longitude, required String label}) {
    return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$latitude,$longitude($label)')}';
  }

  Future<void> _loadRealDataContext() async {
    try {
      final results = await Future.wait([
        DestinationRepository().getFeatured(limit: 10),
        ProvinceRepository().getAll(),
        RestaurantRepository().getPopular(limit: 10),
      ]);
      final destinations = results[0] as List<Destination>;
      final provinces = (results[1] as List<Province>).where((p) => p.hasContent).toList();
      final restaurants = results[2] as List<Restaurant>;

      final parts = <String>[];
      if (destinations.isNotEmpty) {
        parts.add(
          'Real featured destinations in the TripNest PH catalog you can recommend by name '
          '(never invent a destination that isn\'t one of these or generally well-known): '
          '${destinations.map((d) => '${d.name} (${d.provinceName})').join(', ')}.',
        );
      }

      final destinationsWithLinks = destinations
          .where((d) => d.websiteUrl.isNotEmpty || (d.latitude != null && d.longitude != null))
          .toList();
      if (destinationsWithLinks.isNotEmpty) {
        parts.add(
          'Real links on file for some of those destinations — only use these exact URLs, never invent one: '
          '${destinationsWithLinks.map((d) {
            final links = <String>[];
            if (d.websiteUrl.isNotEmpty) links.add('website: ${d.websiteUrl}');
            if (d.latitude != null && d.longitude != null) {
              links.add('map: ${_mapsSearchUrl(latitude: d.latitude!, longitude: d.longitude!, label: d.name)}');
            }
            return '${d.name} (${links.join(', ')})';
          }).join('; ')}.',
        );
      }

      if (restaurants.isNotEmpty) {
        parts.add(
          'Real restaurants in the TripNest PH catalog you can recommend by name '
          '(never invent a restaurant that isn\'t one of these or generally well-known): '
          '${restaurants.map((r) => '${r.name} (${r.provinceName})').join(', ')}.',
        );
      }

      final restaurantsWithLinks = restaurants
          .where((r) => r.websiteUrl.isNotEmpty || (r.latitude != null && r.longitude != null))
          .toList();
      if (restaurantsWithLinks.isNotEmpty) {
        parts.add(
          'Real links on file for some of those restaurants — only use these exact URLs, never invent one: '
          '${restaurantsWithLinks.map((r) {
            final links = <String>[];
            if (r.websiteUrl.isNotEmpty) links.add('website: ${r.websiteUrl}');
            if (r.latitude != null && r.longitude != null) {
              links.add('map: ${_mapsSearchUrl(latitude: r.latitude!, longitude: r.longitude!, label: r.name)}');
            }
            return '${r.name} (${links.join(', ')})';
          }).join('; ')}.',
        );
      }

      if (provinces.isNotEmpty) {
        parts.add('Provinces with a full TripNest PH in-app travel guide: ${provinces.map((p) => p.name).join(', ')}.');
      }

      final withHotlines = provinces.where((p) => p.emergencyHotlines.isNotEmpty).toList();
      if (withHotlines.isNotEmpty) {
        parts.add(
          'Real emergency hotlines on file per province (use these verbatim if the traveler asks about safety/emergencies in one of these provinces, instead of inventing generic numbers): '
          '${withHotlines.map((p) => '${p.name}: ${p.emergencyHotlines.map((h) => '${h.label} ${h.number}').join(', ')}').join('; ')}.',
        );
      }

      final withTips = provinces.where((p) => p.travelTips.isNotEmpty).toList();
      if (withTips.isNotEmpty) {
        parts.add(
          'Official TripNest PH travel tips on file per province: '
          '${withTips.map((p) => '${p.name}: ${p.travelTips.join('; ')}').join(' | ')}.',
        );
      }

      final withBudget = provinces.where((p) => p.estimatedDailyBudgetMin > 0 && p.estimatedDailyBudgetMax > 0).toList();
      if (withBudget.isNotEmpty) {
        parts.add(
          'Real typical daily budget guide on file per province: '
          '${withBudget.map((p) => '${p.name}: ₱${p.estimatedDailyBudgetMin.toStringAsFixed(0)}–₱${p.estimatedDailyBudgetMax.toStringAsFixed(0)}/day').join(', ')}.',
        );
      }

      if (mounted && parts.isNotEmpty) setState(() => _realDataContext = parts.join(' '));
    } catch (_) {
      // Best-effort — chat still works fine with just profile-based context.
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  /// Keeps the system prompt (this context plus ~3000 chars of fixed
  /// instructions) safely under the server's per-message ceiling
  /// (`AI_MAX_MESSAGE_CHARS` in `functions/index.js`) even as the catalog
  /// this context is grounded in — featured destinations/restaurants,
  /// province guides — keeps growing over time.
  static const int _maxContextChars = 8000;

  String? _buildUserContext() {
    final user = context.read<AuthProvider>().currentUser;
    final parts = <String>[];
    if (user != null) {
      if (user.travelPreferences.isNotEmpty) parts.add('Travel preferences: ${user.travelPreferences.join(', ')}.');
      if (user.favoriteCategories.isNotEmpty) parts.add('Favorite categories: ${user.favoriteCategories.join(', ')}.');
    }
    if (_realDataContext != null) parts.add(_realDataContext!);
    if (parts.isEmpty) return null;
    final joined = parts.join(' ');
    return joined.length > _maxContextChars ? joined.substring(0, _maxContextChars) : joined;
  }

  Future<void> _send(String text) async {
    final chat = context.read<AiChatProvider>();
    _scrollToBottom();
    await chat.sendMessage(text, userContext: _buildUserContext());
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<AiChatProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Symbols.arrow_back_rounded), onPressed: () => context.pop()),
        title: const Text('AI Travel Assistant'),
        actions: [
          if (chat.messages.isNotEmpty)
            IconButton(
              icon: const Icon(Symbols.delete_outline_rounded),
              tooltip: 'Clear conversation',
              onPressed: chat.clearHistory,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chat.messages.isEmpty
                ? _EmptyState(onSuggestionTap: _send)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: chat.messages.length + (chat.isSending ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == chat.messages.length) return const TypingIndicator();
                      return ChatBubble(message: chat.messages[i]);
                    },
                  ),
          ),
          if (chat.messages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 3,
                  separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    const quickFollowUps = ['Estimate my budget', 'Any hidden gems?', 'Safety tips'];
                    return SuggestionPill(
                      label: quickFollowUps[i],
                      onTap: chat.isSending ? null : () => _send(quickFollowUps[i]),
                    );
                  },
                ),
              ),
            ),
          ChatInputBar(onSend: _send, enabled: !chat.isSending),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onSuggestionTap});

  final ValueChanged<String> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),
          const AppLogo(size: 88),
          const SizedBox(height: AppSpacing.lg),
          Text('Hi, I\'m your TripNest PH travel assistant!', style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Ask me to plan a trip, find hidden gems, estimate a budget, or recommend food — anywhere in the Philippines.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Try asking', style: theme.textTheme.titleSmall),
          ),
          const SizedBox(height: AppSpacing.sm),
          PromptSuggestionChips(onSelected: onSuggestionTap),
        ],
      ),
    );
  }
}
