import 'package:flutter/material.dart';

import 'package:tripnest_ph/core/theme/breakpoints.dart';
import 'package:tripnest_ph/core/widgets/navigation/app_bottom_nav.dart';
import 'package:tripnest_ph/core/widgets/navigation/app_nav_sidebar.dart';

import 'layout_harness.dart';

/// The two navigation surfaces the shell swaps between at [Breakpoints.compact]:
/// the floating bottom bar (which shows the selected tab's label — including
/// the long "My Business") and the persistent side nav.
void main() {
  for (final businessOwner in [false, true]) {
    for (var index = 0; index < 5; index++) {
      layoutMatrix(
        'Bottom nav tab $index${businessOwner ? ' (business owner)' : ''}',
        () => Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: AppBottomNav(currentIndex: index, onTap: (_) {}, isBusinessOwner: businessOwner),
        ),
      );
      layoutMatrix(
        'Side nav tab $index${businessOwner ? ' (business owner)' : ''}',
        () => Scaffold(
          body: Row(
            children: [
              AppNavSidebar(currentIndex: index, onTap: (_) {}, isBusinessOwner: businessOwner),
              const Expanded(child: SizedBox.expand()),
            ],
          ),
        ),
      );
    }
  }
}
