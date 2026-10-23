# Borrow Uber's sheets, YouTube's player, Material's clock

Render Watcher should take three things from three sources. From Uber it takes the structure: progressive disclosure, a map-plus-draggable-sheet layout, and information ranked by what a person glances at first. From YouTube it takes chrome and gestures: filter chips under a bar that hides on scroll, a persistent mini-player that drags out to full screen, grouped pill actions, and delight saved for a few frequent moments. From Material Design 3 it takes the motion: published duration, easing and spring tokens that Flutter exposes directly. Neither company publishes mobile motion specs. The only hard Uber numbers come from the open-source Base Web theme, and YouTube's specifics come from its blog and tech press, so any exact timing in this report is either an M3 or Base token or a labelled estimate. The resulting design keeps Render Watcher's near-black #07080C, violet and Inter/JetBrains Mono identity. It adopts Uber's value-based dark surface ramp and desaturated status colors, and YouTube's rule that the brand accent appears only on progress and key calls to action. Each screen gets one main motion idea: a shared-axis onboarding, a container transform from alert card to alert detail, a spring-driven sheet on the overview, and a live-log mini-player that persists across tabs. The 2026 Flutter stack (`material_ui`, `animations` 3.0, `SpringDescription`, `HapticFeedback` notification haptics, `skeletonizer`) can build all of it without custom engines.

## Only token sheets are documented; the "feel" is inferred

