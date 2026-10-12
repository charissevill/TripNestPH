# ACTIVITY 1 – Finals
## Test Scenarios and Test Cases Development

**Course:** Software Testing / Software Quality Assurance
**Application:** TripNest PH

### Learning Outcomes
After completing this activity, you should be able to:
1. Identify functionalities that require testing in your application.
2. Create effective Test Scenarios that describe what should be tested.
3. Develop detailed Test Cases from identified Test Scenarios.
4. Apply software testing principles to improve software quality.

---

## Part 1: Application Information

| Item | Details |
|---|---|
| **Application Name** | TripNest PH |
| **Application Type/Category** | Mobile App (Android/iOS) with a Web build / Travel and Trip-Planning Platform (Flutter + Firebase) |
| **Main Features/Modules** | 1. Home, Destination Explore & Search (filters, live search)<br>2. Destination Details, Nearby Places & Reviews<br>3. AI Trip Planner & Generated Itinerary (generate, edit, budget tracker, save)<br>4. AI Travel Assistant (chat and Generate Full Itinerary)<br>5. Favorites & Saved Trips (bookmarks, named lists, saved itineraries)<br>6. Profile & Settings Management |

> **Scope note:** TripNest PH has no checkout; its main flow is generating and saving an itinerary.

---

## Part 2: Test Scenarios

Format: **TS-XX: Verify that [user action/feature] works correctly.**

| Scenario ID | Test Scenario |
|---|---|
| TS-01 | Verify that a user can browse Explore and narrow the destination list using filters. |
| TS-02 | Verify that a user can generate an AI itinerary using valid planner inputs. |
| TS-03 | Verify that the search functionality returns accurate and relevant results. |
| TS-04 | Verify that a user can save places to Favorites and organize them into lists. |
| TS-05 | Verify that a user can save a generated itinerary to Saved Trips. |
| TS-06 | Verify that a user can update their profile information (name, email, password). |
| TS-07 | Verify that the Home screen displays its content sections correctly. |
| TS-08 | Verify that a user can view a destination's details, weather, map and emergency access. |
| TS-09 | Verify that a user can chat with the AI Travel Assistant and generate a full itinerary. |
| TS-10 | Verify that a user can write a review with a rating and a comment for a destination. |

---

## Part 3: Test Cases

All ten Test Scenarios below were given one **Positive / Happy Path** and one **Negative / Error Path** Test Case.

### TS-01 — Verify that a user can browse Explore and narrow the destination list using filters.

### Positive / Happy Path Test Case: Apply Explore Filters and Reset Them

**Related Scenario:** TS-01

| Field | Details |
|---|---|
| **Test Case ID** | TC_EXPLORE_001 |
| **Title** | Apply Explore Filters and Reset Them |
| **Related Scenario** | TS-01 |
| **Preconditions** | 1. The TripNest PH app is installed and opens normally.<br>2. The device is connected to the internet.<br>3. The tester is signed in with a verified traveler account.<br>4. The tester is on Explore > Destinations.<br>5. Location permission is granted. |
| **Test Steps** | 1. Open the filter and wait for “Loading regions...” to finish.<br>2. Choose a Region, then a Province.<br>3. Select Minimum Rating 4.0+ ★.<br>4. Select Distance Within 25 km.<br>5. Tap **Apply**.<br>6. Open the filter again, tap **Reset**, then **Apply**. |
| **Test Data** | Region: any region<br>Minimum Rating: `4.0+ ★`<br>Distance: `Within 25 km` |
| **Expected Result** | 1. Filter chips for the chosen options are shown after Apply.<br>2. Only matching destinations remain (rating 4.0 or more, in the chosen province, within 25 km).<br>3. After Reset and Apply, the full destination list returns. |

### Negative / Error Path Test Case: Filter Combination That Matches Nothing

**Related Scenario:** TS-01

