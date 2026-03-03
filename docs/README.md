# One Live × Reactiv Clips Challenge

One Live manages concert merchandise for major artists (Jelly Roll, U2, and more). They lose sales because fans face long lines at venue merch booths and One Live has no way to reach fans before or after a show. **Your challenge:** use Reactiv Clips (Apple App Clips) to capture the merch sales One Live is currently missing.

Read the full problem statement: [PROBLEM_STATEMENT.md](PROBLEM_STATEMENT.md)

---

## The Concert Customer Journey

Your solution should target **at least one** of these touchpoints. See [JOURNEY.md](JOURNEY.md) for a detailed guide.

```
Discovery → Ticket Purchase → The Wait → Show Day → Post-Show Afterglow
   │              │                │           │              │
   │              │                │           │              └─ Emotional high.
   │              │                │           │                 "I want to remember tonight."
   │              │                │           │
   │              │                │           └─ At the venue. High intent, high friction.
   │              │                │              Long lines, crowded, cash/card hassle.
   │              │                │
   │              │                └─ Days/weeks before. Fan is excited but unreachable.
   │              │                   One Live has no way to contact them.
   │              │
   │              └─ Ticketmaster owns this. No customer data shared.
   │
   └─ Fan discovers the show. No merch awareness yet.
```

**The key mechanic:** When a fan opens a Reactiv Clip, One Live can send push notifications for **up to 8 hours**. This is the only direct communication channel available.

---

## Setup

1. Clone this repository
2. Open `ReactivChallengeKit/ReactivChallengeKit.xcodeproj` in Xcode
3. Select an iPhone simulator and press **Cmd+R**

No dependencies. No SPM packages. No CocoaPods. If Xcode builds, you're ready.

---

## 10-Minute Quickstart (First Success)

If you are new to SwiftUI or App Clips, follow this exactly:

1. Run the simulator (`Cmd+R`) and confirm the landing screen opens.
2. Copy template: `cp -r Submissions/_template Submissions/YourTeamName`
3. Open `Submissions/YourTeamName/MyClipExperience.swift`
4. Rename struct + fill these 4 fields:
   - `urlPattern`
   - `clipName`
   - `clipDescription`
   - `teamName`
5. Run again (`Cmd+R`) and confirm your clip appears on landing.
6. Use Invocation Console with a matching URL and verify your clip opens.

**You are done with setup when all 3 are true:**
- Your clip card appears on landing
- Your URL pattern invokes your clip correctly
- `Submissions/YourTeamName/SUBMISSION.md` is started

---

## Build Your Clip

### Step 1: Create your team directory

```
cp -r Submissions/_template Submissions/YourTeamName
```

### Step 2: Rename and edit your experience

Open `Submissions/YourTeamName/MyClipExperience.swift`. Rename the struct, set your URL pattern, and build your UI.

```swift
struct PreShowHypeExperience: ClipExperience {
    static let urlPattern = "onelive.com/show/:showId/preorder"
    static let clipName = "Pre-Show Pre-Order"
    static let clipDescription = "Pre-order merch before the show — skip the line on show day."
    static let teamName = "Team Waterloo"

    let context: ClipContext
    @State private var cart: [Product] = []
    @State private var ordered = false

    var body: some View {
        ZStack {
            ClipBackground()
            ScrollView {
                VStack(spacing: 16) {
                    ArtistBanner(artist: OneLiveMockData.artists[0], venue: "Rogers Centre")

                    if ordered {
                        ClipSuccessOverlay(message: "Pre-order confirmed! Pick up at Booth #3.")
                    } else {
                        MerchGrid(products: OneLiveMockData.products) { product in
                            cart.append(product)
                        }
                        if !cart.isEmpty {
                            CartSummary(items: cart) { ordered = true }
                        }
                    }
                }
                .padding(.bottom, 16)
            }
        }
    }
}
```

### Step 3: Rebuild

The build script auto-discovers your experience from `Submissions/`. Run **Cmd+R** and your clip appears in the landing screen.
If it does not appear, run `bash scripts/generate-registry.sh` once and rebuild.

### Step 4: Test

Type your invocation URL in the console at the bottom (e.g., `onelive.com/show/tonight/preorder`) and tap **Invoke**.

---

## Common Mistakes (Avoid These)

1. **URL does not open your clip**
   - `urlPattern` and tested URL must match segment-by-segment (including host/path shape).
2. **Clip not showing on landing**
   - Experience must conform to `ClipExperience` and live inside your `Submissions/YourTeamName/` folder.
3. **PR fails validation**
   - `SUBMISSION.md` still has placeholder values or files were edited outside `Submissions/YourTeamName/`.
4. **Layout overlaps with simulator chrome**
   - Use `ScrollView` and building blocks; do not manually add top spacers for host controls.
5. **Duplicated App Clip banner**
   - Do not add `ConstraintBanner()` in your submission; simulator host already injects it.

---

## Available Building Blocks

Pre-built components you can compose without deep SwiftUI knowledge. See `ReactivChallengeKit/Components/`.

| Component | What It Does |
|---|---|
| `ClipBackground()` | System background with subtle brand tint that adapts to light/dark mode |
| `ClipHeader(title:subtitle:systemImage:)` | Title + subtitle + SF Symbol icon |
| `ClipActionButton(title:icon:action:)` | Large styled call-to-action button |
| `ClipSuccessOverlay(message:)` | Animated checkmark + confirmation message |
| `ArtistBanner(artist:venue:showDate:)` | Artist name, tour name, venue — concert poster style |
| `MerchProductCard(product:onAddToCart:)` | Single product with price and "Add" button |
| `MerchGrid(products:onAddToCart:)` | 2-column product grid |
| `CartSummary(items:onCheckout:)` | Expandable cart with total and checkout button |
| `NotificationPreview(template:)` | Mock iOS notification bubble |
| `NotificationTimeline(templates:)` | Horizontal scroll of notification previews |
| `ConstraintBanner()` | "App Clip Preview — Get the full app" bar (injected by simulator host) |

---

## Mock Data

`OneLiveMockData` provides ready-to-use data so you can focus on the experience:

| Data | Access |
|---|---|
| Artist profiles | `OneLiveMockData.artists` |
| Merch catalog (8 items) | `OneLiveMockData.products` |
| Featured products (top 4) | `OneLiveMockData.featuredProducts` |
| Products by category | `OneLiveMockData.products(for: .apparel)` |
| Venue info | `OneLiveMockData.venues` |
| Show schedule | `OneLiveMockData.shows` |
| Push notification examples | `OneLiveMockData.notificationTemplates` |

---

## Submit

1. Fill out `Submissions/YourTeamName/SUBMISSION.md` with all 5 deliverables
2. Fork this repo, push your team directory, and open a PR
3. Your PR should only add files in `Submissions/YourTeamName/` — do not edit shared code
4. Include demo video link or screenshots in your submission

---

## Simulator Components (provided)

| Component | What It Does |
|---|---|
| **InvocationConsole** | URL text field + Invoke button. Simulates how real clips are triggered. |
| **ClipRouter** | Matches URLs against registered patterns and extracts path parameters. |
| **ConstraintBanner** | "This is an App Clip" bar. Always visible, like real clips. |
| **MomentTimer** | Seconds-since-invocation. Green < 20s, yellow < 30s, red >= 30s. |

---

## Constraints

Real App Clips have hard constraints. Read [CONSTRAINTS.md](CONSTRAINTS.md) to understand them — they're not limitations, they're a design language.

The question is NOT "can you build an iOS app?" The question is: **"what concert merch experience fits the shape of an App Clip that nobody has built yet?"**
