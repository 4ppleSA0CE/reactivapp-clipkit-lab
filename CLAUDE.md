# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ReactivChallengeKit is an iOS SwiftUI application that simulates App Clip behavior. It provides a framework for building and testing App Clip experiences without deploying to a real App Clip target. Clips are URL-invoked, ephemeral, single-task experiences constrained to deliver value in under 30 seconds.

## Build & Run

This is a native Xcode project with zero external dependencies. No SPM packages, CocoaPods, or Carthage.

```bash
# Open project
open ReactivChallengeKit/ReactivChallengeKit.xcodeproj

# Build from command line
xcodebuild -project ReactivChallengeKit/ReactivChallengeKit.xcodeproj -scheme ReactivChallengeKit -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build

# Build and run: Cmd+R in Xcode on an iPhone simulator
```

- **Xcode:** 26+ required
- **iOS Target:** 26.1 (iOS 18+)
- **Swift:** 5.0
- **No tests or linting configured**

## Architecture

All source lives under `ReactivChallengeKit/ReactivChallengeKit/`.

### Core Protocol

- **`Protocol/ClipExperience.swift`** — Protocol every clip conforms to. Defines `urlPattern`, `clipName`, `clipDescription`, `teamName`, `touchpoint`, `invocationSource`, `init(context:)`, and a SwiftUI `body`.
- **`Protocol/ClipContext.swift`** — Data struct passed to clips containing the invocation URL and extracted `pathParameters`/`queryParameters`.

### Simulator Framework (`Simulator/`)

- **`SimulatorShell.swift`** — Root container view and clip host. Manages the full lifecycle: landing screen, clip invocation, constraint enforcement.
- **`ClipRouter.swift`** — `@Observable` class that handles URL pattern matching, parameter extraction, and routing. Combines `builtInExperiences` (examples) with `SubmissionRegistry.all` (team submissions). Contains `AnyClipView` type erasure helper.
- **`LandingView.swift`** — Home screen listing registered clips with InvocationConsole.
- **`InvocationConsole.swift`** — URL input interface replacing real-world QR/NFC triggers.
- **`ConstraintBanner.swift`** — Replica of real App Clip top banner (injected automatically by host — clips should NOT add this).
- **`MomentTimer.swift`** — 30-second countdown timer (green < 20s, yellow < 30s, red >= 30s).

### Submission System

Team submissions live in `Submissions/<team-slug>/` and are compiled into the app via code generation:

- **`scripts/create-submission.sh "Team Name"`** — Scaffolds a new submission folder from `Submissions/_template/`.
- **`scripts/generate-registry.sh`** — Scans `Submissions/` for `ClipExperience` conformances, generates `SubmissionRegistry.swift` (type registry) and `GeneratedSubmissions.swift` (concatenated source). Runs as an Xcode build phase so submissions auto-register on build.
- **`scripts/doctor.sh`** — Pre-flight environment check.
- **`SubmissionRegistry.swift`** and **`GeneratedSubmissions.swift`** — Auto-generated; do not edit manually.

**Compilation gotcha:** The `Submissions/` folder is added as a folder reference in the Xcode project. Only the main experience file (e.g., `StageswagClipExperience.swift`) is listed in the folder reference's "Exceptions" and compiled directly by Xcode. All other supporting files must be included in `GeneratedSubmissions.swift` to be compiled. Do NOT put the main experience struct in `GeneratedSubmissions.swift` or it will be a duplicate. The `generate-registry.sh` build phase script will overwrite `GeneratedSubmissions.swift` on each build — if the script concatenates all files (including the exception file), you'll get redeclaration errors. To avoid this, either disable the build phase or ensure the script excludes files already compiled via the folder reference.

### Reusable Components (`Components/`)

Building blocks for clip UIs: `ClipHeader`, `ClipBackground`, `ClipActionButton`, `ClipSuccessOverlay`, `ArtistBanner`, `MerchGrid`, `MerchProductCard`, `CartSummary`, `NotificationPreview`.

### Mock Data

`MockData/ChallengeMockData.swift` — Sample artists, products, and notification templates for prototyping.

### Entry Point

