# Flutter Implementation of Uber/YouTube-Style Motion and UX for "Render Watcher" (dark-themed dev monitoring app)

Research date: 2026-10-23. Target: Flutter 3.4x / Dart 3.x.
Note on sourcing: anything listed under "Cited Findings" was checked against the linked page in this session. Items under "Inferences" that come from prior knowledge and were not re-checked are tagged **[unverified]**.

---

## 0. Platform context you must know first (2026): Material/Cupertino decoupling

### Takeaway
As of August 2026, Material and Cupertino ship as standalone pub.dev packages (`material_ui`, `cupertino_ui`). The framework copies are frozen and will be deprecated later. The `animations` package 3.0.0 already depends on `material_ui` and needs Flutter 3.44 / Dart 3.12. A new Render Watcher app should start on `material_ui`.

### Cited Findings
- Contributions to Material and Cupertino inside the framework were frozen, and exact replicas were published on pub.dev as `material_ui` 1.0.0 and `cupertino_ui` 1.0.0 (landed August 2026; blog post dated Sep 9, 2026). The framework copies will be deprecated and removed "at a future date", with no version given. Official Material 3 Expressive and Liquid Glass implementations are in progress. — [Flutter blog: Material and Cupertino decoupling are here](https://flutter.dev/blog/decoupling-material-cupertino)
- The packages can ship weekly, compared with Flutter's roughly 3-month stable cadence. Contributions opened to everyone on August 13, 2026. — [Flutter blog](https://flutter.dev/blog/decoupling-material-cupertino)
- Migration command: `dart fix --apply --code=migrate_design_widgets`. It adds `material_ui` and rewrites `package:flutter/material.dart` imports to `package:material_ui/material_ui.dart`. A `MaterialUiCompatibilityBridge` widget bridges ThemeData and MaterialLocalizations for third-party packages that still import the framework's material library. — [material_ui docs on pub.dev](https://pub.dev/documentation/material_ui/latest/)
- The flutter.dev site banner says "Flutter 3.47 made standalone design packages opt-in". This came from the site header, not the article body. — [Flutter blog page header](https://flutter.dev/blog/decoupling-material-cupertino)
- `animations` 3.0.0 (published by flutter.dev, about 2 months before Oct 2026): "Migrates to material_ui", minimum Flutter 3.44 / Dart 3.12. — [animations changelog](https://pub.dev/packages/animations/changelog)

### Inferences
- Pin Flutter at 3.44 or newer and adopt `material_ui` from day one. That avoids two migrations, and the `animations` 3.x package requires it anyway.
- Third-party UI packages such as skeletonizer and flutter_animate may still import `flutter/material.dart`. If theme lookups break, wrap them with `MaterialUiCompatibilityBridge`.
- M3 Expressive motion (spring-based motion tokens) is "in progress" in material_ui. Watch for spring motion-scheme APIs there. Until they arrive, hand-roll springs with `SpringDescription.withDurationAndBounce` (see section 3).

### Gaps
- I did not confirm the exact Flutter version in which the framework copies of material.dart will be marked `@Deprecated`. No date is given.
- I did not confirm whether `Easing` and `Durations` now live only in material_ui. Presumably both copies exist during the transition.

---

## 1. Motion patterns: the `animations` package (container transform, shared axis, fade through, fade)

### Takeaway
The flutter.dev-published `animations` package (3.0.0) provides the four Material motion patterns: container transform, shared axis, fade through and fade. Container transform (`OpenContainer`) is the right fit for alert card → alert detail. `SharedAxisTransition` fits the onboarding steps (sign-in → API key → pick services). `FadeThroughTransition` with `PageTransitionSwitcher` fits switching bottom-nav tabs.

### Cited Findings
- The package lists four patterns: Container transform, Shared axis, Fade through, Fade. Version 3.0.0, verified publisher flutter.dev. — [pub.dev animations](https://pub.dev/packages/animations)
- 2.2.0 added custom `closedShadows` and `openShadows` to `OpenContainer`. 2.1.1 clarified that `OpenContainer.onClosed` fires at the start of the closing transition, not the end. 2.1.0 made `OpenContainerState` public. 2.0.9 switched motion curves to the `Easing` class. 2.0.5 made OpenContainer use `Visibility` + `FadeTransition` instead of `Opacity`, which is a performance improvement. 2.0.0 added `routeSettings` and `filter` to `showModal`. — [animations changelog](https://pub.dev/packages/animations/changelog)
- Flutter's animation docs point to the pub.dev packages for container transforms, shared axis, fade through and fade transitions. They point to `Hero` for shared-element transitions between routes and to `AnimatedList` for animated insert/remove. — [docs.flutter.dev/ui/animations](https://docs.flutter.dev/ui/animations)

### Inferences (API shape from prior knowledge, **[unverified]** in this session; check the [API reference](https://pub.dev/documentation/animations/latest/))
- `OpenContainer<T>(closedBuilder: (ctx, openContainer) => AlertCard(...), openBuilder: (ctx, closeContainer) => AlertDetailPage(...), transitionType: ContainerTransitionType.fadeThrough /* or .fade */, closedColor:, openColor:, middleColor:, closedShape: RoundedRectangleBorder(...), closedElevation:, openElevation:, transitionDuration: (default 300ms), tappable: true, onClosed: (T? result) {...}, useRootNavigator:)`.
  - Dark theme tip: set `closedColor`, `openColor` and `middleColor` to your surface tokens, for example `surfaceContainerHigh` for the card and `surface` for the page. Otherwise the default white flashes during the transform, which is very visible on a dark UI.
- `SharedAxisTransition(animation:, secondaryAnimation:, transitionType: SharedAxisTransitionType.horizontal | vertical | scaled, fillColor:, child:)`. Use it inside a `PageTransitionSwitcher` (with `reverse: true` when going back) or inside a custom `PageRouteBuilder`.
- `FadeThroughTransition(animation:, secondaryAnimation:, fillColor:, child:)` with `PageTransitionSwitcher(duration:, transitionBuilder: (child, a, sa) => FadeThroughTransition(...), child: tabs[index])` for bottom-nav tab swaps. This is the Material-recommended swap for unrelated top-level destinations.
- `showModal(context:, configuration: FadeScaleTransitionConfiguration(), builder:)` gives fade-scale dialogs. Use it for "Confirm rollback/restart" action dialogs on alert detail.
- The package also exposes `SharedAxisPageTransitionsBuilder` and `FadeThroughPageTransitionsBuilder` for use in `PageTransitionsTheme`. Setting them app-wide would cost predictive-back route animations on Android (see section 2).

### Gaps
- I did not re-verify the full constructor signatures or default durations in 3.0.0.

---

## 2. Page routes: predictive back, Material vs Cupertino transitions, Hero, custom routes

### Takeaway
Since Flutter 3.38, Android's default `MaterialPageRoute` transition is `PredictiveBackPageTransitionsBuilder`, which falls back to `FadeForwardsPageTransitionsBuilder`. Keep that default for normal push routes. Opt in through the manifest. Use `PopScope` (not the deprecated `WillPopScope`). Use iOS's `CupertinoPageTransitionsBuilder` for swipe-back on iOS.

### Cited Findings
- The default Android page transition changed from `ZoomPageTransitionsBuilder` to `PredictiveBackPageTransitionsBuilder`. It landed in 3.37.0-0.0.pre and shipped in stable Flutter 3.38.0. To keep Zoom, set `PageTransitionsTheme(builders: {TargetPlatform.android: ZoomPageTransitionsBuilder()})`, but then you lose predictive-back route transitions. — [Breaking change: default Android page transition](https://docs.flutter.dev/release/breaking-changes/default-android-page-transition)
- `PredictiveBackPageTransitionsBuilder` follows the back gesture to reveal the destination route, and the user can cancel by dragging back. It is supported only on Android U (14) and above, and otherwise falls back to `FadeForwardsPageTransitionsBuilder`. Constructor option: `fallbackColor` (scrim). Sibling builders: `PredictiveBackFullscreenPageTransitionsBuilder`, `FadeForwardsPageTransitionsBuilder` (similar to the Android 16 transition), `ZoomPageTransitionsBuilder` (Android 10), `OpenUpwardsPageTransitionsBuilder` (Android 9), `FadeUpwardsPageTransitionsBuilder` (Android 8), `CupertinoPageTransitionsBuilder` (iOS horizontal). — [API: PredictiveBackPageTransitionsBuilder](https://api.flutter.dev/flutter/material/PredictiveBackPageTransitionsBuilder-class.html)
  - Conflict note: one search-result summary claimed the fallback is Zoom. The official API page states FadeForwards. Trust the API page.
- To enable predictive back, add `android:enableOnBackInvokedCallback="true"` on `<application>` in AndroidManifest (Android 13+). From Android 14 (API 34), predictive back system animations are on by default for apps that opt in. `PopScope(canPop:, onPopInvokedWithResult: (didPop, result) {...})` replaces the deprecated `WillPopScope`. — [docs: Add predictive back](https://docs.flutter.dev/platform-integration/android/predictive-back)

### Inferences
- Recommended theme:
  ```dart
  pageTransitionsTheme: const PageTransitionsTheme(builders: {
    TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
  }),
  ```
- Use `OpenContainer` only for the card → detail transform, and the theme default for all other pushes (audit timeline, settings). Mixing a custom `PageRouteBuilder` everywhere breaks the predictive-back peek on Android.
- Use `PopScope(canPop: false)` on the Mandate/Permissions editor when there are unsaved changes, and confirm with a fade-scale modal.
- Hero **[unverified API details]**: `Hero(tag: 'svc-${id}', child: ServiceAvatar())` on the overview list and on the service header in detail screens. Use `flightShuttleBuilder` to morph the status dot and color, and `createRectTween: (b, e) => MaterialRectCenterArcTween(begin: b, end: e)` for an arced path. Avoid Hero inside an `OpenContainer` that is already transforming the same element, because the two animations double up.
- Custom route for a "Live Logs" full-screen expand from a mini-player: use a `PageRouteBuilder(opaque: false, transitionDuration: Durations.medium4, pageBuilder:..., transitionsBuilder: ... SlideTransition + FadeTransition with Easing.emphasizedDecelerate)`, or better, no route at all (see the mini-player section).

### Gaps
- I did not verify whether `OpenContainer` routes participate in predictive back on Android 14+. Likely not, because it uses its own route.

---

## 3. Material 3 easing/duration tokens and spring physics

### Takeaway
Flutter has the `Easing` class (9 curves) and the `Durations` class (16 durations, short1–extralong4). Use them instead of magic numbers. For Uber-style natural, interruptible motion such as sheets, flings and the mini-player, use `SpringDescription.withDurationAndBounce` with `AnimationController.animateWith(SpringSimulation(...))`.

### Cited Findings
- `Easing` constants (all `const Curve`): `emphasizedAccelerate`, `emphasizedDecelerate`, `legacy`, `legacyAccelerate`, `legacyDecelerate`, `linear`, `standard`, `standardAccelerate`, `standardDecelerate`. — [API: Easing](https://api.flutter.dev/flutter/material/Easing-class.html)
- `Durations` constants: short1 50ms, short2 100ms, short3 150ms, short4 200ms; medium1 250ms, medium2 300ms, medium3 350ms, medium4 400ms; long1 450ms, long2 500ms, long3 550ms, long4 600ms; extralong1 700ms, extralong2 800ms, extralong3 900ms, extralong4 1000ms. — [API: Durations](https://api.flutter.dev/flutter/material/Durations-class.html)
- `SpringDescription` constructors: `SpringDescription({mass, stiffness, damping})` (const), `SpringDescription.withDampingRatio({mass, stiffness, ratio = 1.0})`, and factory `SpringDescription.withDurationAndBounce({duration = 500ms, bounce = 0.0})`. The `duration` and `bounce` getters are exposed. It is used to configure a `SpringSimulation`. — [API: SpringDescription](https://api.flutter.dev/flutter/physics/SpringDescription-class.html)
- For physics-based animation, the docs recommend `AnimationController.animateWith` with `SpringSimulation` (cookbook: "Animate using a physics simulation"). — [docs.flutter.dev/ui/animations](https://docs.flutter.dev/ui/animations)
- The `animations` package migrated its curves to `Easing` in 2.0.9. — [animations changelog](https://pub.dev/packages/animations/changelog)

### Inferences
- Note: Flutter does not ship a separate `Easing.emphasized` constant. M3's "emphasized" curve is a threePointCubic that Flutter exposes as `Curves.easeInOutCubicEmphasized` **[unverified in this session]**. Use it for container transforms and large-surface movement.
- Suggested token mapping for Render Watcher:
  - Micro (chip select, toggle, icon morph): `Durations.short4` + `Easing.standard`
  - Card expand, list insert: `Durations.medium2`–`medium4` + `Easing.emphasizedDecelerate` (enter) / `Easing.emphasizedAccelerate` (exit, shorter, e.g. `short4`)
  - Full-screen transforms: `Durations.long2` + `Curves.easeInOutCubicEmphasized`
  - Sheets and mini-player drag release: spring `SpringDescription.withDurationAndBounce(duration: Duration(milliseconds: 350), bounce: 0.15)`. Pass the drag's release velocity into `SpringSimulation(spring, from, to, velocity)` so motion continues the finger's momentum. This is the Uber feel.
  - Confidence meter fill: `TweenAnimationBuilder<double>` with `Durations.long2` and `Easing.emphasizedDecelerate`, with a slight bounce spring for critical (>90%).

### Gaps
- I did not confirm whether material_ui has added M3 Expressive "motion scheme" (spatial/effects springs) tokens yet. The blog says only that it is in progress.

---

## 4. Bottom sheets (Uber-style), hide-on-scroll app bar and chips (YouTube-style), mini-player

### Takeaway
Use `DraggableScrollableSheet` with `snap: true` and `snapSizes` for the Uber-style service sheet on the overview. Use `SliverAppBar(floating: true, snap: true)` with a chip row in `bottom` for YouTube-style hide-on-scroll on the Alerts and Logs lists.

### Cited Findings
- `DraggableScrollableSheet`: defaults are `initialChildSize` 0.5, `minChildSize` 0.25, `maxChildSize` 1.0 (fractions of parent height). The builder **must** use the provided `ScrollController`, otherwise the sheet stays at its initial size. `snap: true` snaps between min and max on release. `snapSizes` adds intermediate points. Snapping does **not** apply to programmatic `DraggableScrollableController.animateTo`/`jumpTo`. `expand` defaults to true. Other properties: `snapAnimationDuration`, `shouldCloseOnMinExtent` (default true). Mouse drag needs `PointerDeviceKind.mouse` added to `ScrollBehavior.dragDevices`. — [API: DraggableScrollableSheet](https://api.flutter.dev/flutter/widgets/DraggableScrollableSheet-class.html)
- `SliverAppBar`: `floating` shows the bar as soon as the user scrolls toward it. `pinned` keeps it visible at the top. `snap` is only valid when `floating` is true and snaps the bar fully into view. `stretch` with `stretchTriggerOffset` (default 100.0) and `onStretchTrigger` supports stretch on overscroll. `SliverAppBar.medium`/`.large` default to `pinned: true`. `bottom` takes a `PreferredSizeWidget`. `scrolledUnderElevation` and `forceMaterialTransparency` are available. — [API: SliverAppBar](https://api.flutter.dev/flutter/material/SliverAppBar-class.html)

### Inferences
- **Overview (Uber pattern):** service map/health grid behind, with `DraggableScrollableSheet(snap: true, minChildSize: 0.12, snapSizes: [0.12, 0.45], maxChildSize: 0.92, controller: _sheetCtrl, builder: (ctx, sc) => CustomScrollView(controller: sc, slivers: [...]))`.
  - Peek state (0.12) shows a "3 services healthy · 1 degraded" summary pill, like Uber's "Choose a ride" peek. Mid state (0.45) shows the service list. Expanded shows full service detail.
  - Use `_sheetCtrl.animateTo(0.45, duration: Durations.medium4, curve: Easing.emphasizedDecelerate)` when a new alert arrives. Snap does not apply to programmatic moves, so target an exact snap size.
  - Fire `HapticFeedback.selectionClick()` on each snap. Detect snaps with a `NotificationListener<DraggableScrollableNotification>` crossing snap thresholds **[unverified notification class name]**.
  - A drag handle, a 28dp top radius, and an `AnimatedContainer` that animates the corner radius to 0 at max extent give the sheet a "becomes a page" feel.
- **Alerts and Logs (YouTube pattern):** `CustomScrollView` with `SliverAppBar(floating: true, snap: true, bottom: PreferredSize(child: ChipFilterRow))`. Chips: All / Critical / Warning / Resolved for alerts. Chips: service, level (ERROR/WARN/INFO) and "Agent-flagged" for logs. Use `FilterChip`/`ChoiceChip` with `HapticFeedback.selectionClick()`. Keep chips in `bottom` so they hide with the bar, as on YouTube, or use `pinned: true` plus a floating chip header if chips must persist.
  - Also hide the `NavigationBar` on scroll down. Listen to `UserScrollNotification.direction` and drive an `AnimatedSlide(offset: hidden ? Offset(0, 1) : Offset.zero, duration: Durations.medium2, curve: Easing.standard)`.
  - Chip change → list content swap: use `AnimatedSwitcher` or `PageTransitionSwitcher` + `FadeThroughTransition` keyed by the filter value.
- **Mini "live log" player (YouTube mini-player):** a persistent overlay above the `NavigationBar` inside a root `Stack` (or a shell route, e.g. go_router `StatefulShellRoute`). It shows a 2-line live tail, the service name, a pulsing "LIVE" dot, and pause/close buttons.
  - Expansion: a single `AnimationController` (0 = mini, 1 = full) driven by vertical drag (`GestureDetector.onVerticalDragUpdate` → `controller.value -= dy / maxHeight`). On release, `controller.animateWith(SpringSimulation(spring, value, target, velocity))`. Interpolate height, corner radius and the cross-fade between the compact row and the full log view from that controller. Don't push a route, so the stream subscription survives tab changes.
  - Swipe down from full collapses to mini. Swipe the mini sideways to dismiss (`Dismissible`).
  - Back handling: wrap the full state in `PopScope(canPop: !expanded, onPopInvokedWithResult: ... collapse)` so Android back collapses instead of exiting.

### Gaps
- I did not verify the `NestedScrollView` + floating SliverAppBar interaction (`SliverOverlapAbsorber` and `floatHeaderSlivers`). Needed only if you use tabs with separate scroll positions.

---

## 5. Implicit animations, AnimatedSwitcher, AnimatedList for streaming logs, flutter_animate

### Takeaway
Use implicit widgets (`AnimatedContainer`, `AnimatedSwitcher`, `TweenAnimationBuilder`) for state changes. Use `SliverAnimatedList` driven by a `GlobalKey` to animate new log lines in. Use `flutter_animate` (4.5.2) for declarative entrance and stagger effects. Gate all of these behind reduce-motion checks.

### Cited Findings
- Flutter's taxonomy: pre-packaged implicit animations; custom implicit via `TweenAnimationBuilder`; built-in explicit transitions; custom explicit via `AnimatedBuilder`/`AnimatedWidget`. Staggered animations are documented separately. — [docs.flutter.dev/ui/animations](https://docs.flutter.dev/ui/animations)
- `SliverAnimatedList` is a `SliverList` that animates inserts and removals. State is reached via a `GlobalKey<SliverAnimatedListState>` or `SliverAnimatedList.of`. It takes `itemBuilder`, `findChildIndexCallback` and `initialItemCount` (default 0). Related widgets: `AnimatedList`, `SliverAnimatedGrid`, `AnimatedGrid`. — [API: SliverAnimatedList](https://api.flutter.dev/flutter/widgets/SliverAnimatedList-class.html)
- `flutter_animate` 4.5.2 (published about 23 months before Oct 2026, so likely late 2024): `.animate()` extension with chainable effects (`fade()`, `scale()`, etc.). `delay`/`duration`/`curve` inherit from the previous effect. `ThenEffect` sequences effects. `AnimateList` with `interval` staggers. `ScrollAdapter` ties progress to a `ScrollController`. `Animate.restartOnHotReload`. Includes a shimmer effect. The page doesn't document reduce-motion support. — [pub.dev flutter_animate](https://pub.dev/packages/flutter_animate)

### Inferences
- **Streaming log lines:** throttle inserts. Render Render's log stream can exceed 60 lines/sec, and animating each insert would jank.
  - Batch incoming lines every ~100–250ms, call `insertAllItems(0, n, duration: Durations.short4)` **[unverified method signature]**, and use `SizeTransition` + `FadeTransition` in `itemBuilder`.
  - Cap the buffer (e.g. 2,000 lines) and `removeItem` from the tail with a zero-duration builder.
  - When the user has scrolled up ("paused tail"), stop animating inserts and show a "↓ 37 new lines" pill (YouTube-comments style) that jumps to live on tap.
  - Use a monospaced font with fixed `itemExtent`/`prototypeItem` if you switch to a plain `SliverList` at high throughput. That avoids layout cost.
- `AnimatedSwitcher` for: status badge text (Healthy → Degraded), the alert count number (pair with `transitionBuilder` slide-up for a counter "tick"), and the connect-API-key button states (idle → spinner → check).
- `flutter_animate` for: staggered entrance of overview service cards (`.animate(interval: 40.ms).fadeIn(duration: 250.ms).slideY(begin: 0.08, curve: Easing.emphasizedDecelerate)`), a shake on invalid API key (`.shakeX()`), and a pulse on the LIVE dot. Check `MediaQuery.disableAnimationsOf(context)` yourself and skip effects, because the package page doesn't document reduce-motion handling. flutter_animate hasn't been updated in about 2 years, so confirm it works with material_ui and Flutter 3.44+ before committing.
- Confidence meter: `TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: confidence), duration: Durations.long2, curve: Easing.emphasizedDecelerate, builder: (_, v, __) => CustomPaint(painter: ArcPainter(v)))`. Wrap it in `RepaintBoundary`. Color-lerp green → amber → red.

### Gaps
- I did not verify the `insertAllItems` signature or the removal-builder behavior on the SliverAnimatedListState page.

---

## 6. Skeleton loading, shimmer, Rive/Lottie micro-interactions

### Takeaway
`skeletonizer` 3.0.0 turns real layouts into skeletons with `Skeletonizer(enabled: loading)`. It is the best fit for "connect API key → fetching services". `rive` 0.14.x (built on `rive_native`) suits interactive state-machine micro-interactions. Lottie suits one-shot illustrations.

### Cited Findings
- skeletonizer 3.0.0 (MIT, codeness.ly): `Skeletonizer(enabled: _loading, child: ...)` and `Skeletonizer.sliver`. Supply fake data (e.g. `BoneMock`). Annotations: `Skeleton.ignore`, `keep`, `leaf`, `shade`, `replace`, `unite`, `ignorePointers`. Manual zones: `Skeletonizer.zone` with `Bone.circle`/`Bone.text`/`Bone.icon`/`Bone.button`. Effects: `ShimmerEffect`, `PulseEffect`, `SoldColorEffect` (sic). Global theming via `SkeletonizerConfig`/`SkeletonizerConfigData` with dark-mode support. Switch animation between skeleton and content is available, but not for slivers. `BoneResolver` matches button bones to themes. — [pub.dev skeletonizer](https://pub.dev/packages/skeletonizer)
- rive 0.14.11 is the latest stable (0.15.0-dev.3 is prerelease). Load with `File.asset(..., riveFactory: Factory.rive | Factory.flutter)`, choosing the Rive renderer or Flutter's (Impeller/Skia) renderer per file. The legacy runtime's last pub release was `rive: 0.13.20`. Most runtime code is now in `rive_native`, whose prebuilt native libraries download on build (`dart run rive_native:setup`). — [pub.dev rive](https://pub.dev/packages/rive)

### Inferences
- Configure `SkeletonizerConfig` with dark-surface colors (`baseColor: surfaceContainerHigh`, `highlightColor: surfaceContainerHighest`). The default light-grey shimmer looks wrong on a dark theme.
- Prefer `PulseEffect` for the dark theme and for reduce motion. A sweeping shimmer is more distracting on dark backgrounds. Switch to `SoldColorEffect` (no motion) when animations are disabled.
- Use Rive for: an animated "agent watching" eye or radar on the overview header (a state machine with idle/scanning/alert states driven by data binding), a bell-ring on new alert, and the pause/play morph on the mini-player. Rive 0.14 is a new API, so old `RiveAnimation.asset` tutorials are outdated **[unverified whether RiveAnimation was removed]**.
- Use Lottie (`lottie` package **[version not verified]**) only for empty states ("No alerts — all clear") and success after connecting the API key.
- The `shimmer` package is largely superseded by skeletonizer's `ShimmerEffect` and flutter_animate's `.shimmer()`. I did not check its maintenance status.

### Gaps
- I did not fetch the `shimmer` or `lottie` pub.dev pages, so their current versions and maintenance status are unknown.

---

## 7. Haptics

### Takeaway
`HapticFeedback` now includes semantic notification haptics (`successNotification`, `warningNotification`, `errorNotification`) alongside impact and selection haptics. They map directly onto alert severity.

### Cited Findings
- `HapticFeedback` static methods (all `Future<void>`): `errorNotification()`, `heavyImpact()`, `lightImpact()`, `mediumImpact()`, `selectionClick()`, `successNotification()`, `vibrate()`, `warningNotification()`. — [API: HapticFeedback](https://api.flutter.dev/flutter/services/HapticFeedback-class.html)

### Inferences
- Mapping:
  - Critical alert arriving in the foreground: `errorNotification()`
  - Warning: `warningNotification()`
  - Action succeeded (restart/rollback triggered, API key verified): `successNotification()`
  - Chip and segment changes, sheet snaps: `selectionClick()`
  - Long-press on a log line to copy: `mediumImpact()`
  - Confirm a destructive action (e.g. a mandate granting deploy rights): `heavyImpact()`
- Debounce haptics during alert storms (at most 1 per ~2s) to avoid a buzzing phone.

### Gaps
- I did not verify which Flutter version added the `*Notification` haptics or how they map on Android (likely `HapticFeedbackConstants.CONFIRM`/`REJECT` on API 30+).

---

## 8. Push notifications with action buttons; Live Activities equivalents

### Takeaway
Send FCM **data** messages, or notification messages handled at the app level. Render them with `flutter_local_notifications` (22.3.2) so you can attach action buttons: `AndroidNotificationAction` on Android and `DarwinNotificationCategory`/`DarwinNotificationAction` on iOS. Handle background taps with an `@pragma('vm:entry-point')` top-level handler. For a "live incident" surface, `live_activities` (2.6.0) covers iOS Live Activities and Dynamic Island, and Android support (RemoteViews) is beta.

### Cited Findings
- flutter_local_notifications 22.3.2 is the latest stable (23.0.0-dev.4 is prerelease) and needs Flutter 3.38.1 or newer.
  - Android actions: `AndroidNotificationAction('id', 'title')` on `AndroidNotificationDetails`. The callback runs on the main isolate when `showsUserInterface` is set.
  - iOS/macOS actions: defined on a `DarwinNotificationCategory` using `DarwinNotificationAction.plain`. The `foreground` option brings the app forward.
  - Callbacks: `onDidReceiveNotificationResponse` (app running) and `onDidReceiveBackgroundNotificationResponse` (separate isolate; top-level/static function with `@pragma('vm:entry-point')`). iOS needs `setPluginRegistrantCallback` in AppDelegate.
  - Android 13+ permission: call `requestNotificationsPermission()`. Since v16 the manifest declares only `POST_NOTIFICATIONS` and `VIBRATE`.
  - Full-screen intent: `USE_FULL_SCREEN_INTENT` permission, `showWhenLocked`/`turnScreenOn`, and `requestFullScreenIntentPermission()`. Treated as a tap.
  - Channel sound and vibration are fixed when the channel is first created. — [pub.dev flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)
- FCM Flutter client: `requestPermission(provisional: true)` supports iOS provisional authorization. Handle interaction via `getInitialMessage()` (terminated) and `onMessageOpenedApp` (background). — [Firebase: FCM Flutter client](https://firebase.google.com/docs/cloud-messaging/flutter/client)
- live_activities 2.6.0 (about 42 days before capture):
  - iOS requirements: iOS 16.1+ (16.2+ for `relevanceScore`, 17.2+ for push-to-start), a Swift Widget Extension, App Groups on both targets, Push Notifications capability, `NSSupportsLiveActivities`, and attributes named `LiveActivitiesAppAttributes`.
  - Updates while backgrounded or killed need APNs pushes using the activity token from `activityUpdateStream`.
  - Android uses RemoteViews on API 24+ with a Kotlin `LiveActivityManager`, and is described as "beta".
  - API: `createActivity`, `updateActivity`, `endActivity`, `createOrUpdateActivity`, `pushToStartTokenUpdateStream`, `urlSchemeStream`. — [pub.dev live_activities](https://pub.dev/packages/live_activities)
- `live_activity_kit` 1.1.x claims support for Android 16 "Live Updates" (promoted ongoing notifications, ProgressStyle) plus iOS Live Activities. I saw this only in search snippets and did not fetch its page. — [pub.dev live_activity_kit](https://pub.dev/packages/live_activity_kit)

### Inferences
- Alert notification design:
  - Android channel `critical_alerts` (Importance.max, custom sound) and `info` (default). Create channels once at startup, because sound can't be changed later.
  - Actions: **Acknowledge** (background, `showsUserInterface: false`, POSTs an ack to your backend from the background isolate), **Restart service** (`showsUserInterface: true`, opens the confirm sheet, because destructive actions shouldn't run blind from a notification; ties into mandate permissions), **View logs** (deep-links to the alert detail and evidence logs).
  - On iOS, register a `DarwinNotificationCategory('ALERT', actions: [...])` and send FCM payloads with `apns.payload.aps.category = 'ALERT'`. Use `interruption-level: time-sensitive` for critical alerts **[unverified flutter_local_notifications field name; APNs payload key is standard]**.
- Foreground: listen to `FirebaseMessaging.onMessage`. Instead of a system banner, show an in-app animated banner (slide-down `AnimatedSlide` + `errorNotification()` haptic) and badge-bump the Alerts tab.
- Live Activity equivalent: while an incident is "Investigating", show a Live Activity or Dynamic Island with the service name, severity color, agent confidence %, and elapsed time. End it on resolve. On Android, use an ongoing notification with progress, or Android 16 Live Updates via live_activity_kit if verified.

### Gaps
- `firebase_messaging` version and the details of data-only background delivery on iOS (content-available throttling) were not verified. The FCM page fetched covered only permission and interaction.
- I did not verify `live_activity_kit` beyond search snippets.

---

## 9. Performance (60/120fps) and Impeller

### Takeaway
Impeller is the only renderer on iOS and the default on Android API 29+ (Vulkan, with an OpenGL fallback). Budget 8ms per frame for 120Hz devices. Avoid `Opacity` and `saveLayer` in animations, use `AnimatedBuilder`'s `child`, build lists lazily, and profile in profile mode.

### Cited Findings
- iOS: Impeller only, no Skia switch. Android: Impeller default on API 29+ since Flutter 3.27, with fallback to the legacy OpenGL renderer on lower API levels or devices without Vulkan. Android opt-out: `--no-enable-impeller`, or manifest meta-data `io.flutter.embedding.android.EnableImpeller=false`. Desktop Impeller is default as of 3.47, and its opt-out will be removed in the future. Web still uses Skia. — [docs: Impeller](https://docs.flutter.dev/perf/impeller)
- If only the first run of an animation janks, ensure Impeller is enabled. Profile in profile mode and use the DevTools Performance view. Use lazy lists. — [docs: Rendering performance](https://docs.flutter.dev/perf/rendering-performance)
- Best practices:
  - `saveLayer` is expensive (offscreen buffer, render-target switch). It can be triggered by `ShaderMask`, `ColorFilter`, `Chip` (when `disabledColorAlpha != 0xff`) and `Text` with `overflowShader`. Detect it with `checkerboardOffscreenLayers`.
  - Avoid the `Opacity` widget in animations. Use `AnimatedOpacity`/`FadeTransition`, or semi-transparent colors.
  - Avoid clipping during animation and use `borderRadius` instead of clip widgets.
  - Pass static subtrees as `AnimatedBuilder`'s `child`.
  - Avoid intrinsic passes. Use `ListView.builder`.
  - At 60Hz, aim for 8ms build + 8ms render. 120fps requires <8ms total.
  - Localize `setState`. Avoid overriding `operator ==` on widgets. — [docs: Performance best practices](https://docs.flutter.dev/perf/best-practices)

### Inferences
- Put a `RepaintBoundary` around: the live log list (repaints constantly), the pulsing LIVE dot, the confidence meter `CustomPaint`, the Rive/radar header, and the mini-player. This isolates per-frame repaints from the rest of the screen. Verify with DevTools "Highlight repaints".
- The log stream should update through a `ValueNotifier`/stream scoped to the list, not via `setState` on the screen.
- Blur (glassy app bars over logs) is a `saveLayer`/`BackdropFilter` cost. On a dark theme, prefer solid `surfaceContainer` with `scrolledUnderElevation` tint.
- Chips: be aware of the `Chip` saveLayer case for disabled alpha. Keep disabled chip colors opaque.

### Gaps
- I did not verify Flutter guidance specific to high-refresh-rate Android (e.g. whether the engine requests 120Hz automatically on all OEMs).

---

## 10. Accessibility: reduce motion

### Takeaway
Use `MediaQuery.disableAnimationsOf(context)` (Android "Remove animations") **and** check iOS Reduce Motion separately via `PlatformDispatcher.instance.accessibilityFeatures.reduceMotion`. On iOS the reduce-motion setting does not set `disableAnimations`.

### Cited Findings
- `MediaQueryData.disableAnimations` reports whether the platform asks for animations to be disabled or reduced. On Android it maps to "Remove animations". On iOS, reduced motion is exposed separately via `dart:ui` `AccessibilityFeatures.reduceMotion` and does not set this flag. The value comes from `PlatformDispatcher.accessibilityFeatures` through `SemanticsBinding`. Framework APIs like `AnimationController` read it, and a `MediaQuery` override won't change framework animations. Custom animations should check it and shorten or skip non-essential motion. — [API: MediaQueryData.disableAnimations](https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html)

### Inferences
- Helper:
  ```dart
  bool reduceMotion(BuildContext c) =>
      MediaQuery.disableAnimationsOf(c) ||
      View.of(c).platformDispatcher.accessibilityFeatures.reduceMotion;
  ```
- With reduce motion on:
  - Replace container transform and shared axis with a plain cross-fade (`Durations.short3`).
  - Disable stagger, shimmer (use `SoldColorEffect`), the pulsing LIVE dot (use a static dot with a "LIVE" label), log-line insert animation, and spring bounce (use `bounce: 0`).
  - Keep haptics, which aren't motion, but respect the system haptics setting.
- Also: semantic labels on severity colors (don't rely on red/green alone). Use `Semantics(liveRegion: true)` for new critical alert banners. Keep the confidence meter readable as text ("Confidence 87%").

### Gaps
- I did not confirm whether `MediaQuery.disableAnimationsOf` exists as an aspect-specific accessor in the current release. It has been present since Flutter 3.10 **[unverified this session]**.

---

## 11. Screen-by-screen mapping summary (synthesis)

### Takeaway
One primary motion idea per screen, built on tokens and springs, with reduce-motion fallbacks. The cited APIs above support every item.

### Cited Findings
- (See sections 1–10 for sources. This section is synthesis only.)

### Inferences
| Screen | Pattern (inspiration) | Flutter implementation |
|---|---|---|
| Sign in | Calm hero intro (Uber splash) | Rive/flutter_animate fade+slide of logo. `SharedAxisTransition.horizontal` to the next step |
| Connect API key | Step flow + skeleton (Uber onboarding) | `PageTransitionSwitcher` + `SharedAxisTransition`. Button `AnimatedSwitcher` (idle→spinner→check) + `successNotification()`. `shakeX` + `errorNotification()` on invalid key |
| Pick services | Selectable list | `Skeletonizer(enabled: loading)` while fetching. `CheckboxListTile` with `AnimatedContainer` selection tint. Sticky "Watch N services" CTA sliding up via `AnimatedSlide` |
| Overview | Uber map + draggable sheet | Health grid/radar backdrop. `DraggableScrollableSheet(snap: true, snapSizes:[peek, mid])`. Staggered card entrance. Hero on service avatars |
| Alerts list | YouTube feed: hide-on-scroll bar + chips | `SliverAppBar(floating: true, snap: true, bottom: chips)`. Nav bar hides on scroll. `OpenContainer` cards. "N new alerts" pill |
| Alert detail | Container transform (Material) | `OpenContainer` from card. Animated confidence arc (`TweenAnimationBuilder`). Evidence logs in `SliverAnimatedList`. Action buttons → `showModal` fade-scale confirm. `PopScope` |
| Live logs | YouTube mini-player + live chat | Persistent mini-player above nav (spring-driven expand). Batched `SliverAnimatedList` inserts. "Jump to live" pill. `RepaintBoundary` |
| Audit timeline | Uber trip timeline | `SliverList` with a timeline rail `CustomPaint`. Entries fade/slide in via flutter_animate `AnimateList` with small `interval`. Hero to entry detail |
| Mandate/permissions | Settings with safety | `SwitchListTile` + `heavyImpact()` on granting high-risk permissions. `PopScope(canPop: !dirty)`. `AnimatedSize` expanding permission explanations |
| Push notifications | Actionable alerts / Live Activity | flutter_local_notifications actions (Ack / Restart / View logs). iOS category. Live Activity for active incidents via `live_activities` |

### Gaps
- No primary source documents Uber or YouTube internal motion specs. The mapping is design synthesis, not sourced from either company.
