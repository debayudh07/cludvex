import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:render_watcher/main.dart';
import 'package:render_watcher/screens/shell/home_shell.dart';
import 'package:render_watcher/state/app_state.dart';
import 'package:render_watcher/theme/app_theme.dart';

Future<void> _pumpAt(WidgetTester tester, Size size, Widget app) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const sizes = {
    'small phone': Size(320, 568),
    'phone': Size(390, 844),
    'large phone': Size(430, 932),
    'tablet': Size(1024, 1366),
  };

  for (final entry in sizes.entries) {
    testWidgets('onboarding lays out on ${entry.key}', (tester) async {
      await _pumpAt(tester, entry.value, RenderWatcherApp(state: AppState()));
      expect(find.text('Continue with GitHub'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('home shell lays out on ${entry.key}', (tester) async {
      final state = AppState();
      await _pumpAt(
        tester,
        entry.value,
        AppScope(
          state: state,
          child: MaterialApp(theme: AppTheme.dark, home: const HomeShell()),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Render Watcher'), findsWidgets);
      expect(tester.takeException(), isNull);
      // Let pending timers (banner, stream) settle before teardown.
      await tester.pumpWidget(const SizedBox());
      state.dispose();
      await tester.pump(const Duration(seconds: 10));
    });
  }
}
