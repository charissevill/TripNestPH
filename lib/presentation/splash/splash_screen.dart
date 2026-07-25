import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/routes/route_paths.dart';
import '../../core/services/local_preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/branding/app_logo.dart';

/// The first screen shown on launch: the TripNest PH logo scales and fades
/// in on a white background, then hands off to onboarding after a short beat.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _navigationTimer;
  final LocalPreferencesService _preferences = LocalPreferencesService();

  @override
  void initState() {
    super.initState();
    _navigationTimer = Timer(const Duration(milliseconds: 2600), _navigateNext);
  }

  /// Onboarding only ever appears once per install — everyone else (signed
  /// out or not) lands on Login instead, and the router's own redirect
  /// logic takes it from there (straight through to Home if already signed
  /// in and verified).
  Future<void> _navigateNext() async {
    final hasSeenOnboarding = await _preferences.getHasSeenOnboarding();
    if (!mounted) return;
    if (hasSeenOnboarding) {
      context.go(RoutePaths.login);
      return;
    }
    await _preferences.setHasSeenOnboarding(true);
    if (!mounted) return;
    context.go(RoutePaths.onboarding);
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppLogo(size: 220)
                  .animate()
                  .scale(
                    begin: const Offset(0.55, 0.55),
                    end: const Offset(1, 1),
                    duration: 700.ms,
                    curve: Curves.easeOutBack,
                  )
                  .fadeIn(duration: 500.ms)
                  .then(delay: 300.ms)
                  .shimmer(duration: 1100.ms, color: AppColors.primary.withValues(alpha: 0.25)),
              const SizedBox(height: AppSpacing.xxl),
              const _LoadingDots().animate().fadeIn(delay: 900.ms, duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three dots pulsing in sequence to signal the app is warming up.
class _LoadingDots extends StatelessWidget {
  const _LoadingDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.85), shape: BoxShape.circle),
          )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .fade(begin: 1, end: 0.25, duration: 600.ms, delay: (i * 150).ms),
        );
      }),
    );
  }
}
