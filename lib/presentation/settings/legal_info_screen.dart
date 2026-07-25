import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/constants/app_strings.dart';
import '../../core/constants/legal_content.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/branding/app_logo.dart';
import '../../domain/models/legal_section.dart';

/// One of the three static legal/info documents reachable from Settings.
enum LegalInfoTopic {
  privacy,
  terms,
  about;

  static LegalInfoTopic fromKey(String key) {
    return LegalInfoTopic.values.firstWhere((t) => t.name == key, orElse: () => LegalInfoTopic.about);
  }

  String get title {
    switch (this) {
      case LegalInfoTopic.privacy:
        return 'Privacy Policy';
      case LegalInfoTopic.terms:
        return 'Terms of Service';
      case LegalInfoTopic.about:
        return 'About ${AppStrings.appName}';
    }
  }

  IconData get icon {
    switch (this) {
      case LegalInfoTopic.privacy:
        return Symbols.privacy_tip_rounded;
      case LegalInfoTopic.terms:
        return Symbols.description_rounded;
      case LegalInfoTopic.about:
        return Symbols.info_rounded;
    }
  }
}

/// Full-screen reader for Privacy Policy / Terms of Service / About — its
/// own page (with a back button and a shareable route) rather than a modal,
/// laid out with real typographic hierarchy (headings, bullets, cards)
/// instead of one long block of plain text.
class LegalInfoScreen extends StatelessWidget {
  const LegalInfoScreen({super.key, required this.topicKey});

  final String topicKey;

  @override
  Widget build(BuildContext context) {
    final topic = LegalInfoTopic.fromKey(topicKey);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Symbols.arrow_back_rounded), onPressed: () => context.pop()),
        title: Text(topic.title),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.huge),
        children: [
          if (topic == LegalInfoTopic.about) const _AboutHeader() else _DocumentHeader(topic: topic),
          const SizedBox(height: AppSpacing.xl),
          if (topic == LegalInfoTopic.about) const _AboutBody() else _DocumentBody(topic: topic),
        ],
      ),
    );
  }
}

class _DocumentHeader extends StatelessWidget {
  const _DocumentHeader({required this.topic});

  final LegalInfoTopic topic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(topic.icon, size: 34, color: theme.colorScheme.primary),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(topic.title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
          decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(AppRadius.pill)),
          child: Text(LegalContent.lastUpdated, style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
        ),
      ],
    );
  }
}

class _DocumentBody extends StatelessWidget {
  const _DocumentBody({required this.topic});

  final LegalInfoTopic topic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final intro = topic == LegalInfoTopic.privacy ? LegalContent.privacyIntro : LegalContent.termsIntro;
    final sections = topic == LegalInfoTopic.privacy ? LegalContent.privacySections : LegalContent.termsSections;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoCard(child: Text(intro, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6))),
        const SizedBox(height: AppSpacing.lg),
        for (var i = 0; i < sections.length; i++) ...[
          _LegalSectionView(section: sections[i]),
          if (i != sections.length - 1) const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

class _LegalSectionView extends StatelessWidget {
  const _LegalSectionView({required this.section});

  final LegalSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 4, height: 18, margin: const EdgeInsets.only(top: 3, right: AppSpacing.sm), decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(2))),
            Expanded(child: Text(section.heading, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (section.paragraph != null)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: Text(section.paragraph!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
          ),
        if (section.bullets.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: section.bullets.map((b) => _BulletRow(text: b)).toList(),
            ),
          ),
      ],
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(width: 6, height: 6, decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6))),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.12)),
      ),
      child: child,
    );
  }
}

class _AboutHeader extends StatelessWidget {
  const _AboutHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: const AppLogo(size: 96),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(AppStrings.appName, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          AppStrings.tagline,
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, fontStyle: FontStyle.italic),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _AboutBody extends StatelessWidget {
  const _AboutBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoCard(child: Text(LegalContent.aboutIntro, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6))),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Container(width: 4, height: 18, margin: const EdgeInsets.only(right: AppSpacing.sm), decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(2))),
            Text('What you can do', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: LegalContent.aboutFeatures
                .map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Symbols.check_circle_rounded, size: 18, color: AppColors.success),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: Text(f, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6))),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(LegalContent.aboutClosing, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: Text(LegalContent.appVersion, style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(LegalContent.aboutFooter, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary)),
            ],
          ),
        ),
      ],
    );
  }
}
