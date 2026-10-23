# YouTube Mobile UX/Motion and the Material Design 3 Motion System (as of Oct 2026)

Research scope: YouTube iOS/Android look-and-feel, its 2022-2025 redesigns, its motion and interactions, and the M3 / M3 Expressive motion tokens it builds on. Material token values come from primary Google sources (the AndroidX Compose source and the Material Components for Android docs). Most YouTube-specific details come from the official YouTube blog or from reputable tech press. Anything not verified is listed under Gaps.

## YouTube mobile layout: app bar, chips, feed cards, bottom nav, dark colors, typography, spacing

### Takeaway
The dark background value of about #0F0F0F (rgb 15,15,15) is reported only by a third party. It is consistent with YouTube's official 2022 statement that the dark theme was made "darker". The brand accent moved in 2024 from pure red to a cooler red, #FF0033, with a red-to-magenta gradient on the progress bar and the Like and Subscribe buttons. YouTube Sans is the brand display face. Most layout metrics (app bar height, chip sizes, card spacing) have no primary documentation and have to be measured from the live app.

### Cited Findings
- YouTube's dark-mode background is #0F0F0F / rgb(15,15,15), and YouTube Studio's dark surface is lighter at #282828. This is a third-party claim, not YouTube documentation. — [Final Cut plugin "YouTube colors" page](https://finalcutplugins.gumroad.com/l/youtube-colors)
- Oct 24, 2022: YouTube made the dark theme "darker so colors pop", across web, mobile and Smart TVs. — [YouTube Blog, "An updated look and feel for YouTube"](https://blog.youtube/news-and-events/an-updated-look-and-feel-for-youtube/)
- Press coverage of the 2022 change: the dark theme had been grey and would move closer to YouTube Music's black background, with "more blacks than greys". — [Android Central](https://androidcentral.com/apps-software/youtube-ambient-mode-ui-update-new-features); [Malay Mail](https://www.malaymail.com/news/tech-gadgets/2022/10/27/youtube-gets-a-new-look-inspired-by-those-fancy-backlit-tvs/35850)
- Brand red: a logo with a more vibrant play button (#FF0033) soft-launched on June 7, 2024 and went global on Oct 22, 2024. The source is a fan wiki, so treat it as secondary. — [Logos Fandom wiki](https://logos.fandom.com/wiki/YouTube)
- The brand moved from a true red to a "cooler, pinker red". A red-to-magenta gradient now appears on the video progress bar, the Like and Subscribe buttons, and Premium badges. — [Design Rush](https://news.designrush.com/youtube-subtle-brand-refresh-brings-new-colors-and-smoother-experience); [LogoLounge](https://www.logolounge.com/news/youtube-cools-down); [Octet Design, Feb 2025](https://octet.design/journal/youtube-changes-signature-red)
- YouTube Sans is a custom typeface released in 2017. A 2019 redraw took 10 months and redrew every glyph. — [9to5Google, 2019](https://9to5google.com/2019/06/12/new-youtube-sans-font/); [Transform magazine, 2017](https://www.transformmagazine.net/articles/2017/youtube-releases-new-typeface-to-coincide-with-live-streaming-offering/)
- Oct 2025 redesign: every icon across the app was updated, including the top bar, bottom bar and video page/player. The new icons have "bolder, more rounded outlines to improve visibility". — [9to5Google, Oct 23 2025](https://9to5google.com/2025/10/23/youtube-video-player-icon-redesign-rollout/)
- Subscribe button (2022): new shape and high-contrast styling, no longer red. Press describes it as a black-and-white pill. — [YouTube Blog 2022](https://blog.youtube/news-and-events/an-updated-look-and-feel-for-youtube/); [Malay Mail](https://www.malaymail.com/news/tech-gadgets/2022/10/27/youtube-gets-a-new-look-inspired-by-those-fancy-backlit-tvs/35850)
- YouTube links in video descriptions became buttons (2022). — [YouTube Blog 2022](https://blog.youtube/news-and-events/an-updated-look-and-feel-for-youtube/)

### Inferences
- A replication palette: background #0F0F0F; raised surfaces (sheets, chips, pills) a step lighter in the #212121-#272727 range (Studio's #282828 is a reference); primary text near-white; secondary text mid-grey; the accent as a red (#FF0033) to magenta gradient used only on progress bars and key CTAs. The intermediate surface and text greys are not confirmed values; verify them with a color picker.
- Selected filter chips read as "inverted" (light fill, dark text) and unselected chips as low-contrast grey fills. This matches the high-contrast black/white Subscribe pill from 2022: YouTube uses value contrast, not hue, for emphasis.
- Use Roboto (Android) or SF (iOS) for body text and save a geometric brand face like YouTube Sans for headings and the logo.

### Gaps
- No primary source gives YouTube's design tokens (yt-spec variables), exact secondary text and surface hexes, app bar or bottom nav heights, chip dimensions, thumbnail corner radius, or avatar sizes. A search for the yt-spec variable names returned nothing authoritative. Measure these from a current build or from Mobbin screenshots.
- No source found documenting the scroll-to-hide top app bar or the sticky chip row. This behavior is widely observed but undocumented.
- No primary source confirms the bottom nav composition (Home / Shorts / + / Subscriptions / You) or when "Library" became "You". Not verified in this research.

## YouTube redesigns 2022-2025: what changed

### Takeaway
There are three main waves: (1) Oct 2022: ambient mode, a darker dark theme, a pill Subscribe button, description links as buttons, pinch-to-zoom and precise seeking. (2) 2024: the cooler red and the gradient accent. (3) Oct 2025, "more expressive" visual update: a new icon set, translucent rounded pill controls in the player, a non-darkening pause state, content-aware Like animations, a subtler double-tap seek, a slide-up tab-switch transition, threaded comments and a simplified save sheet.

### Cited Findings
- **2022 ambient mode:** "dynamic color sampling" tints the app background to match the video. Dark theme only, web and mobile. Playlist pages get the same color treatment. — [YouTube Blog, Oct 24 2022](https://blog.youtube/news-and-events/an-updated-look-and-feel-for-youtube/)
- Ambient mode tints the phone's status bar and the title strip just below the player. — [Android Central](https://androidcentral.com/apps-software/youtube-ambient-mode-ui-update-new-features)
- **2022:** Like, share and download buttons were restyled to be "less distracting". Pinch to zoom on iOS and Android keeps its zoom level after release. In precise seeking, dragging or swiping up while seeking shows a row of thumbnails. Earlier features referenced: long-press to seek, two-finger double tap to skip chapters, and a "most replayed" graph. — [YouTube Blog 2022](https://blog.youtube/news-and-events/an-updated-look-and-feel-for-youtube/)
- **Oct 2025:** the official recap says YouTube rolled out "10 visual updates": updated player controls and icons, Like animations that vary by video, and threaded comment replies. It links a Help Community thread titled "New Visual Updates for YouTube: A More Expressive and Intuitive Experience". — [YouTube Blog, October 2025 Creator News](https://blog.youtube/news-and-events/youtube-updates-october-2025/)
- Oct 2025 details, all from 9to5Google:
  - The redesign aims to "obscure less content".
  - Portrait mode has a new icon set.
  - The landscape fullscreen button is larger and sits in a circle.
  - In landscape, thumbs up/down, comment, save, share and overflow sit in one pill-shaped container at bottom-left, alongside a cleaner "More videos" button.
  - The background is no longer darkened when a video is paused.
  - The new like/dislike icons have a longer thumb.
  - Liking certain videos triggers a "custom, dynamic visual treatment", such as an animated musical note on music videos or a cue from the game on sports videos.
  - The double-tap skip animation is "more subtle and compact... less intrusive".
  - Switching tabs uses a "more seamless" transition that slides the feed up.
  - The save-to-playlist / Watch Later UI was simplified.
  - Comments are threaded.
  - Rollout was wide on Android and iOS (iOS v20.42).

  — [9to5Google, Oct 23 2025](https://9to5google.com/2025/10/23/youtube-video-player-icon-redesign-rollout/)
- The rounded player buttons (Like, Dislike, Comments, Captions, Settings) are translucent. Press compares this to Apple's Liquid Glass but notes it is "nowhere near as intense". Global rollout reportedly began Oct 13, 2025. — [Beebom](https://beebom.com/youtube-video-player-gets-sleek-redesign-with-liquid-glass-vibes/amp/); [mobigyaan](https://www.mobigyaan.com/youtube-new-video-player-threaded-comments-like-animations)
- On the web, thumbs up/down and the like count share one rounded container, and Share, Create, Download and similar actions get the same pill treatment. Mobile followed. Reception was mixed: YouTube calls the elements "more expressive", while some users call them "cartoonish". — [Android Headlines, Oct 2025](https://www.androidheadlines.com/2025/10/youtubes-major-ui-redesign-is-now-hitting-android-and-ios.html)
- Shorts: a "Clear Screen" mode temporarily hides all icons and text, and a heart icon replaces the thumbs-up on Shorts. The date was not confirmed in this research. — [YouTube Blog, Shorts experience updates](https://blog.youtube/news-and-events/youtube-shorts-experience-updates-features/)
- YouTube's stated design principle is to remove intrusive elements, for example by moving product overlays to a cleaner shelf below the player. — [YouTube Blog, design principles](https://blog.youtube/inside-youtube/design-principles-use-put-creators-center-stage/)
- Older posts (dates unverified): a player that changes shape to match the video format, and an improved miniplayer that can be resized and moved in the mobile app. — [YouTube Blog, "Looking ahead in the YouTube player"](https://blog.youtube/news-and-events/looking-ahead-in-youtube-player/)

### Inferences
- The visual direction for 2025-2026: translucent or blurred pill groups floating over media; controls grouped by function into segmented pills (like|dislike share a pill with a divider); bolder, rounded-outline icons; less scrim over content; delight placed in a few high-frequency moments (Like) rather than everywhere.
- To borrow ambient mode in a dark app, sample the dominant color of the current media and apply it as a very low-opacity blurred glow behind the player and header. Keep the base background near-black so text contrast holds.

### Gaps
- The full list of the "10 visual updates" could not be retrieved, because the Help Community thread did not render.
- No spec found for the Like animation's frame timing, the double-tap ripple dimensions, or the slide-up tab transition's duration or easing.

## Motion and interactions: miniplayer, dismiss, double-tap seek, Like, pull-to-refresh, shimmer, tabs, sheets, haptics

### Takeaway
YouTube publishes no motion specs. The documented behaviors are: a slide-up tab transition, a compact double-tap seek, content-aware Like animations, a movable and resizable miniplayer, long-press seek, two-finger double tap for chapters, and swipe-up precise seeking. Timings have to be borrowed from M3 tokens. The M3 guidance matching each pattern is listed below.

### Cited Findings
- Tab switch: the feed slides up "more seamlessly". — [9to5Google, Oct 2025](https://9to5google.com/2025/10/23/youtube-video-player-icon-redesign-rollout/)
- Double-tap seek: "more subtle and compact" after Oct 2025. — [9to5Google](https://9to5google.com/2025/10/23/youtube-video-player-icon-redesign-rollout/)
- The miniplayer can be resized and moved in the mobile app. — [YouTube Blog, "Looking ahead in the YouTube player"](https://blog.youtube/news-and-events/looking-ahead-in-youtube-player/)
- Gestures in the player:
  - long-press anywhere to seek
  - two-finger double tap to skip chapters
  - drag or swipe up while seeking for the thumbnail filmstrip
  - pinch to zoom, which persists

  — [YouTube Blog 2022](https://blog.youtube/news-and-events/an-updated-look-and-feel-for-youtube/)
- Matching M3 guidance (Material Components for Android docs):
  - **Container transform** links a container to its expanded state. Examples: card to detail, search bar to expanded search. This is the right model for thumbnail-to-player and miniplayer-to-full-player.
  - **Fade through** is for unrelated destinations such as bottom navigation tabs.
  - **Fade** is for dialogs, menus, snackbars and FABs. Defaults: 150 ms in, 75 ms out, linear.

  — [MDC-Android Motion.md](https://raw.githubusercontent.com/material-components/material-components-android/master/docs/theming/Motion.md)
- Bottom sheets map to M3's "default spatial" spring (partial-screen motion). — [MDC-Android Motion.md](https://raw.githubusercontent.com/material-components/material-components-android/master/docs/theming/Motion.md)

### Inferences (practitioner recommendations, not sourced YouTube specs)
- **Draggable player / miniplayer:**
  - Treat drag progress (0 to 1) as the only source of truth and interpolate everything from it: player scale and position, a corner radius from 0 to about 8-12 dp, fade-out of the details panel, and fade-in of the miniplayer controls.
  - On release, settle to the nearest state using velocity, with a spring around damping 0.8-0.9 and stiffness 380-700.
  - Swipe down collapses the player. Swipe the miniplayer sideways or down to dismiss.
  - Fire a haptic tick when crossing the snap threshold.
- **Double-tap seek:** left or right third of the player; a semicircular ripple from the screen edge with a "+10s" label; consecutive taps accumulate. Since 2025, keep it small and short (about 150-250 ms fades).
- **Like:** scale-bounce the icon (about 1.0 to 1.2 to 1.0 on a fast spatial spring), fill the color, and optionally add a contextual particle or Lottie burst. Add a light haptic impact.
- **Pull-to-refresh, skeleton/shimmer, haptics:** use the Material pull-refresh indicator, grey skeleton blocks shaped like thumbnail plus avatar plus two text lines, and a slow (about 1-1.5 s) linear shimmer sweep.
- **Comments and more-menu sheets:**
  - Comments is a tall draggable sheet over the lower part of the watch page, with the video still visible above it.
  - The more-menu is a short modal sheet with a scrim.
  - Animate both with a default-spatial spring.

### Gaps
- No primary or teardown source was found for exact miniplayer dimensions, gesture thresholds, or spring values; for the shimmer and pull-to-refresh implementation; or for YouTube's haptic patterns. Validate by screen recording and frame-stepping the current app.

## Material Design 3 motion specs: easing, duration, transitions, predictive back, M3 Expressive springs

### Takeaway
M3 duration tokens run from 50 ms to 1000 ms in 16 steps. M3 easing tokens are emphasized (a two-segment path), emphasized decelerate/accelerate, standard, and standard decelerate/accelerate. M3 Expressive (2025) adds physics springs: a "standard" scheme and a bouncier "expressive" scheme, each with fast, default and slow speeds and spatial and effects types. Exact values from the AndroidX source are below.

### Cited Findings
- **Duration tokens (ms):**

  | Group | 1 | 2 | 3 | 4 |
  |---|---|---|---|---|
  | Short | 50 | 100 | 150 | 200 |
  | Medium | 250 | 300 | 350 | 400 |
  | Long | 450 | 500 | 550 | 600 |
  | ExtraLong | 700 | 800 | 900 | 1000 |

  — [AndroidX Compose MotionTokens.kt](https://raw.githubusercontent.com/androidx/androidx/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/MotionTokens.kt); [MDC-Android Motion.md](https://raw.githubusercontent.com/material-components/material-components-android/master/docs/theming/Motion.md)
- Guidance: "Duration should increase as an animation's area or traversal increases." — [MDC-Android Motion.md](https://raw.githubusercontent.com/material-components/material-components-android/master/docs/theming/Motion.md)
- **Easing tokens (cubic-bezier):**

  | Token | Value |
  |---|---|
  | Emphasized | path `M 0,0 C 0.05, 0, 0.133333, 0.06, 0.166666, 0.4 C 0.208333, 0.82, 0.25, 1, 1, 1` |
  | Emphasized decelerate | (0.05, 0.7, 0.1, 1.0) |
  | Emphasized accelerate | (0.3, 0.0, 0.8, 0.15) |
  | Standard | (0.2, 0.0, 0.0, 1.0) |
  | Standard decelerate | (0.0, 0.0, 0.0, 1.0) |
  | Standard accelerate | (0.3, 0.0, 1.0, 1.0) |
  | Linear | (0, 0, 1, 1) |
  | Legacy (M2) | (0.4, 0.0, 0.2, 1.0) |
  | Legacy decelerate | (0.0, 0.0, 0.2, 1.0) |
  | Legacy accelerate | (0.4, 0.0, 1.0, 1.0) |

  Compose approximates Emphasized as the single cubic (0.2, 0, 0, 1). On the web, use the path (or a CSS `linear()` approximation) for full fidelity. — [MDC-Android Motion.md](https://raw.githubusercontent.com/material-components/material-components-android/master/docs/theming/Motion.md); [AndroidX MotionTokens.kt](https://raw.githubusercontent.com/androidx/androidx/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/MotionTokens.kt)
- **Transition patterns:** container transform, shared axis (x/y/z; for example onboarding on x, steppers on y, parent-child on z), fade through (unrelated destinations such as bottom-nav tabs), and fade (in-bounds enter/exit of dialogs, menus, snackbars, FABs). — [MDC-Android Motion.md](https://raw.githubusercontent.com/material-components/material-components-android/master/docs/theming/Motion.md)
  - Caveat: that doc lists the container transform, shared axis and fade-through defaults as "300ms (motionDurationLong1)" and container-transform exit as 250 ms. Those look like legacy M2 attribute values, because M3 Long1 is 450 ms. Treat 300 ms as the library default and Medium2-Long2 (300-500 ms) as the M3-era range.
- **Spring tokens, standard scheme** (damping ratio / stiffness):

  | Token | Damping | Stiffness | Use |
  |---|---|---|---|
  | FastSpatial | 0.9 | 1400 | small components such as switches and buttons |
  | DefaultSpatial | 0.9 | 700 | partial-screen motion such as bottom sheets |
  | SlowSpatial | 0.9 | 300 | full-screen motion |
  | FastEffects | 1.0 | 3800 | |
  | DefaultEffects | 1.0 | 1600 | |
  | SlowEffects | 1.0 | 800 | |

  Spatial springs move position and size. Effects springs animate color and opacity and should not overshoot. Available as XML attrs (`motionSpring*`) since MDC 1.13.0. — [AndroidX StandardMotionTokens.kt](https://raw.githubusercontent.com/androidx/androidx/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/StandardMotionTokens.kt); [MDC-Android Motion.md](https://raw.githubusercontent.com/material-components/material-components-android/master/docs/theming/Motion.md)
- **Spring tokens, expressive scheme (M3 Expressive):**

  | Token | Damping | Stiffness |
  |---|---|---|
  | FastSpatial | 0.6 | 800 |
  | DefaultSpatial | 0.8 | 380 |
  | SlowSpatial | 0.8 | 200 |
  | Effects (fast / default / slow) | 1.0 | 3800 / 1600 / 800 |

  The effects values are identical to the standard scheme. — [AndroidX ExpressiveMotionTokens.kt](https://raw.githubusercontent.com/androidx/androidx/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/ExpressiveMotionTokens.kt)
  - Conflict: the third-party Flutter package `material_expressive` lists the expressive default spatial damping as 0.73, while the AndroidX source says 0.8. Prefer AndroidX. — [pub.dev material_expressive](https://pub.dev/documentation/material_expressive/0.8.0/); [pub.dev motor](https://pub.dev/packages/motor)
- **Predictive back (Android):**
  - Android 13 introduced `OnBackInvokedCallback`.
  - On Android 13-14, a developer option enables the back-to-home preview.
  - On Android 15+, the system animations (back-to-home, cross-activity, cross-task) are on by default for opted-in apps.
  - Android 16 adds `PRIORITY_SYSTEM_NAVIGATION_OBSERVER`.
  - Opt in or out with `android:enableOnBackInvokedCallback` at app or activity level.
  - In-app progress uses `PredictiveBackHandler` in activity-compose 1.8.0+, or `OnBackPressedCallback` in AndroidX Activity 1.6.0+.
  - Reset the UI on cancellation.

  — [Android Developers, predictive back](https://developer.android.com/guide/navigation/custom-back/predictive-back-gesture)

### Inferences
- **For a web or React Native dark app:**
  - Standard: `cubic-bezier(0.2,0,0,1)` at 200-300 ms for most UI.
  - Entering elements: `cubic-bezier(0.05,0.7,0.1,1)` at 400-500 ms.
  - Exiting elements: `cubic-bezier(0.3,0,0.8,0.15)` at 200 ms.
  - Springs for anything driven by gestures (player drag, sheets).
- **Converting M3 springs to other engines:** M3 springs are given as damping ratio ζ and stiffness k with mass 1. In engines that take a damping coefficient c (Framer Motion, React Native Animated, Reanimated), use c = 2ζ√k. Examples:
  - DefaultSpatial standard: c ≈ 2 × 0.9 × 26.46 ≈ 47.6
  - Expressive DefaultSpatial: c ≈ 2 × 0.8 × 19.49 ≈ 31.2
  - Expressive FastSpatial: c ≈ 2 × 0.6 × 28.28 ≈ 33.9
- **Predictive-back preview:** apps commonly shrink the outgoing surface to about 90% with rounded corners as progress goes from 0 to 1. This research did not confirm the exact Material scale values.

### Gaps
- m3.material.io renders client-side, so the official M3 Expressive pages and the predictive-back motion spec (scale and margin values) could not be fetched. The values above come from AndroidX and MDC source, which implement the spec.

## Notable UX patterns worth borrowing

### Takeaway
These are YouTube's documented, borrowable patterns: filter chips over the feed, inline action pills grouped by function, precise seeking with thumbnails, gesture shortcuts (long-press seek, double-tap skip, pinch zoom), ambient color, a less intrusive overlay policy, and delight placed in high-frequency moments. Snackbar-with-undo and progressive skeleton loading are standard Material patterns. This research did not find YouTube-specific documentation for them.

### Cited Findings
- Grouped pill actions (like|dislike, share, save, download) and a single landscape action pill. — [9to5Google](https://9to5google.com/2025/10/23/youtube-video-player-icon-redesign-rollout/); [Android Headlines](https://www.androidheadlines.com/2025/10/youtubes-major-ui-redesign-is-now-hitting-android-and-ios.html)
- Move overlays off the content and into a shelf below it, and remove intrusive elements. — [YouTube Blog, design principles](https://blog.youtube/inside-youtube/design-principles-use-put-creators-center-stage/)
- Precise seeking with a thumbnail filmstrip, and a "most replayed" heat graph on the scrubber. — [YouTube Blog 2022](https://blog.youtube/news-and-events/an-updated-look-and-feel-for-youtube/)
- Fade (150 ms in, 75 ms out) is the M3 pattern for snackbars. — [MDC-Android Motion.md](https://raw.githubusercontent.com/material-components/material-components-android/master/docs/theming/Motion.md)
- Clear Screen mode in Shorts hides all chrome on demand. — [YouTube Blog, Shorts updates](https://blog.youtube/news-and-events/youtube-shorts-experience-updates-features/)

### Inferences
- **Chip row:** horizontally scrollable, pinned under the app bar. It hides with the bar on scroll-down and returns on scroll-up. Switching chips fades the feed (fade through), and selection uses the inverted fill.
- **Saving:** show an immediate snackbar such as "Saved to Watch Later" with a "Change" or "Undo" action. This is a common YouTube interaction, but this research did not cite it.
- **Ambient tinting:** sample the media color for headers, playlist pages and the player backdrop.

### Gaps
- No YouTube-specific source was found for snackbar-with-undo copy and behavior, sticky-header implementation, or the progressive-loading strategy (thumbnail placeholders, preloading).