| Field | Details |
|---|---|
| **Test Case ID** | TC_EXPLORE_002 |
| **Title** | Filter Combination That Matches Nothing |
| **Related Scenario** | TS-01 |
| **Preconditions** | 1. The TripNest PH app is installed and opens normally.<br>2. The device is connected to the internet.<br>3. The tester is signed in with a verified traveler account.<br>4. The tester is on Explore > Destinations. |
| **Test Steps** | 1. Open the filter.<br>2. Select Minimum Rating 4.5+ ★ together with Distance Within 5 km, in an area with no matching spots.<br>3. Tap **Apply**. |
| **Test Data** | Minimum Rating: `4.5+ ★` *(Invalid/Edge Data)*<br>Distance: `Within 5 km` *(Invalid/Edge Data)* |
| **Expected Result** | 1. An empty state titled **“Nothing here yet”** is shown instead of a blank screen.<br>2. No destination cards are shown and the app does not crash.<br>3. The filters can still be changed or reset from this screen. |

### TS-02 — Verify that a user can generate an AI itinerary using valid planner inputs.

### Positive / Happy Path Test Case: Successful Itinerary Generation with Valid Inputs

**Related Scenario:** TS-02

| Field | Details |
|---|---|
| **Test Case ID** | TC_PLAN_001 |
| **Title** | Successful Itinerary Generation with Valid Inputs |
| **Related Scenario** | TS-02 |
| **Preconditions** | 1. The TripNest PH app is installed and opens normally.<br>2. The device is connected to the internet.<br>3. The tester is signed in with a verified traveler account.<br>4. The AI service (Cloud Functions) is available. |
| **Test Steps** | 1. Tap the **Planner** tab.<br>2. Under “Where do you want to go?”, select the destination.<br>3. Select the budget, set the number of days, and choose who is traveling and how many travelers.<br>4. Select the transportation, the interests, and the trip pace.<br>5. Tap **Generate Itinerary**. |
| **Test Data** | Destination: `Baguio (Benguet)`<br>Budget: `Mid-range (₱15k – ₱40k)`<br>Days: `3`<br>Who is traveling: `Friends`, Travelers: `4`<br>Transportation: `Van / Car Rental`<br>Interests: `Food, Nature`<br>Trip pace: `Balanced` |
| **Expected Result** | 1. The button changes to “Crafting your itinerary...” with a loading indicator and cannot be tapped again.<br>2. The generated itinerary screen opens.<br>3. It shows a **3-day**, day-by-day plan.<br>4. A budget summary, weather outlook (when the destination has coordinates), recommended restaurants and accommodations, and travel tips are shown. |

### Negative / Error Path Test Case: Generate Itinerary Blocked Without a Destination

**Related Scenario:** TS-02

| Field | Details |
|---|---|
| **Test Case ID** | TC_PLAN_002 |
| **Title** | Generate Itinerary Blocked Without a Destination |
| **Related Scenario** | TS-02 |
| **Preconditions** | 1. The TripNest PH app is installed and opens normally.<br>2. The device is connected to the internet.<br>3. The tester is signed in with a verified traveler account.<br>4. The Planner form is freshly opened, with no destination selected. |
| **Test Steps** | 1. Tap the **Planner** tab.<br>2. Leave the destination empty (other options may stay at their default values).<br>3. Look at the bottom of the screen.<br>4. Try to tap **Generate Itinerary**. |
| **Test Data** | Destination: none selected *(Invalid/Edge Data)*<br>Other options: default values |
| **Expected Result** | 1. The text **“Select a destination to continue”** is shown above the button.<br>2. The **Generate Itinerary** button is disabled and nothing happens when it is tapped.<br>3. The user remains on the Planner screen and no loading state (“Crafting your itinerary...”) appears.<br>4. No itinerary is generated and nothing is added to Saved Trips. |

### TS-03 — Verify that the search functionality returns accurate and relevant results.

### Positive / Happy Path Test Case: Successful Search with a Valid Keyword

**Related Scenario:** TS-03

| Field | Details |
|---|---|
| **Test Case ID** | TC_SEARCH_001 |
| **Title** | Successful Search with a Valid Keyword |
| **Related Scenario** | TS-03 |
| **Preconditions** | 1. The TripNest PH app is installed and opens normally.<br>2. The device is connected to the internet.<br>3. The tester is signed in with a verified traveler account.<br>4. The catalog contains a destination named “Boracay”. |
| **Test Steps** | 1. From the **Home** screen, tap the search bar (“Search destinations, food, festivals...”).<br>2. On the search screen, type the keyword in the search box.<br>3. Wait about one second (no need to press Enter). |
| **Test Data** | Search Keyword: `Boracay` |
| **Expected Result** | 1. Matching results appear automatically after typing stops (about 0.35 second delay), without pressing Enter.<br>2. The list contains **Boracay** and other entries related to the keyword; the number of results is greater than zero.<br>3. A **“More places”** section with live Google Places results may also appear (shown only for keywords of 3 or more characters).<br>4. Entries unrelated to “Boracay” are not listed among the matches.<br>5. Tapping the Boracay result opens its Details screen. |

