# Uber Mobile Apps (Rider, Eats, Driver) and the Base Design System: UI/UX, Layout and Motion

Scope note: Uber's mobile Base documentation (base.uber.com) sits behind a JS-rendered/zeroheight-style site that would not fetch (only the title "Base design system" came back). The most precise primary data available publicly is the open-source **Base Web** React library (github.com/uber/baseweb), which Uber describes as "the Base Design System … translated into code" for its web tools. Its tokens are the best public proxy for Base's foundations, but they are the web implementation. Mobile-specific values (iOS/Android sheet physics, haptics) are **not publicly documented**. Researched October 2026.

## 1. What does Base specify? (typography, spacing, color/dark mode, radius, elevation, motion, components)

### Takeaway
Base Web's open-source theme files give exact, citable tokens. Type is Uber Move / Uber Move Text with a 12-96px scale (bold 700 headings, 500 labels, 400 paragraphs). Spacing is a 2-192px scale built mostly on 4px steps. Corners are small (8px buttons/inputs, 0px cards/modals/toasts in the web default, 24px tags). Shadows are soft black at 16% opacity. Dark mode is a near-black, neutral-gray ramp. Motion tokens run from 100ms to 7000ms, with named cubic-bezier curves.

### Cited Findings
**Base / Base Web origin**
- Base Web is "an open source toolkit of React components and utilities that align with the Base Design System". The Base Design System is "essentially the designs translated into code". It was built for Uber's hundreds of internal web tools and open-sourced in 2018. Components are visually regression-tested on every commit and tested end-to-end with Puppeteer. — [Uber Blog: Introducing Base Web](https://www.uber.com/blog/introducing-base-web)

