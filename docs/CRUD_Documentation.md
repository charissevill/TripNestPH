# Week 4 — CRUD Functionality Documentation

**Project:** TripNest PH (Flutter + Firebase)
**Entity:** Saved Trip Itineraries (`saved_itineraries` Firestore collection)
**Student:** Villarama, Charisse

## 1. Data Entity

TripNest PH's AI Trip Planner generates a full day-by-day itinerary (budget
breakdown, weather outlook, recommended stays) for a destination the
traveler picks. A saved itinerary is that generated trip, bookmarked so the
traveler can come back to it later, optionally tag it with a real travel
start date, and manage it from "My Trips." Each document stores: `userId`,
`title`, `itinerary` (the full generated plan), `savedAt`, `startDate`,
`memberNames`/`collaboratorIds` (for shared trips), and `packingItems`.

## 2. Persistent Storage

- **Database:** Cloud Firestore, collection `saved_itineraries`.
- **Repository:** `lib/data/repositories/itinerary_repository.dart` is the
  only place that touches the collection — every screen goes through it.
- **Live updates:** "My Trips" is a `StreamBuilder` on `streamForUser()`, so
  Create/Update/Delete are reflected on screen immediately without a manual
  refresh.

## 3. CRUD Operations

### Create
- **UI:** the bookmark icon on `GeneratedItineraryScreen` (top action row,
  labeled "Save"). Tapping it optionally prompts for a travel start date
  before saving.
- **Logic:** `_toggleSave()` in
  `lib/presentation/ai_planner/generated_itinerary_screen.dart` calls
  `ItineraryRepository.save()`, which writes the whole generated itinerary
  as a new document.
- **Validation:** a traveler must be signed in (checked before saving); the
  start date is optional and can be added later.

### Read
- **UI:** "My Trips" under Profile (`lib/presentation/itineraries/`),
  listing every trip the signed-in traveler owns or collaborates on.
- **Logic:** `ItineraryRepository.streamForUser()` merges the traveler's own
  trips with any they've been added to as a collaborator, live.
- Empty state: "No saved trips yet — Generate an itinerary from the AI
  Planner and save it to see it here."

### Update
- **UI:** the date chip on a saved trip's `GeneratedItineraryScreen`, with
  an edit (pencil) icon — only shown to the trip's owner.
- **Logic:** `_editStartDate()` opens a date picker and calls
  `ItineraryRepository.updateStartDate()`, which updates just the
  `startDate` field. The Weather Outlook section re-fetches for the new date
  automatically.

### Delete
- **UI:** the same bookmark button (now labeled "Remove" once a trip is
  saved) opens a confirmation dialog before anything happens.
- **Logic:** `ItineraryRepository.delete()` deletes the Firestore document.

## 4. User-Friendly Interface

- One button (bookmark icon) doubles as Save/Remove depending on whether the
  trip is already saved — its label and icon change to match.
- Destructive action (remove/delete) requires an explicit confirm step
  naming the trip: `"Bohol" will be permanently removed from your saved
  trips.`
- Inline `SnackBar` confirmation on save ("Itinerary saved to your trips.")
  and on any failure (network issues, permission errors) — the traveler is
  never left guessing.
- Editing the start date is optional at every step — a trip can be saved
  and managed with no date at all.

## 5. Screenshots

| File | Operation |
|---|---|
| `crud_generated_unsaved.png` | A freshly AI-generated Bohol itinerary, not yet saved |
| `crud_create_datepicker.png` | Create — optional travel-date picker shown on Save |
| `crud_create_result.png` | Create — "Itinerary saved to your trips" confirmation |
| `crud_read_list.png` | Read — the new trip appearing live under "My Trips" |
| `crud_update_datepicker.png` | Update — editing the trip's start date |
| `crud_update_result.png` | Update — date changed to Aug 29–31, weather re-fetched |
| `crud_delete_confirm.png` | Delete — "Remove this trip?" confirmation dialog |
| `crud_delete_result.png` | Delete — "My Trips" back to the empty state after removal |