### Negative / Error Path Test Case: Search with No Matching Results (Invalid Keyword)

**Related Scenario:** TS-03

| Field | Details |
|---|---|
| **Test Case ID** | TC_SEARCH_002 |
| **Title** | Search with No Matching Results (Invalid Keyword) |
| **Related Scenario** | TS-03 |
| **Preconditions** | 1. The TripNest PH app is installed and opens normally.<br>2. The device is connected to the internet.<br>3. The tester is signed in with a verified traveler account.<br>4. No destination, restaurant, festival, or live place matches the test keyword. |
| **Test Steps** | 1. From the **Home** screen, tap the search bar.<br>2. Type a keyword that does not match anything in the catalog.<br>3. Wait about one second for the results to load. |
| **Test Data** | Search Keyword: `zzzzqqqq` *(Invalid/Edge Data)* |
| **Expected Result** | 1. No result cards are displayed.<br>2. An empty-state message is shown with the title **No results for “zzzzqqqq”** and the text “Try a different keyword, or browse by category from Explore instead.”<br>3. A **Go to Explore** button is available, and the search box stays editable so the user can search again.<br>4. The app does not crash, freeze, or show an error page or technical error text. |

### TS-04 — Verify that a user can save places to Favorites and organize them into lists.

### Positive / Happy Path Test Case: Save and Unsave a Destination with the Bookmark Icon

**Related Scenario:** TS-04

| Field | Details |
|---|---|
| **Test Case ID** | TC_FAV_001 |
| **Title** | Save and Unsave a Destination with the Bookmark Icon |
| **Related Scenario** | TS-04 |
| **Preconditions** | 1. The TripNest PH app is installed and opens normally.<br>2. The device is connected to the internet.<br>3. The tester is signed in with a verified traveler account.<br>4. The Saved tab has no favorites yet. |
| **Test Steps** | 1. On Home, tap the bookmark icon on a destination card.<br>2. Open the Saved tab, then Places.<br>3. Tap the bookmark icon on the same card again (Home or Explore).<br>4. Return to Saved > Places. |
| **Test Data** | (none required) |
| **Expected Result** | 1. The icon changes to the saved state with a small bounce, and Places (1) shows the destination.<br>2. After the second tap the icon returns to unsaved.<br>3. Places (0) is empty and the destination no longer appears. |

### Negative / Error Path Test Case: List Name Validation (Empty and Over the Character Limit)

**Related Scenario:** TS-04

| Field | Details |
|---|---|
| **Test Case ID** | TC_FAV_002 |
| **Title** | List Name Validation (Empty and Over the Character Limit) |
| **Related Scenario** | TS-04 |
| **Preconditions** | 1. The TripNest PH app is installed and opens normally.<br>2. The device is connected to the internet.<br>3. The tester is signed in with a verified traveler account.<br>4. The “Add to List” sheet is open. |
| **Test Steps** | 1. Tap **New List** and leave the name field empty.<br>2. Look at the confirm button.<br>3. Paste a 61-character list name into the field. |
| **Test Data** | List name: empty, then a 61-character name *(Invalid/Edge Data)* |
| **Expected Result** | 1. The confirm button is disabled while the name field is empty; no list is created.<br>2. The text field accepts at most 60 characters (the 61st character is not entered).<br>3. The app does not crash and no partially-named list is saved. |

### TS-05 — Verify that a user can save a generated itinerary to Saved Trips.

### Positive / Happy Path Test Case: Save a Generated Itinerary to My Trips

**Related Scenario:** TS-05

