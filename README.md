# HealthPlan AI — Apple Intelligence Demo App

A SwiftUI iOS demo application built to showcase **Apple Intelligence** integration in the healthcare domain. The app demonstrates how to use **Foundation Models (on-device LLM)**, **App Intents**, **App Shortcuts**, **Siri**, **App Entities with Spotlight Indexing**, **Live Activities / Dynamic Island**, **Interactive Widgets**, and **@AssistantIntent schemas** to provide natural-language access to health plan information.

---

## Table of Contents

- [Overview](#overview)
- [Screenshots & Screens](#screenshots--screens)
- [Architecture](#architecture)
- [Apple Intelligence Features](#apple-intelligence-features)
  - [On-Device Health Plan Advisor](#on-device-health-plan-advisor-foundation-models)
  - [App Intents](#app-intents-8-total)
  - [App Entities & Spotlight Indexing](#app-entities--spotlight-indexing)
  - [Live Activities & Dynamic Island](#live-activities--dynamic-island)
  - [Interactive Widgets](#interactive-widgets-widgetkit)
  - [@AssistantIntent Schemas](#assistantintent-schemas-ios-184)
- [Project Setup](#project-setup)
- [File Structure](#file-structure)
- [JSON Data Format](#json-data-format)
- [How to Test Apple Intelligence Features](#how-to-test-apple-intelligence-features)
- [Requirements](#requirements)

---

## Overview

**HealthPlan AI** is a sample iOS app that simulates a healthcare benefits portal. It loads health plan data from a local JSON file (simulating a network call) and presents it across four screens including an **AI-powered chat advisor**. The app integrates Apple Intelligence features — from on-device Foundation Models to Siri, Shortcuts, Spotlight, Live Activities, and Widgets — so users can interact with their health plan in natural language.

### Key Highlights

- **4-screen SwiftUI app** with Tab-based navigation (Dashboard, Benefits, **AI Advisor**, Plan Details)
- **On-device Health Plan Advisor** powered by Apple Foundation Models — conversational AI that runs entirely on the device with zero data leaving the phone (iOS 26+)
- **Mock network layer** that loads from a bundled JSON file with simulated latency
- **8 App Intents** for Siri and Shortcuts integration
- **5 @AssistantIntent schemas** for Apple Intelligence conversational queries (iOS 18.4+)
- **App Entities** (`CoveredServiceEntity`, `HealthPlanEntity`) with Spotlight indexing via CoreSpotlight
- **Live Activities & Dynamic Island** for real-time deductible tracking on the Lock Screen
- **3 Interactive Widgets** (Small/Medium/Large) for Home Screen at-a-glance plan info
- **App Shortcuts** with natural language phrases
- MVVM architecture with async/await
- iOS 18+ targeting for Apple Intelligence APIs

---

## Screenshots & Screens

### Screen 1: Dashboard
The main landing screen showing:
- Welcome header with member name and active status
- Plan details card (plan name, type, group, network tier, coverage period)
- Financial summary with progress bars for deductibles and out-of-pocket maximums
- Quick-look section for top covered services
- **Live Activity control** — start/stop deductible tracking on Lock Screen & Dynamic Island
- Siri tips section showing suggested voice commands

### Screen 2: Benefits & Coverage
A searchable list of all covered healthcare services, grouped by category:
- Each service shows the in-network copay, authorization requirements, and deductible applicability
- Tapping a service navigates to a detail view with full cost breakdown
- Supports real-time search filtering by service name or category

### Screen 3: AI Plan Advisor (NEW — Foundation Models)
An interactive chat interface powered by Apple's on-device Foundation Models:
- **Conversational AI** — ask free-form questions about your health plan in natural language
- **Streaming responses** — answers appear word-by-word in real-time
- **Contextual grounding** — the LLM is grounded with your complete plan data (member info, financials, all services) via a detailed system prompt
- **Privacy-first** — Apple Intelligence on-device model; no data sent to any server
- **Suggested questions** — tap pre-built questions to get started quickly
- **Chat history** — full conversation preserved during the session
- **Security** — the model is instructed to only answer based on provided plan data, never fabricate coverage details

Example questions:
- *"Do I need a referral to see a specialist?"*
- *"What happens if I go to an out-of-network ER?"*
- *"How much will physical therapy cost me after my deductible?"*
- *"Explain what coinsurance means for my plan"*
- *"What zero-cost services are available to me?"*

### Screen 4: Plan Details
A comprehensive view of the member's health plan:
- Member profile card with ID and date of birth
- Full plan information (ID, type, status, group, network tier, dates)
- Financial breakdown with gauge visualizations
- Coverage features checklist (Medical, Dental, Vision)
- AI Insights section with a natural-language plan summary

---

## Architecture

```
┌─────────────────────────────────────────────┐
│                  App Layer                   │
│  HealthPlanAIApp.swift → ContentView.swift   │
│          (TabView with 4 screens)            │
├─────────────────────────────────────────────┤
│                  View Layer                  │
│ Dashboard│Benefits│AI Advisor│Plan Details  │
├─────────────────────────────────────────────┤
│               ViewModel Layer                │
│          HealthPlanViewModel                 │
│  (data loading, computed properties, AI text)│
├─────────────────────────────────────────────┤
│               Service Layer                  │
│          HealthPlanService                   │
│  (mock network call → local JSON bundle)     │
├─────────────────────────────────────────────┤
│               Model Layer                    │
│   HealthPlanResponse, HealthPlan, Member,    │
│   FinancialSummary, CoveredService, etc.     │
├─────────────────────────────────────────────┤
│     On-Device Foundation Models Layer        │
│  HealthPlanAdvisor (LanguageModelSession)    │
│  Streaming chat + contextual system prompt   │
├─────────────────────────────────────────────┤
│          Apple Intelligence Layer            │
│  App Intents (8) + AssistantIntents (5)      │
│  App Entities + CoreSpotlight Indexing       │
│  App Shortcuts Provider (10 shortcuts)       │
├─────────────────────────────────────────────┤
│        Live Activities & Widgets Layer       │
│  HealthPlanActivityAttributes (ActivityKit)  │
│  HealthPlanLiveActivity (Dynamic Island)     │
│  3 WidgetKit widgets (S/M/L)                 │
└─────────────────────────────────────────────┘
```

The app follows the **MVVM** pattern:
- **Models** — Codable structs that map to the JSON data
- **ViewModel** — `HealthPlanViewModel` manages data loading, state, and computed properties for views and intents
- **Views** — SwiftUI views that observe the ViewModel
- **Service** — `HealthPlanService` abstracts the data source (simulates network with local JSON)
- **Advisor** — `HealthPlanAdvisor` uses Apple's `FoundationModels` framework to run an on-device LLM grounded with the member's plan data
- **Intents** — `AppIntent` conformances that expose app functionality to Siri and Shortcuts
- **App Entities** — `AppEntity` conformances that make data searchable in Spotlight and available to Apple Intelligence
- **Live Activity** — `ActivityKit` integration for Lock Screen and Dynamic Island deductible tracking
- **Widgets** — `WidgetKit` interactive Home Screen widgets for at-a-glance plan info

---

## Apple Intelligence Features

### On-Device Health Plan Advisor (Foundation Models)

The headline feature of the app — an **on-device AI chat advisor** built with Apple's `FoundationModels` framework (iOS 26+).

#### How It Works
1. When the user opens the Advisor tab, the app creates a `LanguageModelSession` using `SystemLanguageModel.default`
2. A comprehensive **system prompt** is built dynamically from the loaded plan data, including:
   - Member profile (name, ID, relationship)
   - Full plan details (type, group, dates, network tier, dental/vision)
   - Complete financial summary (deductibles, OOP max with current usage)
   - All 12 covered services with copays, coinsurance, limits, and descriptions
   - General insurance knowledge (PPO/HMO rules, deductible mechanics, ACA preventive care)
3. Users type free-form questions in a chat UI
4. The model responds with **streaming text** — answers appear word-by-word
5. The session maintains conversation context, enabling follow-up questions

#### Privacy & Security
- Uses `SystemLanguageModel.default` — Apple's on-device language model
- **Zero network calls** — all inference runs on the Neural Engine
- No data is sent to Apple, third-party LLMs, or any cloud service
- The system prompt constrains the model to only answer from provided data
- The model is explicitly instructed never to fabricate coverage details or provide medical advice

#### Architecture
```
HealthPlanAdvisor (ObservableObject)
├── configure(with: HealthPlanResponse)  → builds system prompt + creates session
├── sendMessageStreaming(_ text: String) → streams response token-by-token
├── resetConversation()                  → clears chat + resets session
├── suggestedQuestions                   → dynamic based on plan features
└── LanguageModelSession                 → Foundation Models on-device LLM
```

#### Requirements
- **iOS 26+** (Foundation Models framework)
- **iPhone 15 Pro or later** (or any Apple Silicon device with Apple Intelligence)
- **Apple Intelligence enabled** in Settings

### App Intents (8 total)

| Intent | What It Does | Example Siri Phrase |
|--------|-------------|---------------------|
| `GetPlanSummaryIntent` | Returns plan name, type, group, coverage status | *"What's my health plan in HealthPlan AI?"* |
| `GetCoverageDatesIntent` | Returns coverage start/end and renewal dates | *"When does my coverage end in HealthPlan AI?"* |
| `GetCopayIntent` | Returns copay for a specific service (with parameter) | *"What's my copay for urgent care in HealthPlan AI?"* |
| `GetDeductibleStatusIntent` | Returns individual and family deductible usage | *"How much deductible have I used in HealthPlan AI?"* |
| `GetOutOfPocketMaxIntent` | Returns out-of-pocket max usage | *"What's my out of pocket max in HealthPlan AI?"* |
| `ListCoveredBenefitsIntent` | Lists all covered services grouped by category | *"What benefits are covered in HealthPlan AI?"* |
| `OpenHealthPlanIntent` | Opens the app directly | — |
| `AskHealthPlanAdvisorIntent` | Opens the on-device AI advisor chat | *"Ask my health plan advisor in HealthPlan AI"* |

### App Shortcuts

All intents are registered as **App Shortcuts** via `HealthPlanShortcuts: AppShortcutsProvider`. This means:
- They appear automatically in the **Shortcuts app**
- They can be triggered via **Siri** using the registered phrases
- They show up in **Spotlight** search results
- Apple Intelligence can surface them proactively based on usage patterns

### Parameterized Intents

The `GetCopayIntent` demonstrates a **parameterized App Intent** — Siri will ask the user which service they want the copay for, enabling dynamic queries like:
- *"What's my copay for emergency room?"*
- *"How much does physical therapy cost?"*

### App Entities & Spotlight Indexing

The app defines two **App Entities** that make health plan data natively searchable:

| Entity | What It Exposes | Spotlight Searchable |
|--------|----------------|---------------------|
| `CoveredServiceEntity` | All 12 covered services with copays, categories, and descriptions | Yes — search "urgent care copay" in Spotlight |
| `HealthPlanEntity` | The member's health plan with type, status, group, and coverage dates | Yes — search "PPO Select 500" in Spotlight |

**How it works:**
- When the app loads data, `SpotlightIndexer` creates `CSSearchableItem` entries for the plan, each service, and the financial summary
- Each entity supports `EntityStringQuery` for natural-language searching from Siri and Shortcuts
- Spotlight results deep-link back into the app

### Live Activities & Dynamic Island

The app includes a **Live Activity** that displays real-time deductible tracking on the Lock Screen and Dynamic Island:

#### Lock Screen Banner
- Shows plan name and days remaining in coverage
- Side-by-side individual vs family deductible progress bars
- Used/limit amounts for both deductibles

#### Dynamic Island
- **Compact**: Shows health plan icon and days remaining
- **Expanded**: Full view with individual & family deductible amounts, progress bars, and coverage countdown
- **Minimal**: Health plan icon

#### How to Use
1. Open the app's **Dashboard** tab
2. Scroll to the **Live Activity** section
3. Tap **"Start Live Activity"** to begin tracking
4. View the Lock Screen or Dynamic Island to see your deductible status
5. Tap **"Stop Live Activity"** to dismiss

### Interactive Widgets (WidgetKit)

Three Home Screen widgets provide at-a-glance plan information:

| Widget | Size | What It Shows |
|--------|------|---------------|
| **Deductible Donut** | Small | Circular progress chart of individual deductible usage percentage |
| **Top Services** | Medium | Plan name, days remaining, and top 3 services with copays |
| **Financial Summary** | Large | Full breakdown with deductibles + OOP max progress bars, member name, days remaining |

All widgets refresh every 4 hours and load data from the bundled JSON.

### @AssistantIntent Schemas (iOS 18.4+)

Five intents use **`@AssistantIntent(schema:)`** to expose the app's data directly to Apple Intelligence for conversational follow-up queries:

| Assistant Intent | Schema | What It Does | Example Query |
|-----------------|--------|-------------|---------------|
| `SearchHealthBenefitsIntent` | `.system.search` | Search for services by name, category, or description | *"Search for pharmacy in HealthPlan AI"* |
| `LookupServiceDetailIntent` | `.system.search` | Full detail view of a specific service | *"Look up emergency room details"* |
| `GetFinancialStatusIntent` | `.system.search` | Returns deductibles, OOP max, or complete financial status | *"Show my financial status"* |
| `CompareCopaysIntent` | `.system.search` | Compare in-network vs out-of-network costs | *"Compare copays for all pharmacy services"* |
| `CheckCoverageIntent` | `.system.search` | Check if a service is covered and get details | *"Is physical therapy covered?"* |

**Key difference from regular App Intents:** `@AssistantIntent` intents are available to Apple Intelligence's on-device model, enabling:
- Conversational follow-up questions
- Proactive surface in Spotlight and Siri Suggestions
- Context-aware entity resolution

---

## Project Setup

### Step 1: Create the Xcode Project

1. Open **Xcode 16** or later
2. Go to **File → New → Project**
3. Select **iOS → App**
4. Set the following:
   - **Product Name**: `HealthPlanAI`
   - **Organization Identifier**: your reverse-domain (e.g., `com.yourname`)
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Minimum Deployment Target**: iOS 18.0
5. Save the project to your desired location

### Step 2: Add Source Files

1. Delete the auto-generated `ContentView.swift` from Xcode
2. Drag the following folders from this project into the Xcode project navigator:
   - `Models/`
   - `ViewModels/`
   - `Views/`
   - `Services/`
   - `Intents/`
   - `Resources/` (the `HealthPlanData.json` file)
3. Replace `HealthPlanAIApp.swift` with the one from this project
4. Add `ContentView.swift` from this project
3. Make sure **"Copy items if needed"** is checked
4. Ensure all `.swift` files have **Target Membership** set to `HealthPlanAI`

### Step 3: Add the JSON to the Bundle

1. Select `HealthPlanData.json` in the project navigator
2. In the **File Inspector** (right panel), verify:
   - **Target Membership**: `HealthPlanAI` is checked
   - The file appears in **Build Phases → Copy Bundle Resources**

### Step 4: Configure Siri & App Intents

1. Select the project in the navigator → select the `HealthPlanAI` target
2. Go to the **Signing & Capabilities** tab
3. Click **+ Capability** and add **Siri**
4. No additional entitlements are needed for App Intents — they work automatically when you conform to `AppShortcutsProvider`

### Step 5: Add the Widget Extension

1. In Xcode, go to **File → New → Target**
2. Select **Widget Extension**
3. Set the Product Name to `HealthPlanWidgets`
4. **Uncheck** "Include Live Activity" (we provide our own)
5. **Uncheck** "Include Configuration App Intent"
6. Click **Finish**
7. Delete the auto-generated widget files
8. Drag the files from the `HealthPlanWidgets/` folder into the new target:
   - `HealthPlanWidgetBundle.swift`
   - `HealthPlanLiveActivity.swift`
   - `InteractiveWidgets.swift`
   - `WidgetDataProvider.swift`
9. **Important**: The following files must have Target Membership for **both** the main app and the widget extension:
   - `HealthPlanModels.swift` (Models)
   - `HealthPlanActivityAttributes.swift` (LiveActivity)
   - `HealthPlanData.json` (Resources)
   - `HealthPlanAppIntents.swift` (for `IntentDataProvider`)
   - `AppEntities.swift` (for entity types)

### Step 6: Configure the Widget Target

1. Select the `HealthPlanWidgets` target
2. Set the **Deployment Target** to iOS 18.0
3. Ensure the widget extension's **Info.plist** has `NSExtension` → `NSExtensionPointIdentifier` set to `com.apple.widgetkit-extension`

### Step 7: Enable Live Activities

1. Select the `HealthPlanAI` main target
2. Open **Info.plist** or the Info tab
3. Add the key: `NSSupportsLiveActivities` → `YES`
4. Also add: `NSSupportsLiveActivitiesFrequentUpdates` → `YES`

### Step 8: Set Up App Groups (Optional, for shared data)

If you want widgets to share live data with the main app:
1. Select both the main app and widget targets
2. Go to **Signing & Capabilities** → **+ Capability** → **App Groups**
3. Create a group like `group.com.yourname.healthplanai`
4. Use `UserDefaults(suiteName:)` for shared data storage

### Step 9: Build & Run

1. Select an **iOS 18+** simulator or device
2. **⌘R** to build and run
3. The app should display the Dashboard tab with loaded health plan data

---

## File Structure

```
HealthPlanAI/
├── HealthPlanAIApp.swift              # App entry point
├── ContentView.swift                  # Root TabView with 3 tabs
├── Models/
│   └── HealthPlanModels.swift         # All Codable model structs
├── ViewModels/
│   └── HealthPlanViewModel.swift      # Main ViewModel with data loading + AI helpers
├── Views/
│   ├── DashboardView.swift            # Screen 1: Dashboard overview + Live Activity toggle
│   ├── BenefitsListView.swift         # Screen 2: Searchable benefits list + detail
│   ├── HealthPlanAdvisorView.swift    # Screen 3: On-device AI chat advisor
│   └── PlanDetailsView.swift          # Screen 4: Full plan details
├── Services/
│   ├── HealthPlanService.swift        # Mock network service (loads local JSON)
│   └── HealthPlanAdvisor.swift        # On-device Foundation Models LLM advisor
├── Intents/
│   ├── HealthPlanAppIntents.swift      # 8 App Intent definitions
│   ├── HealthPlanShortcuts.swift       # App Shortcuts provider (10 shortcuts)
│   ├── AppEntities.swift              # CoveredServiceEntity, HealthPlanEntity, SpotlightIndexer
│   └── AssistantIntents.swift         # 5 @AssistantIntent schemas (iOS 18.4+)
├── LiveActivity/
│   └── HealthPlanActivityAttributes.swift  # ActivityKit attributes + LiveActivityManager
├── Resources/
│   └── HealthPlanData.json            # Sample health plan data
└── Assets.xcassets/                   # App icons and colors

HealthPlanWidgets/                     # Widget Extension Target
├── HealthPlanWidgetBundle.swift        # Widget bundle entry point (@main)
├── HealthPlanLiveActivity.swift        # Live Activity UI (Lock Screen + Dynamic Island)
├── InteractiveWidgets.swift           # 3 widgets: Deductible Donut, Top Services, Financial Summary
└── WidgetDataProvider.swift           # Timeline provider + shared widget data model
```

---

## JSON Data Format

The app uses a custom JSON structure (different from typical benefits APIs) with these top-level keys:

```json
{
  "member_profile": {
    "member_id": "MBR-98234",
    "full_name": "Jane Cooper",
    "date_of_birth": "1985-03-15",
    "relationship": "subscriber"
  },
  "health_plan": {
    "plan_id": "HP-2025-PPO-500",
    "plan_label": "PPO Select 500",
    "plan_type": "PPO",
    "enrollment_status": "active",
    "effective_from": "2025-01-01",
    "effective_through": "2025-12-31",
    ...
  },
  "financial_summary": {
    "individual_deductible": { "annual_limit": 500, "amount_used": 125, "amount_remaining": 375 },
    "family_deductible": { ... },
    "individual_out_of_pocket_max": { ... },
    "family_out_of_pocket_max": { ... }
  },
  "covered_services": [
    {
      "service_id": "SVC-001",
      "service_name": "Preventive Care Visit",
      "category": "Preventive",
      "in_network_copay": 0.00,
      "out_network_copay": 50.00,
      "coinsurance_percentage": 0,
      "deductible_applies": false,
      "annual_visit_limit": null,
      "pre_authorization_required": false,
      "description": "Annual wellness exams..."
    },
    ...
  ]
}
```

To customize the data, edit `Resources/HealthPlanData.json`. The models will automatically parse any valid JSON matching this structure.

---

## How to Test Apple Intelligence Features

### Testing the On-Device AI Advisor

1. Build and run on a **physical iPhone 15 Pro or later** with **iOS 26+**
2. Ensure **Apple Intelligence** is enabled in **Settings → Apple Intelligence & Siri**
3. Open the **Advisor** tab in the app
4. Verify the privacy banner shows "Powered by Apple Intelligence"
5. Try the suggested questions or type your own:
   - *"What's my copay for an urgent care visit?"*
   - *"Do I need pre-authorization for physical therapy?"*
   - *"How much deductible do I have remaining?"*
   - *"Explain what happens if I go out-of-network"*
   - *"What zero-cost services are available to me?"*
6. Verify streaming responses appear word-by-word
7. Tap the menu (⋯) → **New Conversation** to reset

> **Note**: The on-device model requires sufficient device storage and an initial download of Apple Intelligence models. If the model shows as unavailable, check Settings.

### Testing with Siri

1. Build and run the app on an **iOS 18+** device or simulator
2. Invoke Siri and say one of the registered phrases:
   - *"What's my health plan in HealthPlan AI?"*
   - *"When does my coverage end in HealthPlan AI?"*
   - *"What's my copay for urgent care in HealthPlan AI?"*
   - *"Show my deductible status in HealthPlan AI"*
   - *"Is physical therapy covered in HealthPlan AI?"*
   - *"Compare copays for pharmacy in HealthPlan AI"*

### Testing with Shortcuts App

1. Open the **Shortcuts** app on the device
2. Search for **"HealthPlan AI"**
3. You should see all 9 shortcuts listed
4. Tap any shortcut to run it and see the response dialog

### Testing with Spotlight

1. Swipe down on the Home Screen to open Spotlight
2. Type a service name like **"Urgent Care"** or **"emergency room"**
3. Items indexed by the app will appear as search results
4. Tapping a result opens the app

### Testing Live Activities

1. Build and run on a **physical device** (Live Activities have limited simulator support)
2. Go to the **Dashboard** tab
3. Tap **"Start Live Activity"**
4. Lock the device to see the Live Activity on the Lock Screen
5. On iPhone 14 Pro+ / iPhone 15+, the Dynamic Island shows the compact view
6. Long-press the Dynamic Island to see the expanded view
7. Return to the app and tap **"Stop Live Activity"** to dismiss

### Testing Widgets

1. Build and run the app at least once
2. Long-press the Home Screen → tap **+** to add a widget
3. Search for **"HealthPlan AI"** or **"Deductible"** / **"Financial"**
4. Add any of the 3 widget sizes:
   - **Small**: Deductible donut chart
   - **Medium**: Top services with copays
   - **Large**: Full financial summary
5. The widget data refreshes every 4 hours

### Testing App Entities

1. Open the **Shortcuts** app
2. Create a new shortcut
3. Search for actions from **"HealthPlan AI"**
4. Actions like **"Search Health Benefits"** accept entity parameters — you can type a service name and see the entity picker

### Testing in Xcode (Debug)

For debugging App Intents during development:
1. In Xcode, go to **Product → Scheme → Edit Scheme**
2. Under **Run → Arguments → Environment Variables**, add:
   - `ASSISTANTHOST_LOG_LEVEL` = `debug`
3. You can also test intents via the **Shortcuts** app on the Simulator

---

## Requirements

| Requirement | Version |
|-------------|---------|
| Xcode | 16.0+ |
| iOS Deployment Target | 18.0+ (18.4+ for @AssistantIntent, 26+ for Foundation Models) |
| Swift | 5.9+ |
| macOS (for development) | Sonoma 14.0+ |

> **Note**: Apple Intelligence features (App Intents, App Shortcuts) require **iOS 16+** for basic functionality. Some advanced Apple Intelligence features like proactive suggestions require **iOS 18+** and compatible hardware. `@AssistantIntent` schemas require **iOS 18.4+**. Live Activities require a physical device for full Dynamic Island support. This demo targets iOS 18.0 to use the latest APIs.

---

## License

This is a demo/learning project. Feel free to use and modify for educational purposes.

---

## License

This is a demo/learning project. Feel free to use and modify for educational purposes.