`ReactivChallengeKitApp.swift` — Creates `ClipRouter` as `@State`, passes to `SimulatorShell`.

### View Hierarchy

```
ReactivChallengeKitApp -> SimulatorShell
  |-- LandingView (no active clip)
  |   |-- InvocationConsole
  |   +-- ClipCard per registered clip
  +-- ClipHostView (active clip)
      |-- ConstraintBanner (injected by host)
      |-- clip.body (the actual experience)
      +-- MomentTimer
```

## How to Create a New Clip

1. Run `bash scripts/create-submission.sh "Team Name"` (or optionally `"Team Name" "CustomExperienceName"`)
2. Edit the generated file in `Submissions/<team-slug>/`
3. Implement the `ClipExperience` protocol: set `urlPattern`, `clipName`, `clipDescription`, `teamName`, `touchpoint`, `invocationSource`, and build the view in `body`
4. Build (Cmd+R) — the registry auto-generates. If it doesn't appear, run `bash scripts/generate-registry.sh` manually
5. Test by entering a matching URL in the InvocationConsole

Existing examples: `VenueMerchExperience` (merch grid + cart), `TrailCheckInExperience` (stateful with animations), `EmptyClipExperience` (template).

Existing submissions: `StageswagClipExperience` (setlist-driven concert merch with song unlocks, 4 themes, audio player reward).

## Key Patterns

- **URL routing:** Patterns use `:param` syntax (e.g., `"example.com/hello/:name"`). Host matching is case-insensitive and strips `www.` prefix.
- **State management:** `@Observable` on `ClipRouter`, `@Bindable` in views, standard `@State`/`@Binding` in clip implementations.
- **Type erasure:** `AnyClipView` wraps `ClipExperience` conformers so the router can store heterogeneous clips.
- **Visual style:** Dark-mode gradients, glass-morphism via `.glassEffect()` (SwiftUI 6+), system colors (`.primary`, `.secondary`, `.tertiary`) that adapt to Liquid Glass.
- **Haptics:** Gated with `#if !targetEnvironment(simulator)` for `UIImpactFeedbackGenerator`.
- **ScrollView required:** Clip body content should be wrapped in `ScrollView` to avoid overlapping with host-injected overlays.

## Problem Statements

The README contains four example problem statements from Reactiv:
1. **AI-Powered Personalization** — Context-driven recommendations with no login or history
2. **In-Store Companion Shopping** — Product browsing and self-checkout via Clip
3. **Ad-to-Clip Commerce** — Ad-driven native shopping with cart persistence and push notifications
4. **Live Events** — Fan identity capture, merch sales, and real-time engagement at venues (includes concert-goer lifecycle touchpoints: Discovery, Ticket Purchase, The Wait, Show Day, Post-Show Afterglow)

Participants can pick one, combine elements, or invent their own. For checkout-related challenges, Shopify Storefront API + CheckoutSheet Kit or Stripe are recommended.

## Assumptions & Constraints

- iOS only — Reactiv Clips are Apple technology; over 80% of North American mobile commerce is on iPhone
- No trivial builds (e.g., coupon/discount apps with no depth)
- Think commercially and technically — aim for solutions that could ship
- Reasonable assumptions allowed where integrations are unavailable
- All implementations must be runnable Swift-based Clips built on this starter kit

## What You Should Deliver

Submissions should address: problem framing, proposed solution, platform extensions (if applicable), prototype/mockup, and impact hypothesis. See README for full details.

## Submission Workflow

1. Run `bash scripts/create-submission.sh "Team Name"`
2. Build your clip experience in `Submissions/<team-slug>/`
3. Fill out `Submissions/<team-slug>/SUBMISSION.md`
4. Create a branch and open a pull request with a description explaining the solution
5. Include screen recordings of it working
6. CI runs `PR Validation - ClipKit Build / Build & Validate`

## App Clip Constraints (design rules)

See `docs/CONSTRAINTS.md` for full details. Key constraints clips must respect:
- URL-invoked only (no app icon launch)
- Ephemeral: no persistent storage, no login, no onboarding
- Single focused task, value delivered in <=30 seconds
- 15 MB size limit (not enforced in simulator)