| Field | Details |
|---|---|
| **Test Case ID** | TC_ITIN_001 |
| **Title** | Save a Generated Itinerary to My Trips |
| **Related Scenario** | TS-05 |
| **Preconditions** | 1. The TripNest PH app is installed and opens normally.<br>2. The device is connected to the internet.<br>3. The tester is signed in with a verified traveler account.<br>4. A newly generated (unsaved) itinerary is open. |
| **Test Steps** | 1. Tap the save (bookmark) action on the itinerary screen.<br>2. Open Profile > My Trips (Saved Trips). |
| **Test Data** | (none required) |
| **Expected Result** | 1. The message **“Itinerary saved to your trips.”** appears.<br>2. The trip appears once in the Saved Trips list. |

### Negative / Error Path Test Case: Save Fails Gracefully While Offline

**Related Scenario:** TS-05

| Field | Details |
|---|---|
| **Test Case ID** | TC_ITIN_002 |
| **Title** | Save Fails Gracefully While Offline |
| **Related Scenario** | TS-05 |
| **Preconditions** | 1. The TripNest PH app is installed and opens normally.<br>2. The tester is signed in with a verified traveler account.<br>3. An unsaved itinerary is open and the device's internet is turned OFF. |
| **Test Steps** | 1. Tap the save action while offline.<br>2. Read the message shown.<br>3. Turn the internet back ON and tap save again. |
| **Test Data** | Network state: offline, then online *(Invalid/Edge Data)* |
| **Expected Result** | 1. While offline, the friendly message **“No internet connection. Please check your network and try again.”** is shown; no trip is created.<br>2. No stack trace or technical error code is visible.<br>3. Once back online, tapping save shows “Itinerary saved to your trips.” and only one trip is created. |

### TS-06 — Verify that a user can update their profile information (name, email, password).

### Positive / Happy Path Test Case: Update the Full Name Successfully

**Related Scenario:** TS-06

| Field | Details |
|---|---|
| **Test Case ID** | TC_PROF_001 |
| **Title** | Update the Full Name Successfully |
| **Related Scenario** | TS-06 |
| **Preconditions** | 1. The TripNest PH app is installed and opens normally.<br>2. The device is connected to the internet.<br>3. The tester is signed in with a verified traveler account. |
| **Test Steps** | 1. Open Profile > Edit Profile.<br>2. Change Full Name to the new name.<br>3. Tap **Save Changes**. |
| **Test Data** | New name: `Maria S. Santos` |
| **Expected Result** | 1. The message **“Profile updated.”** appears.<br>2. Profile shows the new name.<br>3. The new name is still shown after closing and reopening the app. |

### Negative / Error Path Test Case: Full Name Validation on Edit Profile

**Related Scenario:** TS-06

| Field | Details |
|---|---|
| **Test Case ID** | TC_PROF_002 |
| **Title** | Full Name Validation on Edit Profile |
| **Related Scenario** | TS-06 |
| **Preconditions** | 1. The TripNest PH app is installed and opens normally.<br>2. The device is connected to the internet.<br>3. The tester is signed in with a verified traveler account.<br>4. The Edit Profile screen is open. |
| **Test Steps** | 1. Clear the Full Name field and tap **Save Changes**.<br>2. Enter a single character (“A”) and tap **Save Changes**.<br>3. Paste a 61-character name into the field. |
| **Test Data** | Full Name: empty, `A`, and a 61-character name *(Invalid/Edge Data)* |
| **Expected Result** | 1. An empty name shows **“Name is required”**.<br>2. “A” shows **“Name is too short”**.<br>3. The field accepts at most 60 characters (counter shows 60), and nothing is saved while an error is shown. |

### TS-07 — Verify that the Home screen displays its content sections correctly.

### Positive / Happy Path Test Case: Home Screen Loads Its Content Sections

**Related Scenario:** TS-07

| Field | Details |
|---|---|
| **Test Case ID** | TC_HOME_001 |
| **Title** | Home Screen Loads Its Content Sections |
| **Related Scenario** | TS-07 |
| **Preconditions** | 1. The TripNest PH app is installed and opens normally.<br>2. The device is connected to the internet.<br>3. The tester is signed in with a verified traveler account.<br>4. Content (destinations, restaurants, festivals, travel tips) exists in the catalog. |
| **Test Steps** | 1. Open the app and land on Home.<br>2. Scroll from top to bottom. |
| **Test Data** | (none required) |
| **Expected Result** | 1. Sections appear with images and text: Featured Destinations, Popular Restaurants, Upcoming Festivals, Travel Tips.<br>2. Nearby You and Nearby Restaurants appear when the location is available.<br>3. Loading placeholders are replaced by real content; no error text is visible. |

