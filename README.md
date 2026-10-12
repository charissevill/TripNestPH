# TripNest PH: AI-Powered Local Tourism Discovery Application

TripNest PH is an AI-powered tourism platform designed to help travelers discover destinations, create personalized itineraries, and explore local businesses across the Philippines. By combining artificial intelligence with location-based recommendations, the platform delivers a smarter, more convenient, and personalized travel planning experience while supporting local tourism and businesses.

### Features

* 🗺️ **Destination Explorer** – Discover tourist attractions, restaurants, accommodations, and hidden gems across the Philippines.
* 🤖 **AI Itinerary Planner** – Generate personalized travel itineraries based on budget, interests, travel duration, and preferences.
* 📍 **Location-Based Recommendations** – Receive nearby attractions and businesses based on your current location or accommodation.
* 💰 **Budget Planner** – Estimate travel expenses and manage trip budgets efficiently.
* ❤️ **Saved Trips & Favorites** – Save destinations, itineraries, and favorite places for future travel.
* 💬 **AI Travel Assistant** – Get intelligent travel recommendations, travel tips, and booking links through an AI-powered chatbot.
* ⭐ **Reviews & Ratings** – Read and share reviews to help other travelers make informed decisions.
* 📅 **Local Events & Festivals** – Explore upcoming festivals, cultural events, and activities happening across different provinces.
* 🏢 **Business & Tourism Management** – Enables administrators and business owners to manage tourism destinations, local businesses, and tourism-related content.

### Tech Stack

* **Frontend:** Flutter 3.44 (Dart 3.12), `provider` for state, `go_router` for navigation
* **Backend:** Firebase — Authentication, Cloud Firestore, Cloud Storage, Cloud Functions (Node 22), Hosting
* **External APIs:** Open-Meteo (weather), Google Places / Routes / Maps / Cloud Vision, Groq (AI)

### Setup and Installation

#### Prerequisites

* Flutter SDK 3.44 or newer (`flutter --version`)
* Android Studio with the Android SDK, plus an Android device or emulator
* Chrome (only for the web build and the Admin Portal)
* Node.js 22 and the Firebase CLI (`npm install -g firebase-tools`) — only needed to deploy Cloud Functions, rules or Hosting

The Firebase configuration for the `tripnest-ph` project is already in the repository (`lib/firebase_options.dart` and `android/app/google-services.json`), so the app connects to the backend without extra setup. Android and Web are the configured platforms.

#### Run the app

```
git clone <repository-url>
cd tripnest_ph
flutter pub get
flutter run
```

`flutter run` starts the traveler app (`lib/main.dart`) on the connected device or emulator. An internet connection is required.

#### Run the Admin Portal

The Admin Portal is a separate entrypoint for admin, LGU and business owner accounts:

```
flutter run -d chrome -t lib/main_admin.dart
```

#### Build the Android APK

```
flutter build apk --release
flutter install
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`.

#### Build and deploy the web apps

```
flutter build web
flutter build web -t lib/main_admin.dart -o build/web-admin
firebase deploy --only hosting
```

The traveler site deploys to `tripnest-ph.web.app` and the Admin Portal to `tripnest-ph-admin.web.app`.

#### Backend (only when changing it)

```
cd functions
npm install
cd ..
firebase functions:secrets:set GROQ_API_KEY
firebase functions:secrets:set GOOGLE_PLACES_API_KEY
firebase deploy --only functions,firestore,storage
```

To grant an existing account Admin Portal access for the first time:

```
node tool/create_admin.js someone@example.com
```

#### Checks and tests

```
flutter analyze
flutter test
```

### Project Structure

```
lib/
  main.dart            Traveler app entrypoint
  main_admin.dart      Admin Portal entrypoint
  core/                Routes, theme, services, providers, shared widgets
  data/repositories/   All Firestore reads and writes
  domain/models/       Data models
  presentation/        Screens, grouped by feature
  ai/                  AI planner and chat (prompts, services, providers)
functions/             Cloud Functions (AI, Places, Routes, OCR, OTP email)
test/                  Unit and widget tests
docs/                  Project, API, CRUD and test documentation
```

### Documentation

* [Project Documentation](docs/Project_Documentation.md) — overview, architecture, database design
* [API Documentation](docs/API_Documentation.html) — external APIs and request methods
* [CRUD Documentation](docs/CRUD_Documentation.md) — create, read, update and delete operations
* [Test Scenarios and Test Cases](docs/Activity1_Test_Scenarios_and_Test_Cases.md)

This project demonstrates modern full-stack development by integrating AI, location-based services, and tourism management into a single platform, making travel planning more personalized, efficient, and accessible while promoting local tourism throughout the Philippines.
