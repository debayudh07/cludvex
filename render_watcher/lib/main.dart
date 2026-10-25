import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'screens/onboarding/auth_gate.dart';
import 'services/push_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/toast_host.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

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
        home: const AuthGate(),
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
