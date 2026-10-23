import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/onboarding/onboarding_flow.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/toast_host.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));
  runApp(RenderWatcherApp(state: AppState()));
}

class RenderWatcherApp extends StatelessWidget {
  const RenderWatcherApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'Render Watcher',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: const OnboardingFlow(),
        builder: (context, child) {
          // Respect the user's text size, within bounds the layouts are tuned for.
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.3),
            ),
            child: Stack(children: [
              ?child,
              ToastHost(state: state),
            ]),
          );
        },
      ),
    );
  }
}