The most important fact for this redesign is what does not exist. Uber's mobile Base documentation at base.uber.com would not render, and **no public source gives Uber's bottom-sheet snap points, drag velocities, haptic patterns or skeleton timing**. Uber's Live Activity engineering post explicitly leaves out animation ([Uber Blog](https://www.uber.com/blog/live-activity-on-ios/)). YouTube's case is similar: it documents behaviors, not values. Its October 2025 refresh brought a feed that "slides up" on tab switch, a "more subtle and compact" double-tap seek, content-aware Like animations, translucent rounded pill controls, and a player that no longer darkens on pause ([9to5Google](https://9to5google.com/2025/10/23/youtube-video-player-icon-redesign-rollout/)). Durations and curves are not published. The redesign therefore builds on three hard sources and labels everything else as an estimate.

The first hard source is **Base Web**, which Uber calls the Base Design System "translated into code" ([Uber Blog](https://www.uber.com/blog/introducing-base-web)). Its theme files give durations from 100 to 7000 ms and five named curves ([baseweb animation.ts](https://raw.githubusercontent.com/uber/baseweb/main/src/themes/shared/animation.ts)):

| Curve | cubic-bezier | Uber's own description |
|---|---|---|
| easeDecelerate | (0.22, 1, 0.36, 1) | Entering elements |
| easeAccelerate | (0.64, 0, 0.78, 0) | Exiting elements |
| easeAccelerateDecelerate | (0.83, 0, 0.17, 1) | "A good default for most motion" |
| easeResponsiveAccelerate | (0.11, 0, 0.5, 0) | Responsive feel at short durations |
| linear | (0, 0, 1, 1) | Opacity and color changes |

Base's other foundations describe the "Uber look":

- **Spacing:** a 2–192 px scale built mostly on 4 px steps ([sizing.ts](https://raw.githubusercontent.com/uber/baseweb/main/src/themes/shared/sizing.ts)).
- **Radii:** 8 px on buttons, inputs and popovers, and 24 px pill tags ([borders.ts](https://raw.githubusercontent.com/uber/baseweb/main/src/themes/shared/borders.ts)).
- **Type:** headings at bold 700, UI labels at 500 with tight line-height, paragraphs at 400 with loose line-height ([typography.ts](https://raw.githubusercontent.com/uber/baseweb/main/src/themes/shared/typography.ts)).
- **Dark mode:** a neutral ramp (#161616, #292929, #383838), secondary text at #C4C4C4, and accents desaturated for dark backgrounds: negative #DE5B5D, positive #5C9D70, warning #AE8523. Hover and pressed states are white overlays at 10% and 15% instead of shadows ([dark semantic tokens](https://raw.githubusercontent.com/uber/baseweb/main/src/themes/dark-theme/color-semantic-tokens.ts)).

The second hard source is **Material Design 3**, the system YouTube's Android app builds on. AndroidX source gives exact values ([MotionTokens.kt](https://raw.githubusercontent.com/androidx/androidx/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/MotionTokens.kt)):

- **Durations:** 16 steps from 50 to 1000 ms.
- **Standard easing:** (0.2, 0, 0, 1).
- **Emphasized decelerate:** (0.05, 0.7, 0.1, 1).
- **Emphasized accelerate:** (0.3, 0, 0.8, 0.15).

M3 Expressive adds springs, given as damping ratio and stiffness. The standard scheme is FastSpatial 0.9/1400 for buttons and switches, **DefaultSpatial 0.9/700 for bottom sheets**, and SlowSpatial 0.9/300 for full-screen motion ([StandardMotionTokens.kt](https://raw.githubusercontent.com/androidx/androidx/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/StandardMotionTokens.kt)). The bouncier expressive scheme uses 0.6/800, 0.8/380 and 0.8/200 ([ExpressiveMotionTokens.kt](https://raw.githubusercontent.com/androidx/androidx/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/ExpressiveMotionTokens.kt)).

Material also defines which transition pattern fits which relationship ([MDC-Android Motion.md](https://raw.githubusercontent.com/material-components/material-components-android/master/docs/theming/Motion.md)):

- **Container transform:** card to detail.
- **Shared axis:** steps in a sequence.
- **Fade through:** unrelated destinations such as bottom-nav tabs.
- **Fade:** dialogs and snackbars, 150 ms in and 75 ms out.

One conflict needs resolving. That same Material doc lists 300 ms defaults for container transform, which is a legacy M2 value. This report uses the M3-era range of 300–500 ms.

Base and M3 broadly agree. Both use a decelerating curve on entry, a shorter accelerating curve on exit, linear for opacity, and longer durations for larger moves. **Use M3 tokens as Render Watcher's primary vocabulary**, because Flutter ships them as `Easing` and `Durations` constants ([Easing](https://api.flutter.dev/flutter/material/Easing-class.html); [Durations](https://api.flutter.dev/flutter/material/Durations-class.html)). Use Base's guidance to decide where each token goes.

## A token sheet that keeps violet rare and black truly black

Render Watcher's #07080C is darker than YouTube's reported #0F0F0F, which comes from a third party, not YouTube ([YouTube colors](https://finalcutplugins.gumroad.com/l/youtube-colors)). It is also darker than Base's #161616. That suits the direction both companies took: YouTube made its dark theme "darker so colors pop" in 2022 ([YouTube Blog](https://blog.youtube/news-and-events/an-updated-look-and-feel-for-youtube/)). The lesson from both is to **create hierarchy with steps in value, not with hue or shadow**. Black shadows are invisible on near-black, which is why Base's dark theme uses white overlays for interaction states. YouTube shows the same principle: selected chips are inverted and its 2022 Subscribe button is a high-contrast black-and-white pill.

The accent rule comes from YouTube's 2024 brand refresh, which confined its red-to-magenta gradient to the progress bar, Like, Subscribe and Premium badges ([Design Rush](https://news.designrush.com/youtube-subtle-brand-refresh-brings-new-colors-and-smoother-experience)). Render Watcher should treat violet the same way. Violet marks the agent: its confidence arc, its live indicator, the one primary action on a screen, and the selected tab. It should never fill large surfaces.

The surface hexes below are this report's proposed values, extrapolated from Base's step sizes with a slight cool-violet tint to match #07080C. They are not sourced from either company. The severity colors are Base's dark-mode values.

| Token | Value | Use |
|---|---|---|
| `bg` | #07080C | Scaffold, full-screen log view |
| `surface1` | #0F1117 (proposed) | Cards, nav bar, sheets at rest |
| `surface2` | #171A23 (proposed) | Raised sheet, unselected chips, skeleton base |
| `surface3` | #21252F (proposed) | Pressed state, skeleton highlight, dividers |
| `overlayHover` / `overlayPress` | white 10% / 15% | Interaction tints, from Base dark |
| `accent` / `accentStrong` | #8B5CF6 / #7445E6 | Agent indicators, text accent / filled primary button |
| `critical` / `warning` / `ok` | #DE5B5D / #AE8523 / #5C9D70 | Severity, from Base's desaturated dark accents |
| Type | Inter 700 headings, 500 labels, 400 body; JetBrains Mono for logs, IDs, timestamps | Mirrors Base's Display/Text split |
| Radius | 8 control · 12–16 card · 28 sheet top · pill chips | Base radii; sheet radius is an inference |

Motion tokens map onto Flutter APIs as follows. The spring values are M3's own, so Render Watcher can use them exactly instead of estimating.

| Role | Token | Flutter |
|---|---|---|
| Press, chip select, toggle | 200 ms, standard | `Durations.short4`, `Easing.standard` |
| Element enter (cards, banners, list insert) | 300–400 ms, emphasized decelerate | `Durations.medium2–medium4`, `Easing.emphasizedDecelerate` |
| Element exit | 200 ms, emphasized accelerate | `Durations.short4`, `Easing.emphasizedAccelerate` |
| Container transform, full-screen change | 450–500 ms, emphasized | `Durations.long2`, `Curves.easeInOutCubicEmphasized` (Flutter name unverified) |
| Snackbar, dialog fade | 150 in / 75 out, linear | `Durations.short3`, `Easing.linear` |
| Sheet and mini-player release | spring ζ 0.9, k 700 | `SpringDescription.withDampingRatio(mass: 1, stiffness: 700, ratio: 0.9)` |
| Buttons, toggles | spring ζ 0.9, k 1400 | same constructor |
| Color and opacity "effects" | spring ζ 1.0, k 1600 (no overshoot) | same constructor |

`SpringDescription.withDampingRatio` and `withDurationAndBounce` are both available in Flutter ([SpringDescription](https://api.flutter.dev/flutter/physics/SpringDescription-class.html)), so the M3 damping and stiffness pairs go in unchanged.

Haptics map onto the semantic notification methods that `HapticFeedback` exposes ([HapticFeedback](https://api.flutter.dev/flutter/services/HapticFeedback-class.html)):

- **Critical alert:** `errorNotification`.
- **Warning:** `warningNotification`.
- **Verified or remediated:** `successNotification`.
- **Snaps and chip changes:** `selectionClick`.
- **Granting a high-risk mandate:** `heavyImpact`.

During alert storms, allow at most one haptic every two seconds. That debounce is a design rule, not a documented pattern from either company.

## Screen by screen: one dominant motion idea each

### Sign in, connect API key, pick services as one shared-axis journey

Uber's foundational 2016 move was to replace a busy home with a single question, "Where to?", and defer every other choice until it was answered ([Uber Newsroom](https://www.uber.com/us/en/newsroom/newriderapp/)). Onboarding should follow the same rule: **each screen asks one thing**.

**Sign in** has a large Inter 700 headline at roughly Base's HeadingLarge size (32/40) and one full-width primary button, 48–56 px tall with an 8 px radius in #7445E6. Secondary providers sit below it as text buttons. An optional Rive "agent eye" idles above the headline.

**Connect API key** has a single JetBrains Mono field and a paste affordance. The button uses an `AnimatedSwitcher` to move through idle, spinner and check states. On success it fires `successNotification`. An invalid key triggers a horizontal shake and `errorNotification`.

**Pick services** renders the real list under `Skeletonizer(enabled: loading)` while Render responds ([skeletonizer](https://pub.dev/packages/skeletonizer)). Use `surface2`/`surface3` bones with a `PulseEffect`, because a sweeping shimmer is louder on black. Selected rows get a violet-tinted `AnimatedContainer` and a leading check. A sticky "Watch 4 services" CTA slides up with `AnimatedSlide` as soon as one row is selected, mirroring Uber's pinned "Choose/Confirm" button.

The three screens connect with `SharedAxisTransition` on the horizontal axis inside a `PageTransitionSwitcher`, so forward and back feel spatial. Material assigns shared axis to exactly this kind of stepper relationship ([MDC Motion](https://raw.githubusercontent.com/material-components/material-components-android/master/docs/theming/Motion.md); [animations](https://pub.dev/packages/animations)).

### Push notification as a glanceable status surface

Uber's Live Activity work gives the clearest transferable rule. **Rank content by glance priority**: P0 time to pickup, P1 vehicle and driver identity, P2 a progress bar. Uber also deliberately did not copy the in-app UI. The outcome was measurable, with −2.26% driver cancellations and −2.13% rider cancellations at pickup ([Uber Blog](https://www.uber.com/blog/live-activity-on-ios/)).

For Render Watcher the same ranking becomes:

- **P0 (title):** severity and service, for example "CRITICAL · api-gateway 5xx spike".
- **P1 (body):** the agent's finding and confidence, for example "Likely bad deploy #482 · 87%".
- **P2:** elapsed time.

Three actions go on the notification, built with `flutter_local_notifications` 22.3.2 ([pub.dev](https://pub.dev/packages/flutter_local_notifications)):

- **Acknowledge** runs in the background isolate with no UI.
- **View logs** deep-links to the alert detail.
- **Restart** opens the app into a confirm sheet. Destructive actions should never run blind from a notification.

On iOS, register a `DarwinNotificationCategory`. On Android, create `critical_alerts` and `info` channels at first launch, because channel sound and vibration are fixed once a channel exists.

While an incident is "investigating", mirror it as a Live Activity through `live_activities` 2.6.0 ([pub.dev](https://pub.dev/packages/live_activities)). Android support in that package is still beta. Uber's non-linear progress bar, where the last 20% represents the final two minutes, suits any countdown the mandate defines. One example is the time until the agent is allowed to auto-remediate, so movement stays visible near the deadline.

When the app is in the foreground, replace the system banner with an in-app banner that slides down using emphasized decelerate at about 400 ms, fires the matching haptic, and bumps the Alerts tab badge.

### Overview as Uber's map with a draggable sheet

Uber keeps its trip flow in a consistent "context on top, sheet below" structure. The 2023 redesign made home a launcher with personalized suggestions, Services, and an Activity hub ([Uber Newsroom](https://www.uber.com/us/en/newsroom/were-redesigning-the-uber-app-just-for-you/)). Render Watcher's version puts an ambient health backdrop on top: a radar or grid of service nodes in `surface1`, each with a severity-colored dot, plus a violet pulsing "watching" indicator.

A `DraggableScrollableSheet` with `snap: true` sits over the backdrop ([API](https://api.flutter.dev/flutter/widgets/DraggableScrollableSheet-class.html)). It has three proposed snap sizes, which are estimates since Uber documents none:

- **Peek, about 0.12:** one bold line, "6 healthy · 1 degraded".
- **Mid, about 0.45:** the service list.
- **Full, about 0.92:** at full height the 28 px top radius animates to 0 so the sheet "becomes a page".

Each snap fires `selectionClick`. When a critical alert arrives, call `animateTo(0.45)`. Snapping does not apply to programmatic moves, so target an exact snap size.

Service rows follow Uber's two-line row pattern: a service icon, an Inter 500 name, a JetBrains Mono secondary line ("p95 210 ms · last deploy 2h"), and a status pill on the trailing edge. Cards enter staggered, about 40 ms apart, over 250 ms with emphasized decelerate. Hero tags on service avatars carry identity into the detail screens.

### Alerts list as a YouTube feed

YouTube's feed pattern fits a filtered incident stream: a chip row under the app bar, inverted fill for the selected chip, and chrome that gets out of the way. Build it as `SliverAppBar(floating: true, snap: true)` with chips in `bottom`, so the chips hide with the bar on scroll down and return on scroll up ([SliverAppBar](https://api.flutter.dev/flutter/material/SliverAppBar-class.html)). The chips are All, Critical, Warning, Agent-acted and Resolved.

Changing a chip swaps the list with `FadeThroughTransition`, keyed by the filter value. This report treats YouTube's scroll-hiding bar as an observed behavior; the research found no documentation for it.

Each alert card uses `surface1` with a 3 px severity bar on the leading edge. Its title is Inter 600, and its meta line is mono: service, relative time, and the agent's confidence as a small violet arc. If the user has scrolled down when new alerts arrive, a "3 new alerts" pill appears instead of the list jumping.

### Alert detail as a container transform

Material's container transform covers exactly the card-to-detail relationship. Use `OpenContainer` from the `animations` package. Set `closedColor`, `openColor` and `middleColor` explicitly to `surface1` and `bg`, or the default white flashes mid-transform on a dark UI.

The layout follows Uber's trip-status sheet hierarchy:

- **Headline:** a large status line, for example "api-gateway returning 503s for 12 min".
- **Agent card:** the hypothesis plus a confidence arc. The arc fills over 500 ms with emphasized decelerate through `TweenAnimationBuilder`, inside a `RepaintBoundary`.
- **Evidence:** log lines in mono, with offending tokens highlighted in violet.
- **Action pill:** Restart, Rollback, Silence and Open in Render, grouped YouTube-style. YouTube's 2025 redesign placed actions in one rounded container ([Android Headlines](https://www.androidheadlines.com/2025/10/youtubes-major-ui-redesign-is-now-hitting-android-and-ios.html)).

Destructive actions open a bottom-sheet confirmation, Uber's pattern for costly actions. The sheet has a full-width primary button and a text-button cancel, and confirming fires `heavyImpact`. If the action is reversible, completion shows a snackbar with Undo that fades 150/75 ms.

### Live logs as a YouTube mini-player

YouTube's miniplayer can be resized and moved, and it persists while the user browses ([YouTube Blog](https://blog.youtube/news-and-events/looking-ahead-in-youtube-player/)). That is the right model for a tail that should survive tab changes. Render Watcher's version is a 64–72 px bar docked above the nav. It shows the service name, a pulsing violet LIVE dot, a two-line mono tail, and pause and close buttons.

The mechanics:

- **No route.** The mini-player lives in the shell's root `Stack`, so the stream subscription survives navigation.
- **One controller.** A single `AnimationController` runs from 0 (mini) to 1 (full). Vertical drag drives it, and height, corner radius (12 to 0) and the cross-fade between compact and full views all interpolate from it.
- **Release.** On release, the controller runs a `SpringSimulation` using the DefaultSpatial spring and the finger's velocity.
- **Collapse and dismiss.** Swiping down collapses the player. Swiping the mini bar sideways dismisses it.
- **Back.** `PopScope` makes Android back collapse the player instead of exiting.

Full view has chips for level (ERROR, WARN, INFO) and "Agent-flagged". New lines arrive in batches every 100–250 ms through `SliverAnimatedList` with a 200 ms size-and-fade insert ([SliverAnimatedList](https://api.flutter.dev/flutter/widgets/SliverAnimatedList-class.html)). Cap the buffer at about 2,000 lines. When the user scrolls up, the tail pauses and a "↓ 37 new lines" pill offers a jump back to live.

### Audit log as Uber's Activity hub

Uber's 2023 Activity hub unified past and upcoming rides and orders into one timeline ([Uber Newsroom](https://www.uber.com/us/en/newsroom/were-redesigning-the-uber-app-just-for-you/)). The audit log should do the same for every agent observation, decision and action. Build it as a `SliverList` with a `CustomPaint` timeline rail. Each entry has an icon by actor (agent in violet, human in neutral), a bold one-line verb phrase, and mono metadata. The few rows visible at first load fade and slide in with a short stagger; later rows appear without animation. Entries open with the theme's default predictive-back route, not a custom transform.

### Mandate settings as progressive disclosure with friction

Mandate settings deserve the most friction in the app. Group permissions by risk: observe, notify, restart, rollback, deploy. Each `SwitchListTile` expands an explanation with `AnimatedSize` before it can be enabled. Granting a write-level permission requires a confirmation sheet and fires `heavyImpact`. `PopScope(canPop: !dirty)` guards unsaved changes with a fade-scale `showModal` dialog. This is Uber's "destination first, details later" logic in reverse: hide the scary options until the user explicitly reaches for them.

### Bottom navigation across all tabs

Use four tabs: Overview, Alerts, Logs, Audit. Mandate settings live behind the avatar. Following M3, tab changes use `FadeThroughTransition`. A small upward offset of about 8 px evokes YouTube's 2025 slide-up tab switch without its unpublished timing. The nav hides on scroll-down using `AnimatedSlide` at 300 ms with standard easing, and it never hides while the mini-player is expanded. The selected tab gets a violet indicator pill and a filled icon. Unselected tabs use #C4C4C4-equivalent gray.

## Flutter in 2026 changes the foundations, not the design

Three platform facts shape the build:

- **Material is now a package.** Material and Cupertino left the framework as `material_ui` and `cupertino_ui` in August 2026 ([Flutter blog](https://flutter.dev/blog/decoupling-material-cupertino)). `animations` 3.0.0 already requires `material_ui` and Flutter 3.44 ([changelog](https://pub.dev/packages/animations/changelog)). Start on `material_ui`, and wrap older third-party packages in `MaterialUiCompatibilityBridge`. Official M3 Expressive spring APIs are "in progress", so hand-rolled springs remain necessary for now.
- **Keep the default Android route transition.** Since Flutter 3.38 it is `PredictiveBackPageTransitionsBuilder` ([breaking change](https://docs.flutter.dev/release/breaking-changes/default-android-page-transition)). Overriding routes app-wide with shared-axis or zoom builders forfeits the predictive-back peek. Reserve custom transitions for onboarding (in-place switcher) and alert detail (`OpenContainer`). It is unverified whether `OpenContainer` routes take part in predictive back.
- **Budget frames for 120 Hz.** Impeller is the only renderer on iOS and the default on Android API 29+ ([Impeller](https://docs.flutter.dev/perf/impeller)). At 120 Hz the whole frame budget is about 8 ms, so avoid `Opacity` and `saveLayer` in animations. That argues against YouTube's translucent "glass" pills over a scrolling log ([best practices](https://docs.flutter.dev/perf/best-practices)). Solid `surface2` pills are the honest dark-theme translation. Put `RepaintBoundary` around the log list, LIVE dot, confidence arc, radar and mini-player.

Reduce motion needs two checks. On iOS, Reduce Motion does not set `MediaQuery.disableAnimations` and must be read from `accessibilityFeatures.reduceMotion` ([API](https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html)). When either is on:

- Transforms become 150 ms cross-fades.
- Springs lose their bounce.
- Shimmer becomes a solid color.
- The LIVE dot stops pulsing and gains a text label.

Haptics stay, because they are not motion. Severity is never conveyed by color alone, and new critical banners use `Semantics(liveRegion: true)`.

## Conclusion

Uber and YouTube don't share an aesthetic, but they make the same bet. Both concentrate motion and color in a few high-information moments and keep everything else quiet. Uber's measured cancellation drop from a glance-ranked Live Activity, and YouTube's 2025 push to "obscure less content" and confine its gradient, point the same way. For an AI that watches production, that bet matters more than any curve value. The agent's voice (violet, motion, haptics) should be scarce enough that when it moves, an engineer looks.

The practical consequence is that Render Watcher needs no reverse-engineered Uber or YouTube physics. M3's published springs and durations are exact, Flutter exposes them directly, and the remaining unknowns are tuning parameters to settle with screen recordings and user testing, not blockers. Those unknowns are the snap heights, the mini-player size, and the tab-slide offset.