### Negative / Error Path Test Case: Home Still Works When Location Permission Is Denied

**Related Scenario:** TS-07

| Field | Details |
|---|---|
| **Test Case ID** | TC_HOME_002 |
| **Title** | Home Still Works When Location Permission Is Denied |
| **Related Scenario** | TS-07 |
| **Preconditions** | 1. The TripNest PH app is installed and opens normally.<br>2. The tester is signed in with a verified traveler account.<br>3. Location services are on but permission has not been granted yet. |
| **Test Steps** | 1. On Home, trigger the permission request (tap Allow Location).<br>2. In the system dialog, choose **Deny**.<br>3. Scroll through Home.<br>4. Tap Allow Location again. |
| **Test Data** | Permission response: `Deny` *(Invalid/Edge Data)* |
| **Expected Result** | 1. Home still shows Featured Destinations, Restaurants, Festivals and Tips.<br>2. The location card still reads **“Allow location access to see the tourist spots closest to you.”** with an Allow Location button.<br>3. Tapping it again shows the system permission dialog again, and the app does not crash. |

### TS-08 — Verify that a user can view a destination's details, weather, map and emergency access.

### Positive / Happy Path Test Case: Destination Details Screen Shows Its Information

**Related Scenario:** TS-08

| Field | Details |
|---|---|
| **Test Case ID** | TC_DET_001 |
| **Title** | Destination Details Screen Shows Its Information |
| **Related Scenario** | TS-08 |
| **Preconditions** | 1. The TripNest PH app is installed and opens normally.<br>2. The device is connected to the internet.<br>3. The tester is signed in with a verified traveler account.<br>4. A destination with coordinates, an entrance fee and travel tips exists. |
| **Test Steps** | 1. From Home or Explore, tap a destination card.<br>2. Scroll through the whole screen. |
| **Test Data** | (none required) |
| **Expected Result** | 1. A hero image gallery is shown at the top.<br>2. Sections appear for About, Highlights, Location (map), Travel Tips, Getting Around, and stats such as Rating, Best Time and Entrance Fee.<br>3. A live weather card is shown because the destination has coordinates.<br>4. Nearby Attractions, Nearby Restaurants and Nearby Hotels are listed. |

### Negative / Error Path Test Case: Destination Details Screen Without Coordinates

**Related Scenario:** TS-08

| Field | Details |
|---|---|
| **Test Case ID** | TC_DET_002 |
| **Title** | Destination Details Screen Without Coordinates |
| **Related Scenario** | TS-08 |
| **Preconditions** | 1. The TripNest PH app is installed and opens normally.<br>2. The device is connected to the internet.<br>3. The tester is signed in with a verified traveler account.<br>4. A destination that has no coordinates saved exists. |
| **Test Steps** | 1. Open that destination's details screen.<br>2. Scroll through the whole screen. |
| **Test Data** | Destination: one with no coordinates *(Invalid/Edge Data)* |
| **Expected Result** | 1. The screen still opens normally, with About, Highlights and Travel Tips shown.<br>2. The weather card, map and Get Directions are not shown, or degrade gracefully, instead of crashing.<br>3. No error text or blank space is shown in place of the missing sections. |

### TS-09 — Verify that a user can chat with the AI Travel Assistant and generate a full itinerary.

### Positive / Happy Path Test Case: Send a Chat Message and Get a Reply

**Related Scenario:** TS-09

| Field | Details |
|---|---|
| **Test Case ID** | TC_CHAT_001 |
| **Title** | Send a Chat Message and Get a Reply |
| **Related Scenario** | TS-09 |
| **Preconditions** | 1. The TripNest PH app is installed and opens normally.<br>2. The device is connected to the internet.<br>3. The tester is signed in with a verified traveler account.<br>4. The AI Travel Assistant chat screen is open. |
| **Test Steps** | 1. Tap the “Ask about destinations, food, budgets…” input box.<br>2. Type the message.<br>3. Tap the send button. |
| **Test Data** | Message: `Best food in Ilocos?` |
| **Expected Result** | 1. The message is shown on the right side and the input box is cleared.<br>2. The assistant answers about Ilocos food within a reasonable time.<br>3. No error text or blank reply is shown. |