**Typeface: Uber Move**
- Uber Move was designed by MCKL with Wolff Olins for the September 2018 rebrand. It is inspired by early-20th-century sans serifs such as Futura and Neuzeit Grotesk, "reimagined through the lens of transportation fonts" (transit signage). — [MCKL: Uber custom type](https://mckltype.com/custom/uber); [Engadget 2018](https://www.engadget.com/2018-09-12-uber-new-typeface.html)
- It has 4 weights and 2 optical sizes. The tighter, geometric **Display** cut is for headings. The more open, slightly condensed **Text** cut is for body copy. — [MCKL](https://mckltype.com/custom/uber); [Fast Company](https://www.fastcompany.com/90235065/uber-has-a-new-brand-again)
- Base Web font stacks:
  - primary: `UberMoveText, system-ui, "Helvetica Neue", Helvetica, Arial, sans-serif`
  - secondary (headings): `UberMove, UberMoveText, …`
  - mono: `UberMoveMono, "Lucida Console", Monaco, monospace`
  — [baseweb typography.ts](https://raw.githubusercontent.com/uber/baseweb/main/src/themes/shared/typography.ts)

**Type scale (Base Web, size/line-height/weight)** — [baseweb typography.ts](https://raw.githubusercontent.com/uber/baseweb/main/src/themes/shared/typography.ts)
- ParagraphXSmall 12/20/400 · ParagraphSmall 14/20/400 · ParagraphMedium 16/24/400 · ParagraphLarge 18/28/400
- LabelXSmall 12/16/500 · LabelSmall 14/16/500 · LabelMedium 16/20/500 · LabelLarge 18/24/500
- HeadingXSmall 20/28/700 · HeadingSmall 24/32/700 · HeadingMedium 28/36/700 · HeadingLarge 32/40/700 · HeadingXLarge 36/44/700 · HeadingXXLarge 40/52/700 (all in the Uber Move display family)
- DisplayXSmall 36/44/700 · DisplaySmall 44/52/700 · DisplayMedium 52/64/700 · DisplayLarge 96/112/700
- Labels (500 weight, tight line-height) are used for UI text. Paragraphs (400, loose line-height) are used for body copy. Headings jump straight to 700.

**Spacing / sizing scale** — [baseweb sizing.ts](https://raw.githubusercontent.com/uber/baseweb/main/src/themes/shared/sizing.ts)
- scale0 2 · scale100 4 · scale200 6 · scale300 8 · scale400 10 · scale500 12 · scale550 14 · scale600 16 · scale650 18 · scale700 20 · scale750 22 · scale800 24 · scale850 28 · scale900 32 · scale950 36 · scale1000 40 · scale1200 48 · scale1400 56 · scale1600 64 · scale2400 96 · scale3200 128 · scale4800 192 (px)

**Corner radius and borders** — [baseweb borders.ts](https://raw.githubusercontent.com/uber/baseweb/main/src/themes/shared/borders.ts)
- radius100 2px · radius200 4px · radius300 8px · radius400 12px · radius500 16px
- buttonBorderRadius 8px (mini 4px) · inputBorderRadius 8px (mini 4px) · popoverBorderRadius 8px (popover/menu/tooltip)
- surfaceBorderRadius **0px** (card, datepicker, modal, toast, notification) · tagBorderRadius 24px (pill) · checkbox 0px
- Borders are 1px solid black at alpha 0.04 / 0.08 / 0.12 / 0.16 / 0.20 / 0.24 (border100–600). The dark theme overrides the border colors.

**Elevation / lighting** — [baseweb lighting.ts](https://raw.githubusercontent.com/uber/baseweb/main/src/themes/shared/lighting.ts)
- shadow400 `0 1px 4px hsla(0,0%,0%,.16)` · shadow500 `0 2px 8px …16%` · shadow600 `0 4px 16px …16%` · shadow700 `0 8px 24px …16%`
- shallowAbove `0 -4px 16px rgba(0,0,0,.12)` (bottom sheets and bars that cast shadow upward) · shallowBelow `0 4px 16px …12%` · deepAbove `0 -16px 48px rgba(0,0,0,.22)` · deepBelow `0 16px 48px …22%`
- Pressed/hover overlays are an inset tint (overlay100–600 = black at 4–24%).

**Dark mode color** — [baseweb dark semantic tokens](https://raw.githubusercontent.com/uber/baseweb/main/src/themes/dark-theme/color-semantic-tokens.ts); [baseweb primitive tokens](https://raw.githubusercontent.com/uber/baseweb/main/src/tokens/color-primitive-tokens.ts)
- Dark gray ramp: gray50Dark #161616 · gray100Dark #292929 · gray200Dark #383838 · gray300Dark #484848 · gray400Dark #5D5D5D · gray500Dark #717171 · gray600Dark #8C8C8C · gray700Dark #ABABAB · gray800Dark #C4C4C4 · gray900Dark #DEDEDE
- Semantic mapping (dark):
  - backgroundPrimary = foundation.primaryB · backgroundSecondary = gray100Dark (#292929) · backgroundTertiary = gray200Dark (#383838)
  - contentPrimary = primaryA · contentSecondary = gray800Dark (#C4C4C4) · contentTertiary = gray700Dark (#ABABAB)
  - borderOpaque = #292929 · borderTransparent = primaryA at 8%
- Dark accents are desaturated:
  - contentAccent blue600Dark #5E8BDB · borderAccent blue500Dark #3F6EC5
  - positive green600Dark #5C9D70 · negative red600Dark #DE5B5D · warning yellow600Dark #AE8523
- Light accents for comparison: blue600 #276EF1 (classic Uber blue) · green600 #0E8345 · red600 #DE1135
- Dark hover/pressed overlays are white at 10% and 15% (`rgba(255,255,255,0.1)` / `0.15`).

**Motion tokens (Base Web)** — [baseweb animation.ts](https://raw.githubusercontent.com/uber/baseweb/main/src/themes/shared/animation.ts)
- Durations: 0, 100, 150, 200, 250, 300, 400, 500, 600, 700, 800, 900, 1000, 1500, 3000, 5000, 7000 ms
- `easeLinear` cubic-bezier(0,0,1,1): "commonly used for opacity and color changes"
- `easeDecelerate` cubic-bezier(0.22,1,0.36,1): "starts at top speed and comes to a very gradual stop. Commonly used for entering elements"
- `easeAccelerate` cubic-bezier(0.64,0,0.78,0): "commonly used for exiting elements"
- `easeAccelerateDecelerate` cubic-bezier(0.83,0,0.17,1): "A good default for most motion"
- `easeResponsiveAccelerate` cubic-bezier(0.11,0,0.5,0): "Good for feeling of responsiveness when paired with short durations"
- Legacy curves: easeOutCurve (.2,.8,.4,1) · easeInCurve (.8,.2,.6,1) · easeInOutCurve (0.4,0,0.2,1)
- Third-party "design system gallery" sites list conflicting Uber motion tokens (e.g. 100/200/350ms, or base 250/slow 400ms, or cubic-bezier(0.2,0,0,1)). These are unverified and contradicted by the Base Web source above. — [oppadu gallery](https://www.oppadu.com/tools/design-systems-site/brand/uber-base-web.html); [open-design plugin](https://open-design.ai/ko/plugins/design-system-uber/)

### Inferences
- For a dark-themed replica, use these layers:
  - surfaces: #000/#161616 (page), #292929 (secondary surface, borders), #383838 (tertiary/pressed)
  - text: near-white primary, #C4C4C4 secondary, #ABABAB tertiary
  - interactions: white-alpha overlays (10% hover, 15% pressed) instead of shadows, since black shadows barely show on black.
- A sensible motion mapping from the tokens:
  - 100–200ms + easeResponsiveAccelerate for press feedback
  - 250–300ms + easeDecelerate for enter
  - 200ms + easeAccelerate for exit
  - 300–400ms + easeAccelerateDecelerate for larger moves such as sheet or page transitions
  - linear for opacity and color cross-fades
- Small radii (8px controls, 12–16px surfaces, pill chips) plus heavy bold headings in Uber Move are the core of the "Uber look". The 0px surface radius is a web default. The mobile apps visibly use rounded sheets and cards (observation, not documented).

### Gaps
- I could not retrieve base.uber.com's mobile docs. No public source gives iOS/Android-specific component specs: bottom sheet snap heights, list row heights, button heights, chip sizes, toast durations, skeleton shimmer timing, or icon grid and stroke.
- The dark-theme `primaryA`/`primaryB` hex values are in a foundation-token file I could not fetch (404 at the guessed paths). They are presumably near-white and black, but unverified.
- The Base iconography spec (grid, stroke weight) was not found.

## 2. How does Uber structure screens?

### Takeaway
Since 2016 the rider app has been organized around a single "Where to?" entry. Choosing the vehicle happens only after a destination is set, with shortcuts from past trips. The February 2023 redesign added a simplified home with fewer taps, a **Services** tab (a grid of all offerings), an **Activity** hub (past and upcoming rides and orders), and personalized suggestions shown after tapping "Where to?". The map + bottom sheet structure is consistent across the apps, but its exact snap points are undocumented.

### Cited Findings
- The November 2, 2016 rider redesign replaced the car-type-first home with one "Where to?" question. Product choice (X/XL/Lux) comes after the destination, and the app offers destination shortcuts based on past trips. Uber said the old app had grown complicated since 2012. — [Uber Newsroom: new rider app](https://www.uber.com/us/en/newsroom/newriderapp/); [Mobile Marketing Magazine](https://mobilemarketingmagazine.com/uber-redesigns-app-focusing-on-a-single-question/)
- Design director Didier Hilhorst said the old app "wasn't particularly smart" and advised that adding features is easy, removing them is hard. — [Adobe Blog interview, 2017](https://blog.adobe.com/en/publish/2017/05/04/more-features-simple-user-interface-insights-from-ubers-design-director-didier-hilhorst)
- 2019 (older): a redesign moved away from a map-first home toward a grid of services that included Eats. — [Brand Knew Mag](https://www.brandknewmag.com/?p=16279); [It's Nice That](https://www.itsnicethat.com/news/uber-redesign-digital-270919)
- Feb 22, 2023 redesign (Jen You, Head of Product, Rides) — [Uber Newsroom](https://www.uber.com/us/en/newsroom/were-redesigning-the-uber-app-just-for-you/):
  - simplified home so rides and Eats can be booked with fewer taps
  - **Services tab**, a "one stop shop" for everything from e-scooters to food, flowers and drinks
  - **Activity Hub** for past and upcoming rides and Eats orders
  - tapping "Where to?" shows Saved Places first, then personalized destinations and ride types
  - frequent Uber Green users see Green first; frequent reservers see pre-planned options on the home screen
- Driver app (April 2018, older):
  - map-centric layout with a real-time **Earnings Tracker** at the top
  - a **Status Bar** showing market conditions and nearby opportunities; tapping one offers optional navigation to the area
  — [Uber Newsroom: new driver app](https://www.uber.com/newsroom/new-driver-app); [The Points Guy](https://thepointsguy.com/news/ubers-redesigned-app-shows-drivers-where-they-can-get-peak-fares)
- Uber Eats (April 2024) added a vertical swipeable video feed. It appears as carousels on several pages, including home, and launched first in NYC, SF and Toronto. — [Tubefilter](https://www.tubefilter.com/2024/04/12/uber-eats-for-you-page-restaurant-food-recommendations/)

### Inferences
These patterns are observed across the apps, not documented. Treat them as replication guidance:
- **Rider home:**
  - a prominent full-width "Where to?" pill search field
  - a row of horizontal shortcut chips or tiles (saved places, Services: Ride / Reserve / Eats / Package)
  - recent-destination list rows (icon + two-line label)
  - promo cards
- **Trip flow:** map on top with a draggable bottom sheet. The sheet holds the product list (vehicle image, name, ETA, price) and a full-width black (dark mode: white) primary "Choose/Confirm" button pinned at the bottom.
- **Headings and buttons:** large bold Uber Move headings (HeadingMedium–Large, 28–32px). The primary button is roughly 48–56px tall with 8px radius, which matches the scale1200/1400 and buttonBorderRadius tokens.
- **Eats:** a feed of category chips, carousels of store cards with images, a sticky search bar, and bottom tab navigation (Home / Grocery / Browse / Baskets / Account, as observed).

### Gaps
- No primary source documents the bottom-sheet snap points (peek/half/full heights) or exact list-row and chip dimensions.
- I found no 2024–2026 primary source for a newer rider home redesign. One search snippet suggested December 2024, but it was a third-party caption pointing to the February 2023 post, so it is unreliable.
- I found no primary 2025–2026 Uber Eats visual redesign announcement. Coverage from The Verge or TechCrunch did not surface.

## 3. What are Uber's motion principles and transitions?

### Takeaway
The only published, concrete motion spec is the Base Web animation tokens (Section 1). Uber's Live Activity engineering post gives useful information-design and progress-bar rules but says nothing about animation. Sheet physics, haptics and search-focus transitions are undocumented and must be estimated from observation.

### Cited Findings
- **Live Activities / Dynamic Island** (launched Feb 2023; engineering post July 25, 2024) — [Uber Blog: Live Activity on iOS](https://www.uber.com/blog/live-activity-on-ios/):
  - **Information priority:**
    - P0: time to pickup or destination
    - P1: license plate and vehicle photo; driver name and photo
    - P2: overall trip progress bar
  - The design deliberately does not copy the full app UI, because riders only glance at it for a few seconds.
  - **Non-linear progress bar:** the final 20% of the bar represents the last 2 minutes, regardless of total wait.
  - **Dynamic Island:** the team iterated so the drop-off time would not be mistaken for the system clock.
  - **Architecture:**
    - a server-driven DSL supplies content
    - the client fixes the layout and applies styling from tags such as "title"
    - only labels and images are supported
  - **Backend:** the backend decides which state changes are significant enough to push via APNs, and debounces rapid changes.
  - **Impact:** −2.26% driver cancellations at pickup, −2.13% rider cancellations at pickup, −1.06% pickup defects per request.
- iOS 16+ Lock Screen Live Activity shows vehicle details, ETA and trip status. Dynamic Island support started on iPhone 14 Pro. — [Uber Newsroom 2023](https://www.uber.com/us/en/newsroom/were-redesigning-the-uber-app-just-for-you/); [BGR](https://bgr.com/tech/uber-and-uber-eats-rolling-out-long-awaited-live-activities-feature/)
- A Behance "Uber Motion Guidelines" project covers brand and ad motion (color, logo, type), not app UI. It says animation moves in one direction to suggest progress, with speed "loosely based on the animation found within the app." This is a third-party or agency piece and is not app guidance. — [Behance](https://www.behance.net/gallery/69157695/Uber-Motion-Guidelines)

### Inferences
- The non-linear progress rule is directly reusable: compress the end of any ETA or progress bar so movement stays visible near arrival.
- Status updates should change the P0 number first and keep secondary details stable, which is consistent with the priority ranking.
- Sheet physics: replicate with a spring (critically damped or slightly underdamped). Snap based on release velocity, roughly 300–400ms settle with easeDecelerate when not velocity-driven. These numbers are **estimates**, not Uber-documented.
- Search focus: in the observed app, the "Where to?" field expands into a full-screen search with pickup/destination fields stacked and a keyboard. Implement it as a shared-element expand (~250–300ms easeDecelerate).
- Loading: Uber apps show gray skeleton blocks (#292929/#383838 in dark mode). Use a linear shimmer of about 1000–1500ms per cycle. These durations are drawn from the token set, not from documented skeleton specs.

### Gaps
- I found no published Uber guidance on haptics, bottom-sheet drag thresholds or velocities, route-line drawing animation, car-marker interpolation, or skeleton shimmer timing.
- The Live Activity post explicitly does not discuss animation.
- I found no Uber Design Medium article on app motion.

## 4. Uber's 2023–2026 redesigns and engineering/design blog posts

### Takeaway
The best-documented recent redesign is the February 2023 "redesigning the Uber App just for you" update (Services tab, Activity hub, personalization, Live Activities). It was motivated by fewer taps and cross-selling Eats within one app ("go and get"). Its engineering follow-up is the 2024 Live Activity post. Nothing primary from 2025–2026 surfaced.

### Cited Findings
- The 2023 post frames the redesign as "the first in a series of updates" to make it easier to "go and get", tailored to how each person uses the app. — [Uber Newsroom](https://www.uber.com/us/en/newsroom/were-redesigning-the-uber-app-just-for-you/)
- Third-party coverage describes a new home "feed" of information, promotions and recommendations, alongside the Services tab and Activity center. — [News is my Business](https://newsismybusiness.com/uber-redesigns-its-app-to-optimize-user-experience)
- Base Web was introduced on the Uber engineering blog. — [Introducing Base Web](https://www.uber.com/blog/introducing-base-web)

### Inferences
- The direction is clear: Uber is moving from a single-purpose ride app to a personalized multi-service hub. Home is a launcher (search + services + suggestions), Activity is the unified timeline, and tracking extends outside the app (Live Activities).

### Gaps
- RIBs architecture posts were not re-fetched in this pass. RIBs is Uber's mobile architecture behind the 2016 rewrite, as general knowledge, but I did not verify a source here.
- I found no 2025 or 2026 Uber redesign coverage, despite several searches.

## 5. Notable UX patterns (progressive disclosure, status timelines, confirmations, undo, empty and error states, notifications)

### Takeaway
Progressive disclosure is Uber's documented core pattern: ask "Where to?" first, then show the product choice, with Saved Places and suggestions only after tapping. Status communication follows strict information priority (time first). Other patterns are observable but not documented.

### Cited Findings
- Destination first, vehicle second, with shortcuts from history. — [Uber Newsroom 2016](https://www.uber.com/us/en/newsroom/newriderapp/)
- Saved Places and personalized suggestions appear only after the "Where to?" tap. — [Uber Newsroom 2023](https://www.uber.com/us/en/newsroom/were-redesigning-the-uber-app-just-for-you/)
- Glanceable status ranks time, then vehicle and driver identity, then progress. — [Uber Blog Live Activity](https://www.uber.com/blog/live-activity-on-ios/)
- The Activity Hub works as a unified timeline of past and upcoming rides and orders. — [Uber Newsroom 2023](https://www.uber.com/us/en/newsroom/were-redesigning-the-uber-app-just-for-you/)
- The driver app shows earnings at the top and puts actionable opportunity nudges in a status bar. — [Uber Newsroom driver app](https://www.uber.com/newsroom/new-driver-app)

### Inferences
These are observed patterns to replicate, not documented:
- **Trip-status sheet:** a header with a big ETA ("Driver arriving in 3 min"), a driver/vehicle card (plate in a bold box), and action icon buttons (call, message, share trip, safety).
- **Eats order tracking:** a horizontal multi-step progress bar (preparing, picked up, on the way, delivered) under a bold status headline.
- **Confirmations:** destructive or costly actions such as cancelling a trip or confirming pickup use a bottom-sheet confirmation with a full-width primary and a secondary text button.
- **Notifications:** ride notifications carry the ETA in the title.

### Gaps
- I found no primary documentation of Uber's undo, empty-state, error-state or toast conventions. Base Web has Toast/Notification/Snackbar components, but their mobile timing and specs were not retrieved.
- I did not consult screen-level teardowns (Mobbin, Page Flows), which are paywalled or image-only.
