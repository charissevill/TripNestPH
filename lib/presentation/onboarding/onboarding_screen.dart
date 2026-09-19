import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../core/constants/app_images.dart';
import '../../core/routes/route_paths.dart';
import '../../core/services/local_preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/buttons/animated_button.dart';
import '../../core/widgets/layout/max_width_container.dart';
import '../../core/widgets/media/image_error_placeholder.dart';

class _OnboardingPageData {
  const _OnboardingPageData({required this.imageUrl, required this.title, required this.description});

  final String imageUrl;
  final String title;
  final String description;
}

final List<_OnboardingPageData> _pages = [
  _OnboardingPageData(
    imageUrl: AppImages.onboardingExplore,
    title: 'Discover hidden gems across the Philippines',
    description:
        'From world-famous beaches to secret waterfalls, explore thousands of curated spots across every region.',
  ),
  _OnboardingPageData(
    imageUrl: AppImages.onboardingPlan,
    title: 'Let AI plan your perfect trip',
    description:
        'Tell us your budget, days and interests — get a personalized day-by-day itinerary in seconds.',
  ),
  _OnboardingPageData(
    imageUrl: AppImages.onboardingSave,
    title: 'Save, share and travel smarter',
    description: 'Bookmark favorites, follow local travel tips, and keep every trip organized in one place.',
  ),
];

/// The three-slide first-run introduction to TripNest PH's core value props.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  /// Smallest page height (at 1x text) that still fits the image, title,
  /// description, indicator and button without overflowing.
  static const double _minPageHeight = 540;

  final PageController _controller = PageController();
  final LocalPreferencesService _preferences = LocalPreferencesService();
  int _index = 0;

  bool get _isLast => _index == _pages.length - 1;

  void _finish() {
    // Marked seen only here — once onboarding is actually exited — not on
    // splash simply navigating to it (see splash_screen.dart).
    unawaited(_preferences.setHasSeenOnboarding(true));
    context.go(RoutePaths.home);
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        // The slide (image + copy) needs a minimum height to read properly.
        // A wide, short viewport (landscape phone) lays each slide out side by
        // side so the whole page still fits; anything else too short for it
        // (small phone at a large text size) scrolls rather than overflowing.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minHeight = _minPageHeight * MediaQuery.textScalerOf(context).scale(1);
            final sideBySide = constraints.maxHeight < minHeight && constraints.maxWidth >= constraints.maxHeight * 1.4;
            return SingleChildScrollView(
            child: SizedBox(
              height: sideBySide ? constraints.maxHeight : math.max(constraints.maxHeight, minHeight),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                      child: TextButton(
                        onPressed: _finish,
                        child: const Text('Skip'),
                      ),
                    ),
                  ),
                  Expanded(
                    child: MaxWidthContainer(
                      maxWidth: 640,
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: _pages.length,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder: (context, i) => _OnboardingSlide(data: _pages[i], sideBySide: sideBySide),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SmoothPageIndicator(
                    controller: _controller,
                    count: _pages.length,
                    effect: WormEffect(
                      dotHeight: 7,
                      dotWidth: 7,
                      spacing: 8,
                      activeDotColor: theme.colorScheme.primary,
                      dotColor: AppColors.border,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: MaxWidthContainer(
                      maxWidth: 640,
                      child: AnimatedButton(
                        label: _isLast ? 'Get Started' : 'Next',
                        onPressed: _next,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
            );
          },
        ),
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({required this.data, this.sideBySide = false});

  final _OnboardingPageData data;

  /// Image beside the copy (landscape) instead of stacked above it.
  final bool sideBySide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      child: CachedNetworkImage(
        imageUrl: data.imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorWidget: (context, url, error) => const ImageErrorPlaceholder(width: double.infinity),
      ),
    ).animate().fadeIn(duration: 420.ms).moveY(begin: 16, end: 0);
    final title = Text(
      data.title,
      textAlign: TextAlign.center,
      style: theme.textTheme.headlineLarge,
    ).animate().fadeIn(delay: 120.ms, duration: 420.ms);
    final description = Text(
      data.description,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium,
    ).animate().fadeIn(delay: 200.ms, duration: 420.ms);

    if (sideBySide) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Row(
          children: [
            Expanded(flex: 5, child: image),
            const SizedBox(width: AppSpacing.xl),
            // Centered when it fits, scrolls when the viewport is very short.
            Expanded(
              flex: 6,
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [title, const SizedBox(height: AppSpacing.sm), description],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          Expanded(child: image),
          const SizedBox(height: AppSpacing.xxl),
          title,
          const SizedBox(height: AppSpacing.sm),
          description,
        ],
      ),
    );
  }
}