### Negative / Error Path Test Case: Off-Topic Question Is Politely Redirected

**Related Scenario:** TS-09

| Field | Details |
|---|---|
| **Test Case ID** | TC_CHAT_002 |
| **Title** | Off-Topic Question Is Politely Redirected |
| **Related Scenario** | TS-09 |
| **Preconditions** | 1. The TripNest PH app is installed and opens normally.<br>2. The device is connected to the internet.<br>3. The tester is signed in with a verified traveler account.<br>4. The AI Travel Assistant chat screen is open. |
| **Test Steps** | 1. Type a question unrelated to Philippine travel.<br>2. Tap the send button. |
| **Test Data** | Message: `Write me a Python program to sort numbers.` *(Invalid/Edge Data)* |
| **Expected Result** | 1. The assistant does not provide the requested program.<br>2. It politely redirects the conversation back to Philippine travel planning.<br>3. The chat screen stays usable for a follow-up question. |

### TS-10 — Verify that a user can write a review with a rating and a comment for a destination.

### Positive / Happy Path Test Case: Write a Review with a Rating and a Comment

**Related Scenario:** TS-10

| Field | Details |
|---|---|
| **Test Case ID** | TC_REV_001 |
| **Title** | Write a Review with a Rating and a Comment |
| **Related Scenario** | TS-10 |
| **Preconditions** | 1. The TripNest PH app is installed and opens normally.<br>2. The device is connected to the internet.<br>3. The tester is signed in with a verified traveler account.<br>4. The tester is on a destination details screen and has not reviewed it yet. |
| **Test Steps** | 1. Scroll to the reviews section and tap the write-review action.<br>2. In the “Write a Review” sheet, tap the 4th star.<br>3. Type the comment.<br>4. Tap the submit button. |
| **Test Data** | Rating: `4 stars`<br>Comment: `Beautiful place, clean and easy to reach.` |
| **Expected Result** | 1. The sheet closes.<br>2. The review appears in the list with the author name, 4 stars and the comment.<br>3. The place's rating and review count update. |

### Negative / Error Path Test Case: Review Submission Blocked with an Empty Comment

**Related Scenario:** TS-10

| Field | Details |
|---|---|
| **Test Case ID** | TC_REV_002 |
| **Title** | Review Submission Blocked with an Empty Comment |
| **Related Scenario** | TS-10 |
| **Preconditions** | 1. The TripNest PH app is installed and opens normally.<br>2. The device is connected to the internet.<br>3. The tester is signed in with a verified traveler account.<br>4. The “Write a Review” sheet is open on a destination the tester has not reviewed. |
| **Test Steps** | 1. Select 5 stars.<br>2. Leave the Comment field empty (or type only spaces).<br>3. Tap the submit button. |
| **Test Data** | Comment: empty / spaces only *(Invalid/Edge Data)* |
| **Expected Result** | 1. The message **“Comment is required”** appears under the field.<br>2. The review is not saved and the sheet stays open.<br>3. The place's rating and review count do not change. |

---

## Part 4: Reflection

**1. What is the difference between a Test Scenario and a Test Case?**

A Test Scenario is a high-level statement of *what* should be tested. It describes a feature or user goal in broad terms (for example, "Verify that a user can generate an AI itinerary using valid planner inputs"). A Test Case is a detailed, step-by-step set of instructions derived from a scenario. It states the preconditions, test steps, test data, and expected result, so it answers *how* to test and *what exact outcome* to expect. One scenario usually produces several test cases. TS-02 alone produces a positive case (valid inputs, TC_PLAN_001) and a negative case (no destination selected, TC_PLAN_002).

**2. Why is it important to create Test Cases before performing software testing?**

Writing test cases first makes testing systematic, repeatable, and objective. Each tester knows what to do, what data to use, and what result counts as a pass, so results do not depend on memory or guesswork. Test cases also expose gaps early. While writing TC_PLAN_002, for example, we had to decide what the app should do when no destination is chosen. The code disables the Generate Itinerary button and shows "Select a destination to continue" instead of showing an error after a tap, so a tester who expects an error message might wrongly report a defect. Writing the expected result first makes that behavior explicit. The cases can be reused for regression testing after every change, help estimate the testing effort, and ensure both positive and negative paths are covered.

