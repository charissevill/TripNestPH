import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/core/widgets/media/avatar_preview.dart';

void main() {
  testWidgets('AvatarPreview shows an enlarged photo while held down and hides it on release', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AvatarPreview(
            photoUrl: 'https://example.com/avatar.jpg',
            child: Container(key: const Key('avatar'), width: 40, height: 40, color: Colors.blue),
          ),
        ),
      ),
    );

    expect(find.byType(CachedNetworkImage), findsNothing);

    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('avatar'))));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(CachedNetworkImage), findsOneWidget);

    await gesture.up();
    await tester.pump();

    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('AvatarPreview does nothing on long press when there is no photo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AvatarPreview(
            photoUrl: null,
            child: Container(key: const Key('avatar'), width: 40, height: 40, color: Colors.blue),
          ),
        ),
      ),
    );

    await tester.longPress(find.byKey(const Key('avatar')));
    await tester.pump();

    expect(find.byType(CachedNetworkImage), findsNothing);
  });
}
