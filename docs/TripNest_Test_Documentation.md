# TripNest PH — Test Scenarios and Test Cases

Prepared for: college Software Testing document
Application under test: **TripNest PH** (Flutter app v1.0.0+1 — Traveler app for Android/iOS/Web and the separate Admin Portal web app), backed by Firebase (Auth, Firestore, Storage, Cloud Functions).
Source of this document: the actual project code in `lib/`, `functions/index.js`, `firestore.rules`, `storage.rules` and `docs/Project_Documentation.md`. Where the code was unclear, the test case says **"Needs manual verification"**.

---

# STEP 1 — Feature / Test Coverage Inventory

## 1.1 Applications and user roles

| Item | What was found in the code |
|---|---|
| Traveler app | `lib/main.dart` + `lib/core/routes/app_router.dart`. Android, iOS and Web. |
| Admin Portal | `lib/main_admin.dart` + `admin_router.dart`. Web only. Login page has no Sign Up link. |
| Roles | **Traveler** (default), **Business Owner** (`businessOwner`), **LGU Officer** (`lgu`, limited to one province), **Admin** (`admin`, platform-wide). Roles other than Traveler are stored in `admin_users` and granted through an invite that the user accepts on their Profile. |
| Account states | Unverified email (blocked from the main app), Verified, Suspended (signed out automatically). |

## 1.2 Main modules, screens and workflows

| Module | Screens / features found | Main workflow |
|---|---|---|
| Splash & Onboarding | Splash (2.6 s), 3 onboarding slides (Skip / Next / Get Started) | Splash → Onboarding (first run only) → Login |
| Authentication | Login, Register (First/Last name, Email, Password, Confirm), Role-choice dialog ("Just Exploring" / "I Own a Business"), Forgot Password (6-digit code), Verify Email (6-digit code), Google Sign-In, Log out | Register → Verify Email → Home. Router redirects signed-out users to Login and unverified users to Verify Email. |
| Home | Featured Destinations, Nearby You, Popular/Nearby Restaurants, Upcoming Festivals, Travel Tips, location prompt card, weather chip, pull-to-refresh | Browse → open details |
| Explore | Tabs for destinations, restaurants, festivals and local businesses; 20-item paging with **Load More**; filter sheet | Browse/filter → open details |
| Search | Debounced live search, typo tolerance, live Google Places results (3+ characters), recent searches (max 8), filters | Type → results → details |
| Details screens | Destination, Restaurant, Festival, Province details; weather card, map, Get Directions, Call, Website/Facebook, Share, Emergency sheet, Report incorrect info, Set Reminder (festival) | View info → act |
| Nearby Places | Category chips (Restaurants, Hotels, Cafes, ATMs, etc.), sort (Relevance/Distance/Rating/Popularity), search | Choose category → list |
| Reviews | Write/edit/delete review (rating, comment ≤ 2000, ≤ 3 photos), "Verified Visit" badge, report review, restaurant-owner reply | Open place → review |
| Favorites | Bookmark icon on cards, Saved tabs (Places, Food, Festivals, Local Finds, Attractions), named lists (create, rename, delete) | Bookmark → organize in lists |
| AI Planner | Form: destination, optional accommodation, budget tier, days (1–14), travelers, traveler type, transportation, interests, trip pace; manual itinerary builder | Fill form → Generate → Itinerary |
| Generated/Saved Itinerary | Day-by-day plan, weather, budget summary, Save, Share, Download, Remind, Regenerate, Save for Offline, add/remove activity, Budget Tracker (expenses + split), Packing Checklist, Group Polls, Trip Companions/Invite, Mark completed | Generate → Save → collaborate |
| Saved Trips & Calendar | Saved Trips list, Join a Shared Trip by code, Duplicate, Remove, Leave, Trip Calendar | Share code → join |
| AI Travel Assistant | Chat with 8 suggested prompts, multi-chat sessions (max 30), input ≤ 1000 chars, "Generate Full Itinerary" button | Ask → answer |
| Profile | Profile, Edit Profile (name, photo, preferences, favorite categories, Update Email), Recently Viewed, My Reviews, Accept/Decline role invite | Manage account |
| Settings | Dark Mode, Theme, Font Style, Text Size, Notification switches, Location Services, Change Password, Delete Account, Clear Recently Viewed, Privacy/Terms/About, FAQ, What's New | Configure app |
| Notifications | In-app list, mark as read, push notifications (FCM), local reminders | Receive announcements |
| Business Owner | Application form, invite acceptance, My Business form (with menu/catalog items), permit photo + OCR, status banners, Dashboard (Views, Rating, Reviews, Favorited) | Apply → approved → list business |
| Admin Portal | Overview, Provinces, Tourist Spots (+ form), Bulk Import (CSV), Festivals (+ form), Businesses (approve/reject/suspend/reactivate/delete), Business Applications, Reported Reviews/Listings, Travelers (suspend), Send Announcement, Analytics, Team (invites) | Role-based management |

## 1.3 Forms, fields and validation rules found

| Form | Fields (R = required) | Validation rules in code |
|---|---|---|
| Register | First Name (R), Last Name (R), Email (R), Password (R), Confirm Password | Name 2–60 chars; email pattern (no leading/trailing/double dots); password ≥ 8; confirm must match |
| Login | Email (R), Password (R) | Email pattern; password only "required" (no 8-char rule) |
| Forgot Password | Email; 6-digit code, New password, Confirm | Code exactly 6 digits; password ≥ 8; server: code expires 10 min, 5 wrong tries max, 5 requests/hour |
| Verify Email | 6-digit code | Same code rules; 5 requests/hour |
| AI Planner | Destination (R), days, travelers, etc. | Days 1–14; Solo = 1, Couple = 2, Family/Friends 2–15 travelers |
| Review | Rating (1–5), Comment (R, ≤ 2000), Photos | Max 3 photos; images only, Storage limit 5 MB |
| Expense | Category, Amount (R), Note, Split between | Amount > 0 and ≤ ₱500,000; at least 1 person to split |
| Poll | Question (R), Options | ≥ 2 options, ≤ 6, all different (case-insensitive) |
| Business Owner Application | Business name (R), Category, Phone (R), Description | Phone 7–15 digits (spaces/dashes/+ allowed); description ≤ 1000 |
| My Business listing | Name, Category, Cuisine*, Price range*, Opening hours*, Description, Province, Address, Phone, Website, Accessibility, Hero photo, Permit photo | Description ≤ 3000; URL must start with http(s); province and hero photo required (*Food & Dining only) |
| Admin Tourist Spot | Name, Category, Cover Photo, Lat/Long, Short (≤ 300) and Long (≤ 5000) Description, Entrance Fee, Phone, Website, Facebook | Lat −90..90, Long −180..180; fee > 0 and ≤ ₱100,000 when enabled |
| Admin Festival | Name, Province (R), Date (R), Lat/Long, Description (≤ 3000) | As above |
| Announcement | Title (R, ≤ 100), Message (R, ≤ 500), Category | Required fields |
| Edit Profile | Full Name (≤ 60) | Name 2–60 |
| Chat input | Message | ≤ 1000 characters |
| Bulk Import CSV | name, provinceId, categoryId, shortDescription (+ optional) | Row-by-row checks with error messages |

## 1.4 Technical interactions

| Area | Found in code |
|---|---|
| Database | Cloud Firestore (users, admin_users, tourist_spots, restaurants, festivals, businesses, saved_itineraries + expenses/polls, favorites, reviews, notifications, etc.). Persistence is enabled in `main.dart`. |
| External APIs (through Cloud Functions) | Groq LLM (`aiComplete`), Google Places (`placesSearchNearby`, `placesSearchText`, `placesPhoto`), Google Routes (`computeTripRoute`), Google Vision OCR (`extractPermitText`), reverse geocoding, weather. Rate limits: AI 30/h, Places 120/h, Routes 60/h, OCR 20/h, reverse geocode 30/h. |
| Payments | **None found.** No payment package or checkout screen exists. (Budgets/expenses are only tracked numbers.) |
| Location / GPS | `geolocator`; states: granted, service disabled, denied, denied forever, unavailable. |
| File / image upload | `image_picker`, `image_cropper`; Storage rules: images only, 5 MB (profile, review, listing photos) or 10 MB (admin content, business permit). CSV upload (admin). |
| Notifications | Firebase Cloud Messaging push (Cloud Function `sendPushOnNotificationCreated`), local scheduled reminders (`flutter_local_notifications`), in-app list, per-category switches. |
| Offline / network | `ConnectivityProvider` + **"You're offline — showing saved data"** banner; Firestore persistence; "Save for Offline" for trips. |
| Error handling | `AppException` maps Firebase/network/platform errors to friendly messages; raw errors only go to the debug log. |
| Permissions | Location, Photos/Gallery, Notifications (push and local), Google account chooser. |
| Security | Route redirects (signed-out → Login, unverified → Verify Email); role checks in Firestore/Storage rules; live sign-out for suspended travelers and revoked admins. |

## 1.5 Items to prepare before testing

| Item | Example |
|---|---|
| Verified traveler | `tester01@example.com` / `Test@1234` |
| Second traveler (for sharing, review, join code tests) | `tester02@example.com` / `Test@1234` |
| Unverified traveler | created during TC-REG-001 |
| Suspended traveler | suspend `tester03@example.com` from Admin Portal |
| Admin | `admin01@example.com` (create with `tool/create_admin.js`) |
| LGU Officer | `lgu.benguet@example.com` (province Benguet) |
| Business Owner | `owner01@example.com` (invite accepted) |
| Devices | 1 real Android phone (calls/notifications/GPS), 1 iOS device if available, desktop browser (Chrome/Edge/Firefox) |
| Test files | Photos < 5 MB, one photo > 10 MB, a sample permit photo, valid/invalid CSV files |

---

# STEP 2 — Test Scenarios

### Splash & Onboarding

**TS-ONB-001:** Verify that a first-time user sees the 3 onboarding slides and can finish or skip them.
**TS-ONB-002:** Verify that onboarding is only marked as "seen" after the user actually exits it (Skip or Get Started).

### Registration

**TS-REG-001:** Verify that a new traveler can register with valid details and is taken to Verify Email.
**TS-REG-002:** Verify that choosing "I Own a Business" during sign-up leads to the Business Owner Application screen.
**TS-REG-003:** Verify that required fields are validated on the Register form (empty fields).
**TS-REG-004:** Verify that invalid email formats are rejected.
**TS-REG-005:** Verify password length and confirm-password rules (boundary values).
**TS-REG-006:** Verify first/last name length boundaries and special characters.
**TS-REG-007:** Verify that an already-registered email cannot be used again.
**TS-REG-008:** Verify that registration handles network loss with a friendly message and creates no partial account.
**TS-REG-009:** Verify that repeated taps on Create Account do not create duplicate submissions.

### Login

**TS-LOGIN-001:** Verify that a registered, verified traveler can log in with valid credentials.
**TS-LOGIN-002:** Verify that login is blocked for wrong password or unknown email.
**TS-LOGIN-003:** Verify that empty or badly formatted login input is validated.
**TS-LOGIN-004:** Verify that login handles network problems.
**TS-LOGIN-005:** Verify that unverified and suspended accounts are handled correctly.
**TS-LOGIN-006:** Verify session persistence across app restarts.
**TS-LOGIN-007:** Verify Google sign-in success, cancellation and failure.

### Forgot Password (OTP)

**TS-PWD-001:** Verify a traveler can request a 6-digit reset code by email.
**TS-PWD-002:** Verify the password can be reset with a correct code and a valid new password.
**TS-PWD-003:** Verify wrong, expired, and over-used codes are rejected.
**TS-PWD-004:** Verify input validation and rate limits on the reset flow.

### Email Verification

**TS-VER-001:** Verify an unverified user can request and enter a 6-digit verification code.
**TS-VER-002:** Verify wrong/expired codes and polling behavior on the Verify Email screen.
**TS-VER-003:** Verify signing out from the Verify Email screen.

### Sign-out & Route Guard

**TS-SESS-001:** Verify the user can log out and is then blocked from signed-in screens.

### Home

**TS-HOME-001:** Verify the Home screen loads its content sections for a signed-in traveler.
**TS-HOME-002:** Verify location permission handling on Home (allowed, denied, denied permanently, services off).
**TS-HOME-003:** Verify pull-to-refresh and behavior when Home cannot load.

### Explore

**TS-EXP-001:** Verify Explore lists destinations, restaurants, festivals and businesses with paging.
**TS-EXP-002:** Verify filters (category, region, province, rating, budget, distance, accessibility) narrow Explore results.
**TS-EXP-003:** Verify empty and error states on Explore.

### Search

**TS-SRCH-001:** Verify live search returns matching destinations, restaurants, festivals and live places.
**TS-SRCH-002:** Verify recent searches are saved (max 8) and can be cleared.
**TS-SRCH-003:** Verify search handles empty input, no results, special characters and very long input.
**TS-SRCH-004:** Verify search filters and behavior when the network drops.

### Details Screens

**TS-DET-001:** Verify destination details show information, weather, map and actions.
**TS-DET-002:** Verify restaurant details show hours, price and contact actions.
**TS-DET-003:** Verify festival details and the reminder feature.
**TS-DET-004:** Verify province details, emergency access and directions handling.
**TS-DET-005:** Verify details screens behave when data is missing or the network fails.

### Nearby Places

**TS-NEAR-001:** Verify the Nearby Places screen lists live places by category, sorts them and handles no results.

### Reviews & Reports

**TS-REV-001:** Verify a traveler can write a review with rating, comment and up to 3 photos.
**TS-REV-002:** Verify review validation (empty comment, 2000-character limit, photo limit).
**TS-REV-003:** Verify a traveler can edit and delete only their own review.
**TS-REV-004:** Verify review reporting and the restaurant-owner reply.
**TS-REV-005:** Verify review submission handles network interruption and photo permission denial.

### Favorites & Lists

**TS-FAV-001:** Verify a traveler can save and unsave destinations, restaurants, festivals, businesses and places.
**TS-FAV-002:** Verify favorites can be organized into named lists (create, move, rename, delete).
**TS-FAV-003:** Verify favorites persist after app restart and stay consistent.

### AI Planner

**TS-PLAN-001:** Verify a traveler can generate an AI itinerary from the planner form using valid choices.
**TS-PLAN-002:** Verify the Generate button is blocked until a destination is selected.
**TS-PLAN-003:** Verify day-count boundaries (1 to 14) and traveler-count rules by traveler type.
**TS-PLAN-004:** Verify the planner handles AI/network failures with friendly messages.
**TS-PLAN-005:** Verify the planner defaults, optional accommodation and option selections.

### Generated Itinerary

**TS-ITIN-001:** Verify the itinerary can be saved to My Trips, and unsaved changes are protected.
**TS-ITIN-002:** Verify itinerary content sections are displayed.
**TS-ITIN-003:** Verify itinerary editing (add, remove activity) and regeneration.
**TS-ITIN-004:** Verify the budget tracker (add, edit, delete expense and validation).
**TS-ITIN-005:** Verify group polls (create, vote, edit, delete and validation).
**TS-ITIN-006:** Verify packing checklist management.
**TS-ITIN-007:** Verify share, download, reminders and offline save of a trip.
**TS-ITIN-008:** Verify trip completion rules and start-date handling.

### Saved Trips & Sharing

**TS-TRIP-001:** Verify Saved Trips lists the traveler's trips and supports duplicate and remove.
**TS-TRIP-002:** Verify joining a shared trip by code (valid, invalid, duplicate access).
**TS-TRIP-003:** Verify the trip calendar and the empty state.

### AI Travel Assistant

**TS-CHAT-001:** Verify a traveler can chat with the AI Travel Assistant using typed or suggested prompts.
**TS-CHAT-002:** Verify chat input limits and empty input handling.
**TS-CHAT-003:** Verify multiple chats (create, switch, delete, limit) and persistence on the device.
**TS-CHAT-004:** Verify chat behavior on failures and unrelated questions.

### Profile

**TS-PROF-001:** Verify the Profile screen shows the traveler's details and navigation shortcuts.
**TS-PROF-002:** Verify a traveler can edit name, photo, travel preferences and favorite categories.
**TS-PROF-003:** Verify name validation and photo upload rules on Edit Profile.
**TS-PROF-004:** Verify the email-change flow (re-authentication and confirmation link).
**TS-PROF-005:** Verify Recently Viewed and My Reviews screens.

### Settings

**TS-SET-001:** Verify appearance settings (dark mode, theme, font style, text size) apply and persist.
**TS-SET-002:** Verify notification switches and the Location Services switch.
**TS-SET-003:** Verify Change Password from Settings.
**TS-SET-004:** Verify Delete Account removes the account and its data.
**TS-SET-005:** Verify legal pages, FAQ and What's New screens.

### Notifications

**TS-NOTIF-001:** Verify the in-app notifications list, read state and empty state.
**TS-NOTIF-002:** Verify push notification permission and delivery (background and foreground).

### Business Owner

**TS-BIZ-001:** Verify a traveler can submit a Business Owner application with valid details.
**TS-BIZ-002:** Verify Business Owner application validation.
**TS-BIZ-003:** Verify invite acceptance/decline gives the Business Owner role.
**TS-BIZ-004:** Verify a business owner can create and submit a listing with required fields.
**TS-BIZ-005:** Verify business listing validation and Food & Dining specific fields.
**TS-BIZ-006:** Verify permit photo upload, OCR trigger and the "no permit" warning.
**TS-BIZ-007:** Verify listing status banners (pending, approved, rejected, suspended) and resubmission.
**TS-BIZ-008:** Verify the business dashboard shows listing statistics.

### Admin Portal – Access & Roles

**TS-ADM-001:** Verify Admin Portal login, the missing sign-up link, and the "No access" state for non-admin accounts.
**TS-ADM-002:** Verify the menu and pages available match each role (admin, LGU, business owner).
**TS-ADM-014:** Verify role/status changes and network failures are enforced during a session.

### Admin Portal – Business Approval

**TS-ADM-003:** Verify admins can approve, reject, suspend, reactivate and delete business listings.
**TS-ADM-004:** Verify admins can approve or reject Business Owner applications.

### Admin Portal – Team & Travelers

**TS-ADM-005:** Verify admins can invite, revoke and remove Admin Portal team members.
**TS-ADM-006:** Verify admins can search, suspend and reactivate traveler accounts.

### Admin Portal – Content

**TS-ADM-007:** Verify tourist spots can be created, validated, edited and removed.
**TS-ADM-008:** Verify festivals can be created and validated.
**TS-ADM-009:** Verify tourist spot CSV bulk import (valid, invalid, wrong file).
**TS-ADM-010:** Verify an LGU account is limited to its own province.

### Admin Portal – Announcements & Analytics

**TS-ADM-012:** Verify announcements can be broadcast with validation.
**TS-ADM-013:** Verify the analytics dashboard values and role scoping.

### Admin Portal – Moderation

**TS-ADM-011:** Verify reported reviews/listings can be hidden, restored or dismissed.

### Network & Offline

**TS-NET-001:** Verify the app shows the offline banner and recovers when the connection returns.
**TS-NET-002:** Verify the app is usable on Wi-Fi only, mobile data only, and when switching between them.
**TS-NET-003:** Verify the app stays responsive on a slow or unresponsive network.

### App Interruptions

**TS-INT-001:** Verify the app keeps its state during a phone call, notification, app switch, minimize and screen lock.
**TS-INT-002:** Verify the app recovers after being closed and reopened.

### Error Handling

**TS-ERR-001:** Verify that no technical information (stack traces, codes, API errors) is shown to users.

### Data Consistency

**TS-DATA-001:** Verify data is saved once, not duplicated, and survives refresh/reopen.

### Compatibility & Responsiveness

**TS-COMP-001:** Verify the layout works on phone, tablet and wide desktop web, and in dark mode.

### Security

**TS-SEC-001:** Verify a traveler cannot reach admin data or other users' data through the app.

---

# STEP 3 — Detailed Test Cases

Priority key: High / Medium / Low. **Actual Result** and **Status (Pass/Fail)** are left blank for the tester.

## Splash & Onboarding

### TC-ONB-001 — Complete onboarding with Next and Get Started

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ONB-001 |
| **Test Case Title** | Complete onboarding with Next and Get Started |
| **Related Test Scenario** | TS-ONB-001 — Verify that a first-time user sees the 3 onboarding slides and can finish or skip them. |
| **Module/Feature** | Splash & Onboarding |
| **Test Objective** | Verify the 3 onboarding slides are shown in order and Get Started leaves onboarding. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- Fresh install (or app data cleared) so onboarding has never been completed.
- The tester is signed out.

**Test Data**
- None needed.

**Test Steps**
1. Open the app.
2. Wait for the splash logo (about 2.6 seconds).
3. On slide 1, read the title, then tap **Next**.
4. On slide 2, tap **Next**.
5. On slide 3, confirm the button label now reads **Get Started**, then tap it.

**Expected Result**
- Splash screen shows the TripNest PH logo, then onboarding appears.
- Slide 1 title: "Discover hidden gems across the Philippines".
- Slide 2 title: "Let AI plan your perfect trip".
- Slide 3 title: "Save, share and travel smarter".
- After Get Started the user is not signed in, so the app shows the **Login** screen.

**Postconditions:** Onboarding is marked as seen on this device.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ONB-002 — Skip onboarding from the first slide

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ONB-002 |
| **Test Case Title** | Skip onboarding from the first slide |
| **Related Test Scenario** | TS-ONB-001 — Verify that a first-time user sees the 3 onboarding slides and can finish or skip them. |
| **Module/Feature** | Splash & Onboarding |
| **Test Objective** | Verify the Skip button exits onboarding immediately. |
| **Priority** | Low |
| **Test Type** | Functional |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- Fresh install; onboarding not completed before.

**Test Data**
- None needed.

**Test Steps**
1. Open the app and wait for onboarding.
2. On slide 1, tap **Skip**.

**Expected Result**
- Onboarding closes immediately without visiting slides 2 and 3.
- The Login screen is shown (user is not signed in).

**Postconditions:** Onboarding is marked as seen.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ONB-003 — Onboarding shows again if the app is killed mid-onboarding

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ONB-003 |
| **Test Case Title** | Onboarding shows again if the app is killed mid-onboarding |
| **Related Test Scenario** | TS-ONB-002 — Verify that onboarding is only marked as "seen" after the user actually exits it (Skip or Get Started). |
| **Module/Feature** | Splash & Onboarding |
| **Test Objective** | Verify onboarding is not marked seen when the app is closed before Skip/Get Started. |
| **Priority** | Low |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- Fresh install; onboarding not completed before.

**Test Data**
- None needed.

**Test Steps**
1. Open the app and wait for onboarding to appear.
2. On slide 2, swipe the app away from the recent-apps list to close it completely.
3. Open the app again.

**Expected Result**
- After the splash screen, onboarding is shown again from slide 1.

**Postconditions:** Onboarding is still not marked as seen.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ONB-004 — Returning user skips onboarding

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ONB-004 |
| **Test Case Title** | Returning user skips onboarding |
| **Related Test Scenario** | TS-ONB-002 — Verify that onboarding is only marked as "seen" after the user actually exits it (Skip or Get Started). |
| **Module/Feature** | Splash & Onboarding |
| **Test Objective** | Verify onboarding is not shown again after it was completed. |
| **Priority** | Low |
| **Test Type** | Functional |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- Onboarding was completed once on this device.
- The tester is signed out.

**Test Data**
- None needed.

**Test Steps**
1. Close the app completely.
2. Open the app.
3. Wait for the splash screen to finish.

**Expected Result**
- After the splash screen the **Login** screen is shown directly; onboarding is not shown.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

## Registration

### TC-REG-001 — Register a new traveler ("Just Exploring")

| Field | Detail |
|---|---|
| **Test Case ID** | TC-REG-001 |
| **Test Case Title** | Register a new traveler ("Just Exploring") |
| **Related Test Scenario** | TS-REG-001 — Verify that a new traveler can register with valid details and is taken to Verify Email. |
| **Module/Feature** | Registration |
| **Test Objective** | Verify successful registration creates an account and shows Verify Email. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The tester is signed out and is on the Login screen.
- The email below has never been registered.

**Test Data**
- First Name: `Maria`
- Last Name: `Santos`
- Email: `maria.santos.test01@example.com`
- Password: `Test@1234`
- Confirm Password: `Test@1234`

**Test Steps**
1. On Login, tap **Sign Up**.
2. In the "Welcome to TripNest PH — What brings you here?" dialog, choose **Just Exploring**.
3. Confirm the subtitle reads "Start planning unforgettable Philippine trips."
4. Fill in all fields with the test data.
5. Tap **Create Account**.

**Expected Result**
- The button shows a loading indicator while working.
- A new account is created and the user is signed in.
- The **Verify your email** screen opens with the text "Verify maria.santos.test01@example.com to activate your TripNest PH account."

**Postconditions:** A Firebase Auth user and a `users/{uid}` profile (name "Maria Santos") exist; email is not yet verified.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-REG-002 — Register as a business owner

| Field | Detail |
|---|---|
| **Test Case ID** | TC-REG-002 |
| **Test Case Title** | Register as a business owner |
| **Related Test Scenario** | TS-REG-002 — Verify that choosing "I Own a Business" during sign-up leads to the Business Owner Application screen. |
| **Module/Feature** | Registration |
| **Test Objective** | Verify the business-owner choice routes to the Business Owner Application screen before Verify Email. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The tester is signed out and is on the Login screen.

**Test Data**
- First Name: `Juan`
- Last Name: `Dela Cruz`
- Email: `juan.owner.test01@example.com`
- Password: `Owner@1234`

**Test Steps**
1. On Login, tap **Sign Up**.
2. In the role dialog, choose **I Own a Business**.
3. Confirm the subtitle reads "Let's get your business set up."
4. Fill in the form with the test data (same value in Confirm Password).
5. Tap **Create Account**.

**Expected Result**
- Account is created.
- The **Business Owner Application** screen opens (it is reachable before email verification).

**Postconditions:** Account exists, unverified. No application is stored until the form is submitted.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-REG-003 — Register with all fields empty

| Field | Detail |
|---|---|
| **Test Case ID** | TC-REG-003 |
| **Test Case Title** | Register with all fields empty |
| **Related Test Scenario** | TS-REG-003 — Verify that required fields are validated on the Register form (empty fields). |
| **Module/Feature** | Registration |
| **Test Objective** | Verify required-field messages appear and nothing is submitted. |
| **Priority** | High |
| **Test Type** | Validation |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The tester is on the Register screen.

**Test Data**
- None needed.

**Test Steps**
1. Leave every field empty.
2. Tap **Create Account**.

**Expected Result**
- First Name shows "Name is required".
- Last Name shows "Name is required".
- Email shows "Email is required".
- Password shows "Password is required".
- No loading indicator appears and no account is created.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Confirm Password does not show an error when both password fields are empty, because the validator only compares the two values.

---

### TC-REG-004 — Register with invalid email formats

| Field | Detail |
|---|---|
| **Test Case ID** | TC-REG-004 |
| **Test Case Title** | Register with invalid email formats |
| **Related Test Scenario** | TS-REG-004 — Verify that invalid email formats are rejected. |
| **Module/Feature** | Registration |
| **Test Objective** | Verify malformed emails are rejected on the form. |
| **Priority** | Medium |
| **Test Type** | Validation |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The tester is on the Register screen with other fields filled correctly.

**Test Data**
- `abc`
- `abc@`
- `abc@example`
- `a@b..com`
- `abc@example.com.`
- `abc @example.com`

**Test Steps**
1. Enter the first invalid value in the Email field.
2. Tap **Create Account**.
3. Note the message under Email.
4. Repeat for each remaining value.

**Expected Result**
- For every value, Email shows "Enter a valid email address".
- No account is created.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-REG-005 — Password length boundary (7, 8 characters)

| Field | Detail |
|---|---|
| **Test Case ID** | TC-REG-005 |
| **Test Case Title** | Password length boundary (7, 8 characters) |
| **Related Test Scenario** | TS-REG-005 — Verify password length and confirm-password rules (boundary values). |
| **Module/Feature** | Registration |
| **Test Objective** | Verify the 8-character minimum for a new password. |
| **Priority** | High |
| **Test Type** | Boundary |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The tester is on the Register screen with other fields valid and a new email.

**Test Data**
- Case A password: `Ab@1234` (7 chars)
- Case B password: `Ab@12345` (8 chars)

**Test Steps**
1. Enter the Case A password in both Password and Confirm Password.
2. Tap **Create Account**.
3. Note the result.
4. Change both fields to the Case B password.
5. Tap **Create Account**.

**Expected Result**
- Case A: Password shows "Password must be at least 8 characters" and no account is created.
- Case B: the form passes validation and the account is created (Verify Email screen opens).

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-REG-006 — Confirm Password does not match

| Field | Detail |
|---|---|
| **Test Case ID** | TC-REG-006 |
| **Test Case Title** | Confirm Password does not match |
| **Related Test Scenario** | TS-REG-005 — Verify password length and confirm-password rules (boundary values). |
| **Module/Feature** | Registration |
| **Test Objective** | Verify mismatched passwords are rejected. |
| **Priority** | High |
| **Test Type** | Validation |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The tester is on the Register screen with other fields valid.

**Test Data**
- Password: `Test@1234`
- Confirm Password: `Test@12345`

**Test Steps**
1. Enter the test data.
2. Tap **Create Account**.

**Expected Result**
- Confirm Password shows "Passwords do not match".
- No account is created.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-REG-007 — Name length boundaries

| Field | Detail |
|---|---|
| **Test Case ID** | TC-REG-007 |
| **Test Case Title** | Name length boundaries |
| **Related Test Scenario** | TS-REG-006 — Verify first/last name length boundaries and special characters. |
| **Module/Feature** | Registration |
| **Test Objective** | Verify the 2-character minimum and 60-character maximum for First Name / Last Name. |
| **Priority** | Medium |
| **Test Type** | Boundary |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The tester is on the Register screen; other fields valid.

**Test Data**
- 1 character: `A`
- 2 characters: `Al`
- 60 characters: `Abcdefghij` repeated 6 times
- 61 characters: the 60-character value plus `x`

**Test Steps**
1. Enter `A` in First Name and tap **Create Account**; note the message.
2. Enter `Al` and tap **Create Account**; note the message.
3. Enter the 61-character value and tap **Create Account**; note the message.
4. Enter the 60-character value and tap **Create Account**; note the message.

**Expected Result**
- `A`: "Name is too short".
- `Al`: no First Name error.
- 61 characters: "Name must be 60 characters or fewer".
- 60 characters: no First Name error.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** If the text field itself stops typing at 60 characters, record that instead. The same rules apply to Last Name.

---

### TC-REG-008 — Names with special characters

| Field | Detail |
|---|---|
| **Test Case ID** | TC-REG-008 |
| **Test Case Title** | Names with special characters |
| **Related Test Scenario** | TS-REG-006 — Verify first/last name length boundaries and special characters. |
| **Module/Feature** | Registration |
| **Test Objective** | Verify hyphens, apostrophes and spaces are accepted in names. |
| **Priority** | Low |
| **Test Type** | Validation |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The tester is on the Register screen.

**Test Data**
- First Name: `Ana-Marie`
- Last Name: `O'Neil`
- Email: `ana.oneil.test01@example.com`
- Password: `Test@1234`

**Test Steps**
1. Enter the test data.
2. Tap **Create Account**.
3. After the account is created, open Profile.

**Expected Result**
- Registration succeeds (no name-format error).
- Profile shows the name "Ana-Marie O'Neil".

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-REG-009 — Register with an email that already exists

| Field | Detail |
|---|---|
| **Test Case ID** | TC-REG-009 |
| **Test Case Title** | Register with an email that already exists |
| **Related Test Scenario** | TS-REG-007 — Verify that an already-registered email cannot be used again. |
| **Module/Feature** | Registration |
| **Test Objective** | Verify a friendly error is shown for a duplicate email. |
| **Priority** | High |
| **Test Type** | Negative |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The account `tester01@example.com` already exists.

**Test Data**
- Email: `tester01@example.com`
- Any valid names and password `Test@1234`

**Test Steps**
1. Open Register (choose Just Exploring).
2. Enter the test data.
3. Tap **Create Account**.

**Expected Result**
- A red message appears above the button: "An account already exists with that email."
- The user stays on Register; no raw Firebase code is shown.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-REG-010 — Register while offline

| Field | Detail |
|---|---|
| **Test Case ID** | TC-REG-010 |
| **Test Case Title** | Register while offline |
| **Related Test Scenario** | TS-REG-008 — Verify that registration handles network loss with a friendly message and creates no partial account. |
| **Module/Feature** | Registration |
| **Test Objective** | Verify a friendly network message is shown and no account is created. |
| **Priority** | High |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The tester is on the Register screen with all fields valid and a new email.
- Wi-Fi and mobile data are turned OFF.

**Test Data**
- None needed.

**Test Steps**
1. Tap **Create Account**.
2. Wait for the result.
3. Turn the internet back on and tap **Create Account** again.

**Expected Result**
- While offline: message "No internet connection. Please check your network and try again." is shown; the button is usable again.
- After reconnecting: registration succeeds and Verify Email opens.
- Only one account exists for that email.

**Postconditions:** Exactly one Firebase Auth user exists for the email.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-REG-011 — Internet lost while registering

| Field | Detail |
|---|---|
| **Test Case ID** | TC-REG-011 |
| **Test Case Title** | Internet lost while registering |
| **Related Test Scenario** | TS-REG-008 — Verify that registration handles network loss with a friendly message and creates no partial account. |
| **Module/Feature** | Registration |
| **Test Objective** | Verify the app recovers when the connection drops during submission. |
| **Priority** | Medium |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- Register form filled with a new email; internet ON.

**Test Data**
- None needed.

**Test Steps**
1. Tap **Create Account**.
2. Immediately turn the internet OFF (airplane mode).
3. Observe the screen for up to 30 seconds.
4. Turn the internet ON.
5. If an error is shown, tap **Create Account** again.

**Expected Result**
- The button never stays loading forever; either the account is created or a friendly message (network or "This is taking longer than expected...") appears.
- No stack trace or error code is visible.
- After recovery the user can register or, if the account was already created, is signed in on Verify Email.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Result depends on exact timing. Record what happened.

---

### TC-REG-012 — Double-tap Create Account

| Field | Detail |
|---|---|
| **Test Case ID** | TC-REG-012 |
| **Test Case Title** | Double-tap Create Account |
| **Related Test Scenario** | TS-REG-009 — Verify that repeated taps on Create Account do not create duplicate submissions. |
| **Module/Feature** | Registration |
| **Test Objective** | Verify the button is disabled while a request is running. |
| **Priority** | Medium |
| **Test Type** | Negative |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- Register form filled with a new email.

**Test Data**
- None needed.

**Test Steps**
1. Tap **Create Account** twice quickly.

**Expected Result**
- The button shows a loading state and ignores the second tap.
- Only one account is created and one Verify Email screen opens.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

## Login

### TC-LOGIN-001 — Login with valid credentials

| Field | Detail |
|---|---|
| **Test Case ID** | TC-LOGIN-001 |
| **Test Case Title** | Login with valid credentials |
| **Related Test Scenario** | TS-LOGIN-001 — Verify that a registered, verified traveler can log in with valid credentials. |
| **Module/Feature** | Login |
| **Test Objective** | Verify a verified traveler reaches Home. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The tester is signed out and is on the Login screen.
- Verified traveler account exists.

**Test Data**
- Email: `tester01@example.com`
- Password: `Test@1234`

**Test Steps**
1. Enter the email.
2. Enter the password.
3. Tap **Sign In**.

**Expected Result**
- The button shows a loading indicator.
- The user is authenticated and the **Home** screen with the bottom navigation (Home, Explore, Planner, Saved, Profile) is shown.

**Postconditions:** The traveler is signed in.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-LOGIN-002 — Login with wrong password

| Field | Detail |
|---|---|
| **Test Case ID** | TC-LOGIN-002 |
| **Test Case Title** | Login with wrong password |
| **Related Test Scenario** | TS-LOGIN-002 — Verify that login is blocked for wrong password or unknown email. |
| **Module/Feature** | Login |
| **Test Objective** | Verify wrong credentials are rejected with a friendly message. |
| **Priority** | High |
| **Test Type** | Negative |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The tester is signed out and is on the Login screen.
- Account `tester01@example.com` exists.

**Test Data**
- Email: `tester01@example.com`
- Password: `WrongPass99`

**Test Steps**
1. Enter the test data.
2. Tap **Sign In**.

**Expected Result**
- A red message "Incorrect email or password." appears under the fields.
- The user stays on Login; no Firebase error code is visible.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-LOGIN-003 — Login with an unregistered email

| Field | Detail |
|---|---|
| **Test Case ID** | TC-LOGIN-003 |
| **Test Case Title** | Login with an unregistered email |
| **Related Test Scenario** | TS-LOGIN-002 — Verify that login is blocked for wrong password or unknown email. |
| **Module/Feature** | Login |
| **Test Objective** | Verify an unknown email is rejected without exposing technical details. |
| **Priority** | High |
| **Test Type** | Negative |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The tester is signed out and is on the Login screen.

**Test Data**
- Email: `nobody.here99@example.com`
- Password: `Test@1234`

**Test Steps**
1. Enter the test data.
2. Tap **Sign In**.

**Expected Result**
- A friendly message appears: "Incorrect email or password." (or "No account found with that email.").
- The user stays on Login.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Firebase may return either error code depending on project settings. Both are acceptable friendly messages.

---

### TC-LOGIN-004 — Login with empty fields

| Field | Detail |
|---|---|
| **Test Case ID** | TC-LOGIN-004 |
| **Test Case Title** | Login with empty fields |
| **Related Test Scenario** | TS-LOGIN-003 — Verify that empty or badly formatted login input is validated. |
| **Module/Feature** | Login |
| **Test Objective** | Verify required-field validation on Login. |
| **Priority** | High |
| **Test Type** | Validation |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The tester is signed out and is on the Login screen.

**Test Data**
- None needed.

**Test Steps**
1. Leave Email and Password empty.
2. Tap **Sign In**.

**Expected Result**
- Email shows "Email is required".
- Password shows "Password is required".
- No request is sent (no loading indicator).

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-LOGIN-005 — Login with invalid email format

| Field | Detail |
|---|---|
| **Test Case ID** | TC-LOGIN-005 |
| **Test Case Title** | Login with invalid email format |
| **Related Test Scenario** | TS-LOGIN-003 — Verify that empty or badly formatted login input is validated. |
| **Module/Feature** | Login |
| **Test Objective** | Verify email format is checked before sending. |
| **Priority** | Medium |
| **Test Type** | Validation |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The tester is signed out and is on the Login screen.

**Test Data**
- Email: `tester01@`
- Password: `Test@1234`

**Test Steps**
1. Enter the test data.
2. Tap **Sign In**.

**Expected Result**
- Email shows "Enter a valid email address".
- No request is sent.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-LOGIN-006 — Login accepts a short password attempt (no 8-character rule)

| Field | Detail |
|---|---|
| **Test Case ID** | TC-LOGIN-006 |
| **Test Case Title** | Login accepts a short password attempt (no 8-character rule) |
| **Related Test Scenario** | TS-LOGIN-003 — Verify that empty or badly formatted login input is validated. |
| **Module/Feature** | Login |
| **Test Objective** | Verify the Login form does not apply the 8-character rule and lets Firebase decide. |
| **Priority** | Low |
| **Test Type** | Boundary |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The tester is signed out and is on the Login screen.

**Test Data**
- Email: `tester01@example.com`
- Password: `abc123` (6 characters)

**Test Steps**
1. Enter the test data.
2. Tap **Sign In**.

**Expected Result**
- No "at least 8 characters" message appears on the form.
- The request is sent and the result is "Incorrect email or password."

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Code comment in login_screen.dart says this is intentional so older short-password accounts can still sign in.

---

### TC-LOGIN-007 — Password field is masked and Enter submits

| Field | Detail |
|---|---|
| **Test Case ID** | TC-LOGIN-007 |
| **Test Case Title** | Password field is masked and Enter submits |
| **Related Test Scenario** | TS-LOGIN-003 — Verify that empty or badly formatted login input is validated. |
| **Module/Feature** | Login |
| **Test Objective** | Verify password characters are hidden and the keyboard Enter/Done key submits the form. |
| **Priority** | Low |
| **Test Type** | Usability |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The tester is signed out and is on the Login screen.

**Test Data**
- None needed.

**Test Steps**
1. Type `Test@1234` in the Password field and check how the text looks.
2. Fill in a valid email, then press **Done/Enter** on the keyboard while in the Password field.

**Expected Result**
- Password characters are shown as dots, not readable text.
- Pressing Done/Enter starts sign-in the same way as tapping **Sign In**.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-LOGIN-008 — Login while offline

| Field | Detail |
|---|---|
| **Test Case ID** | TC-LOGIN-008 |
| **Test Case Title** | Login while offline |
| **Related Test Scenario** | TS-LOGIN-004 — Verify that login handles network problems. |
| **Module/Feature** | Login |
| **Test Objective** | Verify a friendly network error is shown on Login. |
| **Priority** | High |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The tester is signed out and is on the Login screen.
- Wi-Fi and mobile data are OFF.

**Test Data**
- Email: `tester01@example.com`
- Password: `Test@1234`

**Test Steps**
1. Enter the test data.
2. Tap **Sign In**.
3. Turn the internet ON and tap **Sign In** again.

**Expected Result**
- While offline: "No internet connection. Please check your network and try again."
- After reconnecting: login succeeds and Home opens.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-LOGIN-009 — Internet lost during sign-in

| Field | Detail |
|---|---|
| **Test Case ID** | TC-LOGIN-009 |
| **Test Case Title** | Internet lost during sign-in |
| **Related Test Scenario** | TS-LOGIN-004 — Verify that login handles network problems. |
| **Module/Feature** | Login |
| **Test Objective** | Verify the app does not freeze when the connection drops mid-request. |
| **Priority** | Medium |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The tester is signed out and is on the Login screen.
- Valid credentials typed in.

**Test Data**
- None needed.

**Test Steps**
1. Tap **Sign In**.
2. Immediately switch on airplane mode.
3. Wait up to 30 seconds.

**Expected Result**
- The loading indicator ends; a friendly message appears (network or timeout text).
- The Sign In button becomes tappable again.
- No technical text is shown.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** The result depends on timing; login may also succeed if the request finished first.

---

### TC-LOGIN-010 — Unverified account is sent to Verify Email

| Field | Detail |
|---|---|
| **Test Case ID** | TC-LOGIN-010 |
| **Test Case Title** | Unverified account is sent to Verify Email |
| **Related Test Scenario** | TS-LOGIN-005 — Verify that unverified and suspended accounts are handled correctly. |
| **Module/Feature** | Login |
| **Test Objective** | Verify an unverified account cannot reach the main app. |
| **Priority** | High |
| **Test Type** | Security |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The tester is signed out and is on the Login screen.
- An account exists whose email is NOT verified (e.g., the one from TC-REG-001).

**Test Data**
- None needed.

**Test Steps**
1. Sign in with the unverified account.
2. After landing on the next screen, try to open Home by other means (e.g., relaunch the app).

**Expected Result**
- The user is taken to **Verify your email** instead of Home.
- After relaunch the user is still routed to Verify Email.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-LOGIN-011 — Suspended account is signed out

| Field | Detail |
|---|---|
| **Test Case ID** | TC-LOGIN-011 |
| **Test Case Title** | Suspended account is signed out |
| **Related Test Scenario** | TS-LOGIN-005 — Verify that unverified and suspended accounts are handled correctly. |
| **Module/Feature** | Login |
| **Test Objective** | Verify a suspended traveler cannot stay signed in. |
| **Priority** | High |
| **Test Type** | Security |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The tester is signed out and is on the Login screen.
- A verified traveler account whose status is "suspended" (set from Admin Portal > Travelers > Suspend).

**Test Data**
- None needed.

**Test Steps**
1. Sign in with the suspended account.

**Expected Result**
- The user is returned to the Login screen.
- The message "This account has been suspended. Contact support for help." is shown.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Needs manual verification: whether the Home screen flashes briefly before sign-out.

---

### TC-LOGIN-012 — Suspend an account while the traveler is using the app

| Field | Detail |
|---|---|
| **Test Case ID** | TC-LOGIN-012 |
| **Test Case Title** | Suspend an account while the traveler is using the app |
| **Related Test Scenario** | TS-LOGIN-005 — Verify that unverified and suspended accounts are handled correctly. |
| **Module/Feature** | Login |
| **Test Objective** | Verify suspension is enforced live during a session. |
| **Priority** | Medium |
| **Test Type** | Security |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- A second person/browser is logged in to the Admin Portal as an admin.

**Test Data**
- None needed.

**Test Steps**
1. On the traveler device, stay on the Home screen.
2. On the Admin Portal, open **Travelers**, find the traveler and suspend the account.
3. Watch the traveler device for up to one minute.

**Expected Result**
- The traveler is signed out automatically and sees the Login screen with the suspension message.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-LOGIN-013 — Too many failed login attempts

| Field | Detail |
|---|---|
| **Test Case ID** | TC-LOGIN-013 |
| **Test Case Title** | Too many failed login attempts |
| **Related Test Scenario** | TS-LOGIN-004 — Verify that login handles network problems. |
| **Module/Feature** | Login |
| **Test Objective** | Verify the friendly rate-limit message. |
| **Priority** | Low |
| **Test Type** | Negative |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The tester is signed out and is on the Login screen.

**Test Data**
- Email: `tester01@example.com`
- Wrong password entered repeatedly

**Test Steps**
1. Enter a wrong password and tap **Sign In**.
2. Repeat about 10 times in a row.

**Expected Result**
- At some point the message "Too many attempts. Please wait a moment and try again." appears (instead of a Firebase code).

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Firebase decides when to throttle. If it does not throttle, record "not triggered".

---

### TC-LOGIN-014 — Session stays after closing and reopening the app

| Field | Detail |
|---|---|
| **Test Case ID** | TC-LOGIN-014 |
| **Test Case Title** | Session stays after closing and reopening the app |
| **Related Test Scenario** | TS-LOGIN-006 — Verify session persistence across app restarts. |
| **Module/Feature** | Login |
| **Test Objective** | Verify the user remains signed in. |
| **Priority** | High |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).

**Test Data**
- None needed.

**Test Steps**
1. Close the app completely (swipe it away).
2. Open the app.
3. Wait for the splash screen.

**Expected Result**
- The user goes directly to Home without seeing Login.
- Saved data (favorites, trips) is still visible.

**Postconditions:** The user remains signed in.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-LOGIN-015 — Continue with Google — success

| Field | Detail |
|---|---|
| **Test Case ID** | TC-LOGIN-015 |
| **Test Case Title** | Continue with Google — success |
| **Related Test Scenario** | TS-LOGIN-007 — Verify Google sign-in success, cancellation and failure. |
| **Module/Feature** | Login |
| **Test Objective** | Verify Google sign-in signs the user in. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The tester is signed out and is on the Login screen.
- A Google account is available on the device.

**Test Data**
- None needed.

**Test Steps**
1. On Login, tap **Continue with Google**.
2. Choose the Google account.

**Expected Result**
- The Google account chooser appears.
- After choosing, the user is signed in and Home opens.
- A traveler profile is created if this is the first sign-in.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Needs manual verification of email-verified status for Google accounts on each platform (Android/iOS/Web).

---

### TC-LOGIN-016 — Continue with Google — user cancels

| Field | Detail |
|---|---|
| **Test Case ID** | TC-LOGIN-016 |
| **Test Case Title** | Continue with Google — user cancels |
| **Related Test Scenario** | TS-LOGIN-007 — Verify Google sign-in success, cancellation and failure. |
| **Module/Feature** | Login |
| **Test Objective** | Verify cancelling the Google chooser shows a friendly message. |
| **Priority** | Medium |
| **Test Type** | Negative |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The tester is signed out and is on the Login screen.

**Test Data**
- None needed.

**Test Steps**
1. Tap **Continue with Google**.
2. Close the account chooser without selecting an account (tap outside / Back).

**Expected Result**
- The user stays on Login.
- The message "Sign-in was cancelled." is shown; the app does not crash.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-LOGIN-017 — Continue with Google while offline

| Field | Detail |
|---|---|
| **Test Case ID** | TC-LOGIN-017 |
| **Test Case Title** | Continue with Google while offline |
| **Related Test Scenario** | TS-LOGIN-007 — Verify Google sign-in success, cancellation and failure. |
| **Module/Feature** | Login |
| **Test Objective** | Verify a network message is shown. |
| **Priority** | Medium |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The tester is signed out and is on the Login screen.
- Internet OFF.

**Test Data**
- None needed.

**Test Steps**
1. Tap **Continue with Google**.

**Expected Result**
- A friendly message appears ("No internet connection. Please check your network and try again." or a generic "Something went wrong. Please try again.").
- No raw platform error text is visible.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

## Forgot Password (OTP)

### TC-PWD-001 — Request a reset code for a registered email

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PWD-001 |
| **Test Case Title** | Request a reset code for a registered email |
| **Related Test Scenario** | TS-PWD-001 — Verify a traveler can request a 6-digit reset code by email. |
| **Module/Feature** | Forgot Password (OTP) |
| **Test Objective** | Verify step 2 (Enter the code) opens after requesting a code. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The tester is signed out and is on the Login screen.
- Account `tester01@example.com` exists and its inbox can be read.

**Test Data**
- None needed.

**Test Steps**
1. On Login, tap **Forgot Password?**.
2. Enter `tester01@example.com`.
3. Tap **Send Code**.
4. Check the inbox of the email.

**Expected Result**
- The screen changes to "Enter the code" with the text "We sent a 6-digit code to tester01@example.com. It expires in 10 minutes."
- An email with a 6-digit numeric code arrives.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Email delivery depends on the firestore-send-email extension; check spam folder too.

---

### TC-PWD-002 — Request a code for an unregistered email

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PWD-002 |
| **Test Case Title** | Request a code for an unregistered email |
| **Related Test Scenario** | TS-PWD-001 — Verify a traveler can request a 6-digit reset code by email. |
| **Module/Feature** | Forgot Password (OTP) |
| **Test Objective** | Verify the app does not reveal whether an email is registered. |
| **Priority** | Medium |
| **Test Type** | Security |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The tester is on Forgot Password step 1.

**Test Data**
- Email: `nobody.here99@example.com`

**Test Steps**
1. Enter the email.
2. Tap **Send Code**.

**Expected Result**
- The screen still moves to "Enter the code" (no "user not found" error).
- No email is delivered to that address (nothing exists to receive).

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-PWD-003 — Send Code with empty or invalid email

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PWD-003 |
| **Test Case Title** | Send Code with empty or invalid email |
| **Related Test Scenario** | TS-PWD-004 — Verify input validation and rate limits on the reset flow. |
| **Module/Feature** | Forgot Password (OTP) |
| **Test Objective** | Verify email validation on step 1. |
| **Priority** | Medium |
| **Test Type** | Validation |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The tester is on Forgot Password step 1.

**Test Data**
- None needed.

**Test Steps**
1. Leave Email empty and tap **Send Code**.
2. Type `abc@` and tap **Send Code**.

**Expected Result**
- Empty: "Email is required".
- Invalid: "Enter a valid email address".
- No request is sent.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-PWD-004 — Reset password with the correct code

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PWD-004 |
| **Test Case Title** | Reset password with the correct code |
| **Related Test Scenario** | TS-PWD-002 — Verify the password can be reset with a correct code and a valid new password. |
| **Module/Feature** | Forgot Password (OTP) |
| **Test Objective** | Verify the password is changed and the old password stops working. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A valid code was received within the last 10 minutes (TC-PWD-001) and step 2 is open.

**Test Data**
- Code: the 6-digit code from the email
- New password: `NewPass@123`
- Confirm: `NewPass@123`

**Test Steps**
1. Enter the code.
2. Enter the new password and confirm it.
3. Tap **Reset Password**.
4. On Login, sign in with the OLD password.
5. Sign in with `NewPass@123`.

**Expected Result**
- A message "Password updated. Sign in with your new password." appears and the app returns to Login.
- Old password: "Incorrect email or password."
- New password: login succeeds.

**Postconditions:** The account password is `NewPass@123`; the code cannot be reused.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-PWD-005 — Wrong code is rejected

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PWD-005 |
| **Test Case Title** | Wrong code is rejected |
| **Related Test Scenario** | TS-PWD-003 — Verify wrong, expired, and over-used codes are rejected. |
| **Module/Feature** | Forgot Password (OTP) |
| **Test Objective** | Verify an incorrect code shows a friendly message. |
| **Priority** | High |
| **Test Type** | Negative |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- Step 2 is open with a valid code already sent.

**Test Data**
- Code: `000000` (not the real code)
- New password: `NewPass@123`

**Test Steps**
1. Enter the wrong code and a valid new password (twice).
2. Tap **Reset Password**.

**Expected Result**
- The message "Incorrect code. Please try again." is shown.
- The password is not changed.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-PWD-006 — Code and new-password field validation

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PWD-006 |
| **Test Case Title** | Code and new-password field validation |
| **Related Test Scenario** | TS-PWD-004 — Verify input validation and rate limits on the reset flow. |
| **Module/Feature** | Forgot Password (OTP) |
| **Test Objective** | Verify client-side checks on step 2. |
| **Priority** | Medium |
| **Test Type** | Validation |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- Step 2 is open.

**Test Data**
- Code cases: empty, `12345`, `12ab56`, `1234567`
- Password case: `Ab@1234` (7 chars)
- Confirm case: different from password

**Test Steps**
1. Tap **Reset Password** with all fields empty.
2. Enter `12345` in the code field and tap **Reset Password**.
3. Enter `12ab56` and tap **Reset Password**.
4. Enter a valid code, a 7-character new password and tap **Reset Password**.
5. Enter a valid password and a different confirm value; tap **Reset Password**.

**Expected Result**
- Empty code: "Enter the 6-digit code".
- `12345` or `12ab56`: "Code must be 6 digits".
- 7-character password: "Password must be at least 8 characters".
- Mismatch: "Passwords do not match".
- No request is sent while any error is showing.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** `1234567` (7 digits) should also give "Code must be 6 digits" if the field allows 7 characters.

---

### TC-PWD-007 — Expired code (older than 10 minutes)

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PWD-007 |
| **Test Case Title** | Expired code (older than 10 minutes) |
| **Related Test Scenario** | TS-PWD-003 — Verify wrong, expired, and over-used codes are rejected. |
| **Module/Feature** | Forgot Password (OTP) |
| **Test Objective** | Verify an expired code is rejected. |
| **Priority** | Medium |
| **Test Type** | Negative |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A code was requested more than 10 minutes ago and step 2 is still open (or reopen the flow and use the old code).

**Test Data**
- None needed.

**Test Steps**
1. Wait more than 10 minutes after receiving the code.
2. Enter the old code and a valid new password.
3. Tap **Reset Password**.

**Expected Result**
- The message "This code has expired. Please request a new one." is shown.
- The password is unchanged.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-PWD-008 — Five wrong attempts lock the code

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PWD-008 |
| **Test Case Title** | Five wrong attempts lock the code |
| **Related Test Scenario** | TS-PWD-003 — Verify wrong, expired, and over-used codes are rejected. |
| **Module/Feature** | Forgot Password (OTP) |
| **Test Objective** | Verify the attempt limit of 5 wrong codes. |
| **Priority** | Medium |
| **Test Type** | Security |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- Step 2 is open with a valid code sent.

**Test Data**
- None needed.

**Test Steps**
1. Enter a wrong code and tap **Reset Password**. Repeat until 5 wrong tries were made.
2. On the 6th try, enter the CORRECT code.

**Expected Result**
- Tries 1–5: "Incorrect code. Please try again."
- 6th try (even with the right code): "Too many incorrect attempts. Please request a new code."
- After tapping **Resend code**, a new code works.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-PWD-009 — Resend code and hourly request limit

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PWD-009 |
| **Test Case Title** | Resend code and hourly request limit |
| **Related Test Scenario** | TS-PWD-004 — Verify input validation and rate limits on the reset flow. |
| **Module/Feature** | Forgot Password (OTP) |
| **Test Objective** | Verify the Resend code button and the 5-requests-per-hour limit. |
| **Priority** | Low |
| **Test Type** | Boundary |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- Step 2 is open for `tester01@example.com`; no reset code requested in the last hour.

**Test Data**
- None needed.

**Test Steps**
1. Tap **Resend code** and check the inbox.
2. Keep tapping **Resend code** until the total number of requests (including the first) reaches 6.

**Expected Result**
- Each of the first 5 requests succeeds and a new code email is sent (the latest code replaces the earlier one).
- The 6th request shows "You're doing that too often — please wait a bit and try again."

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Limit is 5 requests per hour per email (functions/index.js). Testing consumes the tester account's quota for one hour. Bug fixed: Resend code used to crash (null form state); see test/widgets/forgot_password_screen_test.dart.

---

### TC-PWD-010 — Back button on the code step

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PWD-010 |
| **Test Case Title** | Back button on the code step |
| **Related Test Scenario** | TS-PWD-004 — Verify input validation and rate limits on the reset flow. |
| **Module/Feature** | Forgot Password (OTP) |
| **Test Objective** | Verify the back arrow returns from step 2 to step 1. |
| **Priority** | Low |
| **Test Type** | Usability |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- Step 2 is open.

**Test Data**
- None needed.

**Test Steps**
1. Tap the back arrow at the top left.

**Expected Result**
- The screen returns to the email step ("Reset your password") instead of leaving the flow.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-PWD-011 — Reset password while offline

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PWD-011 |
| **Test Case Title** | Reset password while offline |
| **Related Test Scenario** | TS-PWD-001 — Verify a traveler can request a 6-digit reset code by email. |
| **Module/Feature** | Forgot Password (OTP) |
| **Test Objective** | Verify a friendly network message during code request. |
| **Priority** | Medium |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- Step 1 is open with a valid email typed; internet OFF.

**Test Data**
- None needed.

**Test Steps**
1. Tap **Send Code**.

**Expected Result**
- A friendly message appears ("No internet connection..." or a generic try-again message).
- The app stays on step 1.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

## Email Verification

### TC-VER-001 — Verify email with a correct code

| Field | Detail |
|---|---|
| **Test Case ID** | TC-VER-001 |
| **Test Case Title** | Verify email with a correct code |
| **Related Test Scenario** | TS-VER-001 — Verify an unverified user can request and enter a 6-digit verification code. |
| **Module/Feature** | Email Verification |
| **Test Objective** | Verify the flow from sending a code to reaching Home. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The tester is signed in with an unverified account and is on **Verify your email**.

**Test Data**
- None needed.

**Test Steps**
1. Tap **Send Verification Code**.
2. Read the 6-digit code from the email inbox.
3. Enter the code in the "6-digit code" field.
4. Tap **Verify Code**.

**Expected Result**
- After step 1 the text "Verification code sent." appears and a code field plus **Verify Code** and **Send New Code** buttons are shown.
- After step 4 the account becomes verified and the app opens **Home**.

**Postconditions:** The account email is marked verified.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-VER-002 — Incorrect verification code

| Field | Detail |
|---|---|
| **Test Case ID** | TC-VER-002 |
| **Test Case Title** | Incorrect verification code |
| **Related Test Scenario** | TS-VER-002 — Verify wrong/expired codes and polling behavior on the Verify Email screen. |
| **Module/Feature** | Email Verification |
| **Test Objective** | Verify wrong and badly formatted codes are rejected. |
| **Priority** | High |
| **Test Type** | Negative |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- Code field is visible on Verify Email (a code was requested).

**Test Data**
- `123`
- `000000`

**Test Steps**
1. Enter `123` and tap **Verify Code**.
2. Enter `000000` and tap **Verify Code**.

**Expected Result**
- `123`: "Code must be 6 digits".
- `000000`: "Incorrect code. Please try again."
- The user stays on Verify Email.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-VER-003 — Verification via another device is detected automatically

| Field | Detail |
|---|---|
| **Test Case ID** | TC-VER-003 |
| **Test Case Title** | Verification via another device is detected automatically |
| **Related Test Scenario** | TS-VER-002 — Verify wrong/expired codes and polling behavior on the Verify Email screen. |
| **Module/Feature** | Email Verification |
| **Test Objective** | Verify the 4-second polling moves the user forward after verification. |
| **Priority** | Low |
| **Test Type** | Integration |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The tester is on Verify Email with an unverified account.

**Test Data**
- None needed.

**Test Steps**
1. Verify the same account by another way (e.g., request a code on a second device signed in to the same account and verify it).
2. Keep the first device on the Verify Email screen and wait up to 10 seconds.

**Expected Result**
- The first device moves to Home without any tap.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Needs manual verification: only one device can normally hold the code. The tester may also use the Firebase Console to set the user to verified.

---

### TC-VER-004 — Polling stops after about 2 minutes

| Field | Detail |
|---|---|
| **Test Case ID** | TC-VER-004 |
| **Test Case Title** | Polling stops after about 2 minutes |
| **Related Test Scenario** | TS-VER-002 — Verify wrong/expired codes and polling behavior on the Verify Email screen. |
| **Module/Feature** | Email Verification |
| **Test Objective** | Verify the "Still waiting?" hint appears after 30 polls. |
| **Priority** | Low |
| **Test Type** | Functional |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The tester is on Verify Email with an unverified account.

**Test Data**
- None needed.

**Test Steps**
1. Stay on the screen for more than 2 minutes without verifying.

**Expected Result**
- The hint "Still waiting? Check your spam folder, or send a code below." appears.
- The user can still send and enter a code.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-VER-005 — "I've already verified" while still unverified

| Field | Detail |
|---|---|
| **Test Case ID** | TC-VER-005 |
| **Test Case Title** | "I've already verified" while still unverified |
| **Related Test Scenario** | TS-VER-002 — Verify wrong/expired codes and polling behavior on the Verify Email screen. |
| **Module/Feature** | Email Verification |
| **Test Objective** | Verify the manual check does not let an unverified user in. |
| **Priority** | Low |
| **Test Type** | Negative |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- Unverified account on Verify Email; no code requested yet (the button is visible).

**Test Data**
- None needed.

**Test Steps**
1. Tap **I've already verified**.

**Expected Result**
- The user stays on Verify Email; no crash and no technical message.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-VER-006 — Sign out from Verify Email

| Field | Detail |
|---|---|
| **Test Case ID** | TC-VER-006 |
| **Test Case Title** | Sign out from Verify Email |
| **Related Test Scenario** | TS-VER-003 — Verify signing out from the Verify Email screen. |
| **Module/Feature** | Email Verification |
| **Test Objective** | Verify the Sign out link asks for confirmation and returns to Login. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- Unverified account on Verify Email.

**Test Data**
- None needed.

**Test Steps**
1. Tap **Sign out**.
2. In the "Log out?" dialog (message: "You can sign back in anytime with the same account."), tap **Log Out**.

**Expected Result**
- The user is signed out and the Login screen is shown.

**Postconditions:** No user is signed in.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-VER-007 — Verification code limit and expiry

| Field | Detail |
|---|---|
| **Test Case ID** | TC-VER-007 |
| **Test Case Title** | Verification code limit and expiry |
| **Related Test Scenario** | TS-VER-001 — Verify an unverified user can request and enter a 6-digit verification code. |
| **Module/Feature** | Email Verification |
| **Test Objective** | Verify the 5 requests-per-hour limit and the 10-minute expiry message. |
| **Priority** | Low |
| **Test Type** | Boundary |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- Unverified account on Verify Email; no code requested in the last hour.

**Test Data**
- None needed.

**Test Steps**
1. Tap **Send Verification Code**, then tap **Send New Code** until 6 requests are made in total.
2. Separately, wait 10+ minutes and enter an old code.

**Expected Result**
- The 6th request shows "You're doing that too often — please wait a bit and try again."
- An expired code shows "This code has expired. Please request a new one."

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

## Sign-out & Route Guard

### TC-SESS-001 — Log out from Profile

| Field | Detail |
|---|---|
| **Test Case ID** | TC-SESS-001 |
| **Test Case Title** | Log out from Profile |
| **Related Test Scenario** | TS-SESS-001 — Verify the user can log out and is then blocked from signed-in screens. |
| **Module/Feature** | Sign-out & Route Guard |
| **Test Objective** | Verify log-out confirmation and result. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).

**Test Data**
- None needed.

**Test Steps**
1. Open the **Profile** tab.
2. Tap **Log Out**.
3. In the "Log out?" dialog tap **Cancel** (or dismiss) and check the screen.
4. Tap **Log Out** again and this time confirm with **Log Out**.

**Expected Result**
- Cancel keeps the user signed in on Profile.
- Confirming signs the user out and the Login screen is shown.

**Postconditions:** No user is signed in.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-SESS-002 — Signed-out user cannot open app screens

| Field | Detail |
|---|---|
| **Test Case ID** | TC-SESS-002 |
| **Test Case Title** | Signed-out user cannot open app screens |
| **Related Test Scenario** | TS-SESS-001 — Verify the user can log out and is then blocked from signed-in screens. |
| **Module/Feature** | Sign-out & Route Guard |
| **Test Objective** | Verify the router sends signed-out users to Login. |
| **Priority** | Medium |
| **Test Type** | Security |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The tester is signed out.

**Test Data**
- None needed.

**Test Steps**
1. On the web build, type a signed-in URL such as `/saved` or `/planner` in the browser address bar and press Enter.

**Expected Result**
- The Login screen is shown instead of the requested page.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Web only. On mobile, deep links are not exposed, so this is a web check.

---

### TC-SESS-003 — Signed-in user is redirected away from Login

| Field | Detail |
|---|---|
| **Test Case ID** | TC-SESS-003 |
| **Test Case Title** | Signed-in user is redirected away from Login |
| **Related Test Scenario** | TS-SESS-001 — Verify the user can log out and is then blocked from signed-in screens. |
| **Module/Feature** | Sign-out & Route Guard |
| **Test Objective** | Verify a signed-in, verified user cannot reopen Login/Register. |
| **Priority** | Low |
| **Test Type** | Security |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Web build open.

**Test Data**
- None needed.

**Test Steps**
1. In the address bar go to `/login`, then `/register`.

**Expected Result**
- In both cases the app redirects to **Home**.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Web only.

---

## Home

### TC-HOME-001 — Home screen loads its sections

| Field | Detail |
|---|---|
| **Test Case ID** | TC-HOME-001 |
| **Test Case Title** | Home screen loads its sections |
| **Related Test Scenario** | TS-HOME-001 — Verify the Home screen loads its content sections for a signed-in traveler. |
| **Module/Feature** | Home |
| **Test Objective** | Verify the main Home sections are displayed. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Content (destinations, restaurants, festivals, travel tips) exists in the database.

**Test Data**
- None needed.

**Test Steps**
1. Open the app and land on **Home**.
2. Scroll from top to bottom.

**Expected Result**
- Sections appear with images and text: **Featured Destinations**, **Popular Restaurants**, **Upcoming Festivals**, **Travel Tips**.
- **Nearby You** and **Nearby Restaurants** appear when the location is available.
- Loading placeholders are replaced by real content; no error text is visible.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-HOME-002 — Allow location permission on Home

| Field | Detail |
|---|---|
| **Test Case ID** | TC-HOME-002 |
| **Test Case Title** | Allow location permission on Home |
| **Related Test Scenario** | TS-HOME-002 — Verify location permission handling on Home (allowed, denied, denied permanently, services off). |
| **Module/Feature** | Home |
| **Test Objective** | Verify "nearby" sections appear after granting permission. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Device location services are ON.
- Location permission for TripNest PH is not yet granted (fresh install or reset permissions).

**Test Data**
- None needed.

**Test Steps**
1. Open **Home**.
2. If the "See what's nearby" card shows, tap **Allow Location**.
3. In the system dialog choose **While using the app** (or Allow).

**Expected Result**
- The card message before granting reads "Allow location access to see the tourist spots closest to you."
- After allowing, the card disappears and **Nearby You** shows attractions sorted around the current location.

**Postconditions:** Location permission is granted.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-HOME-003 — Deny location permission

| Field | Detail |
|---|---|
| **Test Case ID** | TC-HOME-003 |
| **Test Case Title** | Deny location permission |
| **Related Test Scenario** | TS-HOME-002 — Verify location permission handling on Home (allowed, denied, denied permanently, services off). |
| **Module/Feature** | Home |
| **Test Objective** | Verify the app keeps working and offers to ask again. |
| **Priority** | High |
| **Test Type** | Negative |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Location services ON; permission not granted yet.

**Test Data**
- None needed.

**Test Steps**
1. Open **Home** and trigger the permission request (tap **Allow Location**).
2. In the system dialog choose **Deny**.
3. Scroll through Home.
4. Tap **Allow Location** again.

**Expected Result**
- Home still shows Featured Destinations, Restaurants, Festivals and Tips.
- The card still says "Allow location access to see the tourist spots closest to you." with **Allow Location**.
- Tapping it shows the system permission dialog again.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-HOME-004 — Location permission denied permanently

| Field | Detail |
|---|---|
| **Test Case ID** | TC-HOME-004 |
| **Test Case Title** | Location permission denied permanently |
| **Related Test Scenario** | TS-HOME-002 — Verify location permission handling on Home (allowed, denied, denied permanently, services off). |
| **Module/Feature** | Home |
| **Test Objective** | Verify the app points the user to App Settings. |
| **Priority** | High |
| **Test Type** | Negative |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Location permission was denied with "Don't ask again" / denied permanently.

**Test Data**
- None needed.

**Test Steps**
1. Open **Home**.
2. Read the location card.
3. Tap **Open App Settings**.
4. Enable Location in the system settings and return to the app.
5. Pull down to refresh Home (or tap the card's action again).

**Expected Result**
- The card reads "Location access is turned off for TripNest PH. Enable it in Settings to see spots near you." with **Open App Settings**.
- The phone's app settings page opens.
- After enabling and returning, nearby sections appear.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-HOME-005 — Device location services turned off

| Field | Detail |
|---|---|
| **Test Case ID** | TC-HOME-005 |
| **Test Case Title** | Device location services turned off |
| **Related Test Scenario** | TS-HOME-002 — Verify location permission handling on Home (allowed, denied, denied permanently, services off). |
| **Module/Feature** | Home |
| **Test Objective** | Verify the message when GPS/location service is disabled. |
| **Priority** | Medium |
| **Test Type** | Negative |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Device location (GPS) is switched OFF in quick settings.

**Test Data**
- None needed.

**Test Steps**
1. Open **Home**.
2. Read the location card.
3. Tap **Open Location Settings**.

**Expected Result**
- The card reads "Turn on location services on your device to see the tourist spots closest to you."
- The system location settings screen opens.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-HOME-006 — Location cannot be determined

| Field | Detail |
|---|---|
| **Test Case ID** | TC-HOME-006 |
| **Test Case Title** | Location cannot be determined |
| **Related Test Scenario** | TS-HOME-002 — Verify location permission handling on Home (allowed, denied, denied permanently, services off). |
| **Module/Feature** | Home |
| **Test Objective** | Verify the "Try Again" state. |
| **Priority** | Low |
| **Test Type** | Negative |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Permission is granted but the device cannot get a fix (e.g., indoors with GPS disabled in mock settings, or emulator without a set location).

**Test Data**
- None needed.

**Test Steps**
1. Open **Home**.
2. Tap **Try Again** on the location card.

**Expected Result**
- Message "We couldn't get your location just now. Please try again." with **Try Again**.
- Tapping it retries; if it still fails, the same message stays and the app does not crash.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Hard to reproduce on a real device; use an emulator with no location set.

---

### TC-HOME-007 — Pull down to refresh Home

| Field | Detail |
|---|---|
| **Test Case ID** | TC-HOME-007 |
| **Test Case Title** | Pull down to refresh Home |
| **Related Test Scenario** | TS-HOME-003 — Verify pull-to-refresh and behavior when Home cannot load. |
| **Module/Feature** | Home |
| **Test Objective** | Verify pull-to-refresh reloads content. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The tester is on Home.

**Test Data**
- None needed.

**Test Steps**
1. Add or change a festival in the Admin Portal (optional).
2. On Home, pull down from the top of the screen and release.

**Expected Result**
- A refresh indicator appears and then disappears.
- Content is reloaded (new/changed items appear if data changed).

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-HOME-008 — Home opened while offline

| Field | Detail |
|---|---|
| **Test Case ID** | TC-HOME-008 |
| **Test Case Title** | Home opened while offline |
| **Related Test Scenario** | TS-HOME-003 — Verify pull-to-refresh and behavior when Home cannot load. |
| **Module/Feature** | Home |
| **Test Objective** | Verify offline behavior and recovery. |
| **Priority** | High |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Home was opened at least once with internet (so data can be cached).

**Test Data**
- None needed.

**Test Steps**
1. Turn Wi-Fi and mobile data OFF.
2. Close the app fully and reopen it.
3. Observe Home and the top of the screen.
4. Turn the internet ON and pull down to refresh.

**Expected Result**
- A banner reads "You're offline — showing saved data".
- Previously loaded content is shown, or a friendly error state whose title begins with "Couldn't" appears with no technical text.
- After reconnecting and refreshing, the banner disappears and content loads.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** The project documentation says there is no offline cache, but the code enables Firestore persistence and shows this banner. Record what really happens.

---

## Explore

### TC-EXP-001 — Browse each Explore tab

| Field | Detail |
|---|---|
| **Test Case ID** | TC-EXP-001 |
| **Test Case Title** | Browse each Explore tab |
| **Related Test Scenario** | TS-EXP-001 — Verify Explore lists destinations, restaurants, festivals and businesses with paging. |
| **Module/Feature** | Explore |
| **Test Objective** | Verify all four tabs load their own lists. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).

**Test Data**
- None needed.

**Test Steps**
1. Tap the **Explore** bottom tab.
2. View the Destinations list.
3. Switch to the Restaurants tab, then Festivals, then the local businesses tab.

**Expected Result**
- Each tab shows cards in a two-column responsive grid with image, name and rating/date info.
- Switching tabs shows a different list each time without a crash.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Exact tab labels for the local-business tab need manual verification.

---

### TC-EXP-002 — Load More paging (20 items per page)

| Field | Detail |
|---|---|
| **Test Case ID** | TC-EXP-002 |
| **Test Case Title** | Load More paging (20 items per page) |
| **Related Test Scenario** | TS-EXP-001 — Verify Explore lists destinations, restaurants, festivals and businesses with paging. |
| **Module/Feature** | Explore |
| **Test Objective** | Verify paging loads the next page without duplicates. |
| **Priority** | Medium |
| **Test Type** | Boundary |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- More than 20 destinations exist in the database.

**Test Data**
- None needed.

**Test Steps**
1. Open **Explore** > Destinations.
2. Scroll to the bottom and count the cards shown.
3. Tap **Load More**.
4. Check the list again for repeated cards.

**Expected Result**
- About 20 cards are shown first.
- After **Load More**, additional cards are added below.
- No card appears twice.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-EXP-003 — Apply filters and reset them

| Field | Detail |
|---|---|
| **Test Case ID** | TC-EXP-003 |
| **Test Case Title** | Apply filters and reset them |
| **Related Test Scenario** | TS-EXP-002 — Verify filters (category, region, province, rating, budget, distance, accessibility) narrow Explore results. |
| **Module/Feature** | Explore |
| **Test Objective** | Verify the Filter Results sheet applies and clears filters. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The tester is on Explore > Destinations.

**Test Data**
- Region: any region
- Minimum Rating: `4.0+ ★`
- Distance: `Within 25 km` (location permission granted)

**Test Steps**
1. Open the filter and wait for "Loading regions..." to finish.
2. Choose a Region, then a Province.
3. Select Minimum Rating `4.0+ ★`.
4. Select Distance `Within 25 km`.
5. Tap **Apply**.
6. Open the filter again and tap **Reset**, then **Apply**.

**Expected Result**
- Filter chips for the chosen options are shown after Apply.
- Only matching destinations remain (all with rating 4.0 or more, in the chosen province, within 25 km).
- After Reset + Apply the full list returns.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-EXP-004 — Budget and accessibility filters on restaurants

| Field | Detail |
|---|---|
| **Test Case ID** | TC-EXP-004 |
| **Test Case Title** | Budget and accessibility filters on restaurants |
| **Related Test Scenario** | TS-EXP-002 — Verify filters (category, region, province, rating, budget, distance, accessibility) narrow Explore results. |
| **Module/Feature** | Explore |
| **Test Objective** | Verify price-tier and accessibility filtering behavior. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Restaurant data with price range (₱, ₱₱, ₱₱₱) exists; at least one restaurant has an accessibility tag.

**Test Data**
- None needed.

**Test Steps**
1. Open **Explore** > Restaurants.
2. Open the filter, choose Budget `₱ Budget-friendly`, then tap **Apply**.
3. Open the filter again, keep Budget and also choose one Accessibility tag, then **Apply**.

**Expected Result**
- With Budget only: restaurants with one ₱ sign are shown.
- With the accessibility tag also selected: only restaurants that have that tag remain; items with no accessibility data are hidden.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-EXP-005 — Filters that match nothing

| Field | Detail |
|---|---|
| **Test Case ID** | TC-EXP-005 |
| **Test Case Title** | Filters that match nothing |
| **Related Test Scenario** | TS-EXP-003 — Verify empty and error states on Explore. |
| **Module/Feature** | Explore |
| **Test Objective** | Verify the empty state. |
| **Priority** | Medium |
| **Test Type** | Negative |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The tester is on Explore > Destinations.

**Test Data**
- None needed.

**Test Steps**
1. Open the filter and pick Minimum Rating `4.5+ ★` together with Distance `Within 5 km` in an area with no matching spots.
2. Tap **Apply**.

**Expected Result**
- An empty state with the title "Nothing here yet" (or similar) is shown instead of a blank screen.
- Filters can be changed or reset.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-EXP-006 — Explore loading fails (network dropped)

| Field | Detail |
|---|---|
| **Test Case ID** | TC-EXP-006 |
| **Test Case Title** | Explore loading fails (network dropped) |
| **Related Test Scenario** | TS-EXP-003 — Verify empty and error states on Explore. |
| **Module/Feature** | Explore |
| **Test Objective** | Verify a friendly error state with recovery. |
| **Priority** | High |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The tester has not opened Explore in this session; internet is ON.

**Test Data**
- None needed.

**Test Steps**
1. Turn the internet OFF.
2. Tap the **Explore** tab.
3. Turn the internet ON.
4. Pull down to refresh.

**Expected Result**
- A friendly error state (title starting with "Couldn't ...") or cached content with the offline banner is shown; no stack trace or error code appears.
- After refresh with internet ON, the list loads.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

## Search

### TC-SRCH-001 — Search for an existing destination

| Field | Detail |
|---|---|
| **Test Case ID** | TC-SRCH-001 |
| **Test Case Title** | Search for an existing destination |
| **Related Test Scenario** | TS-SRCH-001 — Verify live search returns matching destinations, restaurants, festivals and live places. |
| **Module/Feature** | Search |
| **Test Objective** | Verify results appear while typing. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- A destination named "Boracay" (or another known name) exists.

**Test Data**
- Query: `Boracay`

**Test Steps**
1. Open the search screen from Home/Explore (tap the search bar).
2. Type `Boracay` in the box "Search destinations, food, festivals...".
3. Wait about 1 second.

**Expected Result**
- Matching results appear without pressing Enter (about 0.35 second after typing stops).
- Results include the destination; a "More places" section may show live Google Places results (only for queries of 3+ characters).
- Tapping a result opens its details screen.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-SRCH-002 — Search with a slightly misspelled word

| Field | Detail |
|---|---|
| **Test Case ID** | TC-SRCH-002 |
| **Test Case Title** | Search with a slightly misspelled word |
| **Related Test Scenario** | TS-SRCH-003 — Verify search handles empty input, no results, special characters and very long input. |
| **Module/Feature** | Search |
| **Test Objective** | Verify typo tolerance. |
| **Priority** | Low |
| **Test Type** | Functional |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Destination "Boracay" exists.

**Test Data**
- Query: `Boracy`

**Test Steps**
1. Open search.
2. Type `Boracy`.

**Expected Result**
- "Boracay" still appears in the results (small typos are tolerated).

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Code allows up to about 30% of the word length in edits (1 to 3). Check with 1 and 2 letter mistakes.

---

### TC-SRCH-003 — Search with no matching result

| Field | Detail |
|---|---|
| **Test Case ID** | TC-SRCH-003 |
| **Test Case Title** | Search with no matching result |
| **Related Test Scenario** | TS-SRCH-003 — Verify search handles empty input, no results, special characters and very long input. |
| **Module/Feature** | Search |
| **Test Objective** | Verify the empty-result message. |
| **Priority** | Medium |
| **Test Type** | Negative |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).

**Test Data**
- Query: `zzzzqqqq`

**Test Steps**
1. Open search.
2. Type `zzzzqqqq`.

**Expected Result**
- A message with the title `No results for "zzzzqqqq"` is shown.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-SRCH-004 — Empty query, spaces and clearing the box

| Field | Detail |
|---|---|
| **Test Case ID** | TC-SRCH-004 |
| **Test Case Title** | Empty query, spaces and clearing the box |
| **Related Test Scenario** | TS-SRCH-003 — Verify search handles empty input, no results, special characters and very long input. |
| **Module/Feature** | Search |
| **Test Objective** | Verify no search runs for blank text and suggestions return when the box is emptied. |
| **Priority** | Low |
| **Test Type** | Boundary |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).

**Test Data**
- None needed.

**Test Steps**
1. Open search and type three spaces.
2. Type `Cebu`, wait for results, then delete all text.

**Expected Result**
- Spaces only: no results/no error; recent/trending suggestions remain visible.
- After deleting `Cebu`, results disappear and the suggestions (recent/trending) view returns.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-SRCH-005 — Special characters and very long text

| Field | Detail |
|---|---|
| **Test Case ID** | TC-SRCH-005 |
| **Test Case Title** | Special characters and very long text |
| **Related Test Scenario** | TS-SRCH-003 — Verify search handles empty input, no results, special characters and very long input. |
| **Module/Feature** | Search |
| **Test Objective** | Verify the app does not crash on unusual input. |
| **Priority** | Medium |
| **Test Type** | Security |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).

**Test Data**
- `@#$%^&*()`
- `<script>alert(1)</script>`
- 300 characters of the letter `a`

**Test Steps**
1. Open search.
2. Enter each value one by one, waiting for the result each time.

**Expected Result**
- The app shows "No results ..." (or a friendly message) for each value.
- No crash, freeze, raw error, or script execution occurs.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-SRCH-006 — Recent searches: save, limit of 8 and clear

| Field | Detail |
|---|---|
| **Test Case ID** | TC-SRCH-006 |
| **Test Case Title** | Recent searches: save, limit of 8 and clear |
| **Related Test Scenario** | TS-SRCH-002 — Verify recent searches are saved (max 8) and can be cleared. |
| **Module/Feature** | Search |
| **Test Objective** | Verify the history keeps the latest 8 and can be cleared. |
| **Priority** | Medium |
| **Test Type** | Boundary |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Recent search history is empty (Settings > Clear Recent Searches, or fresh install).

**Test Data**
- Queries: Cebu, Bohol, Baguio, Palawan, Siargao, Sagada, Vigan, Davao, Clark

**Test Steps**
1. Search for each query in order, pausing at least 2 seconds after each so it is recorded.
2. Clear the search box and read the Recent searches list.
3. Tap **Clear** next to Recent, then confirm **Clear Recent Searches?**.

**Expected Result**
- Only the 8 latest queries are listed; the oldest (`Cebu`) is gone.
- After confirming, the recent list is empty; favorites and reviews are unaffected.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-SRCH-007 — Search with filters and offline behavior

| Field | Detail |
|---|---|
| **Test Case ID** | TC-SRCH-007 |
| **Test Case Title** | Search with filters and offline behavior |
| **Related Test Scenario** | TS-SRCH-004 — Verify search filters and behavior when the network drops. |
| **Module/Feature** | Search |
| **Test Objective** | Verify filter application in Search and a friendly error when the network drops. |
| **Priority** | Medium |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).

**Test Data**
- None needed.

**Test Steps**
1. Open search and type `beach`.
2. Open the filter, select Category = Beaches (or an available category) and **Apply**.
3. Turn the internet OFF.
4. Change the query to `waterfall`.

**Expected Result**
- With the filter, only items of that category are listed.
- After the internet is off, the screen shows a friendly title "Couldn't complete your search" (or shows cached results) with no technical text.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

## Details Screens

### TC-DET-001 — Open a destination details screen

| Field | Detail |
|---|---|
| **Test Case ID** | TC-DET-001 |
| **Test Case Title** | Open a destination details screen |
| **Related Test Scenario** | TS-DET-001 — Verify destination details show information, weather, map and actions. |
| **Module/Feature** | Details Screens |
| **Test Objective** | Verify all main sections of a destination are shown. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- A destination with coordinates, entrance fee and tips exists.

**Test Data**
- None needed.

**Test Steps**
1. From Home or Explore, tap a destination card.
2. Scroll through the whole screen.

**Expected Result**
- A hero image gallery is shown at the top.
- Sections/labels are shown: **About**, **Highlights**, **Location** (map), **Travel Tips**, **Getting Around**, stats such as **Rating**, **Best Time**, **Entrance Fee**.
- A live weather card is shown when the destination has coordinates.
- **Nearby Attractions**, **Nearby Restaurants** and **Nearby Hotels** are listed.

**Postconditions:** The destination is added to Recently Viewed.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-DET-002 — Get Directions opens the maps app

| Field | Detail |
|---|---|
| **Test Case ID** | TC-DET-002 |
| **Test Case Title** | Get Directions opens the maps app |
| **Related Test Scenario** | TS-DET-001 — Verify destination details show information, weather, map and actions. |
| **Module/Feature** | Details Screens |
| **Test Objective** | Verify the Get Directions action. |
| **Priority** | Medium |
| **Test Type** | Integration |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The tester is on a destination with coordinates; a maps or browser app exists on the device.

**Test Data**
- None needed.

**Test Steps**
1. Tap **Get Directions**.

**Expected Result**
- An external maps app (or browser Google Maps) opens with the destination.

**Postconditions:** The user can return to TripNest PH with the Back/app-switch.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-DET-003 — Get Directions when no maps app is available

| Field | Detail |
|---|---|
| **Test Case ID** | TC-DET-003 |
| **Test Case Title** | Get Directions when no maps app is available |
| **Related Test Scenario** | TS-DET-005 — Verify details screens behave when data is missing or the network fails. |
| **Module/Feature** | Details Screens |
| **Test Objective** | Verify the friendly failure message. |
| **Priority** | Low |
| **Test Type** | Negative |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- A device/emulator with no browser or maps app able to open the link.

**Test Data**
- None needed.

**Test Steps**
1. Tap **Get Directions**.

**Expected Result**
- A message "Couldn't open Maps. Please check that a maps or browser app is installed." appears; the app does not crash.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Hard to reproduce on a normal phone. Optional test.

---

### TC-DET-004 — Share a destination

| Field | Detail |
|---|---|
| **Test Case ID** | TC-DET-004 |
| **Test Case Title** | Share a destination |
| **Related Test Scenario** | TS-DET-001 — Verify destination details show information, weather, map and actions. |
| **Module/Feature** | Details Screens |
| **Test Objective** | Verify the share action opens the system share sheet. |
| **Priority** | Low |
| **Test Type** | Integration |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The tester is on a destination details screen.

**Test Data**
- None needed.

**Test Steps**
1. Tap the share button in the top image bar.

**Expected Result**
- The system share sheet opens with text about the destination.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-DET-005 — Open a restaurant details screen

| Field | Detail |
|---|---|
| **Test Case ID** | TC-DET-005 |
| **Test Case Title** | Open a restaurant details screen |
| **Related Test Scenario** | TS-DET-002 — Verify restaurant details show hours, price and contact actions. |
| **Module/Feature** | Details Screens |
| **Test Objective** | Verify restaurant information and contact buttons. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- A restaurant with phone, hours and price range exists.

**Test Data**
- None needed.

**Test Steps**
1. Open **Explore** > Restaurants and tap a restaurant.
2. Read the stats and sections.
3. Tap **Call**.

**Expected Result**
- Stats show **Rating**, **Open Hours**, **Price Range**; sections **About**, **Menu Highlights**, **Accessibility**, **Location** appear when data exists.
- A **Verified Partner** label is shown for restaurants that come from an approved business.
- **Call** opens the phone dialer with the number (no call is placed automatically).

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-DET-006 — Set a festival reminder

| Field | Detail |
|---|---|
| **Test Case ID** | TC-DET-006 |
| **Test Case Title** | Set a festival reminder |
| **Related Test Scenario** | TS-DET-003 — Verify festival details and the reminder feature. |
| **Module/Feature** | Details Screens |
| **Test Objective** | Verify a reminder can be scheduled for a festival. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- An upcoming festival exists; notification permission is allowed.

**Test Data**
- None needed.

**Test Steps**
1. Open a festival from **Explore** > Festivals.
2. Tap **Set Reminder**.
3. Pick a future date, then a time (for example 3 minutes from now).

**Expected Result**
- A message "Reminder set for <festival name>." appears.
- At about the chosen time a local notification titled "Festival Reminder" from the "TripNest PH Reminders" channel is shown (it can be a few minutes late).

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Needs manual verification on Android 13+ / exact-alarm settings and on iOS.

---

### TC-DET-007 — Festival reminder with notification permission denied

| Field | Detail |
|---|---|
| **Test Case ID** | TC-DET-007 |
| **Test Case Title** | Festival reminder with notification permission denied |
| **Related Test Scenario** | TS-DET-003 — Verify festival details and the reminder feature. |
| **Module/Feature** | Details Screens |
| **Test Objective** | Verify behavior when the OS blocks notifications. |
| **Priority** | Medium |
| **Test Type** | Negative |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Notification permission for TripNest PH is denied in device settings.

**Test Data**
- None needed.

**Test Steps**
1. Open a festival and tap **Set Reminder**.
2. Pick a future date/time and confirm.
3. Wait for the time to arrive.

**Expected Result**
- The app does not crash.
- No notification is delivered.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Needs manual verification: the code does not show a specific "permission denied" message for reminders. Record what the app shows.

---

### TC-DET-008 — Open a province details screen

| Field | Detail |
|---|---|
| **Test Case ID** | TC-DET-008 |
| **Test Case Title** | Open a province details screen |
| **Related Test Scenario** | TS-DET-004 — Verify province details, emergency access and directions handling. |
| **Module/Feature** | Details Screens |
| **Test Objective** | Verify the province page sections. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- A province with content exists.

**Test Data**
- None needed.

**Test Steps**
1. Open a province (e.g., from the destination or a province card).
2. Scroll through the page.

**Expected Result**
- Sections such as **Featured Attractions**, **Things to Do**, **Where to Eat**, **Hotels & Resorts**, **Local Businesses**, **Local Festivals**, **Local Culture**, **Getting Around**, **Travel Tips**, **Emergency Hotlines** and stats (**Best Time**, **Daily Budget**) are shown when data exists.
- **View on Google Maps** opens the maps app.
- Provinces with no content show "Content coming soon".

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-DET-009 — Emergency access sheet

| Field | Detail |
|---|---|
| **Test Case ID** | TC-DET-009 |
| **Test Case Title** | Emergency access sheet |
| **Related Test Scenario** | TS-DET-004 — Verify province details, emergency access and directions handling. |
| **Module/Feature** | Details Screens |
| **Test Objective** | Verify emergency information and Find Nearby actions. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The tester is on a destination or festival details screen.

**Test Data**
- None needed.

**Test Steps**
1. Tap the emergency button in the top image bar.
2. Read the sheet.
3. Tap **Hospital** under **Find Nearby**, go back, then tap **Police**.

**Expected Result**
- A sheet opens with **National Emergency Hotline** first, followed by that province's hotlines if any exist.
- **Hospital** and **Police** open a nearby search/maps app.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Do not actually call the emergency number during testing.

---

### TC-DET-010 — Destination without coordinates

| Field | Detail |
|---|---|
| **Test Case ID** | TC-DET-010 |
| **Test Case Title** | Destination without coordinates |
| **Related Test Scenario** | TS-DET-005 — Verify details screens behave when data is missing or the network fails. |
| **Module/Feature** | Details Screens |
| **Test Objective** | Verify missing coordinates hide weather/map/directions safely. |
| **Priority** | Low |
| **Test Type** | Negative |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- A destination saved by an admin without latitude/longitude exists.

**Test Data**
- None needed.

**Test Steps**
1. Open that destination.

**Expected Result**
- The screen opens normally.
- The weather card, map and directions are not shown (or degrade gracefully); no error text appears.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-DET-011 — Details screen opened while offline

| Field | Detail |
|---|---|
| **Test Case ID** | TC-DET-011 |
| **Test Case Title** | Details screen opened while offline |
| **Related Test Scenario** | TS-DET-005 — Verify details screens behave when data is missing or the network fails. |
| **Module/Feature** | Details Screens |
| **Test Objective** | Verify a friendly error or cached data. |
| **Priority** | Medium |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- A destination that was NOT opened before; internet OFF.

**Test Data**
- None needed.

**Test Steps**
1. Tap the destination card (list is already cached).
2. Watch the screen.
3. Turn the internet ON and reopen the screen.

**Expected Result**
- A friendly state whose title begins "Couldn't ..." is shown (no stack trace or code), or cached data is shown with the offline banner.
- After reconnecting the details load.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-DET-012 — Report incorrect info on a listing

| Field | Detail |
|---|---|
| **Test Case ID** | TC-DET-012 |
| **Test Case Title** | Report incorrect info on a listing |
| **Related Test Scenario** | TS-DET-001 — Verify destination details show information, weather, map and actions. |
| **Module/Feature** | Details Screens |
| **Test Objective** | Verify a traveler can report a listing. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The tester is on a destination details screen.

**Test Data**
- None needed.

**Test Steps**
1. Tap **Report incorrect info**.
2. In "Report this listing" select **Info is outdated or wrong**.
3. Tap **Report**.
4. Repeat and this time tap **Cancel**.

**Expected Result**
- Report options: outdated/wrong info, Permanently closed, Inappropriate photo, Something else.
- After **Report** the message "Thanks — our team will take a look." appears.
- **Cancel** closes the dialog with no report sent.
- The report appears in the Admin Portal reports list.

**Postconditions:** One content report is stored (none for Cancel).

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-DET-013 — Festival reminder with a time that already passed

| Field | Detail |
|---|---|
| **Test Case ID** | TC-DET-013 |
| **Test Case Title** | Festival reminder with a time that already passed |
| **Related Test Scenario** | TS-DET-003 — Verify festival details and the reminder feature. |
| **Module/Feature** | Details Screens |
| **Test Objective** | Verify a reminder cannot be set in the past. |
| **Priority** | Medium |
| **Test Type** | Validation |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- An upcoming festival exists; the tester is on its details screen.

**Test Data**
- Date: today
- Time: one hour earlier than the current time

**Test Steps**
1. Tap **Set Reminder**.
2. Pick today as the date.
3. Pick a time earlier than now.

**Expected Result**
- The message "Pick a time in the future." appears.
- No "Reminder set for ..." message appears and no notification is scheduled.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Added after a code trace: the picker used to accept past times. Fixed in lib/core/utils/reminder_picker.dart.

---

## Nearby Places

### TC-NEAR-001 — Browse nearby places by category and sort

| Field | Detail |
|---|---|
| **Test Case ID** | TC-NEAR-001 |
| **Test Case Title** | Browse nearby places by category and sort |
| **Related Test Scenario** | TS-NEAR-001 — Verify the Nearby Places screen lists live places by category, sorts them and handles no results. |
| **Module/Feature** | Nearby Places |
| **Test Objective** | Verify category chips, sorting and search. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Location permission granted; Google Places is available.

**Test Data**
- None needed.

**Test Steps**
1. On a destination details screen tap **Plan a Trip Nearby** or a "Nearby" section see-all action (or open the Nearby Places screen from Home).
2. Tap category chips such as **Restaurants**, **Hotels**, **Cafes**.
3. Change **Sort** to **Distance**, then **Rating**.
4. Type `coffee` in "Search places...".

**Expected Result**
- A list of places for the selected category is shown.
- The order changes when the sort option changes (Relevance, Distance, Rating, Popularity).
- The search box narrows the list.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Needs manual verification of the exact entry point to this screen on each device.

---

### TC-NEAR-002 — Nearby category with no results

| Field | Detail |
|---|---|
| **Test Case ID** | TC-NEAR-002 |
| **Test Case Title** | Nearby category with no results |
| **Related Test Scenario** | TS-NEAR-001 — Verify the Nearby Places screen lists live places by category, sorts them and handles no results. |
| **Module/Feature** | Nearby Places |
| **Test Objective** | Verify the empty state. |
| **Priority** | Low |
| **Test Type** | Negative |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- A remote location with few places (or a rare category such as Hostels).

**Test Data**
- None needed.

**Test Steps**
1. Open Nearby Places and select a category that returns nothing.

**Expected Result**
- A "No places found" state with the text "Nothing matched this search — try a different category." is shown.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

## Reviews & Reports

### TC-REV-001 — Write a review with rating and comment

| Field | Detail |
|---|---|
| **Test Case ID** | TC-REV-001 |
| **Test Case Title** | Write a review with rating and comment |
| **Related Test Scenario** | TS-REV-001 — Verify a traveler can write a review with rating, comment and up to 3 photos. |
| **Module/Feature** | Reviews & Reports |
| **Test Objective** | Verify a review is saved and shown. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The tester is on a destination details screen and has not reviewed it yet.

**Test Data**
- Rating: 4 stars
- Comment: `Beautiful place, clean and easy to reach.`

**Test Steps**
1. Scroll to the reviews section and tap the write-review action.
2. In the "Write a Review" sheet tap the 4th star.
3. Type the comment.
4. Tap the submit button.

**Expected Result**
- The sheet closes.
- The review appears in the list with the author name, 4 stars and the comment.
- The place's rating and review count update.
- A "verified" badge appears only if the traveler has a visit record for this place.

**Postconditions:** One review document exists for this user and place.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-REV-002 — Submit a review with an empty comment

| Field | Detail |
|---|---|
| **Test Case ID** | TC-REV-002 |
| **Test Case Title** | Submit a review with an empty comment |
| **Related Test Scenario** | TS-REV-002 — Verify review validation (empty comment, 2000-character limit, photo limit). |
| **Module/Feature** | Reviews & Reports |
| **Test Objective** | Verify the comment is required. |
| **Priority** | High |
| **Test Type** | Validation |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The write-review sheet is open.

**Test Data**
- None needed.

**Test Steps**
1. Select 5 stars.
2. Leave the Comment field empty (or only spaces).
3. Tap the submit button.

**Expected Result**
- The message "Comment is required" appears under the field.
- The review is not saved and the sheet stays open.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-REV-003 — Comment length limit (2000 characters)

| Field | Detail |
|---|---|
| **Test Case ID** | TC-REV-003 |
| **Test Case Title** | Comment length limit (2000 characters) |
| **Related Test Scenario** | TS-REV-002 — Verify review validation (empty comment, 2000-character limit, photo limit). |
| **Module/Feature** | Reviews & Reports |
| **Test Objective** | Verify the 2000-character limit. |
| **Priority** | Low |
| **Test Type** | Boundary |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The write-review sheet is open.

**Test Data**
- A text of 2001 characters (copy/paste)

**Test Steps**
1. Paste the 2001-character text into the Comment field.
2. Look at the character counter.
3. Submit the review.

**Expected Result**
- The field accepts at most 2000 characters (the counter shows 2000/2000).
- The review is saved with 2000 characters and the app does not crash.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-REV-004 — Attach photos: maximum of 3

| Field | Detail |
|---|---|
| **Test Case ID** | TC-REV-004 |
| **Test Case Title** | Attach photos: maximum of 3 |
| **Related Test Scenario** | TS-REV-002 — Verify review validation (empty comment, 2000-character limit, photo limit). |
| **Module/Feature** | Reviews & Reports |
| **Test Objective** | Verify the 3-photo limit and photo permission handling. |
| **Priority** | Medium |
| **Test Type** | Boundary |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The write-review sheet is open; the gallery has at least 4 photos smaller than 5 MB.

**Test Data**
- None needed.

**Test Steps**
1. Tap the add-photo box and allow photo access if asked.
2. Pick a photo. Repeat until 3 photos are attached.
3. Look for the add-photo box.
4. Remove one photo with its remove button.
5. Add a different photo and submit the review.

**Expected Result**
- After 3 photos, the add-photo box is hidden (no 4th photo can be added).
- Removing a photo makes the add box appear again.
- The review is saved with its photos and they show in the review list.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-REV-005 — Photo permission denied

| Field | Detail |
|---|---|
| **Test Case ID** | TC-REV-005 |
| **Test Case Title** | Photo permission denied |
| **Related Test Scenario** | TS-REV-005 — Verify review submission handles network interruption and photo permission denial. |
| **Module/Feature** | Reviews & Reports |
| **Test Objective** | Verify a friendly message when gallery access is refused. |
| **Priority** | Medium |
| **Test Type** | Negative |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Photos permission for TripNest PH is denied (OS settings).

**Test Data**
- None needed.

**Test Steps**
1. Open the write-review sheet.
2. Tap the add-photo box.

**Expected Result**
- The app does not crash.
- A friendly message such as "Permission was denied. Please allow access in your device settings and try again." is shown, or the picker simply does not attach a photo.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Needs manual verification of platform behavior (Android vs iOS).

---

### TC-REV-006 — Edit and delete own review

| Field | Detail |
|---|---|
| **Test Case ID** | TC-REV-006 |
| **Test Case Title** | Edit and delete own review |
| **Related Test Scenario** | TS-REV-003 — Verify a traveler can edit and delete only their own review. |
| **Module/Feature** | Reviews & Reports |
| **Test Objective** | Verify the owner can edit and delete a review. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The traveler has an existing review on a place.

**Test Data**
- None needed.

**Test Steps**
1. Open the place and find your review.
2. Choose **Edit**; change the rating to 2 stars and the comment; submit.
3. Choose **Delete** on the review and confirm.

**Expected Result**
- The sheet title is "Edit Your Review" and the old values are pre-filled.
- After the edit the list shows the new rating/comment.
- After delete the review disappears and the review count decreases by 1.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-REV-007 — Other users' reviews cannot be edited or deleted

| Field | Detail |
|---|---|
| **Test Case ID** | TC-REV-007 |
| **Test Case Title** | Other users' reviews cannot be edited or deleted |
| **Related Test Scenario** | TS-REV-003 — Verify a traveler can edit and delete only their own review. |
| **Module/Feature** | Reviews & Reports |
| **Test Objective** | Verify edit/delete options are not offered on another user's review. |
| **Priority** | High |
| **Test Type** | Security |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Another traveler has reviewed the same place.

**Test Data**
- None needed.

**Test Steps**
1. Open the place and look at the other traveler's review actions.

**Expected Result**
- Edit and Delete are not shown; a Report option is available instead.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-REV-008 — Report a review

| Field | Detail |
|---|---|
| **Test Case ID** | TC-REV-008 |
| **Test Case Title** | Report a review |
| **Related Test Scenario** | TS-REV-004 — Verify review reporting and the restaurant-owner reply. |
| **Module/Feature** | Reviews & Reports |
| **Test Objective** | Verify reporting reasons. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Another traveler's review is visible.

**Test Data**
- None needed.

**Test Steps**
1. Open the report action on that review.
2. Read the options and select **Spam or advertising**.
3. Tap **Report**.

**Expected Result**
- Options shown: Spam or advertising; Inappropriate or offensive; Fake — doesn't seem like a real visit; Something else.
- A confirmation is shown and the report appears in the Admin Portal **Reports** list.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-REV-009 — Restaurant owner replies to a review

| Field | Detail |
|---|---|
| **Test Case ID** | TC-REV-009 |
| **Test Case Title** | Restaurant owner replies to a review |
| **Related Test Scenario** | TS-REV-004 — Verify review reporting and the restaurant-owner reply. |
| **Module/Feature** | Reviews & Reports |
| **Test Objective** | Verify the owner reply action is available only to the restaurant owner. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The signed-in traveler has an active Business Owner role (accepted invite) — example: owner01@example.com.
- The owner's approved Food & Dining listing has a review from another traveler.

**Test Data**
- None needed.

**Test Steps**
1. Sign in as the owner and open the restaurant details.
2. On the review tap **Reply as owner**, type a reply and save.
3. Reopen the same review with another traveler account.

**Expected Result**
- The owner reply is shown under the review; the action changes to **Edit reply**.
- The other traveler sees the reply but does not see a reply action.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-REV-010 — Internet lost while submitting a review

| Field | Detail |
|---|---|
| **Test Case ID** | TC-REV-010 |
| **Test Case Title** | Internet lost while submitting a review |
| **Related Test Scenario** | TS-REV-005 — Verify review submission handles network interruption and photo permission denial. |
| **Module/Feature** | Reviews & Reports |
| **Test Objective** | Verify no partial/duplicate review is created. |
| **Priority** | High |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- A filled review form (rating, comment, 1 photo) is ready.

**Test Data**
- None needed.

**Test Steps**
1. Tap submit.
2. Immediately turn the internet OFF.
3. Wait for the result.
4. Turn the internet ON and open the place again.

**Expected Result**
- A friendly message appears (network or timeout) if the submit failed; no technical text.
- After reconnecting, at most ONE review from this traveler exists for the place (no duplicates).

**Postconditions:** Review count matches the number of visible reviews.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

## Favorites & Lists

### TC-FAV-001 — Save and unsave a destination with the bookmark icon

| Field | Detail |
|---|---|
| **Test Case ID** | TC-FAV-001 |
| **Test Case Title** | Save and unsave a destination with the bookmark icon |
| **Related Test Scenario** | TS-FAV-001 — Verify a traveler can save and unsave destinations, restaurants, festivals, businesses and places. |
| **Module/Feature** | Favorites & Lists |
| **Test Objective** | Verify the bookmark toggles saved state and appears under Saved > Places. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The Saved tab has no favorites.

**Test Data**
- None needed.

**Test Steps**
1. On Home tap the bookmark icon on a destination card.
2. Open the **Saved** tab and the **Places** tab.
3. Tap the bookmark icon on the same card again (Home or Explore).
4. Return to **Saved** > **Places**.

**Expected Result**
- The icon changes to the saved state with a small bounce.
- **Places (1)** shows the destination.
- After the second tap the icon returns to unsaved and **Places (0)** is empty.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-FAV-002 — Saved tabs show each type

| Field | Detail |
|---|---|
| **Test Case ID** | TC-FAV-002 |
| **Test Case Title** | Saved tabs show each type |
| **Related Test Scenario** | TS-FAV-001 — Verify a traveler can save and unsave destinations, restaurants, festivals, businesses and places. |
| **Module/Feature** | Favorites & Lists |
| **Test Objective** | Verify every saved type appears in its own tab. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).

**Test Data**
- None needed.

**Test Steps**
1. Save one destination, one restaurant, one festival, one local business and one live Google place.
2. Open **Saved** and check the tabs **Places**, **Food**, **Festivals**, **Local Finds**, **Attractions**.

**Expected Result**
- Each item is in its correct tab and every tab counter shows (1).

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-FAV-003 — Create a list and add a favorite to it

| Field | Detail |
|---|---|
| **Test Case ID** | TC-FAV-003 |
| **Test Case Title** | Create a list and add a favorite to it |
| **Related Test Scenario** | TS-FAV-002 — Verify favorites can be organized into named lists (create, move, rename, delete). |
| **Module/Feature** | Favorites & Lists |
| **Test Objective** | Verify creating a list and moving a saved item into it. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- At least one saved destination.

**Test Data**
- List name: `Summer Trip`

**Test Steps**
1. Open **Saved** > **Places**.
2. Tap the list icon at the top right of a saved card.
3. In "Add to List" tap **New List**, type `Summer Trip` and confirm.
4. Select the new list for the item.
5. Select the `Summer Trip` chip at the top of Saved.

**Expected Result**
- The list `Summer Trip` is created.
- The item appears when that list is selected and is not shown under Unsorted.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-FAV-004 — List name validation (empty and 60-character maximum)

| Field | Detail |
|---|---|
| **Test Case ID** | TC-FAV-004 |
| **Test Case Title** | List name validation (empty and 60-character maximum) |
| **Related Test Scenario** | TS-FAV-002 — Verify favorites can be organized into named lists (create, move, rename, delete). |
| **Module/Feature** | Favorites & Lists |
| **Test Objective** | Verify the list name rules. |
| **Priority** | Low |
| **Test Type** | Boundary |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The "Add to List" sheet is open.

**Test Data**
- 61-character name

**Test Steps**
1. Tap **New List** and leave the name empty; look at the confirm button.
2. Paste a 61-character name.

**Expected Result**
- The confirm button is disabled while the name is empty.
- The text field accepts a maximum of 60 characters.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-FAV-005 — Rename and delete a list

| Field | Detail |
|---|---|
| **Test Case ID** | TC-FAV-005 |
| **Test Case Title** | Rename and delete a list |
| **Related Test Scenario** | TS-FAV-002 — Verify favorites can be organized into named lists (create, move, rename, delete). |
| **Module/Feature** | Favorites & Lists |
| **Test Objective** | Verify long-press options and that deleting a list keeps the items. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- A list `Summer Trip` containing 1 favorite exists.

**Test Data**
- None needed.

**Test Steps**
1. On **Saved**, long-press the `Summer Trip` chip.
2. Choose **Rename list**, enter `Winter Trip` and **Save**.
3. Long-press the chip again, choose **Delete list** and confirm **Delete "Winter Trip"?**.

**Expected Result**
- The chip name changes to `Winter Trip`.
- After delete the list is gone and its favorite moves back to Unsorted (message: "Favorites in this list aren't removed — they just go back to Unsorted.").

**Postconditions:** The favorite still exists under Unsorted.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-FAV-006 — Favorites persist after restart and sync across sign-in

| Field | Detail |
|---|---|
| **Test Case ID** | TC-FAV-006 |
| **Test Case Title** | Favorites persist after restart and sync across sign-in |
| **Related Test Scenario** | TS-FAV-003 — Verify favorites persist after app restart and stay consistent. |
| **Module/Feature** | Favorites & Lists |
| **Test Objective** | Verify saved data is not lost. |
| **Priority** | High |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- At least 2 saved items.

**Test Data**
- None needed.

**Test Steps**
1. Close the app completely and open it again.
2. Open **Saved**.
3. Log out, log in again with the same account, and open **Saved**.

**Expected Result**
- The same items and lists are shown after the restart and after re-login; no duplicates.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-FAV-007 — Save an item while offline

| Field | Detail |
|---|---|
| **Test Case ID** | TC-FAV-007 |
| **Test Case Title** | Save an item while offline |
| **Related Test Scenario** | TS-FAV-003 — Verify favorites persist after app restart and stay consistent. |
| **Module/Feature** | Favorites & Lists |
| **Test Objective** | Verify behavior of favoriting during no connection and after reconnecting. |
| **Priority** | Medium |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Home is loaded with cards visible; internet then turned OFF.

**Test Data**
- None needed.

**Test Steps**
1. Tap the bookmark on a destination card while offline.
2. Turn the internet ON and wait 10 seconds.
3. Open **Saved**; then restart the app and check again.

**Expected Result**
- The app does not crash and shows no technical message.
- After reconnecting, the item is saved exactly once (or the app shows a friendly message that it could not save).

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Needs manual verification: Firestore offline persistence may queue the write.

---

## AI Planner

### TC-PLAN-001 — Generate an itinerary with valid inputs

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PLAN-001 |
| **Test Case Title** | Generate an itinerary with valid inputs |
| **Related Test Scenario** | TS-PLAN-001 — Verify a traveler can generate an AI itinerary from the planner form using valid choices. |
| **Module/Feature** | AI Planner |
| **Test Objective** | Verify a multi-day itinerary is created and opened. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Groq AI and Google APIs are working (Cloud Functions deployed).

**Test Data**
- Destination: a destination such as `Baguio` (Benguet)
- Budget: `Mid-range` (₱15k – ₱40k)
- Days: `3`
- Who is traveling: `Friends`, Travelers: `4`
- Transportation: `Van / Car Rental`
- Interests: `Food`, `Nature`
- Trip pace: `Balanced`

**Test Steps**
1. Open the **Planner** tab.
2. Under "Where do you want to go?" pick the destination.
3. Select the budget, set days to 3, choose Friends with 4 travelers.
4. Select the transportation and interests, and the pace.
5. Tap **Generate Itinerary**.

**Expected Result**
- The button changes to "Crafting your itinerary..." with a loading indicator and cannot be tapped again.
- The generated itinerary screen opens.
- It shows a day-by-day plan with 3 days, budget summary, weather outlook (when coordinates exist), recommended restaurants/accommodations and travel tips.

**Postconditions:** The itinerary exists in the app but is NOT saved to "Saved Trips" until the user saves it.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-PLAN-002 — Generate is disabled without a destination

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PLAN-002 |
| **Test Case Title** | Generate is disabled without a destination |
| **Related Test Scenario** | TS-PLAN-002 — Verify the Generate button is blocked until a destination is selected. |
| **Module/Feature** | AI Planner |
| **Test Objective** | Verify the destination is required. |
| **Priority** | High |
| **Test Type** | Validation |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The Planner form is opened fresh (no destination selected).

**Test Data**
- None needed.

**Test Steps**
1. Look at the bottom of the Planner screen.
2. Try to tap **Generate Itinerary**.

**Expected Result**
- The text "Select a destination to continue" is shown above the button.
- The **Generate Itinerary** button is disabled and nothing happens on tap.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-PLAN-003 — Days boundary values 1 and 14

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PLAN-003 |
| **Test Case Title** | Days boundary values 1 and 14 |
| **Related Test Scenario** | TS-PLAN-003 — Verify day-count boundaries (1 to 14) and traveler-count rules by traveler type. |
| **Module/Feature** | AI Planner |
| **Test Objective** | Verify the stepper and typed days are limited to 1–14. |
| **Priority** | High |
| **Test Type** | Boundary |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The Planner form is open.

**Test Data**
- Typed values: `0`, `1`, `14`, `15`, `abc`

**Test Steps**
1. Press the minus button until the days no longer decrease.
2. Press the plus button until the days no longer increase.
3. Tap the days number to open "How many days?" (hint "Between 1 and 14").
4. Type each typed value and tap **Save**.

**Expected Result**
- Minus stops at "1 day"; plus stops at "14 days" (the button becomes disabled).
- `0` or `15`: "Enter a number between 1 and 14".
- `abc`: "Enter a whole number".
- `1` and `14` are accepted.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-PLAN-004 — Traveler count rules by traveler type

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PLAN-004 |
| **Test Case Title** | Traveler count rules by traveler type |
| **Related Test Scenario** | TS-PLAN-003 — Verify day-count boundaries (1 to 14) and traveler-count rules by traveler type. |
| **Module/Feature** | AI Planner |
| **Test Objective** | Verify Solo = 1, Couple = 2, Family/Friends = 2 to 15. |
| **Priority** | Medium |
| **Test Type** | Boundary |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The Planner form is open.

**Test Data**
- None needed.

**Test Steps**
1. Select **Solo** and read the traveler box and hint.
2. Select **Couple** and read them again.
3. Select **Friends**; tap the number and type `1`, then `16`, then `15`.

**Expected Result**
- Solo: "1 traveler", locked (no plus/minus), hint "Solo trips are set to 1 traveler."
- Couple: "2 travelers", locked, hint "Couple trips are set to 2 travelers."
- Friends: hint "Friends trips need at least 2 travelers."
- `1` and `16` show "Enter a number between 2 and 15"; `15` is accepted.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-PLAN-005 — Planner defaults and optional accommodation

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PLAN-005 |
| **Test Case Title** | Planner defaults and optional accommodation |
| **Related Test Scenario** | TS-PLAN-005 — Verify the planner defaults, optional accommodation and option selections. |
| **Module/Feature** | AI Planner |
| **Test Objective** | Verify the default values and the optional accommodation search. |
| **Priority** | Low |
| **Test Type** | Functional |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).

**Test Data**
- None needed.

**Test Steps**
1. Open the **Planner** tab on a fresh session.
2. Read the default selections.
3. Tap the "Where are you staying? (optional)" field and search for a hotel name.
4. Try searching with an empty box.

**Expected Result**
- Defaults: Budget = Mid-range, Days = 3, Travelers = 2, Who = Couple, Transportation = Van / Car Rental, Interests = Beaches + Food, Pace = Balanced.
- Accommodation search sheet shows results, or "No accommodations found" when nothing matches.
- An empty search does not run a search and does not crash.
- The planner can generate with the accommodation left empty.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-PLAN-006 — Generate while offline

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PLAN-006 |
| **Test Case Title** | Generate while offline |
| **Related Test Scenario** | TS-PLAN-004 — Verify the planner handles AI/network failures with friendly messages. |
| **Module/Feature** | AI Planner |
| **Test Objective** | Verify a friendly failure message. |
| **Priority** | High |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The Planner form is filled; internet OFF.

**Test Data**
- None needed.

**Test Steps**
1. Tap **Generate Itinerary**.

**Expected Result**
- A snack bar appears with a friendly message (network/timeout text or "Couldn't generate your itinerary. Please try again.").
- No error codes, JSON or stack trace are shown.
- The button becomes usable again.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-PLAN-007 — Internet lost while the itinerary is generating

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PLAN-007 |
| **Test Case Title** | Internet lost while the itinerary is generating |
| **Related Test Scenario** | TS-PLAN-004 — Verify the planner handles AI/network failures with friendly messages. |
| **Module/Feature** | AI Planner |
| **Test Objective** | Verify the app recovers and does not hang forever. |
| **Priority** | High |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The Planner form is filled.

**Test Data**
- None needed.

**Test Steps**
1. Tap **Generate Itinerary**.
2. While "Crafting your itinerary..." is shown, turn the internet OFF.
3. Wait up to 60 seconds.
4. Turn the internet ON and tap **Generate Itinerary** again.

**Expected Result**
- The loading state ends and a friendly error message appears.
- After reconnecting a new generation succeeds.
- Only one itinerary result is opened.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-PLAN-008 — AI hourly limit (30 requests)

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PLAN-008 |
| **Test Case Title** | AI hourly limit (30 requests) |
| **Related Test Scenario** | TS-PLAN-004 — Verify the planner handles AI/network failures with friendly messages. |
| **Module/Feature** | AI Planner |
| **Test Objective** | Verify the friendly rate-limit message. |
| **Priority** | Low |
| **Test Type** | Boundary |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The account already made about 30 AI calls (planner or chat) in the last hour.

**Test Data**
- None needed.

**Test Steps**
1. Tap **Generate Itinerary** with a valid form.

**Expected Result**
- A friendly message like "You're doing that too often — please wait a bit and try again." (or "Too many requests right now...") is shown.
- No technical error is displayed.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Uses the aiComplete limit of 30 per hour per user. Consumes many AI calls.

---

### TC-PLAN-009 — Phone call / app switch while generating

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PLAN-009 |
| **Test Case Title** | Phone call / app switch while generating |
| **Related Test Scenario** | TS-PLAN-004 — Verify the planner handles AI/network failures with friendly messages. |
| **Module/Feature** | AI Planner |
| **Test Objective** | Verify generation completes or recovers after interruption. |
| **Priority** | Medium |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The Planner form is filled.

**Test Data**
- None needed.

**Test Steps**
1. Tap **Generate Itinerary**.
2. While it is loading, receive/simulate an incoming call (or press Home and open another app for 20 seconds).
3. Return to TripNest PH.

**Expected Result**
- The app resumes on the Planner screen.
- Either the itinerary screen opens or a friendly error appears; the app does not crash or show two results.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-PLAN-010 — Open the manual itinerary builder

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PLAN-010 |
| **Test Case Title** | Open the manual itinerary builder |
| **Related Test Scenario** | TS-PLAN-005 — Verify the planner defaults, optional accommodation and option selections. |
| **Module/Feature** | AI Planner |
| **Test Objective** | Verify "Create manually" and its required fields. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).

**Test Data**
- Destination: any destination
- Start date: a future date
- Days: `2`
- Travelers: `2`

**Test Steps**
1. On Planner tap **Prefer to build it yourself? Create manually**.
2. On "Create Your Own Itinerary" look at **Start Planning** before choosing anything.
3. Choose the Destination, Start Date, Days and Travelers, then tap **Start Planning**.

**Expected Result**
- **Start Planning** is disabled until both a destination and a start date are chosen (there is no error message).
- With valid data, an itinerary with the chosen number of empty days opens for manual editing.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Code trace: manual_itinerary_screen.dart disables the button instead of showing a message.

---

## Generated Itinerary

### TC-ITIN-001 — Read the generated itinerary sections

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ITIN-001 |
| **Test Case Title** | Read the generated itinerary sections |
| **Related Test Scenario** | TS-ITIN-002 — Verify itinerary content sections are displayed. |
| **Module/Feature** | Generated Itinerary |
| **Test Objective** | Verify all main sections are displayed. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- An itinerary was just generated (TC-PLAN-001).

**Test Data**
- None needed.

**Test Steps**
1. Scroll the whole itinerary screen from top to bottom.

**Expected Result**
- Sections are shown: **Weather Outlook**, **Day-by-Day Plan** (each day with Morning/Afternoon/Evening activities), **Recommended Restaurants**, **Recommended Accommodations**, **Nearby Attractions**, **Budget Summary**, **Travel Tips**, **Getting Around**.
- The action row shows **Share**, **Download**, **Remind** and **Regenerate**.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Content is AI-generated; check structure and not exact wording.

---

### TC-ITIN-002 — Save an itinerary to My Trips

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ITIN-002 |
| **Test Case Title** | Save an itinerary to My Trips |
| **Related Test Scenario** | TS-ITIN-001 — Verify the itinerary can be saved to My Trips, and unsaved changes are protected. |
| **Module/Feature** | Generated Itinerary |
| **Test Objective** | Verify saving creates one saved trip. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- A newly generated (unsaved) itinerary is open.

**Test Data**
- None needed.

**Test Steps**
1. Tap the save (bookmark) action on the itinerary screen.
2. Open **Profile** > **My Trips** (Saved Trips).

**Expected Result**
- A message "Itinerary saved to your trips." appears.
- The trip appears once in the Saved Trips list.

**Postconditions:** One `saved_itineraries` document exists for the user.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ITIN-003 — Leave an unsaved itinerary

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ITIN-003 |
| **Test Case Title** | Leave an unsaved itinerary |
| **Related Test Scenario** | TS-ITIN-001 — Verify the itinerary can be saved to My Trips, and unsaved changes are protected. |
| **Module/Feature** | Generated Itinerary |
| **Test Objective** | Verify the "Save this trip?" prompt on leaving. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- A newly generated, unsaved itinerary is open.

**Test Data**
- None needed.

**Test Steps**
1. Press Back on the itinerary screen.
2. Tap **Discard**.
3. Generate another itinerary, press Back again and tap **Save & Leave**.

**Expected Result**
- A "Save this trip?" dialog appears.
- **Discard** leaves without saving; the trip is not in Saved Trips.
- **Save & Leave** saves the trip once and leaves; the trip appears in Saved Trips.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ITIN-004 — Save while signed out / save failure

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ITIN-004 |
| **Test Case Title** | Save while signed out / save failure |
| **Related Test Scenario** | TS-ITIN-001 — Verify the itinerary can be saved to My Trips, and unsaved changes are protected. |
| **Module/Feature** | Generated Itinerary |
| **Test Objective** | Verify the sign-in check and network-failure message when saving. |
| **Priority** | High |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- An unsaved itinerary is open; internet OFF.

**Test Data**
- None needed.

**Test Steps**
1. Tap the save action while offline.
2. Turn the internet ON and tap save again.

**Expected Result**
- Offline: a friendly network or generic message is shown; no trip is created (or it is queued and saved once later).
- Online: "Itinerary saved to your trips." and only one trip exists.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** The message "Sign in to save this itinerary." exists in code for signed-out users but every itinerary screen requires sign-in, so it cannot normally be reached.

---

### TC-ITIN-005 — Add and remove an activity

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ITIN-005 |
| **Test Case Title** | Add and remove an activity |
| **Related Test Scenario** | TS-ITIN-003 — Verify itinerary editing (add, remove activity) and regeneration. |
| **Module/Feature** | Generated Itinerary |
| **Test Objective** | Verify manual editing of the day plan. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- A saved trip is open and the tester is its owner.

**Test Data**
- Time: `Afternoon`
- Title: `Visit Burnham Park`
- Description: leave empty

**Test Steps**
1. Tap **Add Activity** on a day.
2. Enter the time and title (Description is optional).
3. Confirm.
4. Remove the same activity and confirm the "Remove this activity?" dialog.

**Expected Result**
- The new activity appears in that day with the entered time and title.
- After removal it disappears from the list.
- The changes stay after leaving and reopening the trip.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ITIN-006 — Regenerate a saved itinerary

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ITIN-006 |
| **Test Case Title** | Regenerate a saved itinerary |
| **Related Test Scenario** | TS-ITIN-003 — Verify itinerary editing (add, remove activity) and regeneration. |
| **Module/Feature** | Generated Itinerary |
| **Test Objective** | Verify regenerate asks before replacing and does not duplicate the trip. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- A saved trip is open.

**Test Data**
- None needed.

**Test Steps**
1. Tap **Regenerate**.
2. When "Replace your saved itinerary?" appears, tap cancel/decline, then repeat and confirm.
3. Wait for the result.
4. Open Saved Trips.

**Expected Result**
- Cancel: the current itinerary is kept unchanged.
- Confirm: a new plan replaces the old one for the same saved trip.
- Saved Trips still shows only one trip (no duplicate).

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ITIN-007 — Add a shared expense

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ITIN-007 |
| **Test Case Title** | Add a shared expense |
| **Related Test Scenario** | TS-ITIN-004 — Verify the budget tracker (add, edit, delete expense and validation). |
| **Module/Feature** | Generated Itinerary |
| **Test Objective** | Verify an expense with a valid amount and split members is saved. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- A saved trip is open.

**Test Data**
- Category: `Food`
- Amount (₱): `1250.50`
- Note: `Dinner at the market`
- Split between: all members

**Test Steps**
1. In **Budget Tracker** tap **Add Expense**.
2. Choose the category, enter the amount and note.
3. Keep at least one person checked under "Split between".
4. Tap **Add**.

**Expected Result**
- The expense appears in the tracker with ₱1,250.50 and the note.
- **Spend by Category**, **Actual Spend** and **Who Owes What** update.

**Postconditions:** One expense document exists under the trip.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ITIN-008 — Expense amount and split validation

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ITIN-008 |
| **Test Case Title** | Expense amount and split validation |
| **Related Test Scenario** | TS-ITIN-004 — Verify the budget tracker (add, edit, delete expense and validation). |
| **Module/Feature** | Generated Itinerary |
| **Test Objective** | Verify amount boundaries and split rule. |
| **Priority** | High |
| **Test Type** | Boundary |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The "Add Expense" dialog is open on a shared trip.

**Test Data**
- Amounts: empty, `0`, `-5`, `abc`, `500000`, `500001`

**Test Steps**
1. Enter each amount and tap **Add**; note the message.
2. With a valid amount, uncheck every person under "Split between" and tap **Add**.

**Expected Result**
- Empty: "This field is required".
- `0` or `-5`: "Amount must be greater than 0".
- `abc`: "Enter a valid amount".
- `500001`: "Amount must be ₱500000 or less"; `500000` is accepted.
- No person selected: "Select at least one person to split with".

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ITIN-009 — Edit and delete an expense

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ITIN-009 |
| **Test Case Title** | Edit and delete an expense |
| **Related Test Scenario** | TS-ITIN-004 — Verify the budget tracker (add, edit, delete expense and validation). |
| **Module/Feature** | Generated Itinerary |
| **Test Objective** | Verify expense edit/delete keeps totals consistent. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- A trip has an expense of ₱1,000.

**Test Data**
- None needed.

**Test Steps**
1. Open the expense and choose edit; change the amount to `600` and **Save**.
2. Delete the expense and confirm "Delete this expense?".

**Expected Result**
- Totals change to ₱600 after the edit.
- After delete the expense is removed and totals return to ₱0 for it.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ITIN-010 — Create a poll and vote

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ITIN-010 |
| **Test Case Title** | Create a poll and vote |
| **Related Test Scenario** | TS-ITIN-005 — Verify group polls (create, vote, edit, delete and validation). |
| **Module/Feature** | Generated Itinerary |
| **Test Objective** | Verify poll creation and voting. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- A saved trip is open.

**Test Data**
- Question: `Which restaurant for Day 2?`
- Option 1: `Restaurant A`
- Option 2: `Restaurant B`

**Test Steps**
1. In **Group Polls** tap **New Poll**.
2. Enter the question and two options.
3. Tap **Create**.
4. Tap Option 1 to vote.

**Expected Result**
- The poll appears with both options.
- After voting the vote count for Option 1 becomes 1.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ITIN-011 — Poll validation rules

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ITIN-011 |
| **Test Case Title** | Poll validation rules |
| **Related Test Scenario** | TS-ITIN-005 — Verify group polls (create, vote, edit, delete and validation). |
| **Module/Feature** | Generated Itinerary |
| **Test Objective** | Verify empty question, fewer than 2 options, duplicate options and the 6-option maximum. |
| **Priority** | Medium |
| **Test Type** | Validation |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The "New Poll" dialog is open.

**Test Data**
- None needed.

**Test Steps**
1. Tap **Create** with an empty question.
2. Enter a question and only one option; tap **Create**.
3. Enter `Beach` and `beach` as two options; tap **Create**.
4. Tap **Add option** repeatedly.

**Expected Result**
- Empty question: "Enter a question".
- One option: "Add at least 2 options."
- Duplicates (any letter case): "Options must be different from each other."
- **Add option** is no longer shown after 6 options.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ITIN-012 — Edit a poll clears votes; delete a poll

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ITIN-012 |
| **Test Case Title** | Edit a poll clears votes; delete a poll |
| **Related Test Scenario** | TS-ITIN-005 — Verify group polls (create, vote, edit, delete and validation). |
| **Module/Feature** | Generated Itinerary |
| **Test Objective** | Verify the warning and the delete confirmation. |
| **Priority** | Low |
| **Test Type** | Functional |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- A poll with at least 1 vote exists.

**Test Data**
- None needed.

**Test Steps**
1. Open **Edit Poll** for that poll.
2. Read the warning, change an option and **Save**.
3. Delete the poll and confirm "Delete this poll?".

**Expected Result**
- A warning shows "Saving will clear the N existing vote(s) on this poll."
- After saving, votes are 0.
- After delete, the poll is gone.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ITIN-013 — Add, tick and remove a packing item

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ITIN-013 |
| **Test Case Title** | Add, tick and remove a packing item |
| **Related Test Scenario** | TS-ITIN-006 — Verify packing checklist management. |
| **Module/Feature** | Generated Itinerary |
| **Test Objective** | Verify packing checklist actions. |
| **Priority** | Low |
| **Test Type** | Functional |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- A saved trip is open.

**Test Data**
- Item: `Sunscreen`

**Test Steps**
1. In **Packing Checklist** tap **Add Item**.
2. Enter `Sunscreen` and tap **Add**.
3. Tick the item as packed.
4. Remove it and confirm "Remove this item?".

**Expected Result**
- The item appears in the list.
- Ticking updates the counter on the trip card in Saved Trips ("x/y packed").
- After removal the item disappears.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ITIN-014 — Share a trip and download it

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ITIN-014 |
| **Test Case Title** | Share a trip and download it |
| **Related Test Scenario** | TS-ITIN-007 — Verify share, download, reminders and offline save of a trip. |
| **Module/Feature** | Generated Itinerary |
| **Test Objective** | Verify Share and Download actions. |
| **Priority** | Medium |
| **Test Type** | Integration |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- A saved trip is open.

**Test Data**
- None needed.

**Test Steps**
1. Tap **Share** and read the share sheet; cancel it.
2. Tap **Download**.
3. Open the downloaded file with a PDF viewer (if available).

**Expected Result**
- The system share sheet opens with the trip text.
- A file (PDF) is created/offered and opens with the trip day plan.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Needs manual verification of exact file format and where it is saved per platform.

---

### TC-ITIN-015 — Set trip reminders (travel day and packing)

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ITIN-015 |
| **Test Case Title** | Set trip reminders (travel day and packing) |
| **Related Test Scenario** | TS-ITIN-007 — Verify share, download, reminders and offline save of a trip. |
| **Module/Feature** | Generated Itinerary |
| **Test Objective** | Verify reminder toggles schedule local notifications. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- A saved trip has a future start date; notification permission allowed.

**Test Data**
- Date: today or a later day
- Time: a few minutes from now (first try) and an earlier time today (second try)

**Test Steps**
1. Tap **Remind**.
2. In the sheet choose **Travel Day Reminder** (or **Packing Reminder**).
3. Pick the date, then the time (a few minutes from now).
4. Wait for the time to arrive.
5. Repeat and pick a time earlier today.

**Expected Result**
- A message "Travel day reminder set." (or "Packing reminder set.") appears.
- A notification arrives at about the chosen time (it may be a few minutes late because the alarm is inexact).
- For the earlier time today the message "Pick a time in the future." appears and no reminder is scheduled.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Fixed in code: reminder_picker.dart now rejects past times. Still needs a device check on Android 13+ and iOS.

---

### TC-ITIN-016 — Save a trip for offline use

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ITIN-016 |
| **Test Case Title** | Save a trip for offline use |
| **Related Test Scenario** | TS-ITIN-007 — Verify share, download, reminders and offline save of a trip. |
| **Module/Feature** | Generated Itinerary |
| **Test Objective** | Verify the trip is readable without internet. |
| **Priority** | Medium |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- A saved trip is open.

**Test Data**
- None needed.

**Test Steps**
1. Tap **Save for Offline** (in the trip actions or on the trip card).
2. Wait for "This trip is now available offline."
3. Turn the internet OFF, close and reopen the app.
4. Open **Saved Trips** and open that trip.

**Expected Result**
- The message "This trip is now available offline." appears (or ""<trip>" is now available offline." on the list).
- Offline, the trip and its images still open; the offline banner shows.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Images are pre-cached; other live data (weather, maps) is expected to be unavailable.

---

### TC-ITIN-017 — Mark a trip as completed — rules

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ITIN-017 |
| **Test Case Title** | Mark a trip as completed — rules |
| **Related Test Scenario** | TS-ITIN-008 — Verify trip completion rules and start-date handling. |
| **Module/Feature** | Generated Itinerary |
| **Test Objective** | Verify completion is blocked without a start date or before the trip starts. |
| **Priority** | Medium |
| **Test Type** | Validation |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Trip A has no start date; Trip B starts in the future; Trip C started yesterday.

**Test Data**
- None needed.

**Test Steps**
1. Open Trip A and try to mark it completed.
2. Open Trip B and try to mark it completed.
3. Open Trip C, mark it completed and confirm "Mark this trip as completed?".

**Expected Result**
- Trip A: "Set a travel date for this trip before marking it completed."
- Trip B: "This trip starts <date> — you can mark it completed once it's underway."
- Trip C: marked completed (a "Completed" label appears in Saved Trips).

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ITIN-018 — Change the start date of a completed trip

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ITIN-018 |
| **Test Case Title** | Change the start date of a completed trip |
| **Related Test Scenario** | TS-ITIN-008 — Verify trip completion rules and start-date handling. |
| **Module/Feature** | Generated Itinerary |
| **Test Objective** | Verify moving a completed trip to a future date clears the completed mark. |
| **Priority** | Low |
| **Test Type** | Functional |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- A completed trip exists.

**Test Data**
- None needed.

**Test Steps**
1. Open the trip and change its start date to a date in the future.

**Expected Result**
- The message "Unmarked as completed — the new date is still upcoming." appears and the trip is no longer completed.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

## Saved Trips & Sharing

### TC-TRIP-001 — View, duplicate and remove a saved trip

| Field | Detail |
|---|---|
| **Test Case ID** | TC-TRIP-001 |
| **Test Case Title** | View, duplicate and remove a saved trip |
| **Related Test Scenario** | TS-TRIP-001 — Verify Saved Trips lists the traveler's trips and supports duplicate and remove. |
| **Module/Feature** | Saved Trips & Sharing |
| **Test Objective** | Verify list actions and empty state. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The traveler owns one saved trip.

**Test Data**
- None needed.

**Test Steps**
1. Open **Profile** > **My Trips** (Saved Trips).
2. Choose **Duplicate** on the trip.
3. Choose remove on the duplicated trip and confirm "Remove this trip?".
4. Remove the original trip too.

**Expected Result**
- A message `"<trip title>" duplicated.` appears and there are two trips.
- Removed trips disappear from the list.
- After the last removal the empty state "No saved trips yet" is shown.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-TRIP-002 — Join a shared trip with a valid code

| Field | Detail |
|---|---|
| **Test Case ID** | TC-TRIP-002 |
| **Test Case Title** | Join a shared trip with a valid code |
| **Related Test Scenario** | TS-TRIP-002 — Verify joining a shared trip by code (valid, invalid, duplicate access). |
| **Module/Feature** | Saved Trips & Sharing |
| **Test Objective** | Verify a second traveler can join with the trip code. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- Traveler A owns a saved trip and has its code (from **Invite** in Trip Companions).
- Traveler B is signed in on another device/account.

**Test Data**
- None needed.

**Test Steps**
1. On Traveler B's device open **Saved Trips** and tap the "Join a shared trip" icon.
2. In "Join a Shared Trip" paste the code into "Trip code".
3. Tap **Join**.

**Expected Result**
- A message `Joined "<trip title>".` appears.
- The trip is listed for Traveler B and B can view it and edit shared parts such as expenses/packing.
- Traveler B appears under Trip Companions on A's trip.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-TRIP-003 — Join with a wrong or empty code

| Field | Detail |
|---|---|
| **Test Case ID** | TC-TRIP-003 |
| **Test Case Title** | Join with a wrong or empty code |
| **Related Test Scenario** | TS-TRIP-002 — Verify joining a shared trip by code (valid, invalid, duplicate access). |
| **Module/Feature** | Saved Trips & Sharing |
| **Test Objective** | Verify error handling for an invalid code. |
| **Priority** | Medium |
| **Test Type** | Negative |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The join dialog is open.

**Test Data**
- Code: `WRONG123`

**Test Steps**
1. Tap **Join** with the code box empty.
2. Enter `WRONG123` and tap **Join**.

**Expected Result**
- Empty: nothing is joined (no crash).
- Wrong code: "No trip found with that code."

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-TRIP-004 — Join a trip the user already has

| Field | Detail |
|---|---|
| **Test Case ID** | TC-TRIP-004 |
| **Test Case Title** | Join a trip the user already has |
| **Related Test Scenario** | TS-TRIP-002 — Verify joining a shared trip by code (valid, invalid, duplicate access). |
| **Module/Feature** | Saved Trips & Sharing |
| **Test Objective** | Verify duplicate access is prevented. |
| **Priority** | Medium |
| **Test Type** | Negative |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Traveler owns a trip and knows its own code.

**Test Data**
- None needed.

**Test Steps**
1. Open the join dialog and enter the code of the traveler's OWN trip (or a trip already joined).
2. Tap **Join**.

**Expected Result**
- "You already have access to this trip." is shown.
- No duplicate entry is created.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-TRIP-005 — Collaborator leaves a shared trip

| Field | Detail |
|---|---|
| **Test Case ID** | TC-TRIP-005 |
| **Test Case Title** | Collaborator leaves a shared trip |
| **Related Test Scenario** | TS-TRIP-002 — Verify joining a shared trip by code (valid, invalid, duplicate access). |
| **Module/Feature** | Saved Trips & Sharing |
| **Test Objective** | Verify a joined traveler can leave and the owner keeps the trip. |
| **Priority** | Low |
| **Test Type** | Functional |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- Traveler B has joined Traveler A's trip.

**Test Data**
- None needed.

**Test Steps**
1. On B's device open the trip and choose to leave it; confirm "Leave this trip?".
2. Check A's trip.

**Expected Result**
- The trip disappears from B's list.
- A's trip still exists and B is no longer a companion.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-TRIP-006 — Trip calendar

| Field | Detail |
|---|---|
| **Test Case ID** | TC-TRIP-006 |
| **Test Case Title** | Trip calendar |
| **Related Test Scenario** | TS-TRIP-003 — Verify the trip calendar and the empty state. |
| **Module/Feature** | Saved Trips & Sharing |
| **Test Objective** | Verify trips with start dates show in the calendar. |
| **Priority** | Low |
| **Test Type** | Functional |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- A saved trip has a start date this month.

**Test Data**
- None needed.

**Test Steps**
1. Open the trip calendar icon on the Saved Trips screen.
2. Look at the trip's date range.
3. Go to the previous/next month.

**Expected Result**
- The "Trip Calendar" screen shows the trip on the correct dates.
- Changing months works without errors.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Needs manual verification of month navigation controls.

---

## AI Travel Assistant

### TC-CHAT-001 — Send a message using a suggested prompt

| Field | Detail |
|---|---|
| **Test Case ID** | TC-CHAT-001 |
| **Test Case Title** | Send a message using a suggested prompt |
| **Related Test Scenario** | TS-CHAT-001 — Verify a traveler can chat with the AI Travel Assistant using typed or suggested prompts. |
| **Module/Feature** | AI Travel Assistant |
| **Test Objective** | Verify the empty chat shows suggestions and the assistant replies. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- A brand-new chat (no messages).

**Test Data**
- None needed.

**Test Steps**
1. Open the AI chat from the app (AI Travel Assistant).
2. Under "Try asking" tap **Plan a 2-day trip to Baguio**.

**Expected Result**
- The 8 suggestion prompts are visible before the first message (e.g., "Recommend beaches in Cebu").
- The tapped text appears as the user message, a typing indicator shows, then an assistant reply about Baguio appears.
- The reply is readable formatted text; a multi-day answer may show a way to generate a full itinerary.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-CHAT-002 — Type a message and send

| Field | Detail |
|---|---|
| **Test Case ID** | TC-CHAT-002 |
| **Test Case Title** | Type a message and send |
| **Related Test Scenario** | TS-CHAT-002 — Verify chat input limits and empty input handling. |
| **Module/Feature** | AI Travel Assistant |
| **Test Objective** | Verify typed messages are sent and shown. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The chat screen is open.

**Test Data**
- Message: `Best food in Ilocos?`

**Test Steps**
1. Tap the input box "Ask about destinations, food, budgets…".
2. Type the message.
3. Tap the send button.

**Expected Result**
- The message is shown on the right side, the input box is cleared, and the assistant answers about Ilocos food.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-CHAT-003 — Empty message and 1000-character limit

| Field | Detail |
|---|---|
| **Test Case ID** | TC-CHAT-003 |
| **Test Case Title** | Empty message and 1000-character limit |
| **Related Test Scenario** | TS-CHAT-002 — Verify chat input limits and empty input handling. |
| **Module/Feature** | AI Travel Assistant |
| **Test Objective** | Verify empty input is not sent and the input is capped at 1000 characters. |
| **Priority** | Medium |
| **Test Type** | Boundary |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The chat screen is open.

**Test Data**
- A 1001-character text (copy/paste)

**Test Steps**
1. Tap send with the box empty (and with only spaces).
2. Paste the 1001-character text and look at the counter.
3. Send the message.

**Expected Result**
- Nothing is sent for empty/space-only input.
- The box accepts at most 1000 characters.
- The 1000-character message is sent and answered (or a friendly error is shown).

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-CHAT-004 — Ask an unrelated question

| Field | Detail |
|---|---|
| **Test Case ID** | TC-CHAT-004 |
| **Test Case Title** | Ask an unrelated question |
| **Related Test Scenario** | TS-CHAT-004 — Verify chat behavior on failures and unrelated questions. |
| **Module/Feature** | AI Travel Assistant |
| **Test Objective** | Verify the assistant stays within Philippine travel topics. |
| **Priority** | Low |
| **Test Type** | Negative |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The chat screen is open.

**Test Data**
- Message: `Write me a Python program to sort numbers.`

**Test Steps**
1. Send the message.

**Expected Result**
- The assistant politely redirects to Philippine travel planning and does not provide the program.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** AI output can vary. Judge by the intent of the system prompt (travel only).

---

### TC-CHAT-005 — Send a message while offline

| Field | Detail |
|---|---|
| **Test Case ID** | TC-CHAT-005 |
| **Test Case Title** | Send a message while offline |
| **Related Test Scenario** | TS-CHAT-004 — Verify chat behavior on failures and unrelated questions. |
| **Module/Feature** | AI Travel Assistant |
| **Test Objective** | Verify a friendly error bubble instead of technical text. |
| **Priority** | High |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The chat screen is open; internet OFF.

**Test Data**
- None needed.

**Test Steps**
1. Send any message.
2. Turn the internet ON.
3. Send a new message.

**Expected Result**
- An error message bubble appears with friendly text (for example "No internet connection..." or "Something went wrong. Please try again."), with no codes or JSON.
- After reconnecting, the next message gets a normal reply and the earlier error bubble is not treated as a question.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-CHAT-006 — Chat history is kept after closing the app

| Field | Detail |
|---|---|
| **Test Case ID** | TC-CHAT-006 |
| **Test Case Title** | Chat history is kept after closing the app |
| **Related Test Scenario** | TS-CHAT-003 — Verify multiple chats (create, switch, delete, limit) and persistence on the device. |
| **Module/Feature** | AI Travel Assistant |
| **Test Objective** | Verify conversations are stored on the device. |
| **Priority** | Medium |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- A chat with at least 2 exchanges exists.

**Test Data**
- None needed.

**Test Steps**
1. Close the app completely and reopen it.
2. Open the AI Travel Assistant and the chats list (Chats icon).

**Expected Result**
- The earlier chat is listed and its messages are intact.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** History is stored locally per device (SharedPreferences), so it will not appear on another device.

---

### TC-CHAT-007 — Start a new chat, switch chats, delete a chat

| Field | Detail |
|---|---|
| **Test Case ID** | TC-CHAT-007 |
| **Test Case Title** | Start a new chat, switch chats, delete a chat |
| **Related Test Scenario** | TS-CHAT-003 — Verify multiple chats (create, switch, delete, limit) and persistence on the device. |
| **Module/Feature** | AI Travel Assistant |
| **Test Objective** | Verify multiple-chat management. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- At least one existing chat.

**Test Data**
- None needed.

**Test Steps**
1. Tap the **Chats** icon and start a new chat.
2. Send one message in the new chat.
3. Open **Chats** again and switch to the older chat.
4. Delete the new chat using its delete icon and confirm "Delete this chat?".

**Expected Result**
- A new empty chat opens (title "New Chat" until the first message).
- Switching shows each chat's own messages.
- Delete confirmation says "This conversation will be permanently deleted." and the chat is removed from the list.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-CHAT-008 — Chat history limits (30 chats, 60 messages)

| Field | Detail |
|---|---|
| **Test Case ID** | TC-CHAT-008 |
| **Test Case Title** | Chat history limits (30 chats, 60 messages) |
| **Related Test Scenario** | TS-CHAT-003 — Verify multiple chats (create, switch, delete, limit) and persistence on the device. |
| **Module/Feature** | AI Travel Assistant |
| **Test Objective** | Verify the oldest chats/messages age out. |
| **Priority** | Low |
| **Test Type** | Boundary |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- A tester willing to create 31 chats (or edit the stored data).

**Test Data**
- None needed.

**Test Steps**
1. Create 31 chats with one message each.
2. Open the Chats list and count them.
3. In one chat send more than 60 messages in total.

**Expected Result**
- Only the 30 most recent chats are kept; the oldest is removed.
- A single chat keeps only its last 60 messages.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Time-consuming; limits come from ai_chat_provider.dart (_maxSessions = 30, _maxStoredMessages = 60).

---

### TC-CHAT-009 — Location-based question with and without permission

| Field | Detail |
|---|---|
| **Test Case ID** | TC-CHAT-009 |
| **Test Case Title** | Location-based question with and without permission |
| **Related Test Scenario** | TS-CHAT-001 — Verify a traveler can chat with the AI Travel Assistant using typed or suggested prompts. |
| **Module/Feature** | AI Travel Assistant |
| **Test Objective** | Verify "near me" questions behave based on location permission. |
| **Priority** | Low |
| **Test Type** | Functional |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The chat is open.

**Test Data**
- Message: `Hotels near me`

**Test Steps**
1. With location permission DENIED, send the message.
2. Allow location permission and send it again.

**Expected Result**
- Without location: the assistant says it does not have the user's location and suggests enabling location access.
- With location: it recommends real nearby places by name with links.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Needs manual verification: how/when the chat asks for location permission.

---

### TC-CHAT-010 — Generate Full Itinerary from a chat plan

| Field | Detail |
|---|---|
| **Test Case ID** | TC-CHAT-010 |
| **Test Case Title** | Generate Full Itinerary from a chat plan |
| **Related Test Scenario** | TS-CHAT-001 — Verify a traveler can chat with the AI Travel Assistant using typed or suggested prompts. |
| **Module/Feature** | AI Travel Assistant |
| **Test Objective** | Verify a multi-day answer in chat can be turned into a full itinerary. |
| **Priority** | Medium |
| **Test Type** | Integration |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The chat screen is open.

**Test Data**
- Message: `Plan a 2-day trip to Baguio`

**Test Steps**
1. Send the message and wait for a multi-day answer.
2. Under the assistant reply tap **Generate Full Itinerary**.

**Expected Result**
- A loading state is shown, then the generated itinerary screen opens for Baguio with the default settings (Van / Car Rental, Beaches + Food interests).
- If generation fails, a friendly error message is shown and the chat stays open.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Button only appears when the reply follows the multi-day plan format. Default values come from planner_options.dart.

---

## Profile

### TC-PROF-001 — View the Profile screen

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PROF-001 |
| **Test Case Title** | View the Profile screen |
| **Related Test Scenario** | TS-PROF-001 — Verify the Profile screen shows the traveler's details and navigation shortcuts. |
| **Module/Feature** | Profile |
| **Test Objective** | Verify profile information and shortcuts. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).

**Test Data**
- None needed.

**Test Steps**
1. Tap the **Profile** tab.
2. Look at the header, statistics and menu items.

**Expected Result**
- The traveler's name, email and photo (or initials) are shown.
- Shortcuts include **My Trips**, **Reviews**, **Saved**, **Notifications**, **Edit Profile**, **Settings** and **Log Out**.
- The **Travel Preferences** section shows the traveler's choices.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-PROF-002 — Update the full name

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PROF-002 |
| **Test Case Title** | Update the full name |
| **Related Test Scenario** | TS-PROF-002 — Verify a traveler can edit name, photo, travel preferences and favorite categories. |
| **Module/Feature** | Profile |
| **Test Objective** | Verify the name change is saved. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).

**Test Data**
- New name: `Maria S. Santos`

**Test Steps**
1. Open **Profile** > **Edit Profile**.
2. Change **Full Name** to the new name.
3. Tap **Save Changes**.

**Expected Result**
- A message "Profile updated." appears.
- Profile shows the new name.
- Reopening the app still shows the new name.

**Postconditions:** The user profile name is updated.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-PROF-003 — Full Name validation

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PROF-003 |
| **Test Case Title** | Full Name validation |
| **Related Test Scenario** | TS-PROF-003 — Verify name validation and photo upload rules on Edit Profile. |
| **Module/Feature** | Profile |
| **Test Objective** | Verify empty, 1-character and 61-character names are rejected. |
| **Priority** | Medium |
| **Test Type** | Validation |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The Edit Profile screen is open.

**Test Data**
- Empty
- `A`
- 61 characters

**Test Steps**
1. Clear the Full Name field and tap **Save Changes**.
2. Enter `A` and tap **Save Changes**.
3. Paste 61 characters.

**Expected Result**
- Empty: "Name is required".
- `A`: "Name is too short".
- The field accepts at most 60 characters (counter shows 60).
- Nothing is saved while an error shows.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-PROF-004 — Save with no changes

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PROF-004 |
| **Test Case Title** | Save with no changes |
| **Related Test Scenario** | TS-PROF-002 — Verify a traveler can edit name, photo, travel preferences and favorite categories. |
| **Module/Feature** | Profile |
| **Test Objective** | Verify the "Nothing to save." message. |
| **Priority** | Low |
| **Test Type** | Negative |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Edit Profile just opened; nothing changed.

**Test Data**
- None needed.

**Test Steps**
1. Tap **Save Changes** without changing anything.

**Expected Result**
- A message "Nothing to save." appears; no write is made.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-PROF-005 — Change travel preferences and favorite categories

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PROF-005 |
| **Test Case Title** | Change travel preferences and favorite categories |
| **Related Test Scenario** | TS-PROF-002 — Verify a traveler can edit name, photo, travel preferences and favorite categories. |
| **Module/Feature** | Profile |
| **Test Objective** | Verify chips are saved. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Edit Profile is open.

**Test Data**
- None needed.

**Test Steps**
1. Select or unselect chips under **Travel Preferences** and **Favorite Categories**.
2. Tap **Save Changes**.
3. Close and reopen Edit Profile.

**Expected Result**
- "Profile updated." appears.
- The same chips are selected when the screen is reopened.
- Home/Explore suggestions may reflect the chosen interests.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-PROF-006 — Upload a new profile photo

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PROF-006 |
| **Test Case Title** | Upload a new profile photo |
| **Related Test Scenario** | TS-PROF-003 — Verify name validation and photo upload rules on Edit Profile. |
| **Module/Feature** | Profile |
| **Test Objective** | Verify photo picking, upload and replacement. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Gallery permission allowed; a JPG/PNG under 5 MB is available.

**Test Data**
- None needed.

**Test Steps**
1. On Edit Profile tap the camera icon on the avatar.
2. Pick a photo from the gallery.
3. Wait for the upload indicator to finish.

**Expected Result**
- A loading indicator is shown on the avatar while uploading.
- The new photo replaces the old avatar on Edit Profile and Profile.
- The old uploaded photo file is removed from storage (best effort).

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-PROF-007 — Profile photo — permission denied, oversize and offline

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PROF-007 |
| **Test Case Title** | Profile photo — permission denied, oversize and offline |
| **Related Test Scenario** | TS-PROF-003 — Verify name validation and photo upload rules on Edit Profile. |
| **Module/Feature** | Profile |
| **Test Objective** | Verify failures give friendly messages and keep the old photo. |
| **Priority** | Medium |
| **Test Type** | Negative |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Edit Profile is open; a photo larger than 5 MB is available.

**Test Data**
- None needed.

**Test Steps**
1. With Photos permission denied, tap the camera icon.
2. Allow the permission, pick the photo larger than 5 MB.
3. Turn off the internet and pick a normal photo.

**Expected Result**
- Denied: a permission message (e.g., "Permission was denied. Please allow access in your device settings and try again.") or no picker; no crash.
- Large photo: the picker shrinks it (max width 800 px, quality 85) before upload, so it uploads normally and the new avatar shows.
- Offline: "No internet connection. Please check your network and try again." and the old photo remains.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Code trace: edit_profile_screen.dart resizes the image, so the 5 MB Storage limit is rarely reached from this screen.

---

### TC-PROF-008 — Change email — validation and wrong password

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PROF-008 |
| **Test Case Title** | Change email — validation and wrong password |
| **Related Test Scenario** | TS-PROF-004 — Verify the email-change flow (re-authentication and confirmation link). |
| **Module/Feature** | Profile |
| **Test Objective** | Verify the Update Email dialog checks and re-authentication. |
| **Priority** | Medium |
| **Test Type** | Negative |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Edit Profile > Security is visible.

**Test Data**
- New Email: `tester01.new@example.com`
- Wrong password: `Wrong123`

**Test Steps**
1. Tap **Update Email**.
2. Enter `abc@` as New Email and the correct password; confirm.
3. Enter the valid new email with the wrong password `Wrong123`; confirm.

**Expected Result**
- Invalid format: "Enter a valid email address".
- Wrong password: "Incorrect email or password." (re-authentication fails) and the email is not changed.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-PROF-009 — Change email — success

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PROF-009 |
| **Test Case Title** | Change email — success |
| **Related Test Scenario** | TS-PROF-004 — Verify the email-change flow (re-authentication and confirmation link). |
| **Module/Feature** | Profile |
| **Test Objective** | Verify a confirmation link is required. |
| **Priority** | Medium |
| **Test Type** | Integration |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The tester can read the new email inbox.

**Test Data**
- None needed.

**Test Steps**
1. Tap **Update Email**, enter the new email and the correct current password, then confirm.
2. Read the message on screen.
3. Open the new inbox and click the confirmation link.
4. Reopen the app and sign in with the new email.

**Expected Result**
- A message "Check your new email to confirm the change." appears; the current email still works until confirmed.
- After clicking the link the new email becomes the sign-in email and Profile shows it.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** The Firestore profile email updates the next time the app runs while signed in.

---

### TC-PROF-010 — Recently Viewed list

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PROF-010 |
| **Test Case Title** | Recently Viewed list |
| **Related Test Scenario** | TS-PROF-005 — Verify Recently Viewed and My Reviews screens. |
| **Module/Feature** | Profile |
| **Test Objective** | Verify viewed places appear and the empty state. |
| **Priority** | Low |
| **Test Type** | Functional |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The tester opened 2 destination details screens.

**Test Data**
- None needed.

**Test Steps**
1. Open **Profile** > **Recently Viewed**.
2. Tap one item.
3. Later use Settings > **Clear Recently Viewed** and reopen the list.

**Expected Result**
- The viewed places are listed (most recent first).
- Tapping opens the details screen.
- After clearing, the state "Nothing viewed yet" is shown.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-PROF-011 — My Reviews list

| Field | Detail |
|---|---|
| **Test Case ID** | TC-PROF-011 |
| **Test Case Title** | My Reviews list |
| **Related Test Scenario** | TS-PROF-005 — Verify Recently Viewed and My Reviews screens. |
| **Module/Feature** | Profile |
| **Test Objective** | Verify the traveler's reviews appear and the empty state. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The traveler wrote at least one review (TC-REV-001).

**Test Data**
- None needed.

**Test Steps**
1. Open **Profile** > **Reviews** (My Reviews).
2. Use an account with no reviews and open the same screen.

**Expected Result**
- The written reviews are listed with rating, comment and place.
- An account with no reviews shows "No reviews yet".

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

## Settings

### TC-SET-001 — Dark mode, theme, font and text size

| Field | Detail |
|---|---|
| **Test Case ID** | TC-SET-001 |
| **Test Case Title** | Dark mode, theme, font and text size |
| **Related Test Scenario** | TS-SET-001 — Verify appearance settings (dark mode, theme, font style, text size) apply and persist. |
| **Module/Feature** | Settings |
| **Test Objective** | Verify appearance options apply immediately and stay after restart. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The Settings screen is open.

**Test Data**
- None needed.

**Test Steps**
1. Turn **Dark Mode** on.
2. Tap **Theme** and select another accent color.
3. Tap **Font Style** and select another font.
4. Tap **Text Size** and choose the largest size.
5. Close and reopen the app.

**Expected Result**
- Each option changes the look of the whole app immediately.
- The chosen values are still applied after the app restarts.
- Text at the largest size does not overflow or get cut off on Home and Settings.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-SET-002 — Notification switches

| Field | Detail |
|---|---|
| **Test Case ID** | TC-SET-002 |
| **Test Case Title** | Notification switches |
| **Related Test Scenario** | TS-SET-002 — Verify notification switches and the Location Services switch. |
| **Module/Feature** | Settings |
| **Test Objective** | Verify master and category switches. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The Settings screen is open.

**Test Data**
- None needed.

**Test Steps**
1. Turn the **Notifications** switch OFF and look at the category rows.
2. Turn it ON and turn OFF one category (e.g., Travel Tips).
3. Close and reopen Settings.

**Expected Result**
- With the master switch OFF, the category rows are dimmed and cannot be tapped.
- The chosen category stays OFF after reopening Settings.
- The note "Emergency alerts and maintenance notices can't be turned off." is shown; those categories have no switch.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-SET-003 — Location Services switch and permission states

| Field | Detail |
|---|---|
| **Test Case ID** | TC-SET-003 |
| **Test Case Title** | Location Services switch and permission states |
| **Related Test Scenario** | TS-SET-002 — Verify notification switches and the Location Services switch. |
| **Module/Feature** | Settings |
| **Test Objective** | Verify the switch requests permission and reacts to denial. |
| **Priority** | High |
| **Test Type** | Negative |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Location permission not yet granted.

**Test Data**
- None needed.

**Test Steps**
1. Turn **Location Services** ON and choose **Deny** in the system dialog.
2. Turn it ON again and choose **Allow**.
3. Deny permanently in system settings, then turn it ON in the app.

**Expected Result**
- After a plain Deny the app does not crash. The switch stays ON and no message is shown (the code only saves the preference).
- After Allow the switch stays ON.
- When location is permanently denied or the phone's location service is off, the message "Location access is off at the system level. Enable it in your device settings." appears with an **Open Settings** button that opens the system settings.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Code trace: the switch is not turned back OFF after a plain Deny, and Home still shows the "Allow Location" card. Record whether this is acceptable.

---

### TC-SET-004 — Change password from Settings

| Field | Detail |
|---|---|
| **Test Case ID** | TC-SET-004 |
| **Test Case Title** | Change password from Settings |
| **Related Test Scenario** | TS-SET-003 — Verify Change Password from Settings. |
| **Module/Feature** | Settings |
| **Test Objective** | Verify re-authentication and password rules. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The traveler signed in with email and password `Test@1234`.

**Test Data**
- Wrong current: `Wrong123`
- Too short new: `Ab@1234`
- Valid new: `NewPass@123`

**Test Steps**
1. Tap **Change Password**.
2. Leave Current Password empty and tap confirm.
3. Enter the wrong current password with a valid new one.
4. Enter the correct current password with the too-short new password.
5. Enter the correct current password with the valid new password.

**Expected Result**
- Empty: "Current password is required".
- Wrong current: "Incorrect email or password." and no change.
- Too short: "Password must be at least 8 characters".
- Valid: a message "Password updated." appears and the new password works at the next login.

**Postconditions:** The password is `NewPass@123`.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-SET-005 — Delete account — wrong password and cancel

| Field | Detail |
|---|---|
| **Test Case ID** | TC-SET-005 |
| **Test Case Title** | Delete account — wrong password and cancel |
| **Related Test Scenario** | TS-SET-004 — Verify Delete Account removes the account and its data. |
| **Module/Feature** | Settings |
| **Test Objective** | Verify the deletion is protected by the password. |
| **Priority** | High |
| **Test Type** | Negative |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Use a throw-away account.

**Test Data**
- None needed.

**Test Steps**
1. Tap **Delete Account**.
2. In "Confirm Your Password" leave the password empty and confirm.
3. Enter a wrong password and confirm.
4. Cancel the dialog.

**Expected Result**
- Empty: "Current password is required".
- Wrong: an error message is shown (e.g., "Incorrect email or password.") and the account remains.
- Cancel keeps the account.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-SET-006 — Delete account — success and data cleanup

| Field | Detail |
|---|---|
| **Test Case ID** | TC-SET-006 |
| **Test Case Title** | Delete account — success and data cleanup |
| **Related Test Scenario** | TS-SET-004 — Verify Delete Account removes the account and its data. |
| **Module/Feature** | Settings |
| **Test Objective** | Verify the account and user-owned data are removed. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A throw-away account with 1 review, 1 favorite, 1 saved trip and 1 notification.

**Test Data**
- None needed.

**Test Steps**
1. Tap **Delete Account**.
2. Enter the correct password and confirm **Delete Account**.
3. Try to log in again with the same email and password.
4. In the Firebase console (or Admin Portal) check the user, review, favorite and trip data.

**Expected Result**
- The app returns to Login after deletion.
- Login fails ("Incorrect email or password.").
- The user's reviews, notifications, favorites, saved trips and profile are removed; the Auth user is deleted.

**Postconditions:** The account no longer exists.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Code trace: deletion removes reviews, notifications, favorites, saved trips, visited/recently viewed and the profile. It does NOT remove `businesses`, `business_owner_applications` or `admin_users` documents, so a business owner's listing stays after account deletion. Record this as a known gap.

---

### TC-SET-007 — Delete account interrupted by lost internet

| Field | Detail |
|---|---|
| **Test Case ID** | TC-SET-007 |
| **Test Case Title** | Delete account interrupted by lost internet |
| **Related Test Scenario** | TS-SET-004 — Verify Delete Account removes the account and its data. |
| **Module/Feature** | Settings |
| **Test Objective** | Verify data consistency after a failed deletion. |
| **Priority** | Medium |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A throw-away account with 3 reviews and 3 favorites.

**Test Data**
- None needed.

**Test Steps**
1. Start **Delete Account** with the correct password.
2. Turn the internet OFF right after confirming.
3. Turn the internet ON, sign in again (if still possible) and check reviews/favorites.

**Expected Result**
- A friendly error message is shown.
- The account is not left half-deleted with a working login and missing data unnoticed: either the account can still be used (and the tester can retry deletion) or it is fully deleted.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Data is removed step by step and the Auth user last, so a failure can leave partial data. Record exactly what remains.

---

### TC-SET-008 — Legal pages, FAQ and What's New

| Field | Detail |
|---|---|
| **Test Case ID** | TC-SET-008 |
| **Test Case Title** | Legal pages, FAQ and What's New |
| **Related Test Scenario** | TS-SET-005 — Verify legal pages, FAQ and What's New screens. |
| **Module/Feature** | Settings |
| **Test Objective** | Verify the information screens open and FAQ search works. |
| **Priority** | Low |
| **Test Type** | Functional |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The Settings screen is open.

**Test Data**
- FAQ search text: `zzzz`

**Test Steps**
1. Open the Privacy, Terms and About pages from Settings.
2. Open **FAQ** and expand one question; type `zzzz` in the search box.
3. Open **What's New**.

**Expected Result**
- Each page opens with readable text ("Last updated: September 2026" on legal pages; "Version 1.0.0" on About).
- FAQ expands questions and shows "No matches" for `zzzz`.
- What's New lists the release notes.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

## Notifications

### TC-NOTIF-001 — View and read notifications

| Field | Detail |
|---|---|
| **Test Case ID** | TC-NOTIF-001 |
| **Test Case Title** | View and read notifications |
| **Related Test Scenario** | TS-NOTIF-001 — Verify the in-app notifications list, read state and empty state. |
| **Module/Feature** | Notifications |
| **Test Objective** | Verify announcements appear and tapping marks them read. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- An admin sent an announcement (TC-ADM-016) to all travelers.

**Test Data**
- None needed.

**Test Steps**
1. Open **Profile** > **Notifications**.
2. Find the announcement and tap it.

**Expected Result**
- The announcement is listed with its title and text.
- After tapping, the unread indicator is removed.
- It stays read after leaving and reopening the screen.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-NOTIF-002 — Notifications empty state

| Field | Detail |
|---|---|
| **Test Case ID** | TC-NOTIF-002 |
| **Test Case Title** | Notifications empty state |
| **Related Test Scenario** | TS-NOTIF-001 — Verify the in-app notifications list, read state and empty state. |
| **Module/Feature** | Notifications |
| **Test Objective** | Verify empty state text. |
| **Priority** | Low |
| **Test Type** | Functional |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A new traveler account with no notifications.

**Test Data**
- None needed.

**Test Steps**
1. Open the Notifications screen.

**Expected Result**
- An empty state (title beginning "You're ...") is shown instead of a blank page.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-NOTIF-003 — Push notification permission prompt

| Field | Detail |
|---|---|
| **Test Case ID** | TC-NOTIF-003 |
| **Test Case Title** | Push notification permission prompt |
| **Related Test Scenario** | TS-NOTIF-002 — Verify push notification permission and delivery (background and foreground). |
| **Module/Feature** | Notifications |
| **Test Objective** | Verify the OS permission flow. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- Fresh install; notification permission not yet decided; a real device.

**Test Data**
- None needed.

**Test Steps**
1. Sign in for the first time.
2. When the system asks to allow notifications choose **Allow**.
3. Repeat on another install and choose **Don't allow**.

**Expected Result**
- Allow: the app can receive push notifications.
- Don't allow: the app works normally, only pushes are not shown.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-NOTIF-004 — Push notification while app is in background, closed, and locked screen

| Field | Detail |
|---|---|
| **Test Case ID** | TC-NOTIF-004 |
| **Test Case Title** | Push notification while app is in background, closed, and locked screen |
| **Related Test Scenario** | TS-NOTIF-002 — Verify push notification permission and delivery (background and foreground). |
| **Module/Feature** | Notifications |
| **Test Objective** | Verify announcements arrive in different app states. |
| **Priority** | Medium |
| **Test Type** | Integration |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Notification permission allowed; an admin ready to send an announcement.

**Test Data**
- None needed.

**Test Steps**
1. Put the app in the background and send an announcement from the Admin Portal.
2. Close the app fully and send another one.
3. Lock the screen and send a third one.
4. Unlock and open the notification.

**Expected Result**
- A system notification with the announcement title/text appears in each case.
- Tapping it opens the app; the announcement is visible in the Notifications list.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Delivery relies on FCM and the sendPushOnNotificationCreated Cloud Function.

---

### TC-NOTIF-005 — Category switch blocks non-emergency push

| Field | Detail |
|---|---|
| **Test Case ID** | TC-NOTIF-005 |
| **Test Case Title** | Category switch blocks non-emergency push |
| **Related Test Scenario** | TS-NOTIF-002 — Verify push notification permission and delivery (background and foreground). |
| **Module/Feature** | Notifications |
| **Test Objective** | Verify a disabled category is not shown to the traveler. |
| **Priority** | Low |
| **Test Type** | Functional |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- In Settings the **Travel Tips** category is turned OFF.

**Test Data**
- None needed.

**Test Steps**
1. Send an announcement with category Travel Tip from the Admin Portal.
2. Send another with category Emergency Alert.

**Expected Result**
- The Travel Tip announcement is hidden from this traveler's in-app Notifications list.
- The Emergency Alert is still shown in the list (it cannot be switched off).

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Code trace: only the in-app list is filtered (notifications_screen.dart). A system push for a switched-off category may still be shown by the phone.

---

### TC-NOTIF-006 — Notifications when signed out / offline

| Field | Detail |
|---|---|
| **Test Case ID** | TC-NOTIF-006 |
| **Test Case Title** | Notifications when signed out / offline |
| **Related Test Scenario** | TS-NOTIF-001 — Verify the in-app notifications list, read state and empty state. |
| **Module/Feature** | Notifications |
| **Test Objective** | Verify the Notifications screen states without a network. |
| **Priority** | Low |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Notifications screen opened at least once; internet OFF.

**Test Data**
- None needed.

**Test Steps**
1. Turn the internet OFF.
2. Open the Notifications screen.

**Expected Result**
- Previously loaded notifications (cached) or a friendly error state is shown; no technical text.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** The sign-in message ("Sign in to view your notifications.") is only for signed-out users and is not normally reachable.

---

## Business Owner

### TC-BIZ-001 — Submit a Business Owner application

| Field | Detail |
|---|---|
| **Test Case ID** | TC-BIZ-001 |
| **Test Case Title** | Submit a Business Owner application |
| **Related Test Scenario** | TS-BIZ-001 — Verify a traveler can submit a Business Owner application with valid details. |
| **Module/Feature** | Business Owner |
| **Test Objective** | Verify the application is saved and confirmation shown. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- Signed in with a new unverified/verified traveler on the **Business Owner Application** screen (from TC-REG-002).

**Test Data**
- Business name: `Sunset Bay Resort`
- Category: `Accommodation`
- Contact phone: `+63 917 123 4567`
- Description: `Beachfront resort with 12 rooms and a restaurant.`

**Test Steps**
1. Fill in the form with the test data.
2. Tap **Submit Application**.
3. On the "Application submitted" screen tap **Continue**.

**Expected Result**
- The button shows a loading state while saving.
- A screen titled "Application submitted" is shown.
- **Continue** opens Verify Email (or the app if already verified).
- The application appears with status Pending in the Admin Portal **Business Applications** list.

**Postconditions:** One pending application exists.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-BIZ-002 — Application validation

| Field | Detail |
|---|---|
| **Test Case ID** | TC-BIZ-002 |
| **Test Case Title** | Application validation |
| **Related Test Scenario** | TS-BIZ-002 — Verify Business Owner application validation. |
| **Module/Feature** | Business Owner |
| **Test Objective** | Verify required name/phone and description limit. |
| **Priority** | High |
| **Test Type** | Validation |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The Business Owner Application form is open.

**Test Data**
- Phone cases: empty, `12345`, `abc12345`, `+63 917 123 4567`
- Description: 1001 characters

**Test Steps**
1. Tap **Submit Application** with the name empty.
2. Enter a name and test each phone value.
3. Paste a 1001-character description.

**Expected Result**
- Name: "Business name is required".
- Phone empty: "This field is required"; `12345` and `abc12345`: "Enter a valid phone number"; the last value is accepted.
- Description: "Description must be 1000 characters or fewer".

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-BIZ-003 — Skip the application with the back arrow

| Field | Detail |
|---|---|
| **Test Case ID** | TC-BIZ-003 |
| **Test Case Title** | Skip the application with the back arrow |
| **Related Test Scenario** | TS-BIZ-002 — Verify Business Owner application validation. |
| **Module/Feature** | Business Owner |
| **Test Objective** | Verify the user can continue as a normal traveler. |
| **Priority** | Low |
| **Test Type** | Functional |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- Business Owner Application screen opened right after registration.

**Test Data**
- None needed.

**Test Steps**
1. Tap the back arrow at the top left.

**Expected Result**
- The app goes to Verify Email; no application is stored.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-BIZ-004 — Accept the Business Owner role invite

| Field | Detail |
|---|---|
| **Test Case ID** | TC-BIZ-004 |
| **Test Case Title** | Accept the Business Owner role invite |
| **Related Test Scenario** | TS-BIZ-003 — Verify invite acceptance/decline gives the Business Owner role. |
| **Module/Feature** | Business Owner |
| **Test Objective** | Verify invite acceptance gives owner tabs. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The traveler's application was approved in the Admin Portal (invite staged) for this email.

**Test Data**
- None needed.

**Test Steps**
1. Sign in as the traveler and open **Profile**.
2. Find the invitation and tap **Accept**.
3. Confirm "Accept this role?".
4. Look at the bottom navigation.

**Expected Result**
- The message "Welcome to the Admin Portal." (or similar) appears.
- The 4th tab changes from **Saved** to **My Business** and the Home tab shows the business Dashboard.
- An **Admin Portal** link/label is available on Profile.

**Postconditions:** An `admin_users` document with role businessOwner exists for the user.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-BIZ-005 — Decline the invite

| Field | Detail |
|---|---|
| **Test Case ID** | TC-BIZ-005 |
| **Test Case Title** | Decline the invite |
| **Related Test Scenario** | TS-BIZ-003 — Verify invite acceptance/decline gives the Business Owner role. |
| **Module/Feature** | Business Owner |
| **Test Objective** | Verify declining removes the invite without giving access. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A pending invite exists for the traveler.

**Test Data**
- None needed.

**Test Steps**
1. On **Profile** tap **Decline** and confirm "Decline this invite?".

**Expected Result**
- The dialog says "You can be invited again later if you change your mind."
- The invite disappears; the traveler keeps the normal tabs (Saved, Home).

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-BIZ-006 — Create and submit a Food & Dining listing

| Field | Detail |
|---|---|
| **Test Case ID** | TC-BIZ-006 |
| **Test Case Title** | Create and submit a Food & Dining listing |
| **Related Test Scenario** | TS-BIZ-004 — Verify a business owner can create and submit a listing with required fields. |
| **Module/Feature** | Business Owner |
| **Test Objective** | Verify a complete listing is submitted for review. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The signed-in traveler has an active Business Owner role (accepted invite) — example: owner01@example.com.
- No listing exists yet; a listing photo and a permit photo (< 10 MB) are available.

**Test Data**
- Name: `Lola Cely Kitchen`
- Category: `Food & Dining`
- Cuisine: `Filipino`
- Price range: `₱₱`
- Opening hours: `9:00 AM – 9:00 PM`
- Description: `Home-style Filipino dishes.`
- Province: any
- Address: `12 Rizal St., Poblacion`
- Phone: `0917 555 1234`
- Website: `https://lolacely.example.com`

**Test Steps**
1. Open **My Business** and start the listing (**Set Up My Business**).
2. Fill all sections: Basic Information, Location & Contact, Accessibility, Verification.
3. Upload the listing photo and the "Business Permit / DTI Registration" photo.
4. Tap the submit button.

**Expected Result**
- The message "Listing submitted for review." appears.
- A status banner shows the listing is pending review.
- The listing is not visible to travelers until an admin approves it.

**Postconditions:** A `businesses` doc (status pending) and a private permit doc exist.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-BIZ-007 — Listing required fields and limits

| Field | Detail |
|---|---|
| **Test Case ID** | TC-BIZ-007 |
| **Test Case Title** | Listing required fields and limits |
| **Related Test Scenario** | TS-BIZ-005 — Verify business listing validation and Food & Dining specific fields. |
| **Module/Feature** | Business Owner |
| **Test Objective** | Verify all required-field messages on My Business. |
| **Priority** | High |
| **Test Type** | Validation |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The signed-in traveler has an active Business Owner role (accepted invite) — example: owner01@example.com.
- The listing form is open and empty; category is Food & Dining.

**Test Data**
- Website: `www.example.com`
- Description: 3001 characters
- Phone: `12345`

**Test Steps**
1. Tap submit with everything empty.
2. Fill the name and other text fields but leave Province empty; tap submit.
3. Choose a province but no listing photo; tap submit.
4. Enter the test website, phone and long description.

**Expected Result**
- Name: "Name is required"; Cuisine: "Cuisine is required"; Opening hours: "Opening hours is required"; Description: "Description is required"; Address: "Address is required"; Phone: "This field is required".
- No province: "Province is required."
- No photo: "Please upload a photo for your listing."
- Website without http/https: "Enter a valid URL (starting with http:// or https://)".
- Phone `12345`: "Enter a valid phone number".
- Description over 3000: "Description must be 3000 characters or fewer".

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-BIZ-008 — Add a menu/catalog item

| Field | Detail |
|---|---|
| **Test Case ID** | TC-BIZ-008 |
| **Test Case Title** | Add a menu/catalog item |
| **Related Test Scenario** | TS-BIZ-005 — Verify business listing validation and Food & Dining specific fields. |
| **Module/Feature** | Business Owner |
| **Test Objective** | Verify the item dialog needs a name, price and photo. |
| **Priority** | Medium |
| **Test Type** | Validation |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The signed-in traveler has an active Business Owner role (accepted invite) — example: owner01@example.com.
- The listing form is open.

**Test Data**
- Item name: `Adobo`
- Price: `180`

**Test Steps**
1. Tap the **Add** item button (label depends on the category, e.g., "Add Menu Item").
2. Tap **Add** with all fields empty.
3. Enter the name and price but no photo; tap **Add**.
4. Add a photo and tap **Add**.

**Expected Result**
- Empty: name required ("<Item> name is required") and price required ("Price is required").
- No photo: "Add a photo for this item."
- With all data the item is added to the list.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-BIZ-009 — Submit without a permit photo

| Field | Detail |
|---|---|
| **Test Case ID** | TC-BIZ-009 |
| **Test Case Title** | Submit without a permit photo |
| **Related Test Scenario** | TS-BIZ-006 — Verify permit photo upload, OCR trigger and the "no permit" warning. |
| **Module/Feature** | Business Owner |
| **Test Objective** | Verify the warning and the optional continue. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The signed-in traveler has an active Business Owner role (accepted invite) — example: owner01@example.com.
- All required listing fields are filled; no permit photo uploaded.

**Test Data**
- None needed.

**Test Steps**
1. Tap submit.
2. Read the "Submit without a permit photo?" dialog, tap cancel.
3. Tap submit again and choose **Submit Anyway**.

**Expected Result**
- The dialog explains a permit or DTI photo speeds up approval.
- Cancel keeps the form open with no submission.
- Submit Anyway submits the listing ("Listing submitted for review.").

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-BIZ-010 — Permit upload triggers OCR shown to admin

| Field | Detail |
|---|---|
| **Test Case ID** | TC-BIZ-010 |
| **Test Case Title** | Permit upload triggers OCR shown to admin |
| **Related Test Scenario** | TS-BIZ-006 — Verify permit photo upload, OCR trigger and the "no permit" warning. |
| **Module/Feature** | Business Owner |
| **Test Objective** | Verify OCR text is created for the admin only. |
| **Priority** | High |
| **Test Type** | Security |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The signed-in traveler has an active Business Owner role (accepted invite) — example: owner01@example.com.
- A clear photo of a printed permit (< 10 MB).

**Test Data**
- None needed.

**Test Steps**
1. Upload the permit photo and submit the listing.
2. Wait about 30 seconds.
3. In the Admin Portal open **Businesses** and view that listing.
4. Open a traveler account and look at the same business (after approval).

**Expected Result**
- Submission succeeds even if OCR is slow or fails.
- The admin sees the permit photo and the extracted text labeled as a reading aid ("verify against the actual photo").
- The traveler app never shows the permit photo or the OCR text.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-BIZ-011 — Permit photo — non-image and over 10 MB

| Field | Detail |
|---|---|
| **Test Case ID** | TC-BIZ-011 |
| **Test Case Title** | Permit photo — non-image and over 10 MB |
| **Related Test Scenario** | TS-BIZ-006 — Verify permit photo upload, OCR trigger and the "no permit" warning. |
| **Module/Feature** | Business Owner |
| **Test Objective** | Verify Storage rules reject invalid permit files. |
| **Priority** | Medium |
| **Test Type** | Negative |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The signed-in traveler has an active Business Owner role (accepted invite) — example: owner01@example.com.
- A 12 MB image and a PDF/text file are available on the device.

**Test Data**
- None needed.

**Test Steps**
1. Try to select the PDF as the permit photo (if the picker allows).
2. Select the 12 MB image.

**Expected Result**
- Non-image: not selectable or rejected with a friendly message.
- Over 10 MB: the upload fails with a friendly message such as "You don't have permission to do that." and no technical text.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Rule: images only, under 10 MB for permits (storage.rules).

---

### TC-BIZ-012 — Rejected listing — reason shown and resubmit

| Field | Detail |
|---|---|
| **Test Case ID** | TC-BIZ-012 |
| **Test Case Title** | Rejected listing — reason shown and resubmit |
| **Related Test Scenario** | TS-BIZ-007 — Verify listing status banners (pending, approved, rejected, suspended) and resubmission. |
| **Module/Feature** | Business Owner |
| **Test Objective** | Verify the rejection banner and the resubmit flow. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The signed-in traveler has an active Business Owner role (accepted invite) — example: owner01@example.com.
- An admin rejected the listing with reason `Photo is blurry`.

**Test Data**
- None needed.

**Test Steps**
1. Open **My Business**.
2. Read the banner.
3. Change the photo and tap **Edit & Resubmit**.

**Expected Result**
- Banner: "Rejected: Photo is blurry — Edit and resubmit below."
- After resubmitting the listing returns to pending review.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-BIZ-013 — Suspended listing and Contact Support

| Field | Detail |
|---|---|
| **Test Case ID** | TC-BIZ-013 |
| **Test Case Title** | Suspended listing and Contact Support |
| **Related Test Scenario** | TS-BIZ-007 — Verify listing status banners (pending, approved, rejected, suspended) and resubmission. |
| **Module/Feature** | Business Owner |
| **Test Objective** | Verify the suspended banner and support email action. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The signed-in traveler has an active Business Owner role (accepted invite) — example: owner01@example.com.
- An admin suspended the listing with a reason.

**Test Data**
- None needed.

**Test Steps**
1. Open **My Business**.
2. Tap **Contact Support**.

**Expected Result**
- The banner shows the suspension and reason.
- An email app opens to support@tripnestph.app with subject "Suspended listing: <name>"; if no email app exists, the message "Email support@tripnestph.app for help with this listing." is shown.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-BIZ-014 — Leave the listing form with unsaved changes

| Field | Detail |
|---|---|
| **Test Case ID** | TC-BIZ-014 |
| **Test Case Title** | Leave the listing form with unsaved changes |
| **Related Test Scenario** | TS-BIZ-004 — Verify a business owner can create and submit a listing with required fields. |
| **Module/Feature** | Business Owner |
| **Test Objective** | Verify the discard-changes protection. |
| **Priority** | Low |
| **Test Type** | Usability |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The signed-in traveler has an active Business Owner role (accepted invite) — example: owner01@example.com.
- The listing form is open with changes typed and not saved.

**Test Data**
- None needed.

**Test Steps**
1. Press Back or switch to another tab.

**Expected Result**
- A prompt about discarding unsaved changes appears; staying keeps the typed data, leaving discards it.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Needs manual verification of the exact dialog text (DiscardChangesScope).

---

### TC-BIZ-015 — Business dashboard statistics

| Field | Detail |
|---|---|
| **Test Case ID** | TC-BIZ-015 |
| **Test Case Title** | Business dashboard statistics |
| **Related Test Scenario** | TS-BIZ-008 — Verify the business dashboard shows listing statistics. |
| **Module/Feature** | Business Owner |
| **Test Objective** | Verify view, rating, review and favorite counts. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The signed-in traveler has an active Business Owner role (accepted invite) — example: owner01@example.com.
- An approved listing that has been viewed, reviewed and favorited by other travelers.

**Test Data**
- None needed.

**Test Steps**
1. Open the **Home** tab as the business owner (Dashboard).
2. Open the listing as a traveler and add it to Saved; then refresh the dashboard.

**Expected Result**
- The dashboard shows **Views**, **Rating**, **Reviews** and **Favorited** counters that match the real data.
- A user without a listing sees "No listing yet" and **Set Up My Business**.
- **Manage Listing** opens My Business.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-BIZ-016 — Submit listing while offline / interrupted

| Field | Detail |
|---|---|
| **Test Case ID** | TC-BIZ-016 |
| **Test Case Title** | Submit listing while offline / interrupted |
| **Related Test Scenario** | TS-BIZ-004 — Verify a business owner can create and submit a listing with required fields. |
| **Module/Feature** | Business Owner |
| **Test Objective** | Verify no duplicate listing is created if the network fails. |
| **Priority** | High |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- The signed-in traveler has an active Business Owner role (accepted invite) — example: owner01@example.com.
- A fully filled listing form.

**Test Data**
- None needed.

**Test Steps**
1. Tap submit and turn the internet OFF at once.
2. Read the message.
3. Turn the internet ON and open My Business.
4. Submit again if the form is still shown.

**Expected Result**
- A friendly message appears (no technical text).
- After recovery only ONE listing exists for the owner.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

## Admin Portal – Access & Roles

### TC-ADM-001 — Admin Portal login

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ADM-001 |
| **Test Case Title** | Admin Portal login |
| **Related Test Scenario** | TS-ADM-001 — Verify Admin Portal login, the missing sign-up link, and the "No access" state for non-admin accounts. |
| **Module/Feature** | Admin Portal – Access & Roles |
| **Test Objective** | Verify admin login and that self-registration is not offered. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- Admin Portal site/build is open in a browser.
- A verified admin account exists (created with tool/create_admin.js or accepted invite).

**Test Data**
- Email: `admin01@example.com`
- Password: `Admin@1234`

**Test Steps**
1. Look at the Login page for a "Sign Up" link.
2. Enter the admin email and password.
3. Tap **Sign In**.

**Expected Result**
- The Login page has no "Don't have an account? Sign Up" row (Forgot Password? is still available).
- After sign-in the **Admin Overview** (admin home) opens with the side menu and the admin name and role at the bottom.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ADM-002 — Account without an Admin Portal role

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ADM-002 |
| **Test Case Title** | Account without an Admin Portal role |
| **Related Test Scenario** | TS-ADM-001 — Verify Admin Portal login, the missing sign-up link, and the "No access" state for non-admin accounts. |
| **Module/Feature** | Admin Portal – Access & Roles |
| **Test Objective** | Verify a normal traveler cannot use the Admin Portal. |
| **Priority** | High |
| **Test Type** | Security |
| **Coverage Group** | Critical/Core |

**Preconditions**
- Admin Portal is open.
- A verified traveler account with NO admin role exists (tester01@example.com).

**Test Data**
- None needed.

**Test Steps**
1. Sign in to the Admin Portal with the traveler account.
2. Look at the page that opens (`/admin`).
3. Try to open `/admin/team` and `/admin/users` by typing the address in the browser.

**Expected Result**
- `/admin` shows "No access" with the text "This account doesn't have an active Admin Portal role." and no side-menu items.
- On the other admin addresses no traveler, team or business data is displayed (the database rules block the reads); an empty or friendly error state such as "You don't have permission to do that." is acceptable.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Code trace: only AdminHomeScreen shows the "No access" state. The other admin screens have no role check of their own and rely on Firestore rules. Consider adding a guard. Also try the same addresses on the traveler web app.

---

### TC-ADM-003 — Menu items by role

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ADM-003 |
| **Test Case Title** | Menu items by role |
| **Related Test Scenario** | TS-ADM-002 — Verify the menu and pages available match each role (admin, LGU, business owner). |
| **Module/Feature** | Admin Portal – Access & Roles |
| **Test Objective** | Verify each role only sees its permitted menu. |
| **Priority** | High |
| **Test Type** | Security |
| **Coverage Group** | Critical/Core |

**Preconditions**
- Three accounts: admin, LGU, business owner (all verified).

**Test Data**
- None needed.

**Test Steps**
1. Sign in as admin and list the side menu.
2. Sign out; sign in as LGU and list the menu.
3. Sign out; sign in as business owner and list the menu.

**Expected Result**
- Admin: Provinces, Tourist Spots, Bulk Import, Festivals, Analytics, Travelers, Businesses, Business Applications, Reported Reviews, Send Announcement, Team.
- LGU: Provinces, Tourist Spots, Bulk Import, Festivals, Analytics, Send Announcement (no Travelers, Businesses, Business Applications, Reported Reviews or Team).
- Business Owner: My Business only.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Code trace: firestore.rules lets admin and lgu create broadcast notifications, and its comment says this matches the Send Announcement tile. LGU access is intended.

---

### TC-ADM-024 — Role revoked while a business owner is signed in

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ADM-024 |
| **Test Case Title** | Role revoked while a business owner is signed in |
| **Related Test Scenario** | TS-ADM-014 — Verify role/status changes and network failures are enforced during a session. |
| **Module/Feature** | Admin Portal – Access & Roles |
| **Test Objective** | Verify live enforcement of a revoked/suspended admin role. |
| **Priority** | High |
| **Test Type** | Security |
| **Coverage Group** | Important |

**Preconditions**
- The signed-in traveler has an active Business Owner role (accepted invite) — example: owner01@example.com.
- An admin is ready in another browser.

**Test Data**
- None needed.

**Test Steps**
1. Business owner stays on My Business.
2. The admin removes or suspends that owner in **Team**.
3. Watch the owner's device for up to one minute.

**Expected Result**
- The owner is signed out automatically and must sign in again; after signing in they no longer have owner access.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ADM-025 — Admin save interrupted by lost internet

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ADM-025 |
| **Test Case Title** | Admin save interrupted by lost internet |
| **Related Test Scenario** | TS-ADM-014 — Verify role/status changes and network failures are enforced during a session. |
| **Module/Feature** | Admin Portal – Access & Roles |
| **Test Objective** | Verify a friendly error and no duplicate record on network failure. |
| **Priority** | Medium |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).
- The tourist spot form is filled with valid data.

**Test Data**
- None needed.

**Test Steps**
1. Click save and disconnect the internet at the same moment.
2. Read the message.
3. Reconnect and check the Tourist Spots list.
4. Save again if the form is still open.

**Expected Result**
- A friendly message appears with no technical text.
- After recovery only ONE spot with that name exists.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

## Admin Portal – Business Approval

### TC-ADM-004 — Approve a business listing (with and without permit)

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ADM-004 |
| **Test Case Title** | Approve a business listing (with and without permit) |
| **Related Test Scenario** | TS-ADM-003 — Verify admins can approve, reject, suspend, reactivate and delete business listings. |
| **Module/Feature** | Admin Portal – Business Approval |
| **Test Objective** | Verify approval and the no-permit warning. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).
- Pending listing A has a permit photo; pending listing B has none.

**Test Data**
- None needed.

**Test Steps**
1. Open **Businesses**.
2. Tap approve on listing B and read the confirmation.
3. Cancel, then approve listing A and confirm "Approve this listing?".
4. Open the traveler app and look for listing A in its province page (Local Businesses).

**Expected Result**
- For B the dialog warns that no permit photo was provided.
- After approving A the message "Listing approved" appears and status becomes approved.
- Listing A is now visible to travelers; a Food & Dining listing also appears in Restaurants.

**Postconditions:** Listing A is approved.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ADM-005 — Reject and suspend require a reason

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ADM-005 |
| **Test Case Title** | Reject and suspend require a reason |
| **Related Test Scenario** | TS-ADM-003 — Verify admins can approve, reject, suspend, reactivate and delete business listings. |
| **Module/Feature** | Admin Portal – Business Approval |
| **Test Objective** | Verify a reason is asked and the owner sees it. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).
- A pending listing and an approved listing exist.

**Test Data**
- Reject reason: `Photo is blurry`
- Suspend reason: `Reported as closed`

**Test Steps**
1. Tap **Reject** on the pending listing; try to confirm with the reason empty.
2. Enter `Photo is blurry` and confirm.
3. Tap **Suspend** on the approved listing with the reason `Reported as closed` and confirm.
4. Sign in as each owner and open **My Business**.

**Expected Result**
- With an empty reason the Reject/Suspend button does nothing and the dialog stays open.
- "Listing rejected" and "Listing suspended" messages appear.
- Each owner sees the banner with the given reason.
- The suspended listing is no longer visible to travelers.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ADM-006 — Reactivate a suspended listing

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ADM-006 |
| **Test Case Title** | Reactivate a suspended listing |
| **Related Test Scenario** | TS-ADM-003 — Verify admins can approve, reject, suspend, reactivate and delete business listings. |
| **Module/Feature** | Admin Portal – Business Approval |
| **Test Objective** | Verify reactivation makes the listing visible again. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).
- A suspended listing exists.

**Test Data**
- None needed.

**Test Steps**
1. Tap **Reactivate** and confirm "Reactivate this listing?".
2. Check the listing in the traveler app.

**Expected Result**
- "Listing reactivated" is shown and the status returns to approved.
- The listing is visible to travelers again.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ADM-007 — Delete a business listing

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ADM-007 |
| **Test Case Title** | Delete a business listing |
| **Related Test Scenario** | TS-ADM-003 — Verify admins can approve, reject, suspend, reactivate and delete business listings. |
| **Module/Feature** | Admin Portal – Business Approval |
| **Test Objective** | Verify deletion removes the listing and its mirrored restaurant, reviews and favorites. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).
- An approved Food & Dining listing with 1 review and 1 favorite exists.

**Test Data**
- None needed.

**Test Steps**
1. Tap delete on the listing.
2. Read the message `"<name>" will be permanently removed.` and confirm **Delete**.
3. Check the traveler app: Restaurants list, the Saved > Food tab, and search for the name.

**Expected Result**
- The listing disappears from the admin list.
- The mirrored restaurant, its reviews and favorites are gone from the traveler app; no broken (blank) card remains.

**Postconditions:** No leftover restaurant, review or favorite records for the deleted listing.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ADM-008 — Approve a Business Owner application

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ADM-008 |
| **Test Case Title** | Approve a Business Owner application |
| **Related Test Scenario** | TS-ADM-004 — Verify admins can approve or reject Business Owner applications. |
| **Module/Feature** | Admin Portal – Business Approval |
| **Test Objective** | Verify approval stages an invite (does not grant the role directly). |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).
- A pending application from `juan.owner.test01@example.com` exists (TC-BIZ-001).

**Test Data**
- None needed.

**Test Steps**
1. Open **Business Applications**.
2. Read the entry (name · email).
3. Tap **Approve** and confirm "Approve this application?".
4. Sign in to the traveler app as that user and open Profile.

**Expected Result**
- The application leaves the pending list.
- The traveler sees an invitation to accept (TC-BIZ-004); the role is active only after acceptance.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ADM-009 — Reject a Business Owner application

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ADM-009 |
| **Test Case Title** | Reject a Business Owner application |
| **Related Test Scenario** | TS-ADM-004 — Verify admins can approve or reject Business Owner applications. |
| **Module/Feature** | Admin Portal – Business Approval |
| **Test Objective** | Verify a rejection reason can be entered. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).
- A pending application exists.

**Test Data**
- Reason: `Incomplete business information`

**Test Steps**
1. Tap **Reject** on the application.
2. In "Reject this application?" type the reason (placeholder "Tell the applicant why...").
3. Confirm **Reject**.

**Expected Result**
- The application is marked rejected and leaves the pending list.
- The empty state "No pending applications" shows when none remain.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Needs manual verification of what the applicant sees for a rejected application.

---

## Admin Portal – Team & Travelers

### TC-ADM-010 — Invite team members and validation

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ADM-010 |
| **Test Case Title** | Invite team members and validation |
| **Related Test Scenario** | TS-ADM-005 — Verify admins can invite, revoke and remove Admin Portal team members. |
| **Module/Feature** | Admin Portal – Team & Travelers |
| **Test Objective** | Verify roles, the province requirement for LGU and email validation. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).
- Traveler account `newadmin@example.com` exists; `noaccount@example.com` does not.

**Test Data**
- None needed.

**Test Steps**
1. Open **Team** > **Invite to Admin Portal**.
2. Enter `abc@` as Email and try to send.
3. Enter `newadmin@example.com`, select Role **LGU Officer** and try to send without a province.
4. Select a province, tap **Send Invite** and confirm "Invite <email>?".
5. Invite `noaccount@example.com` as **Admin**.

**Expected Result**
- Invalid email: "Enter a valid email address".
- LGU Officer requires a province ("Which province will they manage?").
- After confirming, "Invite sent." appears and the invite is listed under **Pending Invites**.
- The invite for an email without a TripNest account is created but cannot be accepted until that person registers.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Roles offered: Admin, LGU Officer, Business Owner.

---

### TC-ADM-011 — Revoke an invite and remove an admin

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ADM-011 |
| **Test Case Title** | Revoke an invite and remove an admin |
| **Related Test Scenario** | TS-ADM-005 — Verify admins can invite, revoke and remove Admin Portal team members. |
| **Module/Feature** | Admin Portal – Team & Travelers |
| **Test Objective** | Verify revoke and remove confirmations and effects. |
| **Priority** | High |
| **Test Type** | Security |
| **Coverage Group** | Important |

**Preconditions**
- The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).
- One pending invite and one other active admin exist.

**Test Data**
- None needed.

**Test Steps**
1. Tap **Revoke** on the invite and confirm "Revoke this invite?".
2. Tap **Remove** on the other admin and confirm "Remove this admin?".
3. Sign in as the removed user and open the Admin Portal.

**Expected Result**
- The invite disappears and that email will no longer be offered the role.
- The removed admin loses access immediately and sees "No access" (or is signed out); their traveler account still works.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ADM-012 — Search, suspend and reactivate a traveler

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ADM-012 |
| **Test Case Title** | Search, suspend and reactivate a traveler |
| **Related Test Scenario** | TS-ADM-006 — Verify admins can search, suspend and reactivate traveler accounts. |
| **Module/Feature** | Admin Portal – Team & Travelers |
| **Test Objective** | Verify traveler management actions. |
| **Priority** | High |
| **Test Type** | Security |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).
- Traveler `tester01@example.com` exists.

**Test Data**
- None needed.

**Test Steps**
1. Open **Travelers** and type `tester01` in "Search by name or email".
2. Choose **Suspend** and confirm "Suspend this account?".
3. Try to sign in to the traveler app with that account.
4. Choose **Reactivate** and confirm.
5. Sign in to the traveler app again.

**Expected Result**
- The search narrows the list to the matching traveler.
- After suspend the list shows "· suspended" and a message "<name> suspended." appears; the traveler cannot use the app (see TC-LOGIN-011).
- After reactivate the traveler can sign in normally.
- **Load more** appears when the list is longer than one page.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

## Admin Portal – Content

### TC-ADM-013 — Create a tourist spot

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ADM-013 |
| **Test Case Title** | Create a tourist spot |
| **Related Test Scenario** | TS-ADM-007 — Verify tourist spots can be created, validated, edited and removed. |
| **Module/Feature** | Admin Portal – Content |
| **Test Objective** | Verify a valid spot is saved and visible to travelers. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).
- The device is connected to the internet (Wi-Fi or mobile data).
- A province exists; a cover photo (< 5 MB) is available.

**Test Data**
- Name: `Sunset Viewpoint`
- Category: any
- Latitude: `16.4023`
- Longitude: `120.5960`
- Short Description: `A quiet hilltop with sunset views.`
- Has Entrance Fee: ON, Amount: `50`
- Phone: `0917 111 2222`
- Website: `https://example.com`

**Test Steps**
1. Open **Tourist Spots**, pick a province and tap add.
2. Fill in the form with the test data and upload the cover photo.
3. Save the spot.
4. Find the spot in the traveler app (Explore > Destinations).

**Expected Result**
- A success message appears and the spot appears in the admin list.
- The spot is visible in the traveler app with its photo, description and fee.

**Postconditions:** One new `tourist_spots` record exists.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ADM-014 — Tourist spot form validation and boundaries

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ADM-014 |
| **Test Case Title** | Tourist spot form validation and boundaries |
| **Related Test Scenario** | TS-ADM-007 — Verify tourist spots can be created, validated, edited and removed. |
| **Module/Feature** | Admin Portal – Content |
| **Test Objective** | Verify all form limits. |
| **Priority** | High |
| **Test Type** | Boundary |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).
- The tourist spot form is open.

**Test Data**
- Latitude: `91`, `-91`, `abc`, `90`
- Longitude: `181`, `180`
- Short Description: 301 characters
- Long Description: 5001 characters
- Entrance fee: `0`, `100001`, `100000`
- Website: `example.com`
- Phone: `123`

**Test Steps**
1. Leave Name empty and save.
2. Enter each test value in its field and save; note the messages.

**Expected Result**
- Name: "Name is required".
- Latitude `91`/`-91`: "Latitude must be between -90 and 90"; `abc`: "Enter a valid latitude"; `90` accepted.
- Longitude `181`: "Longitude must be between -180 and 180"; `180` accepted.
- Short Description over 300: "Short Description must be 300 characters or fewer".
- Long Description over 5000: "Long Description must be 5000 characters or fewer".
- Fee `0`: "Amount must be greater than 0"; `100001`: "Amount must be ₱100000 or less"; `100000` accepted.
- Website: "Enter a valid URL (starting with http:// or https://)"; Phone: "Enter a valid phone number".
- Nothing is saved while an error shows.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ADM-015 — Edit and remove a tourist spot

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ADM-015 |
| **Test Case Title** | Edit and remove a tourist spot |
| **Related Test Scenario** | TS-ADM-007 — Verify tourist spots can be created, validated, edited and removed. |
| **Module/Feature** | Admin Portal – Content |
| **Test Objective** | Verify edit and delete confirmation. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).
- An existing tourist spot.

**Test Data**
- None needed.

**Test Steps**
1. Open the spot for editing, change the Short Description and save.
2. Remove the spot and confirm "Remove this spot?".

**Expected Result**
- The change is visible in the traveler app.
- After removal the message `"<name>" removed.` appears and the spot no longer shows in the traveler app.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ADM-018 — Create a festival and validation

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ADM-018 |
| **Test Case Title** | Create a festival and validation |
| **Related Test Scenario** | TS-ADM-008 — Verify festivals can be created and validated. |
| **Module/Feature** | Admin Portal – Content |
| **Test Objective** | Verify required Province/Date and description limit. |
| **Priority** | High |
| **Test Type** | Validation |
| **Coverage Group** | Important |

**Preconditions**
- The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).
- The device is connected to the internet (Wi-Fi or mobile data).
- The festival form is open.

**Test Data**
- Name: `Panagbenga Festival`
- Date: a future date range
- Description: 3001 characters

**Test Steps**
1. Tap save with an empty form.
2. Enter the name only and save.
3. Choose a province but no date and save.
4. Choose the date; enter the 3001-character description and save.
5. Reduce the description to a normal text and save.

**Expected Result**
- Name: "Name is required".
- No province: "Province is required."
- No date: "Date is required."
- Description: "Description must be 3000 characters or fewer".
- Final save: "Festival created." and the festival appears in the traveler app (Explore > Festivals).

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ADM-019 — Bulk import tourist spots from a valid CSV

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ADM-019 |
| **Test Case Title** | Bulk import tourist spots from a valid CSV |
| **Related Test Scenario** | TS-ADM-009 — Verify tourist spot CSV bulk import (valid, invalid, wrong file). |
| **Module/Feature** | Admin Portal – Content |
| **Test Objective** | Verify preview and import of valid rows. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).
- The device is connected to the internet (Wi-Fi or mobile data).
- A CSV with header `name,provinceId,categoryId,shortDescription` and 3 valid rows, using real province and category IDs.

**Test Data**
- None needed.

**Test Steps**
1. Open **Bulk Import**.
2. Tap **Choose CSV File** and select the file.
3. Read the preview counts.
4. Start the import and wait for "Importing x/y...".
5. Open **Tourist Spots** and search for the imported names.

**Expected Result**
- The preview shows "3 valid" and no invalid rows.
- The progress counter reaches 3/3.
- The 3 spots exist exactly once.

**Postconditions:** Three new tourist spot records.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ADM-020 — Bulk import with invalid rows and wrong files

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ADM-020 |
| **Test Case Title** | Bulk import with invalid rows and wrong files |
| **Related Test Scenario** | TS-ADM-009 — Verify tourist spot CSV bulk import (valid, invalid, wrong file). |
| **Module/Feature** | Admin Portal – Content |
| **Test Objective** | Verify invalid rows are reported and only valid rows are imported. |
| **Priority** | Medium |
| **Test Type** | Negative |
| **Coverage Group** | Important |

**Preconditions**
- The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).
- The device is connected to the internet (Wi-Fi or mobile data).
- CSV with 4 rows: 1 valid, 1 missing name, 1 unknown provinceId `XX999`, 1 missing shortDescription. Also a `.xlsx` file.

**Test Data**
- None needed.

**Test Steps**
1. Select the CSV and read the preview.
2. Import.
3. Try to pick the `.xlsx` file.

**Expected Result**
- Preview shows 1 valid and 3 invalid with messages "Missing name", `Unknown provinceId "XX999"` and "Missing shortDescription" (with row numbers).
- Only the valid row is created.
- The file picker only allows `.csv` files.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ADM-021 — LGU account is limited to its province

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ADM-021 |
| **Test Case Title** | LGU account is limited to its province |
| **Related Test Scenario** | TS-ADM-010 — Verify an LGU account is limited to its own province. |
| **Module/Feature** | Admin Portal – Content |
| **Test Objective** | Verify the LGU sees and edits only its own province. |
| **Priority** | High |
| **Test Type** | Security |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The tester is signed in to the Admin Portal as an **LGU** account assigned to one province (example: lgu.benguet@example.com, province Benguet).
- Tourist spots exist in Benguet and in another province.

**Test Data**
- None needed.

**Test Steps**
1. Open **Tourist Spots** and look at the province options.
2. Open **Analytics** and read the header/values.
3. Try to add a spot.

**Expected Result**
- The LGU's own province (Benguet) is selected automatically and only its spots are listed; other provinces cannot be managed (verify whether the province picker is hidden).
- Analytics shows Benguet-only numbers (no platform-wide traveler totals).
- A new spot is created for Benguet only.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

## Admin Portal – Announcements & Analytics

### TC-ADM-016 — Send an announcement to all travelers

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ADM-016 |
| **Test Case Title** | Send an announcement to all travelers |
| **Related Test Scenario** | TS-ADM-012 — Verify announcements can be broadcast with validation. |
| **Module/Feature** | Admin Portal – Announcements & Analytics |
| **Test Objective** | Verify an announcement is created and received. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).
- The device is connected to the internet (Wi-Fi or mobile data).
- At least one traveler device is signed in.

**Test Data**
- Title: `Typhoon Advisory`
- Message: `Please check local advisories before traveling.`
- Category: `Emergency Alert`

**Test Steps**
1. Open **Send Announcement**.
2. Enter the title, message and choose the category.
3. Tap **Send to Every Traveler** and confirm "Send this announcement?" with **Send**.

**Expected Result**
- A message "Announcement sent." appears.
- Travelers see it in Notifications (and as a push if permission is allowed).

**Postconditions:** One notification record exists for the announcement.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ADM-017 — Announcement validation and length limits

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ADM-017 |
| **Test Case Title** | Announcement validation and length limits |
| **Related Test Scenario** | TS-ADM-012 — Verify announcements can be broadcast with validation. |
| **Module/Feature** | Admin Portal – Announcements & Analytics |
| **Test Objective** | Verify required fields and the 100/500 character limits. |
| **Priority** | Medium |
| **Test Type** | Boundary |
| **Coverage Group** | Important |

**Preconditions**
- The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).
- The announcement form is open.

**Test Data**
- Title: 101 characters
- Message: 501 characters

**Test Steps**
1. Tap send with both fields empty.
2. Paste the long values.

**Expected Result**
- "Title is required" and "Message is required" appear.
- The Title field accepts up to 100 characters and the Message field up to 500.
- No announcement is sent while an error shows.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ADM-023 — Analytics dashboard values

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ADM-023 |
| **Test Case Title** | Analytics dashboard values |
| **Related Test Scenario** | TS-ADM-013 — Verify the analytics dashboard values and role scoping. |
| **Module/Feature** | Admin Portal – Announcements & Analytics |
| **Test Objective** | Verify counters and the traveler growth chart. |
| **Priority** | Medium |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).
- The device is connected to the internet (Wi-Fi or mobile data).
- Known counts in the database (e.g., 10 travelers, 2 suspended).

**Test Data**
- None needed.

**Test Steps**
1. Open **Analytics**.
2. Compare Total Travelers, Suspended, Provinces w/ Content, Tourist Spots, Restaurants, Festivals, Businesses (Pending Review/Approved), Saved Trips and Pending Reports with the database.
3. Look at the **Traveler Growth** chart.

**Expected Result**
- Each counter matches the real data.
- The chart shows "Total signed-up travelers, last N days" without errors even if there is little history.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Chart needs at least the daily snapshots produced by the scheduled function.

---

## Admin Portal – Moderation

### TC-ADM-022 — Hide, restore and dismiss a reported review

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ADM-022 |
| **Test Case Title** | Hide, restore and dismiss a reported review |
| **Related Test Scenario** | TS-ADM-011 — Verify reported reviews/listings can be hidden, restored or dismissed. |
| **Module/Feature** | Admin Portal – Moderation |
| **Test Objective** | Verify moderation actions and the notification to the author. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Important |

**Preconditions**
- The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).
- A reported review and a reported listing exist (TC-REV-008, TC-DET-012).

**Test Data**
- None needed.

**Test Steps**
1. Open **Reported Reviews** and view the review report.
2. Tap **Hide** and confirm "Hide this review?".
3. Check the review in the traveler app and the author's notifications.
4. Tap **Restore** and confirm.
5. On the listing report tap **Dismiss report** and confirm "Dismiss this report?".

**Expected Result**
- After Hide the review no longer shows publicly and the author gets a notification "Your review was hidden".
- After Restore it shows again.
- Dismiss says "The listing stays as-is." and removes the report from the queue.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

## Network & Offline

### TC-NET-001 — Offline banner appears and disappears

| Field | Detail |
|---|---|
| **Test Case ID** | TC-NET-001 |
| **Test Case Title** | Offline banner appears and disappears |
| **Related Test Scenario** | TS-NET-001 — Verify the app shows the offline banner and recovers when the connection returns. |
| **Module/Feature** | Network & Offline |
| **Test Objective** | Verify the offline banner reacts to connectivity changes. |
| **Priority** | High |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The tester is on the Home or Saved screen.

**Test Data**
- None needed.

**Test Steps**
1. Turn on airplane mode.
2. Wait 5 seconds and look at the top of the screen.
3. Turn off airplane mode.
4. Wait 10 seconds.

**Expected Result**
- A banner "You're offline — showing saved data" appears while offline.
- The banner disappears after the connection returns, and screens can be refreshed normally.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-NET-002 — Wi-Fi disconnected, mobile data connected

| Field | Detail |
|---|---|
| **Test Case ID** | TC-NET-002 |
| **Test Case Title** | Wi-Fi disconnected, mobile data connected |
| **Related Test Scenario** | TS-NET-002 — Verify the app is usable on Wi-Fi only, mobile data only, and when switching between them. |
| **Module/Feature** | Network & Offline |
| **Test Objective** | Verify the app works on mobile data alone. |
| **Priority** | Medium |
| **Test Type** | Compatibility |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The device has mobile data; Wi-Fi is turned OFF.

**Test Data**
- None needed.

**Test Steps**
1. Open Home, then Explore, then open a destination.
2. Send one message in the AI chat.

**Expected Result**
- Content loads and the AI chat replies; no offline banner appears.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-NET-003 — Mobile data disconnected, Wi-Fi connected

| Field | Detail |
|---|---|
| **Test Case ID** | TC-NET-003 |
| **Test Case Title** | Mobile data disconnected, Wi-Fi connected |
| **Related Test Scenario** | TS-NET-002 — Verify the app is usable on Wi-Fi only, mobile data only, and when switching between them. |
| **Module/Feature** | Network & Offline |
| **Test Objective** | Verify the app works on Wi-Fi alone. |
| **Priority** | Medium |
| **Test Type** | Compatibility |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The device is on Wi-Fi; mobile data is turned OFF.

**Test Data**
- None needed.

**Test Steps**
1. Repeat the same actions as TC-NET-002.

**Expected Result**
- Everything loads normally over Wi-Fi with no errors.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-NET-004 — Switch from Wi-Fi to mobile data while browsing

| Field | Detail |
|---|---|
| **Test Case ID** | TC-NET-004 |
| **Test Case Title** | Switch from Wi-Fi to mobile data while browsing |
| **Related Test Scenario** | TS-NET-002 — Verify the app is usable on Wi-Fi only, mobile data only, and when switching between them. |
| **Module/Feature** | Network & Offline |
| **Test Objective** | Verify the app continues after a network change. |
| **Priority** | Low |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Wi-Fi ON and mobile data ON; the tester is scrolling Explore.

**Test Data**
- None needed.

**Test Steps**
1. While a list is loading, turn Wi-Fi OFF so that the phone changes to mobile data.
2. Continue scrolling and tap **Load More**.

**Expected Result**
- Loading continues or shows a temporary friendly error; after a few seconds the content loads again.
- The app does not crash or need to be restarted.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-NET-005 — Slow network

| Field | Detail |
|---|---|
| **Test Case ID** | TC-NET-005 |
| **Test Case Title** | Slow network |
| **Related Test Scenario** | TS-NET-003 — Verify the app stays responsive on a slow or unresponsive network. |
| **Module/Feature** | Network & Offline |
| **Test Objective** | Verify loading indicators and timeouts on a slow connection. |
| **Priority** | Medium |
| **Test Type** | Performance |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The device uses a throttled connection (e.g., developer network throttling to 2G / "Slow 3G" in browser dev tools).

**Test Data**
- None needed.

**Test Steps**
1. Open Home, Explore and a destination details screen.
2. Tap **Generate Itinerary** with a valid form.
3. Wait up to 60 seconds.

**Expected Result**
- Loading placeholders (shimmer/loading indicators) are shown instead of a blank screen.
- Actions cannot be double-submitted while loading.
- If a request times out, the message "This is taking longer than expected. Please check your connection and try again." (or another friendly message) is shown.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

## App Interruptions

### TC-INT-001 — Incoming phone call while filling a form

| Field | Detail |
|---|---|
| **Test Case ID** | TC-INT-001 |
| **Test Case Title** | Incoming phone call while filling a form |
| **Related Test Scenario** | TS-INT-001 — Verify the app keeps its state during a phone call, notification, app switch, minimize and screen lock. |
| **Module/Feature** | App Interruptions |
| **Test Objective** | Verify typed data is kept after a call. |
| **Priority** | Medium |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Real device with calling. The Planner form is partly filled (destination, days = 5).

**Test Data**
- None needed.

**Test Steps**
1. Receive a phone call and answer it for 20 seconds.
2. End the call and return to TripNest PH.

**Expected Result**
- The app is on the same screen; the Planner form still has the destination and 5 days.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-INT-002 — Notification arrives while using the app

| Field | Detail |
|---|---|
| **Test Case ID** | TC-INT-002 |
| **Test Case Title** | Notification arrives while using the app |
| **Related Test Scenario** | TS-INT-001 — Verify the app keeps its state during a phone call, notification, app switch, minimize and screen lock. |
| **Module/Feature** | App Interruptions |
| **Test Objective** | Verify a notification banner does not disturb the current task. |
| **Priority** | Low |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The tester is typing a review comment.

**Test Data**
- None needed.

**Test Steps**
1. Trigger another app's notification (e.g., send a message to the device).
2. Ignore it (or pull down and close it) and continue typing.
3. Submit the review.

**Expected Result**
- The typed text is kept and the review is submitted normally.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-INT-003 — Switch to another app and return

| Field | Detail |
|---|---|
| **Test Case ID** | TC-INT-003 |
| **Test Case Title** | Switch to another app and return |
| **Related Test Scenario** | TS-INT-001 — Verify the app keeps its state during a phone call, notification, app switch, minimize and screen lock. |
| **Module/Feature** | App Interruptions |
| **Test Objective** | Verify state is kept when the app is in the background for a short time. |
| **Priority** | Medium |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The tester is on a destination details screen scrolled halfway.

**Test Data**
- None needed.

**Test Steps**
1. Press the Home button and open another app for 1 minute.
2. Return to TripNest PH from the recent apps.

**Expected Result**
- The same screen and scroll position are shown; the user is still signed in.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-INT-004 — Minimize for a long time then return

| Field | Detail |
|---|---|
| **Test Case ID** | TC-INT-004 |
| **Test Case Title** | Minimize for a long time then return |
| **Related Test Scenario** | TS-INT-001 — Verify the app keeps its state during a phone call, notification, app switch, minimize and screen lock. |
| **Module/Feature** | App Interruptions |
| **Test Objective** | Verify the session and data after a long background period. |
| **Priority** | Medium |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).

**Test Data**
- None needed.

**Test Steps**
1. Minimize the app and leave the device for 30 minutes (the OS may close the app).
2. Open the app again.

**Expected Result**
- The user is still signed in and lands on Home (or the same screen).
- Data loads normally; no crash or forced logout.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-INT-005 — Lock and unlock the screen during a request

| Field | Detail |
|---|---|
| **Test Case ID** | TC-INT-005 |
| **Test Case Title** | Lock and unlock the screen during a request |
| **Related Test Scenario** | TS-INT-001 — Verify the app keeps its state during a phone call, notification, app switch, minimize and screen lock. |
| **Module/Feature** | App Interruptions |
| **Test Objective** | Verify pending work finishes after the device is locked. |
| **Priority** | Low |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The chat screen is open.

**Test Data**
- None needed.

**Test Steps**
1. Send a chat message.
2. Immediately lock the screen for 15 seconds.
3. Unlock the device.

**Expected Result**
- The reply is shown in the chat (or a friendly error bubble); the message is not duplicated.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-INT-006 — Force close and reopen during an action

| Field | Detail |
|---|---|
| **Test Case ID** | TC-INT-006 |
| **Test Case Title** | Force close and reopen during an action |
| **Related Test Scenario** | TS-INT-002 — Verify the app recovers after being closed and reopened. |
| **Module/Feature** | App Interruptions |
| **Test Objective** | Verify no corrupted or half-saved data after closing the app during a save. |
| **Priority** | Medium |
| **Test Type** | Interruption/Recovery |
| **Coverage Group** | Important |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- A new itinerary is open and unsaved.

**Test Data**
- None needed.

**Test Steps**
1. Tap the save action and immediately swipe the app away.
2. Reopen the app and open Saved Trips.

**Expected Result**
- At most one copy of the trip exists (saved or not saved) and it opens normally.
- No duplicated or blank trip appears.

**Postconditions:** Data is consistent.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

## Error Handling

### TC-ERR-001 — Errors never expose technical details

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ERR-001 |
| **Test Case Title** | Errors never expose technical details |
| **Related Test Scenario** | TS-ERR-001 — Verify that no technical information (stack traces, codes, API errors) is shown to users. |
| **Module/Feature** | Error Handling |
| **Test Objective** | Verify user-facing errors are friendly across several failure types. |
| **Priority** | High |
| **Test Type** | Security |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Tester can turn the internet on/off and has a suspended-test account.

**Test Data**
- None needed.

**Test Steps**
1. Cause a network error on Login, Explore, Planner and Chat (internet OFF).
2. Cause a permission error (e.g., upload an over-5 MB profile photo).
3. Cause a wrong-password error on Login.
4. Read every message shown.

**Expected Result**
- All messages are plain-language sentences (for example "No internet connection. Please check your network and try again." or "You don't have permission to do that.").
- None of them contains: stack traces, "Exception", "FirebaseException", "[firebase_auth/...]", HTTP codes such as 401/500, JSON, URLs or database paths.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-ERR-002 — Unexpected AI response / service unavailable

| Field | Detail |
|---|---|
| **Test Case ID** | TC-ERR-002 |
| **Test Case Title** | Unexpected AI response / service unavailable |
| **Related Test Scenario** | TS-ERR-001 — Verify that no technical information (stack traces, codes, API errors) is shown to users. |
| **Module/Feature** | Error Handling |
| **Test Objective** | Verify AI failures give a friendly message. |
| **Priority** | Medium |
| **Test Type** | Negative |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- A test environment where the AI key is missing or the AI service is unreachable (ask the developer to disable it), if available.

**Test Data**
- None needed.

**Test Steps**
1. Send a message in the AI chat.
2. Tap **Generate Itinerary** on the Planner.

**Expected Result**
- The chat shows an error bubble and the Planner shows a snack bar, both with friendly text (for example "This feature isn't available right now. Please try again later.").
- No raw error text from the AI provider is shown.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Optional; needs a controlled failure setup.

---

## Data Consistency

### TC-DATA-001 — No duplicate records after double taps

| Field | Detail |
|---|---|
| **Test Case ID** | TC-DATA-001 |
| **Test Case Title** | No duplicate records after double taps |
| **Related Test Scenario** | TS-DATA-001 — Verify data is saved once, not duplicated, and survives refresh/reopen. |
| **Module/Feature** | Data Consistency |
| **Test Objective** | Verify quick repeated taps do not create duplicates. |
| **Priority** | High |
| **Test Type** | Negative |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).

**Test Data**
- None needed.

**Test Steps**
1. Double-tap **Save** on a generated itinerary.
2. Double-tap **Add** when adding an expense.
3. Double-tap the review submit button.
4. Check Saved Trips, the Budget Tracker and the review list.

**Expected Result**
- Exactly one trip, one expense and one review exist.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-DATA-002 — Data is the same after refresh and reopen

| Field | Detail |
|---|---|
| **Test Case ID** | TC-DATA-002 |
| **Test Case Title** | Data is the same after refresh and reopen |
| **Related Test Scenario** | TS-DATA-001 — Verify data is saved once, not duplicated, and survives refresh/reopen. |
| **Module/Feature** | Data Consistency |
| **Test Objective** | Verify saved trips, favorites, reviews and profile survive reopening and re-login. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- The traveler has 1 saved trip, 2 favorites, 1 review and an edited profile.

**Test Data**
- None needed.

**Test Steps**
1. Note the data.
2. Pull to refresh on Home and Saved.
3. Close the app, reopen it, log out and log in again.
4. Compare all data.

**Expected Result**
- Every item is still present, unchanged, and not duplicated.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-DATA-003 — Rating and review count stay consistent

| Field | Detail |
|---|---|
| **Test Case ID** | TC-DATA-003 |
| **Test Case Title** | Rating and review count stay consistent |
| **Related Test Scenario** | TS-DATA-001 — Verify data is saved once, not duplicated, and survives refresh/reopen. |
| **Module/Feature** | Data Consistency |
| **Test Objective** | Verify the place rating updates correctly after add/edit/delete. |
| **Priority** | High |
| **Test Type** | Functional |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A place with no reviews; two traveler accounts.

**Test Data**
- None needed.

**Test Steps**
1. Account A reviews it with 5 stars; Account B reviews it with 3 stars.
2. Check the average rating and count.
3. Account B edits to 1 star; then Account A deletes their review.
4. Check the rating and count each time.

**Expected Result**
- After A and B: rating 4.0 with 2 reviews.
- After B edits: rating 3.0 with 2 reviews.
- After A deletes: rating 1.0 with 1 review.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

## Compatibility & Responsiveness

### TC-COMP-001 — Responsive layout: phone vs wide desktop web

| Field | Detail |
|---|---|
| **Test Case ID** | TC-COMP-001 |
| **Test Case Title** | Responsive layout: phone vs wide desktop web |
| **Related Test Scenario** | TS-COMP-001 — Verify the layout works on phone, tablet and wide desktop web, and in dark mode. |
| **Module/Feature** | Compatibility & Responsiveness |
| **Test Objective** | Verify the compact and expanded layouts. |
| **Priority** | Medium |
| **Test Type** | Compatibility |
| **Coverage Group** | Important |

**Preconditions**
- The traveler web build is open in a desktop browser (Chrome or Edge).

**Test Data**
- None needed.

**Test Steps**
1. Resize the browser window to about 400 px wide and open Login and Home.
2. Resize to about 1300 px wide (wider than 1100 px) and reopen Login and Home.

**Expected Result**
- Narrow: single-column layout with a bottom navigation bar.
- Wide: Login and Register show a two-panel layout (branded panel + form) and the main app uses a side navigation instead of the bottom bar.
- No overlapping or cut-off text at either size.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-COMP-002 — Dark mode readability on key screens

| Field | Detail |
|---|---|
| **Test Case ID** | TC-COMP-002 |
| **Test Case Title** | Dark mode readability on key screens |
| **Related Test Scenario** | TS-COMP-001 — Verify the layout works on phone, tablet and wide desktop web, and in dark mode. |
| **Module/Feature** | Compatibility & Responsiveness |
| **Test Objective** | Verify all key screens are readable in dark mode. |
| **Priority** | Low |
| **Test Type** | Usability |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).
- Dark Mode is ON (Settings).

**Test Data**
- None needed.

**Test Steps**
1. Visit Home, Explore, a details screen, the Planner, the itinerary, Saved, Profile and Settings.

**Expected Result**
- Text, icons, buttons and images are readable with enough contrast; no white boxes or invisible text.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

### TC-COMP-003 — Browser compatibility of the web build

| Field | Detail |
|---|---|
| **Test Case ID** | TC-COMP-003 |
| **Test Case Title** | Browser compatibility of the web build |
| **Related Test Scenario** | TS-COMP-001 — Verify the layout works on phone, tablet and wide desktop web, and in dark mode. |
| **Module/Feature** | Compatibility & Responsiveness |
| **Test Objective** | Verify core actions in different browsers. |
| **Priority** | Low |
| **Test Type** | Compatibility |
| **Coverage Group** | Additional/Edge |

**Preconditions**
- Traveler web build; browsers Chrome, Edge and Firefox are available.

**Test Data**
- None needed.

**Test Steps**
1. In each browser sign in, open Explore, open a destination and generate a short itinerary.

**Expected Result**
- The same features work in all three browsers with no blank screens or console-visible crashes on screen.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Safari/iOS Safari is not in the list because it was not verified in the code.

---

## Security

### TC-SEC-001 — Traveler opens admin pages on the traveler app

| Field | Detail |
|---|---|
| **Test Case ID** | TC-SEC-001 |
| **Test Case Title** | Traveler opens admin pages on the traveler app |
| **Related Test Scenario** | TS-SEC-001 — Verify a traveler cannot reach admin data or other users' data through the app. |
| **Module/Feature** | Security |
| **Test Objective** | Verify admin routes show "No access" to a normal traveler. |
| **Priority** | High |
| **Test Type** | Security |
| **Coverage Group** | Critical/Core |

**Preconditions**
- Traveler web build; signed in as `tester01@example.com` (no admin role).

**Test Data**
- None needed.

**Test Steps**
1. Type `/admin` and then `/admin/users` in the browser address bar.

**Expected Result**
- `/admin` shows "No access" with the text "This account doesn't have an active Admin Portal role."
- `/admin/users` shows no traveler data (blocked by the database rules); an empty or friendly error state is acceptable.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** Code trace: the traveler app router contains the admin routes. Only `/admin` has a UI role check; the other screens depend on Firestore rules. Consider adding a guard.

---

### TC-SEC-002 — Another user's trip is not visible

| Field | Detail |
|---|---|
| **Test Case ID** | TC-SEC-002 |
| **Test Case Title** | Another user's trip is not visible |
| **Related Test Scenario** | TS-SEC-001 — Verify a traveler cannot reach admin data or other users' data through the app. |
| **Module/Feature** | Security |
| **Test Objective** | Verify trips are private unless shared by code. |
| **Priority** | High |
| **Test Type** | Security |
| **Coverage Group** | Critical/Core |

**Preconditions**
- The TripNest PH traveler app is installed and opens normally.
- The device is connected to the internet (Wi-Fi or mobile data).
- Traveler A has a saved trip; Traveler B has not joined it.

**Test Data**
- None needed.

**Test Steps**
1. Sign in as Traveler B and open Saved Trips.
2. Search in the app for A's trip title.

**Expected Result**
- B never sees A's trip in any list or search.

**Postconditions:** No change to saved data.

**Actual Result:** ______________________________

**Status:** ☐ Pass  ☐ Fail

**Remarks:** 

---

# STEP 4 — Special Conditions Coverage Map

This table shows which test cases cover each special condition.

| Area | Condition | Test Cases |
|---|---|---|
| Network | Wi-Fi disconnected (mobile data on) | TC-NET-002 |
| Network | Mobile data disconnected (Wi-Fi on) | TC-NET-003 |
| Network | Internet unavailable while loading | TC-HOME-008, TC-EXP-006, TC-DET-011, TC-NOTIF-006, TC-SRCH-007 |
| Network | Internet unavailable while submitting | TC-REG-010, TC-REG-011, TC-LOGIN-008, TC-LOGIN-009, TC-REV-010, TC-PLAN-006, TC-PLAN-007, TC-ITIN-004, TC-BIZ-016, TC-SET-007, TC-ADM-025, TC-CHAT-005 |
| Network | Internet returns after an interruption | TC-NET-001, TC-REG-010, TC-LOGIN-008, TC-EXP-006, TC-NET-004 |
| Network | Slow / unresponsive network | TC-NET-005 |
| App interruption | Incoming phone call | TC-INT-001, TC-PLAN-009 |
| App interruption | Notification appears | TC-INT-002, TC-NOTIF-004 |
| App interruption | Switch to another app / minimize / return | TC-INT-003, TC-INT-004, TC-PLAN-009 |
| App interruption | App closed and reopened | TC-LOGIN-014, TC-INT-006, TC-CHAT-006, TC-FAV-006, TC-ONB-003, TC-DATA-002 |
| App interruption | Screen locked / unlocked | TC-INT-005, TC-NOTIF-004 |
| User input | Empty fields | TC-REG-003, TC-LOGIN-004, TC-PWD-003, TC-REV-002, TC-PLAN-002, TC-BIZ-007, TC-ADM-017 |
| User input | Invalid format | TC-REG-004, TC-LOGIN-005, TC-PWD-006, TC-BIZ-002, TC-ADM-014 |
| User input | Very long input | TC-SRCH-005, TC-REV-003, TC-CHAT-003, TC-ADM-017, TC-BIZ-007 |
| User input | Minimum / maximum values | TC-REG-005, TC-REG-007, TC-PLAN-003, TC-PLAN-004, TC-ITIN-008, TC-ADM-014, TC-PROF-003 |
| User input | Special characters | TC-REG-008, TC-SRCH-005 |
| User input | Duplicate data | TC-REG-009, TC-ITIN-011, TC-TRIP-004, TC-DATA-001 |
| User input | Invalid combinations | TC-PLAN-004, TC-ITIN-017, TC-ADM-010, TC-EXP-005 |
| Permissions | Permission allowed | TC-HOME-002, TC-SET-003, TC-NOTIF-003, TC-PROF-006 |
| Permissions | Permission denied | TC-HOME-003, TC-REV-005, TC-DET-007, TC-NOTIF-003, TC-PROF-007 |
| Permissions | Permission denied permanently | TC-HOME-004, TC-HOME-005, TC-SET-003 |
| Permissions | Permission requested again when needed | TC-HOME-003, TC-SET-003 |
| Error handling | Friendly messages, no technical details | TC-ERR-001, TC-ERR-002, TC-LOGIN-002, TC-REG-009, TC-PLAN-006 |
| Data consistency | Saved correctly, no duplicates, survives reopen | TC-DATA-001, TC-DATA-002, TC-DATA-003, TC-FAV-006, TC-REV-010, TC-SET-006, TC-INT-006 |

---

# STEP 5 — Prioritized Organization of Test Coverage

This is only a way to organize the testing order. It is not a score or a ranking of quality.

## Critical/Core (77 test cases)

Authentication, account protection, saving data, itinerary generation and saving, expenses, business approval, role security and data consistency.

| Module | Test Case IDs |
|---|---|
| Registration | TC-REG-001, TC-REG-002, TC-REG-003, TC-REG-005, TC-REG-006, TC-REG-009, TC-REG-010 |
| Login | TC-LOGIN-001, TC-LOGIN-002, TC-LOGIN-003, TC-LOGIN-004, TC-LOGIN-008, TC-LOGIN-010, TC-LOGIN-011, TC-LOGIN-014, TC-LOGIN-015 |
| Forgot Password (OTP) | TC-PWD-001, TC-PWD-004, TC-PWD-005 |
| Email Verification | TC-VER-001, TC-VER-002 |
| Sign-out & Route Guard | TC-SESS-001 |
| Home | TC-HOME-001, TC-HOME-002, TC-HOME-003, TC-HOME-004, TC-HOME-008 |
| Explore | TC-EXP-006 |
| Search | TC-SRCH-001 |
| Details Screens | TC-DET-001 |
| Reviews & Reports | TC-REV-001, TC-REV-002, TC-REV-010 |
| Favorites & Lists | TC-FAV-001, TC-FAV-006 |
| AI Planner | TC-PLAN-001, TC-PLAN-002, TC-PLAN-003, TC-PLAN-006, TC-PLAN-007 |
| Generated Itinerary | TC-ITIN-001, TC-ITIN-002, TC-ITIN-003, TC-ITIN-004, TC-ITIN-007, TC-ITIN-008 |
| AI Travel Assistant | TC-CHAT-001, TC-CHAT-002, TC-CHAT-005 |
| Profile | TC-PROF-002 |
| Settings | TC-SET-004, TC-SET-005, TC-SET-006 |
| Business Owner | TC-BIZ-001, TC-BIZ-002, TC-BIZ-004, TC-BIZ-006, TC-BIZ-007, TC-BIZ-010, TC-BIZ-016 |
| Admin Portal – Access & Roles | TC-ADM-001, TC-ADM-002, TC-ADM-003 |
| Admin Portal – Business Approval | TC-ADM-004, TC-ADM-005, TC-ADM-008 |
| Admin Portal – Team & Travelers | TC-ADM-012 |
| Admin Portal – Content | TC-ADM-013, TC-ADM-014, TC-ADM-021 |
| Network & Offline | TC-NET-001 |
| Error Handling | TC-ERR-001 |
| Data Consistency | TC-DATA-001, TC-DATA-002, TC-DATA-003 |
| Security | TC-SEC-001, TC-SEC-002 |

## Important (103 test cases)

Major features that should work but are not transaction-critical: browsing, search, filters, favorites, profile, settings, notifications, moderation, content forms.

| Module | Test Case IDs |
|---|---|
| Splash & Onboarding | TC-ONB-001 |
| Registration | TC-REG-004, TC-REG-007 |
| Login | TC-LOGIN-005, TC-LOGIN-012, TC-LOGIN-016 |
| Forgot Password (OTP) | TC-PWD-002, TC-PWD-003, TC-PWD-006, TC-PWD-007, TC-PWD-008 |
| Email Verification | TC-VER-006 |
| Sign-out & Route Guard | TC-SESS-002 |
| Home | TC-HOME-005, TC-HOME-007 |
| Explore | TC-EXP-001, TC-EXP-002, TC-EXP-003, TC-EXP-004, TC-EXP-005 |
| Search | TC-SRCH-003, TC-SRCH-005, TC-SRCH-006 |
| Details Screens | TC-DET-002, TC-DET-005, TC-DET-006, TC-DET-008, TC-DET-009, TC-DET-011, TC-DET-012, TC-DET-013 |
| Nearby Places | TC-NEAR-001 |
| Reviews & Reports | TC-REV-004, TC-REV-006, TC-REV-007, TC-REV-008, TC-REV-009 |
| Favorites & Lists | TC-FAV-002, TC-FAV-003, TC-FAV-005 |
| AI Planner | TC-PLAN-004, TC-PLAN-010 |
| Generated Itinerary | TC-ITIN-005, TC-ITIN-006, TC-ITIN-009, TC-ITIN-010, TC-ITIN-011, TC-ITIN-014, TC-ITIN-015, TC-ITIN-016, TC-ITIN-017 |
| Saved Trips & Sharing | TC-TRIP-001, TC-TRIP-002, TC-TRIP-003, TC-TRIP-004 |
| AI Travel Assistant | TC-CHAT-003, TC-CHAT-006, TC-CHAT-007, TC-CHAT-010 |
| Profile | TC-PROF-001, TC-PROF-003, TC-PROF-005, TC-PROF-006, TC-PROF-007, TC-PROF-008, TC-PROF-009, TC-PROF-011 |
| Settings | TC-SET-001, TC-SET-002, TC-SET-003, TC-SET-007 |
| Notifications | TC-NOTIF-001, TC-NOTIF-003, TC-NOTIF-004 |
| Business Owner | TC-BIZ-005, TC-BIZ-008, TC-BIZ-009, TC-BIZ-011, TC-BIZ-012, TC-BIZ-013, TC-BIZ-015 |
| Admin Portal – Access & Roles | TC-ADM-024 |
| Admin Portal – Business Approval | TC-ADM-006, TC-ADM-007, TC-ADM-009 |
| Admin Portal – Team & Travelers | TC-ADM-010, TC-ADM-011 |
| Admin Portal – Content | TC-ADM-015, TC-ADM-018, TC-ADM-019, TC-ADM-020 |
| Admin Portal – Announcements & Analytics | TC-ADM-016, TC-ADM-017, TC-ADM-023 |
| Admin Portal – Moderation | TC-ADM-022 |
| Network & Offline | TC-NET-002, TC-NET-003, TC-NET-005 |
| App Interruptions | TC-INT-001, TC-INT-003, TC-INT-004, TC-INT-006 |
| Compatibility & Responsiveness | TC-COMP-001 |

## Additional/Edge Cases (58 test cases)

Unusual conditions, interruptions, boundary values, rate limits and recovery scenarios.

| Module | Test Case IDs |
|---|---|
| Splash & Onboarding | TC-ONB-002, TC-ONB-003, TC-ONB-004 |
| Registration | TC-REG-008, TC-REG-011, TC-REG-012 |
| Login | TC-LOGIN-006, TC-LOGIN-007, TC-LOGIN-009, TC-LOGIN-013, TC-LOGIN-017 |
| Forgot Password (OTP) | TC-PWD-009, TC-PWD-010, TC-PWD-011 |
| Email Verification | TC-VER-003, TC-VER-004, TC-VER-005, TC-VER-007 |
| Sign-out & Route Guard | TC-SESS-003 |
| Home | TC-HOME-006 |
| Search | TC-SRCH-002, TC-SRCH-004, TC-SRCH-007 |
| Details Screens | TC-DET-003, TC-DET-004, TC-DET-007, TC-DET-010 |
| Nearby Places | TC-NEAR-002 |
| Reviews & Reports | TC-REV-003, TC-REV-005 |
| Favorites & Lists | TC-FAV-004, TC-FAV-007 |
| AI Planner | TC-PLAN-005, TC-PLAN-008, TC-PLAN-009 |
| Generated Itinerary | TC-ITIN-012, TC-ITIN-013, TC-ITIN-018 |
| Saved Trips & Sharing | TC-TRIP-005, TC-TRIP-006 |
| AI Travel Assistant | TC-CHAT-004, TC-CHAT-008, TC-CHAT-009 |
| Profile | TC-PROF-004, TC-PROF-010 |
| Settings | TC-SET-008 |
| Notifications | TC-NOTIF-002, TC-NOTIF-005, TC-NOTIF-006 |
| Business Owner | TC-BIZ-003, TC-BIZ-014 |
| Admin Portal – Access & Roles | TC-ADM-025 |
| Network & Offline | TC-NET-004 |
| App Interruptions | TC-INT-002, TC-INT-005 |
| Error Handling | TC-ERR-002 |
| Compatibility & Responsiveness | TC-COMP-002, TC-COMP-003 |

---

# STEP 6 — Final Test Case Table (Master Table, divided by module)

## Splash & Onboarding

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-ONB-001 | TS-ONB-001 | Complete onboarding with Next and Get Started | Splash & Onboarding | The TripNest PH traveler app is installed and opens normally.<br>Fresh install (or app data cleared) so onboarding has never been completed.<br>The tester is signed out. | — | 1. Open the app.<br>2. Wait for the splash logo (about 2.6 seconds).<br>3. On slide 1, read the title, then tap **Next**.<br>4. On slide 2, tap **Next**.<br>5. On slide 3, confirm the button label now reads **Get Started**, then tap it. | Splash screen shows the TripNest PH logo, then onboarding appears.<br>Slide 1 title: "Discover hidden gems across the Philippines".<br>Slide 2 title: "Let AI plan your perfect trip".<br>Slide 3 title: "Save, share and travel smarter".<br>After Get Started the user is not signed in, so the app shows the **Login** screen. | Medium | Functional | | |  |
| TC-ONB-002 | TS-ONB-001 | Skip onboarding from the first slide | Splash & Onboarding | The TripNest PH traveler app is installed and opens normally.<br>Fresh install; onboarding not completed before. | — | 1. Open the app and wait for onboarding.<br>2. On slide 1, tap **Skip**. | Onboarding closes immediately without visiting slides 2 and 3.<br>The Login screen is shown (user is not signed in). | Low | Functional | | |  |
| TC-ONB-003 | TS-ONB-002 | Onboarding shows again if the app is killed mid-onboarding | Splash & Onboarding | The TripNest PH traveler app is installed and opens normally.<br>Fresh install; onboarding not completed before. | — | 1. Open the app and wait for onboarding to appear.<br>2. On slide 2, swipe the app away from the recent-apps list to close it completely.<br>3. Open the app again. | After the splash screen, onboarding is shown again from slide 1. | Low | Interruption/Recovery | | |  |
| TC-ONB-004 | TS-ONB-002 | Returning user skips onboarding | Splash & Onboarding | The TripNest PH traveler app is installed and opens normally.<br>Onboarding was completed once on this device.<br>The tester is signed out. | — | 1. Close the app completely.<br>2. Open the app.<br>3. Wait for the splash screen to finish. | After the splash screen the **Login** screen is shown directly; onboarding is not shown. | Low | Functional | | |  |

## Registration

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-REG-001 | TS-REG-001 | Register a new traveler ("Just Exploring") | Registration | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The tester is signed out and is on the Login screen.<br>The email below has never been registered. | First Name: `Maria`<br>Last Name: `Santos`<br>Email: `maria.santos.test01@example.com`<br>Password: `Test@1234`<br>Confirm Password: `Test@1234` | 1. On Login, tap **Sign Up**.<br>2. In the "Welcome to TripNest PH — What brings you here?" dialog, choose **Just Exploring**.<br>3. Confirm the subtitle reads "Start planning unforgettable Philippine trips."<br>4. Fill in all fields with the test data.<br>5. Tap **Create Account**. | The button shows a loading indicator while working.<br>A new account is created and the user is signed in.<br>The **Verify your email** screen opens with the text "Verify maria.santos.test01@example.com to activate your TripNest PH account." | High | Functional | | |  |
| TC-REG-002 | TS-REG-002 | Register as a business owner | Registration | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The tester is signed out and is on the Login screen. | First Name: `Juan`<br>Last Name: `Dela Cruz`<br>Email: `juan.owner.test01@example.com`<br>Password: `Owner@1234` | 1. On Login, tap **Sign Up**.<br>2. In the role dialog, choose **I Own a Business**.<br>3. Confirm the subtitle reads "Let's get your business set up."<br>4. Fill in the form with the test data (same value in Confirm Password).<br>5. Tap **Create Account**. | Account is created.<br>The **Business Owner Application** screen opens (it is reachable before email verification). | High | Functional | | |  |
| TC-REG-003 | TS-REG-003 | Register with all fields empty | Registration | The TripNest PH traveler app is installed and opens normally.<br>The tester is on the Register screen. | — | 1. Leave every field empty.<br>2. Tap **Create Account**. | First Name shows "Name is required".<br>Last Name shows "Name is required".<br>Email shows "Email is required".<br>Password shows "Password is required".<br>No loading indicator appears and no account is created. | High | Validation | | | Confirm Password does not show an error when both password fields are empty, because the validator only compares the two values. |
| TC-REG-004 | TS-REG-004 | Register with invalid email formats | Registration | The TripNest PH traveler app is installed and opens normally.<br>The tester is on the Register screen with other fields filled correctly. | `abc`<br>`abc@`<br>`abc@example`<br>`a@b..com`<br>`abc@example.com.`<br>`abc @example.com` | 1. Enter the first invalid value in the Email field.<br>2. Tap **Create Account**.<br>3. Note the message under Email.<br>4. Repeat for each remaining value. | For every value, Email shows "Enter a valid email address".<br>No account is created. | Medium | Validation | | |  |
| TC-REG-005 | TS-REG-005 | Password length boundary (7, 8 characters) | Registration | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The tester is on the Register screen with other fields valid and a new email. | Case A password: `Ab@1234` (7 chars)<br>Case B password: `Ab@12345` (8 chars) | 1. Enter the Case A password in both Password and Confirm Password.<br>2. Tap **Create Account**.<br>3. Note the result.<br>4. Change both fields to the Case B password.<br>5. Tap **Create Account**. | Case A: Password shows "Password must be at least 8 characters" and no account is created.<br>Case B: the form passes validation and the account is created (Verify Email screen opens). | High | Boundary | | |  |
| TC-REG-006 | TS-REG-005 | Confirm Password does not match | Registration | The TripNest PH traveler app is installed and opens normally.<br>The tester is on the Register screen with other fields valid. | Password: `Test@1234`<br>Confirm Password: `Test@12345` | 1. Enter the test data.<br>2. Tap **Create Account**. | Confirm Password shows "Passwords do not match".<br>No account is created. | High | Validation | | |  |
| TC-REG-007 | TS-REG-006 | Name length boundaries | Registration | The TripNest PH traveler app is installed and opens normally.<br>The tester is on the Register screen; other fields valid. | 1 character: `A`<br>2 characters: `Al`<br>60 characters: `Abcdefghij` repeated 6 times<br>61 characters: the 60-character value plus `x` | 1. Enter `A` in First Name and tap **Create Account**; note the message.<br>2. Enter `Al` and tap **Create Account**; note the message.<br>3. Enter the 61-character value and tap **Create Account**; note the message.<br>4. Enter the 60-character value and tap **Create Account**; note the message. | `A`: "Name is too short".<br>`Al`: no First Name error.<br>61 characters: "Name must be 60 characters or fewer".<br>60 characters: no First Name error. | Medium | Boundary | | | If the text field itself stops typing at 60 characters, record that instead. The same rules apply to Last Name. |
| TC-REG-008 | TS-REG-006 | Names with special characters | Registration | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The tester is on the Register screen. | First Name: `Ana-Marie`<br>Last Name: `O'Neil`<br>Email: `ana.oneil.test01@example.com`<br>Password: `Test@1234` | 1. Enter the test data.<br>2. Tap **Create Account**.<br>3. After the account is created, open Profile. | Registration succeeds (no name-format error).<br>Profile shows the name "Ana-Marie O'Neil". | Low | Validation | | |  |
| TC-REG-009 | TS-REG-007 | Register with an email that already exists | Registration | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The account `tester01@example.com` already exists. | Email: `tester01@example.com`<br>Any valid names and password `Test@1234` | 1. Open Register (choose Just Exploring).<br>2. Enter the test data.<br>3. Tap **Create Account**. | A red message appears above the button: "An account already exists with that email."<br>The user stays on Register; no raw Firebase code is shown. | High | Negative | | |  |
| TC-REG-010 | TS-REG-008 | Register while offline | Registration | The TripNest PH traveler app is installed and opens normally.<br>The tester is on the Register screen with all fields valid and a new email.<br>Wi-Fi and mobile data are turned OFF. | — | 1. Tap **Create Account**.<br>2. Wait for the result.<br>3. Turn the internet back on and tap **Create Account** again. | While offline: message "No internet connection. Please check your network and try again." is shown; the button is usable again.<br>After reconnecting: registration succeeds and Verify Email opens.<br>Only one account exists for that email. | High | Interruption/Recovery | | |  |
| TC-REG-011 | TS-REG-008 | Internet lost while registering | Registration | The TripNest PH traveler app is installed and opens normally.<br>Register form filled with a new email; internet ON. | — | 1. Tap **Create Account**.<br>2. Immediately turn the internet OFF (airplane mode).<br>3. Observe the screen for up to 30 seconds.<br>4. Turn the internet ON.<br>5. If an error is shown, tap **Create Account** again. | The button never stays loading forever; either the account is created or a friendly message (network or "This is taking longer than expected...") appears.<br>No stack trace or error code is visible.<br>After recovery the user can register or, if the account was already created, is signed in on Verify Email. | Medium | Interruption/Recovery | | | Result depends on exact timing. Record what happened. |
| TC-REG-012 | TS-REG-009 | Double-tap Create Account | Registration | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>Register form filled with a new email. | — | 1. Tap **Create Account** twice quickly. | The button shows a loading state and ignores the second tap.<br>Only one account is created and one Verify Email screen opens. | Medium | Negative | | |  |

## Login

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-LOGIN-001 | TS-LOGIN-001 | Login with valid credentials | Login | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The tester is signed out and is on the Login screen.<br>Verified traveler account exists. | Email: `tester01@example.com`<br>Password: `Test@1234` | 1. Enter the email.<br>2. Enter the password.<br>3. Tap **Sign In**. | The button shows a loading indicator.<br>The user is authenticated and the **Home** screen with the bottom navigation (Home, Explore, Planner, Saved, Profile) is shown. | High | Functional | | |  |
| TC-LOGIN-002 | TS-LOGIN-002 | Login with wrong password | Login | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The tester is signed out and is on the Login screen.<br>Account `tester01@example.com` exists. | Email: `tester01@example.com`<br>Password: `WrongPass99` | 1. Enter the test data.<br>2. Tap **Sign In**. | A red message "Incorrect email or password." appears under the fields.<br>The user stays on Login; no Firebase error code is visible. | High | Negative | | |  |
| TC-LOGIN-003 | TS-LOGIN-002 | Login with an unregistered email | Login | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The tester is signed out and is on the Login screen. | Email: `nobody.here99@example.com`<br>Password: `Test@1234` | 1. Enter the test data.<br>2. Tap **Sign In**. | A friendly message appears: "Incorrect email or password." (or "No account found with that email.").<br>The user stays on Login. | High | Negative | | | Firebase may return either error code depending on project settings. Both are acceptable friendly messages. |
| TC-LOGIN-004 | TS-LOGIN-003 | Login with empty fields | Login | The TripNest PH traveler app is installed and opens normally.<br>The tester is signed out and is on the Login screen. | — | 1. Leave Email and Password empty.<br>2. Tap **Sign In**. | Email shows "Email is required".<br>Password shows "Password is required".<br>No request is sent (no loading indicator). | High | Validation | | |  |
| TC-LOGIN-005 | TS-LOGIN-003 | Login with invalid email format | Login | The TripNest PH traveler app is installed and opens normally.<br>The tester is signed out and is on the Login screen. | Email: `tester01@`<br>Password: `Test@1234` | 1. Enter the test data.<br>2. Tap **Sign In**. | Email shows "Enter a valid email address".<br>No request is sent. | Medium | Validation | | |  |
| TC-LOGIN-006 | TS-LOGIN-003 | Login accepts a short password attempt (no 8-character rule) | Login | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The tester is signed out and is on the Login screen. | Email: `tester01@example.com`<br>Password: `abc123` (6 characters) | 1. Enter the test data.<br>2. Tap **Sign In**. | No "at least 8 characters" message appears on the form.<br>The request is sent and the result is "Incorrect email or password." | Low | Boundary | | | Code comment in login_screen.dart says this is intentional so older short-password accounts can still sign in. |
| TC-LOGIN-007 | TS-LOGIN-003 | Password field is masked and Enter submits | Login | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The tester is signed out and is on the Login screen. | — | 1. Type `Test@1234` in the Password field and check how the text looks.<br>2. Fill in a valid email, then press **Done/Enter** on the keyboard while in the Password field. | Password characters are shown as dots, not readable text.<br>Pressing Done/Enter starts sign-in the same way as tapping **Sign In**. | Low | Usability | | |  |
| TC-LOGIN-008 | TS-LOGIN-004 | Login while offline | Login | The TripNest PH traveler app is installed and opens normally.<br>The tester is signed out and is on the Login screen.<br>Wi-Fi and mobile data are OFF. | Email: `tester01@example.com`<br>Password: `Test@1234` | 1. Enter the test data.<br>2. Tap **Sign In**.<br>3. Turn the internet ON and tap **Sign In** again. | While offline: "No internet connection. Please check your network and try again."<br>After reconnecting: login succeeds and Home opens. | High | Interruption/Recovery | | |  |
| TC-LOGIN-009 | TS-LOGIN-004 | Internet lost during sign-in | Login | The TripNest PH traveler app is installed and opens normally.<br>The tester is signed out and is on the Login screen.<br>Valid credentials typed in. | — | 1. Tap **Sign In**.<br>2. Immediately switch on airplane mode.<br>3. Wait up to 30 seconds. | The loading indicator ends; a friendly message appears (network or timeout text).<br>The Sign In button becomes tappable again.<br>No technical text is shown. | Medium | Interruption/Recovery | | | The result depends on timing; login may also succeed if the request finished first. |
| TC-LOGIN-010 | TS-LOGIN-005 | Unverified account is sent to Verify Email | Login | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The tester is signed out and is on the Login screen.<br>An account exists whose email is NOT verified (e.g., the one from TC-REG-001). | — | 1. Sign in with the unverified account.<br>2. After landing on the next screen, try to open Home by other means (e.g., relaunch the app). | The user is taken to **Verify your email** instead of Home.<br>After relaunch the user is still routed to Verify Email. | High | Security | | |  |
| TC-LOGIN-011 | TS-LOGIN-005 | Suspended account is signed out | Login | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The tester is signed out and is on the Login screen.<br>A verified traveler account whose status is "suspended" (set from Admin Portal > Travelers > Suspend). | — | 1. Sign in with the suspended account. | The user is returned to the Login screen.<br>The message "This account has been suspended. Contact support for help." is shown. | High | Security | | | Needs manual verification: whether the Home screen flashes briefly before sign-out. |
| TC-LOGIN-012 | TS-LOGIN-005 | Suspend an account while the traveler is using the app | Login | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>A second person/browser is logged in to the Admin Portal as an admin. | — | 1. On the traveler device, stay on the Home screen.<br>2. On the Admin Portal, open **Travelers**, find the traveler and suspend the account.<br>3. Watch the traveler device for up to one minute. | The traveler is signed out automatically and sees the Login screen with the suspension message. | Medium | Security | | |  |
| TC-LOGIN-013 | TS-LOGIN-004 | Too many failed login attempts | Login | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The tester is signed out and is on the Login screen. | Email: `tester01@example.com`<br>Wrong password entered repeatedly | 1. Enter a wrong password and tap **Sign In**.<br>2. Repeat about 10 times in a row. | At some point the message "Too many attempts. Please wait a moment and try again." appears (instead of a Firebase code). | Low | Negative | | | Firebase decides when to throttle. If it does not throttle, record "not triggered". |
| TC-LOGIN-014 | TS-LOGIN-006 | Session stays after closing and reopening the app | Login | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234). | — | 1. Close the app completely (swipe it away).<br>2. Open the app.<br>3. Wait for the splash screen. | The user goes directly to Home without seeing Login.<br>Saved data (favorites, trips) is still visible. | High | Interruption/Recovery | | |  |
| TC-LOGIN-015 | TS-LOGIN-007 | Continue with Google — success | Login | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The tester is signed out and is on the Login screen.<br>A Google account is available on the device. | — | 1. On Login, tap **Continue with Google**.<br>2. Choose the Google account. | The Google account chooser appears.<br>After choosing, the user is signed in and Home opens.<br>A traveler profile is created if this is the first sign-in. | High | Functional | | | Needs manual verification of email-verified status for Google accounts on each platform (Android/iOS/Web). |
| TC-LOGIN-016 | TS-LOGIN-007 | Continue with Google — user cancels | Login | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The tester is signed out and is on the Login screen. | — | 1. Tap **Continue with Google**.<br>2. Close the account chooser without selecting an account (tap outside / Back). | The user stays on Login.<br>The message "Sign-in was cancelled." is shown; the app does not crash. | Medium | Negative | | |  |
| TC-LOGIN-017 | TS-LOGIN-007 | Continue with Google while offline | Login | The TripNest PH traveler app is installed and opens normally.<br>The tester is signed out and is on the Login screen.<br>Internet OFF. | — | 1. Tap **Continue with Google**. | A friendly message appears ("No internet connection. Please check your network and try again." or a generic "Something went wrong. Please try again.").<br>No raw platform error text is visible. | Medium | Interruption/Recovery | | |  |

## Forgot Password (OTP)

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-PWD-001 | TS-PWD-001 | Request a reset code for a registered email | Forgot Password (OTP) | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The tester is signed out and is on the Login screen.<br>Account `tester01@example.com` exists and its inbox can be read. | — | 1. On Login, tap **Forgot Password?**.<br>2. Enter `tester01@example.com`.<br>3. Tap **Send Code**.<br>4. Check the inbox of the email. | The screen changes to "Enter the code" with the text "We sent a 6-digit code to tester01@example.com. It expires in 10 minutes."<br>An email with a 6-digit numeric code arrives. | High | Functional | | | Email delivery depends on the firestore-send-email extension; check spam folder too. |
| TC-PWD-002 | TS-PWD-001 | Request a code for an unregistered email | Forgot Password (OTP) | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The tester is on Forgot Password step 1. | Email: `nobody.here99@example.com` | 1. Enter the email.<br>2. Tap **Send Code**. | The screen still moves to "Enter the code" (no "user not found" error).<br>No email is delivered to that address (nothing exists to receive). | Medium | Security | | |  |
| TC-PWD-003 | TS-PWD-004 | Send Code with empty or invalid email | Forgot Password (OTP) | The TripNest PH traveler app is installed and opens normally.<br>The tester is on Forgot Password step 1. | — | 1. Leave Email empty and tap **Send Code**.<br>2. Type `abc@` and tap **Send Code**. | Empty: "Email is required".<br>Invalid: "Enter a valid email address".<br>No request is sent. | Medium | Validation | | |  |
| TC-PWD-004 | TS-PWD-002 | Reset password with the correct code | Forgot Password (OTP) | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A valid code was received within the last 10 minutes (TC-PWD-001) and step 2 is open. | Code: the 6-digit code from the email<br>New password: `NewPass@123`<br>Confirm: `NewPass@123` | 1. Enter the code.<br>2. Enter the new password and confirm it.<br>3. Tap **Reset Password**.<br>4. On Login, sign in with the OLD password.<br>5. Sign in with `NewPass@123`. | A message "Password updated. Sign in with your new password." appears and the app returns to Login.<br>Old password: "Incorrect email or password."<br>New password: login succeeds. | High | Functional | | |  |
| TC-PWD-005 | TS-PWD-003 | Wrong code is rejected | Forgot Password (OTP) | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>Step 2 is open with a valid code already sent. | Code: `000000` (not the real code)<br>New password: `NewPass@123` | 1. Enter the wrong code and a valid new password (twice).<br>2. Tap **Reset Password**. | The message "Incorrect code. Please try again." is shown.<br>The password is not changed. | High | Negative | | |  |
| TC-PWD-006 | TS-PWD-004 | Code and new-password field validation | Forgot Password (OTP) | The TripNest PH traveler app is installed and opens normally.<br>Step 2 is open. | Code cases: empty, `12345`, `12ab56`, `1234567`<br>Password case: `Ab@1234` (7 chars)<br>Confirm case: different from password | 1. Tap **Reset Password** with all fields empty.<br>2. Enter `12345` in the code field and tap **Reset Password**.<br>3. Enter `12ab56` and tap **Reset Password**.<br>4. Enter a valid code, a 7-character new password and tap **Reset Password**.<br>5. Enter a valid password and a different confirm value; tap **Reset Password**. | Empty code: "Enter the 6-digit code".<br>`12345` or `12ab56`: "Code must be 6 digits".<br>7-character password: "Password must be at least 8 characters".<br>Mismatch: "Passwords do not match".<br>No request is sent while any error is showing. | Medium | Validation | | | `1234567` (7 digits) should also give "Code must be 6 digits" if the field allows 7 characters. |
| TC-PWD-007 | TS-PWD-003 | Expired code (older than 10 minutes) | Forgot Password (OTP) | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A code was requested more than 10 minutes ago and step 2 is still open (or reopen the flow and use the old code). | — | 1. Wait more than 10 minutes after receiving the code.<br>2. Enter the old code and a valid new password.<br>3. Tap **Reset Password**. | The message "This code has expired. Please request a new one." is shown.<br>The password is unchanged. | Medium | Negative | | |  |
| TC-PWD-008 | TS-PWD-003 | Five wrong attempts lock the code | Forgot Password (OTP) | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>Step 2 is open with a valid code sent. | — | 1. Enter a wrong code and tap **Reset Password**. Repeat until 5 wrong tries were made.<br>2. On the 6th try, enter the CORRECT code. | Tries 1–5: "Incorrect code. Please try again."<br>6th try (even with the right code): "Too many incorrect attempts. Please request a new code."<br>After tapping **Resend code**, a new code works. | Medium | Security | | |  |
| TC-PWD-009 | TS-PWD-004 | Resend code and hourly request limit | Forgot Password (OTP) | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>Step 2 is open for `tester01@example.com`; no reset code requested in the last hour. | — | 1. Tap **Resend code** and check the inbox.<br>2. Keep tapping **Resend code** until the total number of requests (including the first) reaches 6. | Each of the first 5 requests succeeds and a new code email is sent (the latest code replaces the earlier one).<br>The 6th request shows "You're doing that too often — please wait a bit and try again." | Low | Boundary | | | Limit is 5 requests per hour per email (functions/index.js). Testing consumes the tester account's quota for one hour. Bug fixed: Resend code used to crash (null form state); see test/widgets/forgot_password_screen_test.dart. |
| TC-PWD-010 | TS-PWD-004 | Back button on the code step | Forgot Password (OTP) | The TripNest PH traveler app is installed and opens normally.<br>Step 2 is open. | — | 1. Tap the back arrow at the top left. | The screen returns to the email step ("Reset your password") instead of leaving the flow. | Low | Usability | | |  |
| TC-PWD-011 | TS-PWD-001 | Reset password while offline | Forgot Password (OTP) | The TripNest PH traveler app is installed and opens normally.<br>Step 1 is open with a valid email typed; internet OFF. | — | 1. Tap **Send Code**. | A friendly message appears ("No internet connection..." or a generic try-again message).<br>The app stays on step 1. | Medium | Interruption/Recovery | | |  |

## Email Verification

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-VER-001 | TS-VER-001 | Verify email with a correct code | Email Verification | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The tester is signed in with an unverified account and is on **Verify your email**. | — | 1. Tap **Send Verification Code**.<br>2. Read the 6-digit code from the email inbox.<br>3. Enter the code in the "6-digit code" field.<br>4. Tap **Verify Code**. | After step 1 the text "Verification code sent." appears and a code field plus **Verify Code** and **Send New Code** buttons are shown.<br>After step 4 the account becomes verified and the app opens **Home**. | High | Functional | | |  |
| TC-VER-002 | TS-VER-002 | Incorrect verification code | Email Verification | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>Code field is visible on Verify Email (a code was requested). | `123`<br>`000000` | 1. Enter `123` and tap **Verify Code**.<br>2. Enter `000000` and tap **Verify Code**. | `123`: "Code must be 6 digits".<br>`000000`: "Incorrect code. Please try again."<br>The user stays on Verify Email. | High | Negative | | |  |
| TC-VER-003 | TS-VER-002 | Verification via another device is detected automatically | Email Verification | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The tester is on Verify Email with an unverified account. | — | 1. Verify the same account by another way (e.g., request a code on a second device signed in to the same account and verify it).<br>2. Keep the first device on the Verify Email screen and wait up to 10 seconds. | The first device moves to Home without any tap. | Low | Integration | | | Needs manual verification: only one device can normally hold the code. The tester may also use the Firebase Console to set the user to verified. |
| TC-VER-004 | TS-VER-002 | Polling stops after about 2 minutes | Email Verification | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The tester is on Verify Email with an unverified account. | — | 1. Stay on the screen for more than 2 minutes without verifying. | The hint "Still waiting? Check your spam folder, or send a code below." appears.<br>The user can still send and enter a code. | Low | Functional | | |  |
| TC-VER-005 | TS-VER-002 | "I've already verified" while still unverified | Email Verification | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>Unverified account on Verify Email; no code requested yet (the button is visible). | — | 1. Tap **I've already verified**. | The user stays on Verify Email; no crash and no technical message. | Low | Negative | | |  |
| TC-VER-006 | TS-VER-003 | Sign out from Verify Email | Email Verification | The TripNest PH traveler app is installed and opens normally.<br>Unverified account on Verify Email. | — | 1. Tap **Sign out**.<br>2. In the "Log out?" dialog (message: "You can sign back in anytime with the same account."), tap **Log Out**. | The user is signed out and the Login screen is shown. | Medium | Functional | | |  |
| TC-VER-007 | TS-VER-001 | Verification code limit and expiry | Email Verification | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>Unverified account on Verify Email; no code requested in the last hour. | — | 1. Tap **Send Verification Code**, then tap **Send New Code** until 6 requests are made in total.<br>2. Separately, wait 10+ minutes and enter an old code. | The 6th request shows "You're doing that too often — please wait a bit and try again."<br>An expired code shows "This code has expired. Please request a new one." | Low | Boundary | | |  |

## Sign-out & Route Guard

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-SESS-001 | TS-SESS-001 | Log out from Profile | Sign-out & Route Guard | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234). | — | 1. Open the **Profile** tab.<br>2. Tap **Log Out**.<br>3. In the "Log out?" dialog tap **Cancel** (or dismiss) and check the screen.<br>4. Tap **Log Out** again and this time confirm with **Log Out**. | Cancel keeps the user signed in on Profile.<br>Confirming signs the user out and the Login screen is shown. | High | Functional | | |  |
| TC-SESS-002 | TS-SESS-001 | Signed-out user cannot open app screens | Sign-out & Route Guard | The TripNest PH traveler app is installed and opens normally.<br>The tester is signed out. | — | 1. On the web build, type a signed-in URL such as `/saved` or `/planner` in the browser address bar and press Enter. | The Login screen is shown instead of the requested page. | Medium | Security | | | Web only. On mobile, deep links are not exposed, so this is a web check. |
| TC-SESS-003 | TS-SESS-001 | Signed-in user is redirected away from Login | Sign-out & Route Guard | The TripNest PH traveler app is installed and opens normally.<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Web build open. | — | 1. In the address bar go to `/login`, then `/register`. | In both cases the app redirects to **Home**. | Low | Security | | | Web only. |

## Home

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-HOME-001 | TS-HOME-001 | Home screen loads its sections | Home | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Content (destinations, restaurants, festivals, travel tips) exists in the database. | — | 1. Open the app and land on **Home**.<br>2. Scroll from top to bottom. | Sections appear with images and text: **Featured Destinations**, **Popular Restaurants**, **Upcoming Festivals**, **Travel Tips**.<br>**Nearby You** and **Nearby Restaurants** appear when the location is available.<br>Loading placeholders are replaced by real content; no error text is visible. | High | Functional | | |  |
| TC-HOME-002 | TS-HOME-002 | Allow location permission on Home | Home | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Device location services are ON.<br>Location permission for TripNest PH is not yet granted (fresh install or reset permissions). | — | 1. Open **Home**.<br>2. If the "See what's nearby" card shows, tap **Allow Location**.<br>3. In the system dialog choose **While using the app** (or Allow). | The card message before granting reads "Allow location access to see the tourist spots closest to you."<br>After allowing, the card disappears and **Nearby You** shows attractions sorted around the current location. | High | Functional | | |  |
| TC-HOME-003 | TS-HOME-002 | Deny location permission | Home | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Location services ON; permission not granted yet. | — | 1. Open **Home** and trigger the permission request (tap **Allow Location**).<br>2. In the system dialog choose **Deny**.<br>3. Scroll through Home.<br>4. Tap **Allow Location** again. | Home still shows Featured Destinations, Restaurants, Festivals and Tips.<br>The card still says "Allow location access to see the tourist spots closest to you." with **Allow Location**.<br>Tapping it shows the system permission dialog again. | High | Negative | | |  |
| TC-HOME-004 | TS-HOME-002 | Location permission denied permanently | Home | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Location permission was denied with "Don't ask again" / denied permanently. | — | 1. Open **Home**.<br>2. Read the location card.<br>3. Tap **Open App Settings**.<br>4. Enable Location in the system settings and return to the app.<br>5. Pull down to refresh Home (or tap the card's action again). | The card reads "Location access is turned off for TripNest PH. Enable it in Settings to see spots near you." with **Open App Settings**.<br>The phone's app settings page opens.<br>After enabling and returning, nearby sections appear. | High | Negative | | |  |
| TC-HOME-005 | TS-HOME-002 | Device location services turned off | Home | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Device location (GPS) is switched OFF in quick settings. | — | 1. Open **Home**.<br>2. Read the location card.<br>3. Tap **Open Location Settings**. | The card reads "Turn on location services on your device to see the tourist spots closest to you."<br>The system location settings screen opens. | Medium | Negative | | |  |
| TC-HOME-006 | TS-HOME-002 | Location cannot be determined | Home | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Permission is granted but the device cannot get a fix (e.g., indoors with GPS disabled in mock settings, or emulator without a set location). | — | 1. Open **Home**.<br>2. Tap **Try Again** on the location card. | Message "We couldn't get your location just now. Please try again." with **Try Again**.<br>Tapping it retries; if it still fails, the same message stays and the app does not crash. | Low | Negative | | | Hard to reproduce on a real device; use an emulator with no location set. |
| TC-HOME-007 | TS-HOME-003 | Pull down to refresh Home | Home | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The tester is on Home. | — | 1. Add or change a festival in the Admin Portal (optional).<br>2. On Home, pull down from the top of the screen and release. | A refresh indicator appears and then disappears.<br>Content is reloaded (new/changed items appear if data changed). | Medium | Functional | | |  |
| TC-HOME-008 | TS-HOME-003 | Home opened while offline | Home | The TripNest PH traveler app is installed and opens normally.<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Home was opened at least once with internet (so data can be cached). | — | 1. Turn Wi-Fi and mobile data OFF.<br>2. Close the app fully and reopen it.<br>3. Observe Home and the top of the screen.<br>4. Turn the internet ON and pull down to refresh. | A banner reads "You're offline — showing saved data".<br>Previously loaded content is shown, or a friendly error state whose title begins with "Couldn't" appears with no technical text.<br>After reconnecting and refreshing, the banner disappears and content loads. | High | Interruption/Recovery | | | The project documentation says there is no offline cache, but the code enables Firestore persistence and shows this banner. Record what really happens. |

## Explore

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-EXP-001 | TS-EXP-001 | Browse each Explore tab | Explore | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234). | — | 1. Tap the **Explore** bottom tab.<br>2. View the Destinations list.<br>3. Switch to the Restaurants tab, then Festivals, then the local businesses tab. | Each tab shows cards in a two-column responsive grid with image, name and rating/date info.<br>Switching tabs shows a different list each time without a crash. | High | Functional | | | Exact tab labels for the local-business tab need manual verification. |
| TC-EXP-002 | TS-EXP-001 | Load More paging (20 items per page) | Explore | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>More than 20 destinations exist in the database. | — | 1. Open **Explore** > Destinations.<br>2. Scroll to the bottom and count the cards shown.<br>3. Tap **Load More**.<br>4. Check the list again for repeated cards. | About 20 cards are shown first.<br>After **Load More**, additional cards are added below.<br>No card appears twice. | Medium | Boundary | | |  |
| TC-EXP-003 | TS-EXP-002 | Apply filters and reset them | Explore | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The tester is on Explore > Destinations. | Region: any region<br>Minimum Rating: `4.0+ ★`<br>Distance: `Within 25 km` (location permission granted) | 1. Open the filter and wait for "Loading regions..." to finish.<br>2. Choose a Region, then a Province.<br>3. Select Minimum Rating `4.0+ ★`.<br>4. Select Distance `Within 25 km`.<br>5. Tap **Apply**.<br>6. Open the filter again and tap **Reset**, then **Apply**. | Filter chips for the chosen options are shown after Apply.<br>Only matching destinations remain (all with rating 4.0 or more, in the chosen province, within 25 km).<br>After Reset + Apply the full list returns. | High | Functional | | |  |
| TC-EXP-004 | TS-EXP-002 | Budget and accessibility filters on restaurants | Explore | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Restaurant data with price range (₱, ₱₱, ₱₱₱) exists; at least one restaurant has an accessibility tag. | — | 1. Open **Explore** > Restaurants.<br>2. Open the filter, choose Budget `₱ Budget-friendly`, then tap **Apply**.<br>3. Open the filter again, keep Budget and also choose one Accessibility tag, then **Apply**. | With Budget only: restaurants with one ₱ sign are shown.<br>With the accessibility tag also selected: only restaurants that have that tag remain; items with no accessibility data are hidden. | Medium | Functional | | |  |
| TC-EXP-005 | TS-EXP-003 | Filters that match nothing | Explore | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The tester is on Explore > Destinations. | — | 1. Open the filter and pick Minimum Rating `4.5+ ★` together with Distance `Within 5 km` in an area with no matching spots.<br>2. Tap **Apply**. | An empty state with the title "Nothing here yet" (or similar) is shown instead of a blank screen.<br>Filters can be changed or reset. | Medium | Negative | | |  |
| TC-EXP-006 | TS-EXP-003 | Explore loading fails (network dropped) | Explore | The TripNest PH traveler app is installed and opens normally.<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The tester has not opened Explore in this session; internet is ON. | — | 1. Turn the internet OFF.<br>2. Tap the **Explore** tab.<br>3. Turn the internet ON.<br>4. Pull down to refresh. | A friendly error state (title starting with "Couldn't ...") or cached content with the offline banner is shown; no stack trace or error code appears.<br>After refresh with internet ON, the list loads. | High | Interruption/Recovery | | |  |

## Search

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-SRCH-001 | TS-SRCH-001 | Search for an existing destination | Search | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>A destination named "Boracay" (or another known name) exists. | Query: `Boracay` | 1. Open the search screen from Home/Explore (tap the search bar).<br>2. Type `Boracay` in the box "Search destinations, food, festivals...".<br>3. Wait about 1 second. | Matching results appear without pressing Enter (about 0.35 second after typing stops).<br>Results include the destination; a "More places" section may show live Google Places results (only for queries of 3+ characters).<br>Tapping a result opens its details screen. | High | Functional | | |  |
| TC-SRCH-002 | TS-SRCH-003 | Search with a slightly misspelled word | Search | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Destination "Boracay" exists. | Query: `Boracy` | 1. Open search.<br>2. Type `Boracy`. | "Boracay" still appears in the results (small typos are tolerated). | Low | Functional | | | Code allows up to about 30% of the word length in edits (1 to 3). Check with 1 and 2 letter mistakes. |
| TC-SRCH-003 | TS-SRCH-003 | Search with no matching result | Search | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234). | Query: `zzzzqqqq` | 1. Open search.<br>2. Type `zzzzqqqq`. | A message with the title `No results for "zzzzqqqq"` is shown. | Medium | Negative | | |  |
| TC-SRCH-004 | TS-SRCH-003 | Empty query, spaces and clearing the box | Search | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234). | — | 1. Open search and type three spaces.<br>2. Type `Cebu`, wait for results, then delete all text. | Spaces only: no results/no error; recent/trending suggestions remain visible.<br>After deleting `Cebu`, results disappear and the suggestions (recent/trending) view returns. | Low | Boundary | | |  |
| TC-SRCH-005 | TS-SRCH-003 | Special characters and very long text | Search | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234). | `@#$%^&*()`<br>`<script>alert(1)</script>`<br>300 characters of the letter `a` | 1. Open search.<br>2. Enter each value one by one, waiting for the result each time. | The app shows "No results ..." (or a friendly message) for each value.<br>No crash, freeze, raw error, or script execution occurs. | Medium | Security | | |  |
| TC-SRCH-006 | TS-SRCH-002 | Recent searches: save, limit of 8 and clear | Search | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Recent search history is empty (Settings > Clear Recent Searches, or fresh install). | Queries: Cebu, Bohol, Baguio, Palawan, Siargao, Sagada, Vigan, Davao, Clark | 1. Search for each query in order, pausing at least 2 seconds after each so it is recorded.<br>2. Clear the search box and read the Recent searches list.<br>3. Tap **Clear** next to Recent, then confirm **Clear Recent Searches?**. | Only the 8 latest queries are listed; the oldest (`Cebu`) is gone.<br>After confirming, the recent list is empty; favorites and reviews are unaffected. | Medium | Boundary | | |  |
| TC-SRCH-007 | TS-SRCH-004 | Search with filters and offline behavior | Search | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234). | — | 1. Open search and type `beach`.<br>2. Open the filter, select Category = Beaches (or an available category) and **Apply**.<br>3. Turn the internet OFF.<br>4. Change the query to `waterfall`. | With the filter, only items of that category are listed.<br>After the internet is off, the screen shows a friendly title "Couldn't complete your search" (or shows cached results) with no technical text. | Medium | Interruption/Recovery | | |  |

## Details Screens

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-DET-001 | TS-DET-001 | Open a destination details screen | Details Screens | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>A destination with coordinates, entrance fee and tips exists. | — | 1. From Home or Explore, tap a destination card.<br>2. Scroll through the whole screen. | A hero image gallery is shown at the top.<br>Sections/labels are shown: **About**, **Highlights**, **Location** (map), **Travel Tips**, **Getting Around**, stats such as **Rating**, **Best Time**, **Entrance Fee**.<br>A live weather card is shown when the destination has coordinates.<br>**Nearby Attractions**, **Nearby Restaurants** and **Nearby Hotels** are listed. | High | Functional | | |  |
| TC-DET-002 | TS-DET-001 | Get Directions opens the maps app | Details Screens | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The tester is on a destination with coordinates; a maps or browser app exists on the device. | — | 1. Tap **Get Directions**. | An external maps app (or browser Google Maps) opens with the destination. | Medium | Integration | | |  |
| TC-DET-003 | TS-DET-005 | Get Directions when no maps app is available | Details Screens | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>A device/emulator with no browser or maps app able to open the link. | — | 1. Tap **Get Directions**. | A message "Couldn't open Maps. Please check that a maps or browser app is installed." appears; the app does not crash. | Low | Negative | | | Hard to reproduce on a normal phone. Optional test. |
| TC-DET-004 | TS-DET-001 | Share a destination | Details Screens | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The tester is on a destination details screen. | — | 1. Tap the share button in the top image bar. | The system share sheet opens with text about the destination. | Low | Integration | | |  |
| TC-DET-005 | TS-DET-002 | Open a restaurant details screen | Details Screens | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>A restaurant with phone, hours and price range exists. | — | 1. Open **Explore** > Restaurants and tap a restaurant.<br>2. Read the stats and sections.<br>3. Tap **Call**. | Stats show **Rating**, **Open Hours**, **Price Range**; sections **About**, **Menu Highlights**, **Accessibility**, **Location** appear when data exists.<br>A **Verified Partner** label is shown for restaurants that come from an approved business.<br>**Call** opens the phone dialer with the number (no call is placed automatically). | Medium | Functional | | |  |
| TC-DET-006 | TS-DET-003 | Set a festival reminder | Details Screens | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>An upcoming festival exists; notification permission is allowed. | — | 1. Open a festival from **Explore** > Festivals.<br>2. Tap **Set Reminder**.<br>3. Pick a future date, then a time (for example 3 minutes from now). | A message "Reminder set for <festival name>." appears.<br>At about the chosen time a local notification titled "Festival Reminder" from the "TripNest PH Reminders" channel is shown (it can be a few minutes late). | Medium | Functional | | | Needs manual verification on Android 13+ / exact-alarm settings and on iOS. |
| TC-DET-007 | TS-DET-003 | Festival reminder with notification permission denied | Details Screens | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Notification permission for TripNest PH is denied in device settings. | — | 1. Open a festival and tap **Set Reminder**.<br>2. Pick a future date/time and confirm.<br>3. Wait for the time to arrive. | The app does not crash.<br>No notification is delivered. | Medium | Negative | | | Needs manual verification: the code does not show a specific "permission denied" message for reminders. Record what the app shows. |
| TC-DET-008 | TS-DET-004 | Open a province details screen | Details Screens | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>A province with content exists. | — | 1. Open a province (e.g., from the destination or a province card).<br>2. Scroll through the page. | Sections such as **Featured Attractions**, **Things to Do**, **Where to Eat**, **Hotels & Resorts**, **Local Businesses**, **Local Festivals**, **Local Culture**, **Getting Around**, **Travel Tips**, **Emergency Hotlines** and stats (**Best Time**, **Daily Budget**) are shown when data exists.<br>**View on Google Maps** opens the maps app.<br>Provinces with no content show "Content coming soon". | Medium | Functional | | |  |
| TC-DET-009 | TS-DET-004 | Emergency access sheet | Details Screens | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The tester is on a destination or festival details screen. | — | 1. Tap the emergency button in the top image bar.<br>2. Read the sheet.<br>3. Tap **Hospital** under **Find Nearby**, go back, then tap **Police**. | A sheet opens with **National Emergency Hotline** first, followed by that province's hotlines if any exist.<br>**Hospital** and **Police** open a nearby search/maps app. | High | Functional | | | Do not actually call the emergency number during testing. |
| TC-DET-010 | TS-DET-005 | Destination without coordinates | Details Screens | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>A destination saved by an admin without latitude/longitude exists. | — | 1. Open that destination. | The screen opens normally.<br>The weather card, map and directions are not shown (or degrade gracefully); no error text appears. | Low | Negative | | |  |
| TC-DET-011 | TS-DET-005 | Details screen opened while offline | Details Screens | The TripNest PH traveler app is installed and opens normally.<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>A destination that was NOT opened before; internet OFF. | — | 1. Tap the destination card (list is already cached).<br>2. Watch the screen.<br>3. Turn the internet ON and reopen the screen. | A friendly state whose title begins "Couldn't ..." is shown (no stack trace or code), or cached data is shown with the offline banner.<br>After reconnecting the details load. | Medium | Interruption/Recovery | | |  |
| TC-DET-012 | TS-DET-001 | Report incorrect info on a listing | Details Screens | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The tester is on a destination details screen. | — | 1. Tap **Report incorrect info**.<br>2. In "Report this listing" select **Info is outdated or wrong**.<br>3. Tap **Report**.<br>4. Repeat and this time tap **Cancel**. | Report options: outdated/wrong info, Permanently closed, Inappropriate photo, Something else.<br>After **Report** the message "Thanks — our team will take a look." appears.<br>**Cancel** closes the dialog with no report sent.<br>The report appears in the Admin Portal reports list. | Medium | Functional | | |  |
| TC-DET-013 | TS-DET-003 | Festival reminder with a time that already passed | Details Screens | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>An upcoming festival exists; the tester is on its details screen. | Date: today<br>Time: one hour earlier than the current time | 1. Tap **Set Reminder**.<br>2. Pick today as the date.<br>3. Pick a time earlier than now. | The message "Pick a time in the future." appears.<br>No "Reminder set for ..." message appears and no notification is scheduled. | Medium | Validation | | | Added after a code trace: the picker used to accept past times. Fixed in lib/core/utils/reminder_picker.dart. |

## Nearby Places

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-NEAR-001 | TS-NEAR-001 | Browse nearby places by category and sort | Nearby Places | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Location permission granted; Google Places is available. | — | 1. On a destination details screen tap **Plan a Trip Nearby** or a "Nearby" section see-all action (or open the Nearby Places screen from Home).<br>2. Tap category chips such as **Restaurants**, **Hotels**, **Cafes**.<br>3. Change **Sort** to **Distance**, then **Rating**.<br>4. Type `coffee` in "Search places...". | A list of places for the selected category is shown.<br>The order changes when the sort option changes (Relevance, Distance, Rating, Popularity).<br>The search box narrows the list. | Medium | Functional | | | Needs manual verification of the exact entry point to this screen on each device. |
| TC-NEAR-002 | TS-NEAR-001 | Nearby category with no results | Nearby Places | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>A remote location with few places (or a rare category such as Hostels). | — | 1. Open Nearby Places and select a category that returns nothing. | A "No places found" state with the text "Nothing matched this search — try a different category." is shown. | Low | Negative | | |  |

## Reviews & Reports

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-REV-001 | TS-REV-001 | Write a review with rating and comment | Reviews & Reports | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The tester is on a destination details screen and has not reviewed it yet. | Rating: 4 stars<br>Comment: `Beautiful place, clean and easy to reach.` | 1. Scroll to the reviews section and tap the write-review action.<br>2. In the "Write a Review" sheet tap the 4th star.<br>3. Type the comment.<br>4. Tap the submit button. | The sheet closes.<br>The review appears in the list with the author name, 4 stars and the comment.<br>The place's rating and review count update.<br>A "verified" badge appears only if the traveler has a visit record for this place. | High | Functional | | |  |
| TC-REV-002 | TS-REV-002 | Submit a review with an empty comment | Reviews & Reports | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The write-review sheet is open. | — | 1. Select 5 stars.<br>2. Leave the Comment field empty (or only spaces).<br>3. Tap the submit button. | The message "Comment is required" appears under the field.<br>The review is not saved and the sheet stays open. | High | Validation | | |  |
| TC-REV-003 | TS-REV-002 | Comment length limit (2000 characters) | Reviews & Reports | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The write-review sheet is open. | A text of 2001 characters (copy/paste) | 1. Paste the 2001-character text into the Comment field.<br>2. Look at the character counter.<br>3. Submit the review. | The field accepts at most 2000 characters (the counter shows 2000/2000).<br>The review is saved with 2000 characters and the app does not crash. | Low | Boundary | | |  |
| TC-REV-004 | TS-REV-002 | Attach photos: maximum of 3 | Reviews & Reports | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The write-review sheet is open; the gallery has at least 4 photos smaller than 5 MB. | — | 1. Tap the add-photo box and allow photo access if asked.<br>2. Pick a photo. Repeat until 3 photos are attached.<br>3. Look for the add-photo box.<br>4. Remove one photo with its remove button.<br>5. Add a different photo and submit the review. | After 3 photos, the add-photo box is hidden (no 4th photo can be added).<br>Removing a photo makes the add box appear again.<br>The review is saved with its photos and they show in the review list. | Medium | Boundary | | |  |
| TC-REV-005 | TS-REV-005 | Photo permission denied | Reviews & Reports | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Photos permission for TripNest PH is denied (OS settings). | — | 1. Open the write-review sheet.<br>2. Tap the add-photo box. | The app does not crash.<br>A friendly message such as "Permission was denied. Please allow access in your device settings and try again." is shown, or the picker simply does not attach a photo. | Medium | Negative | | | Needs manual verification of platform behavior (Android vs iOS). |
| TC-REV-006 | TS-REV-003 | Edit and delete own review | Reviews & Reports | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The traveler has an existing review on a place. | — | 1. Open the place and find your review.<br>2. Choose **Edit**; change the rating to 2 stars and the comment; submit.<br>3. Choose **Delete** on the review and confirm. | The sheet title is "Edit Your Review" and the old values are pre-filled.<br>After the edit the list shows the new rating/comment.<br>After delete the review disappears and the review count decreases by 1. | High | Functional | | |  |
| TC-REV-007 | TS-REV-003 | Other users' reviews cannot be edited or deleted | Reviews & Reports | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Another traveler has reviewed the same place. | — | 1. Open the place and look at the other traveler's review actions. | Edit and Delete are not shown; a Report option is available instead. | High | Security | | |  |
| TC-REV-008 | TS-REV-004 | Report a review | Reviews & Reports | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Another traveler's review is visible. | — | 1. Open the report action on that review.<br>2. Read the options and select **Spam or advertising**.<br>3. Tap **Report**. | Options shown: Spam or advertising; Inappropriate or offensive; Fake — doesn't seem like a real visit; Something else.<br>A confirmation is shown and the report appears in the Admin Portal **Reports** list. | Medium | Functional | | |  |
| TC-REV-009 | TS-REV-004 | Restaurant owner replies to a review | Reviews & Reports | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The signed-in traveler has an active Business Owner role (accepted invite) — example: owner01@example.com.<br>The owner's approved Food & Dining listing has a review from another traveler. | — | 1. Sign in as the owner and open the restaurant details.<br>2. On the review tap **Reply as owner**, type a reply and save.<br>3. Reopen the same review with another traveler account. | The owner reply is shown under the review; the action changes to **Edit reply**.<br>The other traveler sees the reply but does not see a reply action. | Medium | Functional | | |  |
| TC-REV-010 | TS-REV-005 | Internet lost while submitting a review | Reviews & Reports | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>A filled review form (rating, comment, 1 photo) is ready. | — | 1. Tap submit.<br>2. Immediately turn the internet OFF.<br>3. Wait for the result.<br>4. Turn the internet ON and open the place again. | A friendly message appears (network or timeout) if the submit failed; no technical text.<br>After reconnecting, at most ONE review from this traveler exists for the place (no duplicates). | High | Interruption/Recovery | | |  |

## Favorites & Lists

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-FAV-001 | TS-FAV-001 | Save and unsave a destination with the bookmark icon | Favorites & Lists | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The Saved tab has no favorites. | — | 1. On Home tap the bookmark icon on a destination card.<br>2. Open the **Saved** tab and the **Places** tab.<br>3. Tap the bookmark icon on the same card again (Home or Explore).<br>4. Return to **Saved** > **Places**. | The icon changes to the saved state with a small bounce.<br>**Places (1)** shows the destination.<br>After the second tap the icon returns to unsaved and **Places (0)** is empty. | High | Functional | | |  |
| TC-FAV-002 | TS-FAV-001 | Saved tabs show each type | Favorites & Lists | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234). | — | 1. Save one destination, one restaurant, one festival, one local business and one live Google place.<br>2. Open **Saved** and check the tabs **Places**, **Food**, **Festivals**, **Local Finds**, **Attractions**. | Each item is in its correct tab and every tab counter shows (1). | Medium | Functional | | |  |
| TC-FAV-003 | TS-FAV-002 | Create a list and add a favorite to it | Favorites & Lists | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>At least one saved destination. | List name: `Summer Trip` | 1. Open **Saved** > **Places**.<br>2. Tap the list icon at the top right of a saved card.<br>3. In "Add to List" tap **New List**, type `Summer Trip` and confirm.<br>4. Select the new list for the item.<br>5. Select the `Summer Trip` chip at the top of Saved. | The list `Summer Trip` is created.<br>The item appears when that list is selected and is not shown under Unsorted. | Medium | Functional | | |  |
| TC-FAV-004 | TS-FAV-002 | List name validation (empty and 60-character maximum) | Favorites & Lists | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The "Add to List" sheet is open. | 61-character name | 1. Tap **New List** and leave the name empty; look at the confirm button.<br>2. Paste a 61-character name. | The confirm button is disabled while the name is empty.<br>The text field accepts a maximum of 60 characters. | Low | Boundary | | |  |
| TC-FAV-005 | TS-FAV-002 | Rename and delete a list | Favorites & Lists | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>A list `Summer Trip` containing 1 favorite exists. | — | 1. On **Saved**, long-press the `Summer Trip` chip.<br>2. Choose **Rename list**, enter `Winter Trip` and **Save**.<br>3. Long-press the chip again, choose **Delete list** and confirm **Delete "Winter Trip"?**. | The chip name changes to `Winter Trip`.<br>After delete the list is gone and its favorite moves back to Unsorted (message: "Favorites in this list aren't removed — they just go back to Unsorted."). | Medium | Functional | | |  |
| TC-FAV-006 | TS-FAV-003 | Favorites persist after restart and sync across sign-in | Favorites & Lists | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>At least 2 saved items. | — | 1. Close the app completely and open it again.<br>2. Open **Saved**.<br>3. Log out, log in again with the same account, and open **Saved**. | The same items and lists are shown after the restart and after re-login; no duplicates. | High | Interruption/Recovery | | |  |
| TC-FAV-007 | TS-FAV-003 | Save an item while offline | Favorites & Lists | The TripNest PH traveler app is installed and opens normally.<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Home is loaded with cards visible; internet then turned OFF. | — | 1. Tap the bookmark on a destination card while offline.<br>2. Turn the internet ON and wait 10 seconds.<br>3. Open **Saved**; then restart the app and check again. | The app does not crash and shows no technical message.<br>After reconnecting, the item is saved exactly once (or the app shows a friendly message that it could not save). | Medium | Interruption/Recovery | | | Needs manual verification: Firestore offline persistence may queue the write. |

## AI Planner

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-PLAN-001 | TS-PLAN-001 | Generate an itinerary with valid inputs | AI Planner | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Groq AI and Google APIs are working (Cloud Functions deployed). | Destination: a destination such as `Baguio` (Benguet)<br>Budget: `Mid-range` (₱15k – ₱40k)<br>Days: `3`<br>Who is traveling: `Friends`, Travelers: `4`<br>Transportation: `Van / Car Rental`<br>Interests: `Food`, `Nature`<br>Trip pace: `Balanced` | 1. Open the **Planner** tab.<br>2. Under "Where do you want to go?" pick the destination.<br>3. Select the budget, set days to 3, choose Friends with 4 travelers.<br>4. Select the transportation and interests, and the pace.<br>5. Tap **Generate Itinerary**. | The button changes to "Crafting your itinerary..." with a loading indicator and cannot be tapped again.<br>The generated itinerary screen opens.<br>It shows a day-by-day plan with 3 days, budget summary, weather outlook (when coordinates exist), recommended restaurants/accommodations and travel tips. | High | Functional | | |  |
| TC-PLAN-002 | TS-PLAN-002 | Generate is disabled without a destination | AI Planner | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The Planner form is opened fresh (no destination selected). | — | 1. Look at the bottom of the Planner screen.<br>2. Try to tap **Generate Itinerary**. | The text "Select a destination to continue" is shown above the button.<br>The **Generate Itinerary** button is disabled and nothing happens on tap. | High | Validation | | |  |
| TC-PLAN-003 | TS-PLAN-003 | Days boundary values 1 and 14 | AI Planner | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The Planner form is open. | Typed values: `0`, `1`, `14`, `15`, `abc` | 1. Press the minus button until the days no longer decrease.<br>2. Press the plus button until the days no longer increase.<br>3. Tap the days number to open "How many days?" (hint "Between 1 and 14").<br>4. Type each typed value and tap **Save**. | Minus stops at "1 day"; plus stops at "14 days" (the button becomes disabled).<br>`0` or `15`: "Enter a number between 1 and 14".<br>`abc`: "Enter a whole number".<br>`1` and `14` are accepted. | High | Boundary | | |  |
| TC-PLAN-004 | TS-PLAN-003 | Traveler count rules by traveler type | AI Planner | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The Planner form is open. | — | 1. Select **Solo** and read the traveler box and hint.<br>2. Select **Couple** and read them again.<br>3. Select **Friends**; tap the number and type `1`, then `16`, then `15`. | Solo: "1 traveler", locked (no plus/minus), hint "Solo trips are set to 1 traveler."<br>Couple: "2 travelers", locked, hint "Couple trips are set to 2 travelers."<br>Friends: hint "Friends trips need at least 2 travelers."<br>`1` and `16` show "Enter a number between 2 and 15"; `15` is accepted. | Medium | Boundary | | |  |
| TC-PLAN-005 | TS-PLAN-005 | Planner defaults and optional accommodation | AI Planner | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234). | — | 1. Open the **Planner** tab on a fresh session.<br>2. Read the default selections.<br>3. Tap the "Where are you staying? (optional)" field and search for a hotel name.<br>4. Try searching with an empty box. | Defaults: Budget = Mid-range, Days = 3, Travelers = 2, Who = Couple, Transportation = Van / Car Rental, Interests = Beaches + Food, Pace = Balanced.<br>Accommodation search sheet shows results, or "No accommodations found" when nothing matches.<br>An empty search does not run a search and does not crash.<br>The planner can generate with the accommodation left empty. | Low | Functional | | |  |
| TC-PLAN-006 | TS-PLAN-004 | Generate while offline | AI Planner | The TripNest PH traveler app is installed and opens normally.<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The Planner form is filled; internet OFF. | — | 1. Tap **Generate Itinerary**. | A snack bar appears with a friendly message (network/timeout text or "Couldn't generate your itinerary. Please try again.").<br>No error codes, JSON or stack trace are shown.<br>The button becomes usable again. | High | Interruption/Recovery | | |  |
| TC-PLAN-007 | TS-PLAN-004 | Internet lost while the itinerary is generating | AI Planner | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The Planner form is filled. | — | 1. Tap **Generate Itinerary**.<br>2. While "Crafting your itinerary..." is shown, turn the internet OFF.<br>3. Wait up to 60 seconds.<br>4. Turn the internet ON and tap **Generate Itinerary** again. | The loading state ends and a friendly error message appears.<br>After reconnecting a new generation succeeds.<br>Only one itinerary result is opened. | High | Interruption/Recovery | | |  |
| TC-PLAN-008 | TS-PLAN-004 | AI hourly limit (30 requests) | AI Planner | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The account already made about 30 AI calls (planner or chat) in the last hour. | — | 1. Tap **Generate Itinerary** with a valid form. | A friendly message like "You're doing that too often — please wait a bit and try again." (or "Too many requests right now...") is shown.<br>No technical error is displayed. | Low | Boundary | | | Uses the aiComplete limit of 30 per hour per user. Consumes many AI calls. |
| TC-PLAN-009 | TS-PLAN-004 | Phone call / app switch while generating | AI Planner | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The Planner form is filled. | — | 1. Tap **Generate Itinerary**.<br>2. While it is loading, receive/simulate an incoming call (or press Home and open another app for 20 seconds).<br>3. Return to TripNest PH. | The app resumes on the Planner screen.<br>Either the itinerary screen opens or a friendly error appears; the app does not crash or show two results. | Medium | Interruption/Recovery | | |  |
| TC-PLAN-010 | TS-PLAN-005 | Open the manual itinerary builder | AI Planner | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234). | Destination: any destination<br>Start date: a future date<br>Days: `2`<br>Travelers: `2` | 1. On Planner tap **Prefer to build it yourself? Create manually**.<br>2. On "Create Your Own Itinerary" look at **Start Planning** before choosing anything.<br>3. Choose the Destination, Start Date, Days and Travelers, then tap **Start Planning**. | **Start Planning** is disabled until both a destination and a start date are chosen (there is no error message).<br>With valid data, an itinerary with the chosen number of empty days opens for manual editing. | Medium | Functional | | | Code trace: manual_itinerary_screen.dart disables the button instead of showing a message. |

## Generated Itinerary

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-ITIN-001 | TS-ITIN-002 | Read the generated itinerary sections | Generated Itinerary | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>An itinerary was just generated (TC-PLAN-001). | — | 1. Scroll the whole itinerary screen from top to bottom. | Sections are shown: **Weather Outlook**, **Day-by-Day Plan** (each day with Morning/Afternoon/Evening activities), **Recommended Restaurants**, **Recommended Accommodations**, **Nearby Attractions**, **Budget Summary**, **Travel Tips**, **Getting Around**.<br>The action row shows **Share**, **Download**, **Remind** and **Regenerate**. | High | Functional | | | Content is AI-generated; check structure and not exact wording. |
| TC-ITIN-002 | TS-ITIN-001 | Save an itinerary to My Trips | Generated Itinerary | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>A newly generated (unsaved) itinerary is open. | — | 1. Tap the save (bookmark) action on the itinerary screen.<br>2. Open **Profile** > **My Trips** (Saved Trips). | A message "Itinerary saved to your trips." appears.<br>The trip appears once in the Saved Trips list. | High | Functional | | |  |
| TC-ITIN-003 | TS-ITIN-001 | Leave an unsaved itinerary | Generated Itinerary | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>A newly generated, unsaved itinerary is open. | — | 1. Press Back on the itinerary screen.<br>2. Tap **Discard**.<br>3. Generate another itinerary, press Back again and tap **Save & Leave**. | A "Save this trip?" dialog appears.<br>**Discard** leaves without saving; the trip is not in Saved Trips.<br>**Save & Leave** saves the trip once and leaves; the trip appears in Saved Trips. | High | Functional | | |  |
| TC-ITIN-004 | TS-ITIN-001 | Save while signed out / save failure | Generated Itinerary | The TripNest PH traveler app is installed and opens normally.<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>An unsaved itinerary is open; internet OFF. | — | 1. Tap the save action while offline.<br>2. Turn the internet ON and tap save again. | Offline: a friendly network or generic message is shown; no trip is created (or it is queued and saved once later).<br>Online: "Itinerary saved to your trips." and only one trip exists. | High | Interruption/Recovery | | | The message "Sign in to save this itinerary." exists in code for signed-out users but every itinerary screen requires sign-in, so it cannot normally be reached. |
| TC-ITIN-005 | TS-ITIN-003 | Add and remove an activity | Generated Itinerary | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>A saved trip is open and the tester is its owner. | Time: `Afternoon`<br>Title: `Visit Burnham Park`<br>Description: leave empty | 1. Tap **Add Activity** on a day.<br>2. Enter the time and title (Description is optional).<br>3. Confirm.<br>4. Remove the same activity and confirm the "Remove this activity?" dialog. | The new activity appears in that day with the entered time and title.<br>After removal it disappears from the list.<br>The changes stay after leaving and reopening the trip. | Medium | Functional | | |  |
| TC-ITIN-006 | TS-ITIN-003 | Regenerate a saved itinerary | Generated Itinerary | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>A saved trip is open. | — | 1. Tap **Regenerate**.<br>2. When "Replace your saved itinerary?" appears, tap cancel/decline, then repeat and confirm.<br>3. Wait for the result.<br>4. Open Saved Trips. | Cancel: the current itinerary is kept unchanged.<br>Confirm: a new plan replaces the old one for the same saved trip.<br>Saved Trips still shows only one trip (no duplicate). | Medium | Functional | | |  |
| TC-ITIN-007 | TS-ITIN-004 | Add a shared expense | Generated Itinerary | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>A saved trip is open. | Category: `Food`<br>Amount (₱): `1250.50`<br>Note: `Dinner at the market`<br>Split between: all members | 1. In **Budget Tracker** tap **Add Expense**.<br>2. Choose the category, enter the amount and note.<br>3. Keep at least one person checked under "Split between".<br>4. Tap **Add**. | The expense appears in the tracker with ₱1,250.50 and the note.<br>**Spend by Category**, **Actual Spend** and **Who Owes What** update. | High | Functional | | |  |
| TC-ITIN-008 | TS-ITIN-004 | Expense amount and split validation | Generated Itinerary | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The "Add Expense" dialog is open on a shared trip. | Amounts: empty, `0`, `-5`, `abc`, `500000`, `500001` | 1. Enter each amount and tap **Add**; note the message.<br>2. With a valid amount, uncheck every person under "Split between" and tap **Add**. | Empty: "This field is required".<br>`0` or `-5`: "Amount must be greater than 0".<br>`abc`: "Enter a valid amount".<br>`500001`: "Amount must be ₱500000 or less"; `500000` is accepted.<br>No person selected: "Select at least one person to split with". | High | Boundary | | |  |
| TC-ITIN-009 | TS-ITIN-004 | Edit and delete an expense | Generated Itinerary | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>A trip has an expense of ₱1,000. | — | 1. Open the expense and choose edit; change the amount to `600` and **Save**.<br>2. Delete the expense and confirm "Delete this expense?". | Totals change to ₱600 after the edit.<br>After delete the expense is removed and totals return to ₱0 for it. | Medium | Functional | | |  |
| TC-ITIN-010 | TS-ITIN-005 | Create a poll and vote | Generated Itinerary | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>A saved trip is open. | Question: `Which restaurant for Day 2?`<br>Option 1: `Restaurant A`<br>Option 2: `Restaurant B` | 1. In **Group Polls** tap **New Poll**.<br>2. Enter the question and two options.<br>3. Tap **Create**.<br>4. Tap Option 1 to vote. | The poll appears with both options.<br>After voting the vote count for Option 1 becomes 1. | Medium | Functional | | |  |
| TC-ITIN-011 | TS-ITIN-005 | Poll validation rules | Generated Itinerary | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The "New Poll" dialog is open. | — | 1. Tap **Create** with an empty question.<br>2. Enter a question and only one option; tap **Create**.<br>3. Enter `Beach` and `beach` as two options; tap **Create**.<br>4. Tap **Add option** repeatedly. | Empty question: "Enter a question".<br>One option: "Add at least 2 options."<br>Duplicates (any letter case): "Options must be different from each other."<br>**Add option** is no longer shown after 6 options. | Medium | Validation | | |  |
| TC-ITIN-012 | TS-ITIN-005 | Edit a poll clears votes; delete a poll | Generated Itinerary | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>A poll with at least 1 vote exists. | — | 1. Open **Edit Poll** for that poll.<br>2. Read the warning, change an option and **Save**.<br>3. Delete the poll and confirm "Delete this poll?". | A warning shows "Saving will clear the N existing vote(s) on this poll."<br>After saving, votes are 0.<br>After delete, the poll is gone. | Low | Functional | | |  |
| TC-ITIN-013 | TS-ITIN-006 | Add, tick and remove a packing item | Generated Itinerary | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>A saved trip is open. | Item: `Sunscreen` | 1. In **Packing Checklist** tap **Add Item**.<br>2. Enter `Sunscreen` and tap **Add**.<br>3. Tick the item as packed.<br>4. Remove it and confirm "Remove this item?". | The item appears in the list.<br>Ticking updates the counter on the trip card in Saved Trips ("x/y packed").<br>After removal the item disappears. | Low | Functional | | |  |
| TC-ITIN-014 | TS-ITIN-007 | Share a trip and download it | Generated Itinerary | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>A saved trip is open. | — | 1. Tap **Share** and read the share sheet; cancel it.<br>2. Tap **Download**.<br>3. Open the downloaded file with a PDF viewer (if available). | The system share sheet opens with the trip text.<br>A file (PDF) is created/offered and opens with the trip day plan. | Medium | Integration | | | Needs manual verification of exact file format and where it is saved per platform. |
| TC-ITIN-015 | TS-ITIN-007 | Set trip reminders (travel day and packing) | Generated Itinerary | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>A saved trip has a future start date; notification permission allowed. | Date: today or a later day<br>Time: a few minutes from now (first try) and an earlier time today (second try) | 1. Tap **Remind**.<br>2. In the sheet choose **Travel Day Reminder** (or **Packing Reminder**).<br>3. Pick the date, then the time (a few minutes from now).<br>4. Wait for the time to arrive.<br>5. Repeat and pick a time earlier today. | A message "Travel day reminder set." (or "Packing reminder set.") appears.<br>A notification arrives at about the chosen time (it may be a few minutes late because the alarm is inexact).<br>For the earlier time today the message "Pick a time in the future." appears and no reminder is scheduled. | Medium | Functional | | | Fixed in code: reminder_picker.dart now rejects past times. Still needs a device check on Android 13+ and iOS. |
| TC-ITIN-016 | TS-ITIN-007 | Save a trip for offline use | Generated Itinerary | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>A saved trip is open. | — | 1. Tap **Save for Offline** (in the trip actions or on the trip card).<br>2. Wait for "This trip is now available offline."<br>3. Turn the internet OFF, close and reopen the app.<br>4. Open **Saved Trips** and open that trip. | The message "This trip is now available offline." appears (or ""<trip>" is now available offline." on the list).<br>Offline, the trip and its images still open; the offline banner shows. | Medium | Interruption/Recovery | | | Images are pre-cached; other live data (weather, maps) is expected to be unavailable. |
| TC-ITIN-017 | TS-ITIN-008 | Mark a trip as completed — rules | Generated Itinerary | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Trip A has no start date; Trip B starts in the future; Trip C started yesterday. | — | 1. Open Trip A and try to mark it completed.<br>2. Open Trip B and try to mark it completed.<br>3. Open Trip C, mark it completed and confirm "Mark this trip as completed?". | Trip A: "Set a travel date for this trip before marking it completed."<br>Trip B: "This trip starts <date> — you can mark it completed once it's underway."<br>Trip C: marked completed (a "Completed" label appears in Saved Trips). | Medium | Validation | | |  |
| TC-ITIN-018 | TS-ITIN-008 | Change the start date of a completed trip | Generated Itinerary | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>A completed trip exists. | — | 1. Open the trip and change its start date to a date in the future. | The message "Unmarked as completed — the new date is still upcoming." appears and the trip is no longer completed. | Low | Functional | | |  |

## Saved Trips & Sharing

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-TRIP-001 | TS-TRIP-001 | View, duplicate and remove a saved trip | Saved Trips & Sharing | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The traveler owns one saved trip. | — | 1. Open **Profile** > **My Trips** (Saved Trips).<br>2. Choose **Duplicate** on the trip.<br>3. Choose remove on the duplicated trip and confirm "Remove this trip?".<br>4. Remove the original trip too. | A message `"<trip title>" duplicated.` appears and there are two trips.<br>Removed trips disappear from the list.<br>After the last removal the empty state "No saved trips yet" is shown. | High | Functional | | |  |
| TC-TRIP-002 | TS-TRIP-002 | Join a shared trip with a valid code | Saved Trips & Sharing | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>Traveler A owns a saved trip and has its code (from **Invite** in Trip Companions).<br>Traveler B is signed in on another device/account. | — | 1. On Traveler B's device open **Saved Trips** and tap the "Join a shared trip" icon.<br>2. In "Join a Shared Trip" paste the code into "Trip code".<br>3. Tap **Join**. | A message `Joined "<trip title>".` appears.<br>The trip is listed for Traveler B and B can view it and edit shared parts such as expenses/packing.<br>Traveler B appears under Trip Companions on A's trip. | High | Functional | | |  |
| TC-TRIP-003 | TS-TRIP-002 | Join with a wrong or empty code | Saved Trips & Sharing | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The join dialog is open. | Code: `WRONG123` | 1. Tap **Join** with the code box empty.<br>2. Enter `WRONG123` and tap **Join**. | Empty: nothing is joined (no crash).<br>Wrong code: "No trip found with that code." | Medium | Negative | | |  |
| TC-TRIP-004 | TS-TRIP-002 | Join a trip the user already has | Saved Trips & Sharing | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Traveler owns a trip and knows its own code. | — | 1. Open the join dialog and enter the code of the traveler's OWN trip (or a trip already joined).<br>2. Tap **Join**. | "You already have access to this trip." is shown.<br>No duplicate entry is created. | Medium | Negative | | |  |
| TC-TRIP-005 | TS-TRIP-002 | Collaborator leaves a shared trip | Saved Trips & Sharing | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>Traveler B has joined Traveler A's trip. | — | 1. On B's device open the trip and choose to leave it; confirm "Leave this trip?".<br>2. Check A's trip. | The trip disappears from B's list.<br>A's trip still exists and B is no longer a companion. | Low | Functional | | |  |
| TC-TRIP-006 | TS-TRIP-003 | Trip calendar | Saved Trips & Sharing | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>A saved trip has a start date this month. | — | 1. Open the trip calendar icon on the Saved Trips screen.<br>2. Look at the trip's date range.<br>3. Go to the previous/next month. | The "Trip Calendar" screen shows the trip on the correct dates.<br>Changing months works without errors. | Low | Functional | | | Needs manual verification of month navigation controls. |

## AI Travel Assistant

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-CHAT-001 | TS-CHAT-001 | Send a message using a suggested prompt | AI Travel Assistant | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>A brand-new chat (no messages). | — | 1. Open the AI chat from the app (AI Travel Assistant).<br>2. Under "Try asking" tap **Plan a 2-day trip to Baguio**. | The 8 suggestion prompts are visible before the first message (e.g., "Recommend beaches in Cebu").<br>The tapped text appears as the user message, a typing indicator shows, then an assistant reply about Baguio appears.<br>The reply is readable formatted text; a multi-day answer may show a way to generate a full itinerary. | High | Functional | | |  |
| TC-CHAT-002 | TS-CHAT-002 | Type a message and send | AI Travel Assistant | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The chat screen is open. | Message: `Best food in Ilocos?` | 1. Tap the input box "Ask about destinations, food, budgets…".<br>2. Type the message.<br>3. Tap the send button. | The message is shown on the right side, the input box is cleared, and the assistant answers about Ilocos food. | High | Functional | | |  |
| TC-CHAT-003 | TS-CHAT-002 | Empty message and 1000-character limit | AI Travel Assistant | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The chat screen is open. | A 1001-character text (copy/paste) | 1. Tap send with the box empty (and with only spaces).<br>2. Paste the 1001-character text and look at the counter.<br>3. Send the message. | Nothing is sent for empty/space-only input.<br>The box accepts at most 1000 characters.<br>The 1000-character message is sent and answered (or a friendly error is shown). | Medium | Boundary | | |  |
| TC-CHAT-004 | TS-CHAT-004 | Ask an unrelated question | AI Travel Assistant | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The chat screen is open. | Message: `Write me a Python program to sort numbers.` | 1. Send the message. | The assistant politely redirects to Philippine travel planning and does not provide the program. | Low | Negative | | | AI output can vary. Judge by the intent of the system prompt (travel only). |
| TC-CHAT-005 | TS-CHAT-004 | Send a message while offline | AI Travel Assistant | The TripNest PH traveler app is installed and opens normally.<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The chat screen is open; internet OFF. | — | 1. Send any message.<br>2. Turn the internet ON.<br>3. Send a new message. | An error message bubble appears with friendly text (for example "No internet connection..." or "Something went wrong. Please try again."), with no codes or JSON.<br>After reconnecting, the next message gets a normal reply and the earlier error bubble is not treated as a question. | High | Interruption/Recovery | | |  |
| TC-CHAT-006 | TS-CHAT-003 | Chat history is kept after closing the app | AI Travel Assistant | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>A chat with at least 2 exchanges exists. | — | 1. Close the app completely and reopen it.<br>2. Open the AI Travel Assistant and the chats list (Chats icon). | The earlier chat is listed and its messages are intact. | Medium | Interruption/Recovery | | | History is stored locally per device (SharedPreferences), so it will not appear on another device. |
| TC-CHAT-007 | TS-CHAT-003 | Start a new chat, switch chats, delete a chat | AI Travel Assistant | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>At least one existing chat. | — | 1. Tap the **Chats** icon and start a new chat.<br>2. Send one message in the new chat.<br>3. Open **Chats** again and switch to the older chat.<br>4. Delete the new chat using its delete icon and confirm "Delete this chat?". | A new empty chat opens (title "New Chat" until the first message).<br>Switching shows each chat's own messages.<br>Delete confirmation says "This conversation will be permanently deleted." and the chat is removed from the list. | Medium | Functional | | |  |
| TC-CHAT-008 | TS-CHAT-003 | Chat history limits (30 chats, 60 messages) | AI Travel Assistant | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>A tester willing to create 31 chats (or edit the stored data). | — | 1. Create 31 chats with one message each.<br>2. Open the Chats list and count them.<br>3. In one chat send more than 60 messages in total. | Only the 30 most recent chats are kept; the oldest is removed.<br>A single chat keeps only its last 60 messages. | Low | Boundary | | | Time-consuming; limits come from ai_chat_provider.dart (_maxSessions = 30, _maxStoredMessages = 60). |
| TC-CHAT-009 | TS-CHAT-001 | Location-based question with and without permission | AI Travel Assistant | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The chat is open. | Message: `Hotels near me` | 1. With location permission DENIED, send the message.<br>2. Allow location permission and send it again. | Without location: the assistant says it does not have the user's location and suggests enabling location access.<br>With location: it recommends real nearby places by name with links. | Low | Functional | | | Needs manual verification: how/when the chat asks for location permission. |
| TC-CHAT-010 | TS-CHAT-001 | Generate Full Itinerary from a chat plan | AI Travel Assistant | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The chat screen is open. | Message: `Plan a 2-day trip to Baguio` | 1. Send the message and wait for a multi-day answer.<br>2. Under the assistant reply tap **Generate Full Itinerary**. | A loading state is shown, then the generated itinerary screen opens for Baguio with the default settings (Van / Car Rental, Beaches + Food interests).<br>If generation fails, a friendly error message is shown and the chat stays open. | Medium | Integration | | | Button only appears when the reply follows the multi-day plan format. Default values come from planner_options.dart. |

## Profile

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-PROF-001 | TS-PROF-001 | View the Profile screen | Profile | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234). | — | 1. Tap the **Profile** tab.<br>2. Look at the header, statistics and menu items. | The traveler's name, email and photo (or initials) are shown.<br>Shortcuts include **My Trips**, **Reviews**, **Saved**, **Notifications**, **Edit Profile**, **Settings** and **Log Out**.<br>The **Travel Preferences** section shows the traveler's choices. | Medium | Functional | | |  |
| TC-PROF-002 | TS-PROF-002 | Update the full name | Profile | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234). | New name: `Maria S. Santos` | 1. Open **Profile** > **Edit Profile**.<br>2. Change **Full Name** to the new name.<br>3. Tap **Save Changes**. | A message "Profile updated." appears.<br>Profile shows the new name.<br>Reopening the app still shows the new name. | High | Functional | | |  |
| TC-PROF-003 | TS-PROF-003 | Full Name validation | Profile | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The Edit Profile screen is open. | Empty<br>`A`<br>61 characters | 1. Clear the Full Name field and tap **Save Changes**.<br>2. Enter `A` and tap **Save Changes**.<br>3. Paste 61 characters. | Empty: "Name is required".<br>`A`: "Name is too short".<br>The field accepts at most 60 characters (counter shows 60).<br>Nothing is saved while an error shows. | Medium | Validation | | |  |
| TC-PROF-004 | TS-PROF-002 | Save with no changes | Profile | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Edit Profile just opened; nothing changed. | — | 1. Tap **Save Changes** without changing anything. | A message "Nothing to save." appears; no write is made. | Low | Negative | | |  |
| TC-PROF-005 | TS-PROF-002 | Change travel preferences and favorite categories | Profile | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Edit Profile is open. | — | 1. Select or unselect chips under **Travel Preferences** and **Favorite Categories**.<br>2. Tap **Save Changes**.<br>3. Close and reopen Edit Profile. | "Profile updated." appears.<br>The same chips are selected when the screen is reopened.<br>Home/Explore suggestions may reflect the chosen interests. | Medium | Functional | | |  |
| TC-PROF-006 | TS-PROF-003 | Upload a new profile photo | Profile | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Gallery permission allowed; a JPG/PNG under 5 MB is available. | — | 1. On Edit Profile tap the camera icon on the avatar.<br>2. Pick a photo from the gallery.<br>3. Wait for the upload indicator to finish. | A loading indicator is shown on the avatar while uploading.<br>The new photo replaces the old avatar on Edit Profile and Profile.<br>The old uploaded photo file is removed from storage (best effort). | Medium | Functional | | |  |
| TC-PROF-007 | TS-PROF-003 | Profile photo — permission denied, oversize and offline | Profile | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Edit Profile is open; a photo larger than 5 MB is available. | — | 1. With Photos permission denied, tap the camera icon.<br>2. Allow the permission, pick the photo larger than 5 MB.<br>3. Turn off the internet and pick a normal photo. | Denied: a permission message (e.g., "Permission was denied. Please allow access in your device settings and try again.") or no picker; no crash.<br>Large photo: the picker shrinks it (max width 800 px, quality 85) before upload, so it uploads normally and the new avatar shows.<br>Offline: "No internet connection. Please check your network and try again." and the old photo remains. | Medium | Negative | | | Code trace: edit_profile_screen.dart resizes the image, so the 5 MB Storage limit is rarely reached from this screen. |
| TC-PROF-008 | TS-PROF-004 | Change email — validation and wrong password | Profile | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Edit Profile > Security is visible. | New Email: `tester01.new@example.com`<br>Wrong password: `Wrong123` | 1. Tap **Update Email**.<br>2. Enter `abc@` as New Email and the correct password; confirm.<br>3. Enter the valid new email with the wrong password `Wrong123`; confirm. | Invalid format: "Enter a valid email address".<br>Wrong password: "Incorrect email or password." (re-authentication fails) and the email is not changed. | Medium | Negative | | |  |
| TC-PROF-009 | TS-PROF-004 | Change email — success | Profile | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The tester can read the new email inbox. | — | 1. Tap **Update Email**, enter the new email and the correct current password, then confirm.<br>2. Read the message on screen.<br>3. Open the new inbox and click the confirmation link.<br>4. Reopen the app and sign in with the new email. | A message "Check your new email to confirm the change." appears; the current email still works until confirmed.<br>After clicking the link the new email becomes the sign-in email and Profile shows it. | Medium | Integration | | | The Firestore profile email updates the next time the app runs while signed in. |
| TC-PROF-010 | TS-PROF-005 | Recently Viewed list | Profile | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The tester opened 2 destination details screens. | — | 1. Open **Profile** > **Recently Viewed**.<br>2. Tap one item.<br>3. Later use Settings > **Clear Recently Viewed** and reopen the list. | The viewed places are listed (most recent first).<br>Tapping opens the details screen.<br>After clearing, the state "Nothing viewed yet" is shown. | Low | Functional | | |  |
| TC-PROF-011 | TS-PROF-005 | My Reviews list | Profile | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The traveler wrote at least one review (TC-REV-001). | — | 1. Open **Profile** > **Reviews** (My Reviews).<br>2. Use an account with no reviews and open the same screen. | The written reviews are listed with rating, comment and place.<br>An account with no reviews shows "No reviews yet". | Medium | Functional | | |  |

## Settings

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-SET-001 | TS-SET-001 | Dark mode, theme, font and text size | Settings | The TripNest PH traveler app is installed and opens normally.<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The Settings screen is open. | — | 1. Turn **Dark Mode** on.<br>2. Tap **Theme** and select another accent color.<br>3. Tap **Font Style** and select another font.<br>4. Tap **Text Size** and choose the largest size.<br>5. Close and reopen the app. | Each option changes the look of the whole app immediately.<br>The chosen values are still applied after the app restarts.<br>Text at the largest size does not overflow or get cut off on Home and Settings. | Medium | Functional | | |  |
| TC-SET-002 | TS-SET-002 | Notification switches | Settings | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The Settings screen is open. | — | 1. Turn the **Notifications** switch OFF and look at the category rows.<br>2. Turn it ON and turn OFF one category (e.g., Travel Tips).<br>3. Close and reopen Settings. | With the master switch OFF, the category rows are dimmed and cannot be tapped.<br>The chosen category stays OFF after reopening Settings.<br>The note "Emergency alerts and maintenance notices can't be turned off." is shown; those categories have no switch. | Medium | Functional | | |  |
| TC-SET-003 | TS-SET-002 | Location Services switch and permission states | Settings | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Location permission not yet granted. | — | 1. Turn **Location Services** ON and choose **Deny** in the system dialog.<br>2. Turn it ON again and choose **Allow**.<br>3. Deny permanently in system settings, then turn it ON in the app. | After a plain Deny the app does not crash. The switch stays ON and no message is shown (the code only saves the preference).<br>After Allow the switch stays ON.<br>When location is permanently denied or the phone's location service is off, the message "Location access is off at the system level. Enable it in your device settings." appears with an **Open Settings** button that opens the system settings. | High | Negative | | | Code trace: the switch is not turned back OFF after a plain Deny, and Home still shows the "Allow Location" card. Record whether this is acceptable. |
| TC-SET-004 | TS-SET-003 | Change password from Settings | Settings | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The traveler signed in with email and password `Test@1234`. | Wrong current: `Wrong123`<br>Too short new: `Ab@1234`<br>Valid new: `NewPass@123` | 1. Tap **Change Password**.<br>2. Leave Current Password empty and tap confirm.<br>3. Enter the wrong current password with a valid new one.<br>4. Enter the correct current password with the too-short new password.<br>5. Enter the correct current password with the valid new password. | Empty: "Current password is required".<br>Wrong current: "Incorrect email or password." and no change.<br>Too short: "Password must be at least 8 characters".<br>Valid: a message "Password updated." appears and the new password works at the next login. | High | Functional | | |  |
| TC-SET-005 | TS-SET-004 | Delete account — wrong password and cancel | Settings | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Use a throw-away account. | — | 1. Tap **Delete Account**.<br>2. In "Confirm Your Password" leave the password empty and confirm.<br>3. Enter a wrong password and confirm.<br>4. Cancel the dialog. | Empty: "Current password is required".<br>Wrong: an error message is shown (e.g., "Incorrect email or password.") and the account remains.<br>Cancel keeps the account. | High | Negative | | |  |
| TC-SET-006 | TS-SET-004 | Delete account — success and data cleanup | Settings | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A throw-away account with 1 review, 1 favorite, 1 saved trip and 1 notification. | — | 1. Tap **Delete Account**.<br>2. Enter the correct password and confirm **Delete Account**.<br>3. Try to log in again with the same email and password.<br>4. In the Firebase console (or Admin Portal) check the user, review, favorite and trip data. | The app returns to Login after deletion.<br>Login fails ("Incorrect email or password.").<br>The user's reviews, notifications, favorites, saved trips and profile are removed; the Auth user is deleted. | High | Functional | | | Code trace: deletion removes reviews, notifications, favorites, saved trips, visited/recently viewed and the profile. It does NOT remove `businesses`, `business_owner_applications` or `admin_users` documents, so a business owner's listing stays after account deletion. Record this as a known gap. |
| TC-SET-007 | TS-SET-004 | Delete account interrupted by lost internet | Settings | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A throw-away account with 3 reviews and 3 favorites. | — | 1. Start **Delete Account** with the correct password.<br>2. Turn the internet OFF right after confirming.<br>3. Turn the internet ON, sign in again (if still possible) and check reviews/favorites. | A friendly error message is shown.<br>The account is not left half-deleted with a working login and missing data unnoticed: either the account can still be used (and the tester can retry deletion) or it is fully deleted. | Medium | Interruption/Recovery | | | Data is removed step by step and the Auth user last, so a failure can leave partial data. Record exactly what remains. |
| TC-SET-008 | TS-SET-005 | Legal pages, FAQ and What's New | Settings | The TripNest PH traveler app is installed and opens normally.<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The Settings screen is open. | FAQ search text: `zzzz` | 1. Open the Privacy, Terms and About pages from Settings.<br>2. Open **FAQ** and expand one question; type `zzzz` in the search box.<br>3. Open **What's New**. | Each page opens with readable text ("Last updated: September 2026" on legal pages; "Version 1.0.0" on About).<br>FAQ expands questions and shows "No matches" for `zzzz`.<br>What's New lists the release notes. | Low | Functional | | |  |

## Notifications

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-NOTIF-001 | TS-NOTIF-001 | View and read notifications | Notifications | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>An admin sent an announcement (TC-ADM-016) to all travelers. | — | 1. Open **Profile** > **Notifications**.<br>2. Find the announcement and tap it. | The announcement is listed with its title and text.<br>After tapping, the unread indicator is removed.<br>It stays read after leaving and reopening the screen. | Medium | Functional | | |  |
| TC-NOTIF-002 | TS-NOTIF-001 | Notifications empty state | Notifications | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A new traveler account with no notifications. | — | 1. Open the Notifications screen. | An empty state (title beginning "You're ...") is shown instead of a blank page. | Low | Functional | | |  |
| TC-NOTIF-003 | TS-NOTIF-002 | Push notification permission prompt | Notifications | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>Fresh install; notification permission not yet decided; a real device. | — | 1. Sign in for the first time.<br>2. When the system asks to allow notifications choose **Allow**.<br>3. Repeat on another install and choose **Don't allow**. | Allow: the app can receive push notifications.<br>Don't allow: the app works normally, only pushes are not shown. | Medium | Functional | | |  |
| TC-NOTIF-004 | TS-NOTIF-002 | Push notification while app is in background, closed, and locked screen | Notifications | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Notification permission allowed; an admin ready to send an announcement. | — | 1. Put the app in the background and send an announcement from the Admin Portal.<br>2. Close the app fully and send another one.<br>3. Lock the screen and send a third one.<br>4. Unlock and open the notification. | A system notification with the announcement title/text appears in each case.<br>Tapping it opens the app; the announcement is visible in the Notifications list. | Medium | Integration | | | Delivery relies on FCM and the sendPushOnNotificationCreated Cloud Function. |
| TC-NOTIF-005 | TS-NOTIF-002 | Category switch blocks non-emergency push | Notifications | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>In Settings the **Travel Tips** category is turned OFF. | — | 1. Send an announcement with category Travel Tip from the Admin Portal.<br>2. Send another with category Emergency Alert. | The Travel Tip announcement is hidden from this traveler's in-app Notifications list.<br>The Emergency Alert is still shown in the list (it cannot be switched off). | Low | Functional | | | Code trace: only the in-app list is filtered (notifications_screen.dart). A system push for a switched-off category may still be shown by the phone. |
| TC-NOTIF-006 | TS-NOTIF-001 | Notifications when signed out / offline | Notifications | The TripNest PH traveler app is installed and opens normally.<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Notifications screen opened at least once; internet OFF. | — | 1. Turn the internet OFF.<br>2. Open the Notifications screen. | Previously loaded notifications (cached) or a friendly error state is shown; no technical text. | Low | Interruption/Recovery | | | The sign-in message ("Sign in to view your notifications.") is only for signed-out users and is not normally reachable. |

## Business Owner

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-BIZ-001 | TS-BIZ-001 | Submit a Business Owner application | Business Owner | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>Signed in with a new unverified/verified traveler on the **Business Owner Application** screen (from TC-REG-002). | Business name: `Sunset Bay Resort`<br>Category: `Accommodation`<br>Contact phone: `+63 917 123 4567`<br>Description: `Beachfront resort with 12 rooms and a restaurant.` | 1. Fill in the form with the test data.<br>2. Tap **Submit Application**.<br>3. On the "Application submitted" screen tap **Continue**. | The button shows a loading state while saving.<br>A screen titled "Application submitted" is shown.<br>**Continue** opens Verify Email (or the app if already verified).<br>The application appears with status Pending in the Admin Portal **Business Applications** list. | High | Functional | | |  |
| TC-BIZ-002 | TS-BIZ-002 | Application validation | Business Owner | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The Business Owner Application form is open. | Phone cases: empty, `12345`, `abc12345`, `+63 917 123 4567`<br>Description: 1001 characters | 1. Tap **Submit Application** with the name empty.<br>2. Enter a name and test each phone value.<br>3. Paste a 1001-character description. | Name: "Business name is required".<br>Phone empty: "This field is required"; `12345` and `abc12345`: "Enter a valid phone number"; the last value is accepted.<br>Description: "Description must be 1000 characters or fewer". | High | Validation | | |  |
| TC-BIZ-003 | TS-BIZ-002 | Skip the application with the back arrow | Business Owner | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>Business Owner Application screen opened right after registration. | — | 1. Tap the back arrow at the top left. | The app goes to Verify Email; no application is stored. | Low | Functional | | |  |
| TC-BIZ-004 | TS-BIZ-003 | Accept the Business Owner role invite | Business Owner | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The traveler's application was approved in the Admin Portal (invite staged) for this email. | — | 1. Sign in as the traveler and open **Profile**.<br>2. Find the invitation and tap **Accept**.<br>3. Confirm "Accept this role?".<br>4. Look at the bottom navigation. | The message "Welcome to the Admin Portal." (or similar) appears.<br>The 4th tab changes from **Saved** to **My Business** and the Home tab shows the business Dashboard.<br>An **Admin Portal** link/label is available on Profile. | High | Functional | | |  |
| TC-BIZ-005 | TS-BIZ-003 | Decline the invite | Business Owner | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A pending invite exists for the traveler. | — | 1. On **Profile** tap **Decline** and confirm "Decline this invite?". | The dialog says "You can be invited again later if you change your mind."<br>The invite disappears; the traveler keeps the normal tabs (Saved, Home). | Medium | Functional | | |  |
| TC-BIZ-006 | TS-BIZ-004 | Create and submit a Food & Dining listing | Business Owner | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The signed-in traveler has an active Business Owner role (accepted invite) — example: owner01@example.com.<br>No listing exists yet; a listing photo and a permit photo (< 10 MB) are available. | Name: `Lola Cely Kitchen`<br>Category: `Food & Dining`<br>Cuisine: `Filipino`<br>Price range: `₱₱`<br>Opening hours: `9:00 AM – 9:00 PM`<br>Description: `Home-style Filipino dishes.`<br>Province: any<br>Address: `12 Rizal St., Poblacion`<br>Phone: `0917 555 1234`<br>Website: `https://lolacely.example.com` | 1. Open **My Business** and start the listing (**Set Up My Business**).<br>2. Fill all sections: Basic Information, Location & Contact, Accessibility, Verification.<br>3. Upload the listing photo and the "Business Permit / DTI Registration" photo.<br>4. Tap the submit button. | The message "Listing submitted for review." appears.<br>A status banner shows the listing is pending review.<br>The listing is not visible to travelers until an admin approves it. | High | Functional | | |  |
| TC-BIZ-007 | TS-BIZ-005 | Listing required fields and limits | Business Owner | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The signed-in traveler has an active Business Owner role (accepted invite) — example: owner01@example.com.<br>The listing form is open and empty; category is Food & Dining. | Website: `www.example.com`<br>Description: 3001 characters<br>Phone: `12345` | 1. Tap submit with everything empty.<br>2. Fill the name and other text fields but leave Province empty; tap submit.<br>3. Choose a province but no listing photo; tap submit.<br>4. Enter the test website, phone and long description. | Name: "Name is required"; Cuisine: "Cuisine is required"; Opening hours: "Opening hours is required"; Description: "Description is required"; Address: "Address is required"; Phone: "This field is required".<br>No province: "Province is required."<br>No photo: "Please upload a photo for your listing."<br>Website without http/https: "Enter a valid URL (starting with http:// or https://)".<br>Phone `12345`: "Enter a valid phone number".<br>Description over 3000: "Description must be 3000 characters or fewer". | High | Validation | | |  |
| TC-BIZ-008 | TS-BIZ-005 | Add a menu/catalog item | Business Owner | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The signed-in traveler has an active Business Owner role (accepted invite) — example: owner01@example.com.<br>The listing form is open. | Item name: `Adobo`<br>Price: `180` | 1. Tap the **Add** item button (label depends on the category, e.g., "Add Menu Item").<br>2. Tap **Add** with all fields empty.<br>3. Enter the name and price but no photo; tap **Add**.<br>4. Add a photo and tap **Add**. | Empty: name required ("<Item> name is required") and price required ("Price is required").<br>No photo: "Add a photo for this item."<br>With all data the item is added to the list. | Medium | Validation | | |  |
| TC-BIZ-009 | TS-BIZ-006 | Submit without a permit photo | Business Owner | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The signed-in traveler has an active Business Owner role (accepted invite) — example: owner01@example.com.<br>All required listing fields are filled; no permit photo uploaded. | — | 1. Tap submit.<br>2. Read the "Submit without a permit photo?" dialog, tap cancel.<br>3. Tap submit again and choose **Submit Anyway**. | The dialog explains a permit or DTI photo speeds up approval.<br>Cancel keeps the form open with no submission.<br>Submit Anyway submits the listing ("Listing submitted for review."). | High | Functional | | |  |
| TC-BIZ-010 | TS-BIZ-006 | Permit upload triggers OCR shown to admin | Business Owner | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The signed-in traveler has an active Business Owner role (accepted invite) — example: owner01@example.com.<br>A clear photo of a printed permit (< 10 MB). | — | 1. Upload the permit photo and submit the listing.<br>2. Wait about 30 seconds.<br>3. In the Admin Portal open **Businesses** and view that listing.<br>4. Open a traveler account and look at the same business (after approval). | Submission succeeds even if OCR is slow or fails.<br>The admin sees the permit photo and the extracted text labeled as a reading aid ("verify against the actual photo").<br>The traveler app never shows the permit photo or the OCR text. | High | Security | | |  |
| TC-BIZ-011 | TS-BIZ-006 | Permit photo — non-image and over 10 MB | Business Owner | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The signed-in traveler has an active Business Owner role (accepted invite) — example: owner01@example.com.<br>A 12 MB image and a PDF/text file are available on the device. | — | 1. Try to select the PDF as the permit photo (if the picker allows).<br>2. Select the 12 MB image. | Non-image: not selectable or rejected with a friendly message.<br>Over 10 MB: the upload fails with a friendly message such as "You don't have permission to do that." and no technical text. | Medium | Negative | | | Rule: images only, under 10 MB for permits (storage.rules). |
| TC-BIZ-012 | TS-BIZ-007 | Rejected listing — reason shown and resubmit | Business Owner | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The signed-in traveler has an active Business Owner role (accepted invite) — example: owner01@example.com.<br>An admin rejected the listing with reason `Photo is blurry`. | — | 1. Open **My Business**.<br>2. Read the banner.<br>3. Change the photo and tap **Edit & Resubmit**. | Banner: "Rejected: Photo is blurry — Edit and resubmit below."<br>After resubmitting the listing returns to pending review. | High | Functional | | |  |
| TC-BIZ-013 | TS-BIZ-007 | Suspended listing and Contact Support | Business Owner | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The signed-in traveler has an active Business Owner role (accepted invite) — example: owner01@example.com.<br>An admin suspended the listing with a reason. | — | 1. Open **My Business**.<br>2. Tap **Contact Support**. | The banner shows the suspension and reason.<br>An email app opens to support@tripnestph.app with subject "Suspended listing: <name>"; if no email app exists, the message "Email support@tripnestph.app for help with this listing." is shown. | Medium | Functional | | |  |
| TC-BIZ-014 | TS-BIZ-004 | Leave the listing form with unsaved changes | Business Owner | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The signed-in traveler has an active Business Owner role (accepted invite) — example: owner01@example.com.<br>The listing form is open with changes typed and not saved. | — | 1. Press Back or switch to another tab. | A prompt about discarding unsaved changes appears; staying keeps the typed data, leaving discards it. | Low | Usability | | | Needs manual verification of the exact dialog text (DiscardChangesScope). |
| TC-BIZ-015 | TS-BIZ-008 | Business dashboard statistics | Business Owner | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The signed-in traveler has an active Business Owner role (accepted invite) — example: owner01@example.com.<br>An approved listing that has been viewed, reviewed and favorited by other travelers. | — | 1. Open the **Home** tab as the business owner (Dashboard).<br>2. Open the listing as a traveler and add it to Saved; then refresh the dashboard. | The dashboard shows **Views**, **Rating**, **Reviews** and **Favorited** counters that match the real data.<br>A user without a listing sees "No listing yet" and **Set Up My Business**.<br>**Manage Listing** opens My Business. | Medium | Functional | | |  |
| TC-BIZ-016 | TS-BIZ-004 | Submit listing while offline / interrupted | Business Owner | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The signed-in traveler has an active Business Owner role (accepted invite) — example: owner01@example.com.<br>A fully filled listing form. | — | 1. Tap submit and turn the internet OFF at once.<br>2. Read the message.<br>3. Turn the internet ON and open My Business.<br>4. Submit again if the form is still shown. | A friendly message appears (no technical text).<br>After recovery only ONE listing exists for the owner. | High | Interruption/Recovery | | |  |

## Admin Portal – Access & Roles

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-ADM-001 | TS-ADM-001 | Admin Portal login | Admin Portal – Access & Roles | Admin Portal site/build is open in a browser.<br>A verified admin account exists (created with tool/create_admin.js or accepted invite). | Email: `admin01@example.com`<br>Password: `Admin@1234` | 1. Look at the Login page for a "Sign Up" link.<br>2. Enter the admin email and password.<br>3. Tap **Sign In**. | The Login page has no "Don't have an account? Sign Up" row (Forgot Password? is still available).<br>After sign-in the **Admin Overview** (admin home) opens with the side menu and the admin name and role at the bottom. | High | Functional | | |  |
| TC-ADM-002 | TS-ADM-001 | Account without an Admin Portal role | Admin Portal – Access & Roles | Admin Portal is open.<br>A verified traveler account with NO admin role exists (tester01@example.com). | — | 1. Sign in to the Admin Portal with the traveler account.<br>2. Look at the page that opens (`/admin`).<br>3. Try to open `/admin/team` and `/admin/users` by typing the address in the browser. | `/admin` shows "No access" with the text "This account doesn't have an active Admin Portal role." and no side-menu items.<br>On the other admin addresses no traveler, team or business data is displayed (the database rules block the reads); an empty or friendly error state such as "You don't have permission to do that." is acceptable. | High | Security | | | Code trace: only AdminHomeScreen shows the "No access" state. The other admin screens have no role check of their own and rely on Firestore rules. Consider adding a guard. Also try the same addresses on the traveler web app. |
| TC-ADM-003 | TS-ADM-002 | Menu items by role | Admin Portal – Access & Roles | Three accounts: admin, LGU, business owner (all verified). | — | 1. Sign in as admin and list the side menu.<br>2. Sign out; sign in as LGU and list the menu.<br>3. Sign out; sign in as business owner and list the menu. | Admin: Provinces, Tourist Spots, Bulk Import, Festivals, Analytics, Travelers, Businesses, Business Applications, Reported Reviews, Send Announcement, Team.<br>LGU: Provinces, Tourist Spots, Bulk Import, Festivals, Analytics, Send Announcement (no Travelers, Businesses, Business Applications, Reported Reviews or Team).<br>Business Owner: My Business only. | High | Security | | | Code trace: firestore.rules lets admin and lgu create broadcast notifications, and its comment says this matches the Send Announcement tile. LGU access is intended. |
| TC-ADM-024 | TS-ADM-014 | Role revoked while a business owner is signed in | Admin Portal – Access & Roles | The signed-in traveler has an active Business Owner role (accepted invite) — example: owner01@example.com.<br>An admin is ready in another browser. | — | 1. Business owner stays on My Business.<br>2. The admin removes or suspends that owner in **Team**.<br>3. Watch the owner's device for up to one minute. | The owner is signed out automatically and must sign in again; after signing in they no longer have owner access. | High | Security | | |  |
| TC-ADM-025 | TS-ADM-014 | Admin save interrupted by lost internet | Admin Portal – Access & Roles | The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).<br>The tourist spot form is filled with valid data. | — | 1. Click save and disconnect the internet at the same moment.<br>2. Read the message.<br>3. Reconnect and check the Tourist Spots list.<br>4. Save again if the form is still open. | A friendly message appears with no technical text.<br>After recovery only ONE spot with that name exists. | Medium | Interruption/Recovery | | |  |

## Admin Portal – Business Approval

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-ADM-004 | TS-ADM-003 | Approve a business listing (with and without permit) | Admin Portal – Business Approval | The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).<br>Pending listing A has a permit photo; pending listing B has none. | — | 1. Open **Businesses**.<br>2. Tap approve on listing B and read the confirmation.<br>3. Cancel, then approve listing A and confirm "Approve this listing?".<br>4. Open the traveler app and look for listing A in its province page (Local Businesses). | For B the dialog warns that no permit photo was provided.<br>After approving A the message "Listing approved" appears and status becomes approved.<br>Listing A is now visible to travelers; a Food & Dining listing also appears in Restaurants. | High | Functional | | |  |
| TC-ADM-005 | TS-ADM-003 | Reject and suspend require a reason | Admin Portal – Business Approval | The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).<br>A pending listing and an approved listing exist. | Reject reason: `Photo is blurry`<br>Suspend reason: `Reported as closed` | 1. Tap **Reject** on the pending listing; try to confirm with the reason empty.<br>2. Enter `Photo is blurry` and confirm.<br>3. Tap **Suspend** on the approved listing with the reason `Reported as closed` and confirm.<br>4. Sign in as each owner and open **My Business**. | With an empty reason the Reject/Suspend button does nothing and the dialog stays open.<br>"Listing rejected" and "Listing suspended" messages appear.<br>Each owner sees the banner with the given reason.<br>The suspended listing is no longer visible to travelers. | High | Functional | | |  |
| TC-ADM-006 | TS-ADM-003 | Reactivate a suspended listing | Admin Portal – Business Approval | The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).<br>A suspended listing exists. | — | 1. Tap **Reactivate** and confirm "Reactivate this listing?".<br>2. Check the listing in the traveler app. | "Listing reactivated" is shown and the status returns to approved.<br>The listing is visible to travelers again. | Medium | Functional | | |  |
| TC-ADM-007 | TS-ADM-003 | Delete a business listing | Admin Portal – Business Approval | The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).<br>An approved Food & Dining listing with 1 review and 1 favorite exists. | — | 1. Tap delete on the listing.<br>2. Read the message `"<name>" will be permanently removed.` and confirm **Delete**.<br>3. Check the traveler app: Restaurants list, the Saved > Food tab, and search for the name. | The listing disappears from the admin list.<br>The mirrored restaurant, its reviews and favorites are gone from the traveler app; no broken (blank) card remains. | High | Functional | | |  |
| TC-ADM-008 | TS-ADM-004 | Approve a Business Owner application | Admin Portal – Business Approval | The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).<br>A pending application from `juan.owner.test01@example.com` exists (TC-BIZ-001). | — | 1. Open **Business Applications**.<br>2. Read the entry (name · email).<br>3. Tap **Approve** and confirm "Approve this application?".<br>4. Sign in to the traveler app as that user and open Profile. | The application leaves the pending list.<br>The traveler sees an invitation to accept (TC-BIZ-004); the role is active only after acceptance. | High | Functional | | |  |
| TC-ADM-009 | TS-ADM-004 | Reject a Business Owner application | Admin Portal – Business Approval | The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).<br>A pending application exists. | Reason: `Incomplete business information` | 1. Tap **Reject** on the application.<br>2. In "Reject this application?" type the reason (placeholder "Tell the applicant why...").<br>3. Confirm **Reject**. | The application is marked rejected and leaves the pending list.<br>The empty state "No pending applications" shows when none remain. | Medium | Functional | | | Needs manual verification of what the applicant sees for a rejected application. |

## Admin Portal – Team & Travelers

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-ADM-010 | TS-ADM-005 | Invite team members and validation | Admin Portal – Team & Travelers | The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).<br>Traveler account `newadmin@example.com` exists; `noaccount@example.com` does not. | — | 1. Open **Team** > **Invite to Admin Portal**.<br>2. Enter `abc@` as Email and try to send.<br>3. Enter `newadmin@example.com`, select Role **LGU Officer** and try to send without a province.<br>4. Select a province, tap **Send Invite** and confirm "Invite <email>?".<br>5. Invite `noaccount@example.com` as **Admin**. | Invalid email: "Enter a valid email address".<br>LGU Officer requires a province ("Which province will they manage?").<br>After confirming, "Invite sent." appears and the invite is listed under **Pending Invites**.<br>The invite for an email without a TripNest account is created but cannot be accepted until that person registers. | High | Functional | | | Roles offered: Admin, LGU Officer, Business Owner. |
| TC-ADM-011 | TS-ADM-005 | Revoke an invite and remove an admin | Admin Portal – Team & Travelers | The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).<br>One pending invite and one other active admin exist. | — | 1. Tap **Revoke** on the invite and confirm "Revoke this invite?".<br>2. Tap **Remove** on the other admin and confirm "Remove this admin?".<br>3. Sign in as the removed user and open the Admin Portal. | The invite disappears and that email will no longer be offered the role.<br>The removed admin loses access immediately and sees "No access" (or is signed out); their traveler account still works. | High | Security | | |  |
| TC-ADM-012 | TS-ADM-006 | Search, suspend and reactivate a traveler | Admin Portal – Team & Travelers | The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).<br>Traveler `tester01@example.com` exists. | — | 1. Open **Travelers** and type `tester01` in "Search by name or email".<br>2. Choose **Suspend** and confirm "Suspend this account?".<br>3. Try to sign in to the traveler app with that account.<br>4. Choose **Reactivate** and confirm.<br>5. Sign in to the traveler app again. | The search narrows the list to the matching traveler.<br>After suspend the list shows "· suspended" and a message "<name> suspended." appears; the traveler cannot use the app (see TC-LOGIN-011).<br>After reactivate the traveler can sign in normally.<br>**Load more** appears when the list is longer than one page. | High | Security | | |  |

## Admin Portal – Content

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-ADM-013 | TS-ADM-007 | Create a tourist spot | Admin Portal – Content | The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A province exists; a cover photo (< 5 MB) is available. | Name: `Sunset Viewpoint`<br>Category: any<br>Latitude: `16.4023`<br>Longitude: `120.5960`<br>Short Description: `A quiet hilltop with sunset views.`<br>Has Entrance Fee: ON, Amount: `50`<br>Phone: `0917 111 2222`<br>Website: `https://example.com` | 1. Open **Tourist Spots**, pick a province and tap add.<br>2. Fill in the form with the test data and upload the cover photo.<br>3. Save the spot.<br>4. Find the spot in the traveler app (Explore > Destinations). | A success message appears and the spot appears in the admin list.<br>The spot is visible in the traveler app with its photo, description and fee. | High | Functional | | |  |
| TC-ADM-014 | TS-ADM-007 | Tourist spot form validation and boundaries | Admin Portal – Content | The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).<br>The tourist spot form is open. | Latitude: `91`, `-91`, `abc`, `90`<br>Longitude: `181`, `180`<br>Short Description: 301 characters<br>Long Description: 5001 characters<br>Entrance fee: `0`, `100001`, `100000`<br>Website: `example.com`<br>Phone: `123` | 1. Leave Name empty and save.<br>2. Enter each test value in its field and save; note the messages. | Name: "Name is required".<br>Latitude `91`/`-91`: "Latitude must be between -90 and 90"; `abc`: "Enter a valid latitude"; `90` accepted.<br>Longitude `181`: "Longitude must be between -180 and 180"; `180` accepted.<br>Short Description over 300: "Short Description must be 300 characters or fewer".<br>Long Description over 5000: "Long Description must be 5000 characters or fewer".<br>Fee `0`: "Amount must be greater than 0"; `100001`: "Amount must be ₱100000 or less"; `100000` accepted.<br>Website: "Enter a valid URL (starting with http:// or https://)"; Phone: "Enter a valid phone number".<br>Nothing is saved while an error shows. | High | Boundary | | |  |
| TC-ADM-015 | TS-ADM-007 | Edit and remove a tourist spot | Admin Portal – Content | The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).<br>An existing tourist spot. | — | 1. Open the spot for editing, change the Short Description and save.<br>2. Remove the spot and confirm "Remove this spot?". | The change is visible in the traveler app.<br>After removal the message `"<name>" removed.` appears and the spot no longer shows in the traveler app. | Medium | Functional | | |  |
| TC-ADM-018 | TS-ADM-008 | Create a festival and validation | Admin Portal – Content | The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).<br>The device is connected to the internet (Wi-Fi or mobile data).<br>The festival form is open. | Name: `Panagbenga Festival`<br>Date: a future date range<br>Description: 3001 characters | 1. Tap save with an empty form.<br>2. Enter the name only and save.<br>3. Choose a province but no date and save.<br>4. Choose the date; enter the 3001-character description and save.<br>5. Reduce the description to a normal text and save. | Name: "Name is required".<br>No province: "Province is required."<br>No date: "Date is required."<br>Description: "Description must be 3000 characters or fewer".<br>Final save: "Festival created." and the festival appears in the traveler app (Explore > Festivals). | High | Validation | | |  |
| TC-ADM-019 | TS-ADM-009 | Bulk import tourist spots from a valid CSV | Admin Portal – Content | The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A CSV with header `name,provinceId,categoryId,shortDescription` and 3 valid rows, using real province and category IDs. | — | 1. Open **Bulk Import**.<br>2. Tap **Choose CSV File** and select the file.<br>3. Read the preview counts.<br>4. Start the import and wait for "Importing x/y...".<br>5. Open **Tourist Spots** and search for the imported names. | The preview shows "3 valid" and no invalid rows.<br>The progress counter reaches 3/3.<br>The 3 spots exist exactly once. | High | Functional | | |  |
| TC-ADM-020 | TS-ADM-009 | Bulk import with invalid rows and wrong files | Admin Portal – Content | The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).<br>The device is connected to the internet (Wi-Fi or mobile data).<br>CSV with 4 rows: 1 valid, 1 missing name, 1 unknown provinceId `XX999`, 1 missing shortDescription. Also a `.xlsx` file. | — | 1. Select the CSV and read the preview.<br>2. Import.<br>3. Try to pick the `.xlsx` file. | Preview shows 1 valid and 3 invalid with messages "Missing name", `Unknown provinceId "XX999"` and "Missing shortDescription" (with row numbers).<br>Only the valid row is created.<br>The file picker only allows `.csv` files. | Medium | Negative | | |  |
| TC-ADM-021 | TS-ADM-010 | LGU account is limited to its province | Admin Portal – Content | The tester is signed in to the Admin Portal as an **LGU** account assigned to one province (example: lgu.benguet@example.com, province Benguet).<br>Tourist spots exist in Benguet and in another province. | — | 1. Open **Tourist Spots** and look at the province options.<br>2. Open **Analytics** and read the header/values.<br>3. Try to add a spot. | The LGU's own province (Benguet) is selected automatically and only its spots are listed; other provinces cannot be managed (verify whether the province picker is hidden).<br>Analytics shows Benguet-only numbers (no platform-wide traveler totals).<br>A new spot is created for Benguet only. | High | Security | | |  |

## Admin Portal – Announcements & Analytics

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-ADM-016 | TS-ADM-012 | Send an announcement to all travelers | Admin Portal – Announcements & Analytics | The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).<br>The device is connected to the internet (Wi-Fi or mobile data).<br>At least one traveler device is signed in. | Title: `Typhoon Advisory`<br>Message: `Please check local advisories before traveling.`<br>Category: `Emergency Alert` | 1. Open **Send Announcement**.<br>2. Enter the title, message and choose the category.<br>3. Tap **Send to Every Traveler** and confirm "Send this announcement?" with **Send**. | A message "Announcement sent." appears.<br>Travelers see it in Notifications (and as a push if permission is allowed). | High | Functional | | |  |
| TC-ADM-017 | TS-ADM-012 | Announcement validation and length limits | Admin Portal – Announcements & Analytics | The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).<br>The announcement form is open. | Title: 101 characters<br>Message: 501 characters | 1. Tap send with both fields empty.<br>2. Paste the long values. | "Title is required" and "Message is required" appear.<br>The Title field accepts up to 100 characters and the Message field up to 500.<br>No announcement is sent while an error shows. | Medium | Boundary | | |  |
| TC-ADM-023 | TS-ADM-013 | Analytics dashboard values | Admin Portal – Announcements & Analytics | The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).<br>The device is connected to the internet (Wi-Fi or mobile data).<br>Known counts in the database (e.g., 10 travelers, 2 suspended). | — | 1. Open **Analytics**.<br>2. Compare Total Travelers, Suspended, Provinces w/ Content, Tourist Spots, Restaurants, Festivals, Businesses (Pending Review/Approved), Saved Trips and Pending Reports with the database.<br>3. Look at the **Traveler Growth** chart. | Each counter matches the real data.<br>The chart shows "Total signed-up travelers, last N days" without errors even if there is little history. | Medium | Functional | | | Chart needs at least the daily snapshots produced by the scheduled function. |

## Admin Portal – Moderation

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-ADM-022 | TS-ADM-011 | Hide, restore and dismiss a reported review | Admin Portal – Moderation | The tester is signed in to the Admin Portal as an **admin** account (example: admin01@example.com).<br>A reported review and a reported listing exist (TC-REV-008, TC-DET-012). | — | 1. Open **Reported Reviews** and view the review report.<br>2. Tap **Hide** and confirm "Hide this review?".<br>3. Check the review in the traveler app and the author's notifications.<br>4. Tap **Restore** and confirm.<br>5. On the listing report tap **Dismiss report** and confirm "Dismiss this report?". | After Hide the review no longer shows publicly and the author gets a notification "Your review was hidden".<br>After Restore it shows again.<br>Dismiss says "The listing stays as-is." and removes the report from the queue. | High | Functional | | |  |

## Network & Offline

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-NET-001 | TS-NET-001 | Offline banner appears and disappears | Network & Offline | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The tester is on the Home or Saved screen. | — | 1. Turn on airplane mode.<br>2. Wait 5 seconds and look at the top of the screen.<br>3. Turn off airplane mode.<br>4. Wait 10 seconds. | A banner "You're offline — showing saved data" appears while offline.<br>The banner disappears after the connection returns, and screens can be refreshed normally. | High | Interruption/Recovery | | |  |
| TC-NET-002 | TS-NET-002 | Wi-Fi disconnected, mobile data connected | Network & Offline | The TripNest PH traveler app is installed and opens normally.<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The device has mobile data; Wi-Fi is turned OFF. | — | 1. Open Home, then Explore, then open a destination.<br>2. Send one message in the AI chat. | Content loads and the AI chat replies; no offline banner appears. | Medium | Compatibility | | |  |
| TC-NET-003 | TS-NET-002 | Mobile data disconnected, Wi-Fi connected | Network & Offline | The TripNest PH traveler app is installed and opens normally.<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The device is on Wi-Fi; mobile data is turned OFF. | — | 1. Repeat the same actions as TC-NET-002. | Everything loads normally over Wi-Fi with no errors. | Medium | Compatibility | | |  |
| TC-NET-004 | TS-NET-002 | Switch from Wi-Fi to mobile data while browsing | Network & Offline | The TripNest PH traveler app is installed and opens normally.<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Wi-Fi ON and mobile data ON; the tester is scrolling Explore. | — | 1. While a list is loading, turn Wi-Fi OFF so that the phone changes to mobile data.<br>2. Continue scrolling and tap **Load More**. | Loading continues or shows a temporary friendly error; after a few seconds the content loads again.<br>The app does not crash or need to be restarted. | Low | Interruption/Recovery | | |  |
| TC-NET-005 | TS-NET-003 | Slow network | Network & Offline | The TripNest PH traveler app is installed and opens normally.<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The device uses a throttled connection (e.g., developer network throttling to 2G / "Slow 3G" in browser dev tools). | — | 1. Open Home, Explore and a destination details screen.<br>2. Tap **Generate Itinerary** with a valid form.<br>3. Wait up to 60 seconds. | Loading placeholders (shimmer/loading indicators) are shown instead of a blank screen.<br>Actions cannot be double-submitted while loading.<br>If a request times out, the message "This is taking longer than expected. Please check your connection and try again." (or another friendly message) is shown. | Medium | Performance | | |  |

## App Interruptions

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-INT-001 | TS-INT-001 | Incoming phone call while filling a form | App Interruptions | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Real device with calling. The Planner form is partly filled (destination, days = 5). | — | 1. Receive a phone call and answer it for 20 seconds.<br>2. End the call and return to TripNest PH. | The app is on the same screen; the Planner form still has the destination and 5 days. | Medium | Interruption/Recovery | | |  |
| TC-INT-002 | TS-INT-001 | Notification arrives while using the app | App Interruptions | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The tester is typing a review comment. | — | 1. Trigger another app's notification (e.g., send a message to the device).<br>2. Ignore it (or pull down and close it) and continue typing.<br>3. Submit the review. | The typed text is kept and the review is submitted normally. | Low | Interruption/Recovery | | |  |
| TC-INT-003 | TS-INT-001 | Switch to another app and return | App Interruptions | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The tester is on a destination details screen scrolled halfway. | — | 1. Press the Home button and open another app for 1 minute.<br>2. Return to TripNest PH from the recent apps. | The same screen and scroll position are shown; the user is still signed in. | Medium | Interruption/Recovery | | |  |
| TC-INT-004 | TS-INT-001 | Minimize for a long time then return | App Interruptions | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234). | — | 1. Minimize the app and leave the device for 30 minutes (the OS may close the app).<br>2. Open the app again. | The user is still signed in and lands on Home (or the same screen).<br>Data loads normally; no crash or forced logout. | Medium | Interruption/Recovery | | |  |
| TC-INT-005 | TS-INT-001 | Lock and unlock the screen during a request | App Interruptions | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The chat screen is open. | — | 1. Send a chat message.<br>2. Immediately lock the screen for 15 seconds.<br>3. Unlock the device. | The reply is shown in the chat (or a friendly error bubble); the message is not duplicated. | Low | Interruption/Recovery | | |  |
| TC-INT-006 | TS-INT-002 | Force close and reopen during an action | App Interruptions | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>A new itinerary is open and unsaved. | — | 1. Tap the save action and immediately swipe the app away.<br>2. Reopen the app and open Saved Trips. | At most one copy of the trip exists (saved or not saved) and it opens normally.<br>No duplicated or blank trip appears. | Medium | Interruption/Recovery | | |  |

## Error Handling

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-ERR-001 | TS-ERR-001 | Errors never expose technical details | Error Handling | The TripNest PH traveler app is installed and opens normally.<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Tester can turn the internet on/off and has a suspended-test account. | — | 1. Cause a network error on Login, Explore, Planner and Chat (internet OFF).<br>2. Cause a permission error (e.g., upload an over-5 MB profile photo).<br>3. Cause a wrong-password error on Login.<br>4. Read every message shown. | All messages are plain-language sentences (for example "No internet connection. Please check your network and try again." or "You don't have permission to do that.").<br>None of them contains: stack traces, "Exception", "FirebaseException", "[firebase_auth/...]", HTTP codes such as 401/500, JSON, URLs or database paths. | High | Security | | |  |
| TC-ERR-002 | TS-ERR-001 | Unexpected AI response / service unavailable | Error Handling | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>A test environment where the AI key is missing or the AI service is unreachable (ask the developer to disable it), if available. | — | 1. Send a message in the AI chat.<br>2. Tap **Generate Itinerary** on the Planner. | The chat shows an error bubble and the Planner shows a snack bar, both with friendly text (for example "This feature isn't available right now. Please try again later.").<br>No raw error text from the AI provider is shown. | Medium | Negative | | | Optional; needs a controlled failure setup. |

## Data Consistency

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-DATA-001 | TS-DATA-001 | No duplicate records after double taps | Data Consistency | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234). | — | 1. Double-tap **Save** on a generated itinerary.<br>2. Double-tap **Add** when adding an expense.<br>3. Double-tap the review submit button.<br>4. Check Saved Trips, the Budget Tracker and the review list. | Exactly one trip, one expense and one review exist. | High | Negative | | |  |
| TC-DATA-002 | TS-DATA-001 | Data is the same after refresh and reopen | Data Consistency | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>The traveler has 1 saved trip, 2 favorites, 1 review and an edited profile. | — | 1. Note the data.<br>2. Pull to refresh on Home and Saved.<br>3. Close the app, reopen it, log out and log in again.<br>4. Compare all data. | Every item is still present, unchanged, and not duplicated. | High | Functional | | |  |
| TC-DATA-003 | TS-DATA-001 | Rating and review count stay consistent | Data Consistency | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A place with no reviews; two traveler accounts. | — | 1. Account A reviews it with 5 stars; Account B reviews it with 3 stars.<br>2. Check the average rating and count.<br>3. Account B edits to 1 star; then Account A deletes their review.<br>4. Check the rating and count each time. | After A and B: rating 4.0 with 2 reviews.<br>After B edits: rating 3.0 with 2 reviews.<br>After A deletes: rating 1.0 with 1 review. | High | Functional | | |  |

## Compatibility & Responsiveness

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-COMP-001 | TS-COMP-001 | Responsive layout: phone vs wide desktop web | Compatibility & Responsiveness | The traveler web build is open in a desktop browser (Chrome or Edge). | — | 1. Resize the browser window to about 400 px wide and open Login and Home.<br>2. Resize to about 1300 px wide (wider than 1100 px) and reopen Login and Home. | Narrow: single-column layout with a bottom navigation bar.<br>Wide: Login and Register show a two-panel layout (branded panel + form) and the main app uses a side navigation instead of the bottom bar.<br>No overlapping or cut-off text at either size. | Medium | Compatibility | | |  |
| TC-COMP-002 | TS-COMP-001 | Dark mode readability on key screens | Compatibility & Responsiveness | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>A verified traveler account exists and the tester is signed in (example: tester01@example.com / Test@1234).<br>Dark Mode is ON (Settings). | — | 1. Visit Home, Explore, a details screen, the Planner, the itinerary, Saved, Profile and Settings. | Text, icons, buttons and images are readable with enough contrast; no white boxes or invisible text. | Low | Usability | | |  |
| TC-COMP-003 | TS-COMP-001 | Browser compatibility of the web build | Compatibility & Responsiveness | Traveler web build; browsers Chrome, Edge and Firefox are available. | — | 1. In each browser sign in, open Explore, open a destination and generate a short itinerary. | The same features work in all three browsers with no blank screens or console-visible crashes on screen. | Low | Compatibility | | | Safari/iOS Safari is not in the list because it was not verified in the code. |

## Security

| Test Case ID | Test Scenario | Test Case Title | Module | Preconditions | Test Data | Steps | Expected Result | Priority | Test Type | Actual Result | Status | Remarks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-SEC-001 | TS-SEC-001 | Traveler opens admin pages on the traveler app | Security | Traveler web build; signed in as `tester01@example.com` (no admin role). | — | 1. Type `/admin` and then `/admin/users` in the browser address bar. | `/admin` shows "No access" with the text "This account doesn't have an active Admin Portal role."<br>`/admin/users` shows no traveler data (blocked by the database rules); an empty or friendly error state is acceptable. | High | Security | | | Code trace: the traveler app router contains the admin routes. Only `/admin` has a UI role check; the other screens depend on Firestore rules. Consider adding a guard. |
| TC-SEC-002 | TS-SEC-001 | Another user's trip is not visible | Security | The TripNest PH traveler app is installed and opens normally.<br>The device is connected to the internet (Wi-Fi or mobile data).<br>Traveler A has a saved trip; Traveler B has not joined it. | — | 1. Sign in as Traveler B and open Saved Trips.<br>2. Search in the app for A's trip title. | B never sees A's trip in any list or search. | High | Security | | |  |

---

# STEP 7 — Test Coverage Check

## 7.1 Totals

| # | Measure | Count |
|---|---|---|
| 1 | Total Test Scenarios | **113** |
| 2 | Total Test Cases | **238** |
| 3 | Functional test cases | 99 |
| 4 | Negative test cases | 33 |
| 5 | Boundary / Validation test cases | 37 (Boundary 19, Validation 18) |
| 6 | Interruption / Recovery test cases | 34 |
|   | Other types (Usability 4, Security 19, Integration 7, Compatibility 4, Performance 1) | 35 |

Priority split: High 95, Medium 97, Low 46. Each test case has exactly one test type, so the type counts add up to 238.

### Test cases per module

| Module | Scenarios | Test Cases |
|---|---|---|
| Splash & Onboarding | 2 | 4 |
| Registration | 9 | 12 |
| Login | 7 | 17 |
| Forgot Password (OTP) | 4 | 11 |
| Email Verification | 3 | 7 |
| Sign-out & Route Guard | 1 | 3 |
| Home | 3 | 8 |
| Explore | 3 | 6 |
| Search | 4 | 7 |
| Details Screens | 5 | 13 |
| Nearby Places | 1 | 2 |
| Reviews & Reports | 5 | 10 |
| Favorites & Lists | 3 | 7 |
| AI Planner | 5 | 10 |
| Generated Itinerary | 8 | 18 |
| Saved Trips & Sharing | 3 | 6 |
| AI Travel Assistant | 4 | 10 |
| Profile | 5 | 11 |
| Settings | 5 | 8 |
| Notifications | 2 | 6 |
| Business Owner | 8 | 16 |
| Admin Portal – Access & Roles | 3 | 5 |
| Admin Portal – Business Approval | 2 | 6 |
| Admin Portal – Team & Travelers | 2 | 3 |
| Admin Portal – Content | 4 | 7 |
| Admin Portal – Announcements & Analytics | 2 | 3 |
| Admin Portal – Moderation | 1 | 1 |
| Network & Offline | 3 | 5 |
| App Interruptions | 2 | 6 |
| Error Handling | 1 | 2 |
| Data Consistency | 1 | 3 |
| Compatibility & Responsiveness | 1 | 3 |
| Security | 1 | 2 |

## 7.2 Features with NO (or only partial) test coverage

| Feature found in the code | Coverage status | Reason / note |
|---|---|---|
| Admin **Province Edit** screen (`admin_province_edit_screen.dart`) and **Provinces** list | No coverage | Not analyzed in detail; needs its own test cases. |
| Admin **Festival edit / delete** and Festival list filters | Partial | Only creation and validation (TC-ADM-018) are covered. |
| **Upcoming Festivals** screen (`upcoming_festivals_screen.dart`) and Home tiles (Upcoming Trip card, Post-trip Review card, Today Weather chip) | No dedicated coverage | Displayed conditions not fully verified. |
| **Trip route map** (road-following route per day, Google Routes) and "Pin Activity Location" map picker | No coverage | Requires map interaction; add manual map test cases. |
| **Expense split math** ("Who Owes What", "Spend by Category") accuracy | Partial | TC-ITIN-007/009 only check totals appear/update. Needs calculated examples (see `test/utils/expense_split_test.dart`). |
| **Trip Companions / Invite** button (share sheet/code creation) | Partial | Only the join side (TC-TRIP-002) is covered. |
| AI review digest "Travelers say" on restaurant details (scheduled `generateReviewDigests`) | No coverage | Depends on a scheduled function. |
| Scheduled analytics snapshots (`snapshotDailyAnalytics`) | Indirect only | Seen via the analytics chart (TC-ADM-023). |
| Firestore and Storage **security rules** (direct rule tests) | No direct coverage | UI tests only check visible behavior. Use the Firebase Emulator for rule tests. |
| Custom OTP **email template / delivery time** | No coverage | Depends on the firestore-send-email extension and Gmail SMTP. |
| Firebase Analytics / Crashlytics reporting | No coverage | No user-visible behavior. |
| Platforms **macOS, Windows, Linux** (folders exist in the project) | No coverage | Only Android, iOS and Web are mentioned in the documentation. |
| Payment / checkout / ordering | Not applicable | No such feature exists in the code. |

## 7.3 Features where the implementation is unclear and needs manual verification

| # | Item | What to check |
|---|---|---|
| 1 | Offline behavior | docs/Project_Documentation.md says "no offline content cache", but the code enables Firestore persistence, shows the offline banner and has "Save for Offline". Record what really works offline (TC-HOME-008, TC-ITIN-016, TC-NET-001). |
| 2 | Google Sign-In | Email-verified status and behavior on iOS/Web/Android (TC-LOGIN-015). |
| 3 | Unknown-email login message | Firebase may return "Incorrect email or password." or "No account found with that email." (TC-LOGIN-003). |
| 4 | Explore tab labels and filter button | Exact labels of the 4 Explore tabs and where the filter opens were not verified (TC-EXP-001, TC-EXP-003). |
| 5 | Nearby Places entry point | Which button opens the screen from Home/Details (TC-NEAR-001). |
| 6 | Reminders on real devices | Android 13+ / iOS notification permission and alarm timing. Reminders use inexact alarms, so they can arrive a few minutes late (TC-DET-006, TC-DET-007, TC-ITIN-015). |
| 7 | Photo permission messages | Behavior of image_picker when Photos permission is denied differs by platform (TC-REV-005, TC-PROF-007). |
| 8 | Business application rejected state | What the applicant sees after rejection (TC-ADM-009). |
| 9 | Discard-changes dialog wording | Exact text of the unsaved-changes prompt on the business listing form (TC-BIZ-014). |
| 10 | Admin travel-tip management | Documentation lists travel tips as admin-authored, but no admin screen for travel tips was found in lib/presentation/admin/. |
| 11 | Emergency hotline data | Province hotlines depend on admin-entered data; check the national hotline number shown in the app (TC-DET-009). |

---

# STEP 8 — Code Trace Results (added after checking the expected results against the source code)

**How it was done.** (1) Every quoted message and label in the expected results and steps was searched in lib/ and functions/index.js. All were found (a few only differed by how apostrophes are escaped in Dart). (2) Flows that were flagged as unclear were read in the source. (3) The 265 automated tests in the project and the analyzer were run. This is a code check only; no test case was run on a device.

## 8.1 Defects found in the app and fixed

| # | Test case | Problem found | Fix |
|---|---|---|---|
| 1 | TC-PWD-009 | Tapping **Resend code** on the code step crashed with a null-check error, because the email form that the code validated is not on screen at that step (forgot_password_screen.dart). | Validation now only runs when that form exists. Regression test added: test/widgets/forgot_password_screen_test.dart (fails without the fix, passes with it). |
| 2 | TC-DET-006, TC-DET-013, TC-ITIN-015 | The reminder picker accepted a time earlier today, then showed "Reminder set" for a time in the past. | reminder_picker.dart now shows "Pick a time in the future." and schedules nothing. |

## 8.2 Behavior that differs from what was first expected (test cases corrected)

| Test case | What the code really does |
|---|---|
| TC-SET-003 | After a plain Deny the Location switch stays ON with no message. The "Location access is off at the system level..." message with **Open Settings** appears only for permanent denial or when phone location is off. |
| TC-NOTIF-005 | The category switches only filter the in-app Notifications list, not the system push. |
| TC-ADM-003 | LGU accounts can send announcements on purpose (firestore.rules allows it and says it matches the tile). No longer an open question. |
| TC-ADM-002, TC-SEC-001 | Only /admin shows "No access". Other admin screens have no role check and depend on Firestore rules to block data. |
| TC-ITIN-015 | **Remind** opens a two-option sheet (Travel Day / Packing), then a date and time picker. There are no toggles. |
| TC-PROF-007 | The profile photo is resized (800 px, quality 85) before upload, so the 5 MB limit is rarely reached. |
| TC-PLAN-010 | On the manual itinerary screen **Start Planning** is disabled until a destination and start date are chosen; there is no error message. |

## 8.3 Known gaps to report (not changed in the code)

| # | Test case | Observation | Suggested action |
|---|---|---|---|
| 1 | TC-SET-006 | Delete Account removes reviews, notifications, favorites, saved trips, visited/recently viewed and the profile, but not the businesses, business applications or admin_users records of that user. | Decide whether owner data should also be deleted or anonymized. |
| 2 | TC-SET-003 | The Location switch stays ON after a plain permission denial. | Consider turning it off and showing a message. |
| 3 | TC-ADM-002, TC-SEC-001 | Admin screens other than /admin do not show "No access" to non-admins. | Add a role guard to the admin router or screens. Data is still protected by Firestore rules. |

## 8.4 Automated test status after the trace

| Check | Result |
|---|---|
| flutter analyze (whole project) | No errors or warnings; about 83 style-only lints (info) that existed before |
| flutter analyze (files changed here) | No issues found |
| flutter test | 265 passed, 0 failed. Before the trace 9 tests failed because they were out of date: 7 review repository tests, the register flow test, and the Explore map test (the map toggle was removed from the app, so that test was deleted). One new regression test was added. |

---

*Existing automated tests in the project (`test/`) cover validators, repositories, some widgets and utilities. This document is for manual black-box testing and does not replace them.*