**3. Which part of the activity was the most challenging and why?**

The most challenging part was designing the negative test cases. A happy path is easy to describe because there is one expected flow, but a negative case requires choosing data that is invalid in a *meaningful* way and stating exactly how the app should react. For the planner, the app prevents the mistake by disabling the Generate Itinerary button and showing a hint instead of an error message, so the expected result had to describe that behavior precisely. For search, the tester must be sure the keyword matches nothing at all, including live Google Places results, and the app must show a helpful empty state instead of an error. Writing these expected results demanded a closer understanding of the app's validation and error handling than the positive cases did.

---

## Traceability to the Full TripNest Test Suite

These activity cases are condensed from the full test documentation in this folder ([TripNest_Test_Documentation.md](TripNest_Test_Documentation.md) and [TripNest_Test_Cases_Master.csv](TripNest_Test_Cases_Master.csv)).

| Activity ID | Master ID | Master Scenario / Test Case |
|---|---|---|
| TS-01 | TS-EXP-002, TS-EXP-003 | Explore filters narrow results; filter combination matches nothing |
| TS-02 | TS-PLAN-001, TS-PLAN-002 | Generate an AI itinerary with valid choices; Generate blocked until a destination is selected |
| TS-03 | TS-SRCH-001, TS-SRCH-003 | Live search results; empty, no-result, and edge input |
| TS-04 | TS-FAV-001, TS-FAV-002 | Save/unsave places; list name validation |
| TS-05 | TS-ITIN-001, TS-ITIN-004 | Save an itinerary to My Trips; save handles network failure |
| TS-06 | TS-PROF-002, TS-PROF-003 | Edit profile full name; full name validation |
| TS-07 | TS-HOME-001, TS-HOME-002 | Home screen loads its content sections; location permission handling |
| TS-08 | TS-DET-001, TS-DET-005 | Destination details (weather, map, actions); details when data is missing |
| TS-09 | TS-CHAT-001, TS-CHAT-004 | Chat with the AI Travel Assistant; behavior on unrelated questions |
| TS-10 | TS-REV-001, TS-REV-002 | Write a review; review validation (empty comment) |
| TC_EXPLORE_001 | TC-EXP-003 | Apply Explore Filters and Reset Them |
| TC_EXPLORE_002 | TC-EXP-005 | Filter Combination That Matches Nothing |
| TC_PLAN_001 | TC-PLAN-001 | Successful Itinerary Generation with Valid Inputs |
| TC_PLAN_002 | TC-PLAN-002 | Generate Itinerary Blocked Without a Destination |
| TC_SEARCH_001 | TC-SRCH-001 | Successful Search with a Valid Keyword |
| TC_SEARCH_002 | TC-SRCH-003 | Search with No Matching Results (Invalid Keyword) |
| TC_FAV_001 | TC-FAV-001 | Save and Unsave a Destination with the Bookmark Icon |
| TC_FAV_002 | TC-FAV-004 | List Name Validation (Empty and Over the Character Limit) |
| TC_ITIN_001 | TC-ITIN-002 | Save a Generated Itinerary to My Trips |
| TC_ITIN_002 | TC-ITIN-004 | Save Fails Gracefully While Offline |
| TC_PROF_001 | TC-PROF-002 | Update the Full Name Successfully |
| TC_PROF_002 | TC-PROF-003 | Full Name Validation on Edit Profile |
| TC_HOME_001 | TC-HOME-001 | Home Screen Loads Its Content Sections |
| TC_HOME_002 | TC-HOME-003 | Home Still Works When Location Permission Is Denied |
| TC_DET_001 | TC-DET-001 | Destination Details Screen Shows Its Information |
| TC_DET_002 | TC-DET-010 | Destination Details Screen Without Coordinates |
| TC_CHAT_001 | TC-CHAT-002 | Send a Chat Message and Get a Reply |
| TC_CHAT_002 | TC-CHAT-004 | Off-Topic Question Is Politely Redirected |
| TC_REV_001 | TC-REV-001 | Write a Review with a Rating and a Comment |
| TC_REV_002 | TC-REV-002 | Review Submission Blocked with an Empty Comment |

— End of Activity 1 —
