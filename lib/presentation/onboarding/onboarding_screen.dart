import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../core/constants/app_images.dart';
import '../../core/routes/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/buttons/animated_button.dart';

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
  final PageController _controller = PageController();
  int _index = 0;

  bool get _isLast => _index == _pages.length - 1;

  void _next() {
    if (_isLast) {
      context.go(RoutePaths.home);
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
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                child: TextButton(
                  onPressed: () => context.go(RoutePaths.home),
                  child: const Text('Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _OnboardingSlide(data: _pages[i]),
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
              child: AnimatedButton(
                label: _isLast ? 'Get Started' : 'Next',
                onPressed: _next,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xxl),
              child: CachedNetworkImage(imageUrl: data.imageUrl, fit: BoxFit.cover, width: double.infinity),
            ),
          ).animate().fadeIn(duration: 420.ms).moveY(begin: 16, end: 0),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineLarge,
          ).animate().fadeIn(delay: 120.ms, duration: 420.ms),
          const SizedBox(height: AppSpacing.sm),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ).animate().fadeIn(delay: 200.ms, duration: 420.ms),
        ],
      ),
    );
  }
}
