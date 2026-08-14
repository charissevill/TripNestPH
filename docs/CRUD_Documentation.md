# Week 4 — CRUD Functionality Documentation

**Project:** TripNest PH (Flutter + Firebase)
**Entity:** Traveler Reviews (`reviews` Firestore collection)
**Student:** Villarama, Charisse

## 1. Data Entity

TripNest PH lets travelers leave a review — a star rating (1–5) plus a text
comment, optionally with up to 3 photos — on any destination, restaurant, or
festival listing. A review is the entity this submission demonstrates full
CRUD against. Each review document stores: `userId`, `targetId`,
`targetType`, `authorName`, `rating`, `comment`, `photoUrls`, `createdAt`,
and `verified`.

## 2. Persistent Storage

- **Database:** Cloud Firestore, collection `reviews`. Photos (if attached)
  go to Firebase Storage; the review document stores their download URLs.
- **Repository:** `lib/data/repositories/review_repository.dart` is the only
  place that touches the `reviews` collection — every screen goes through it.
- **Live updates:** the review list is a `StreamBuilder` on
  `streamForTarget()`, so Create/Update/Delete are reflected on screen
  immediately without a manual refresh, for every user viewing that listing.

## 3. CRUD Operations

### Create
- **UI:** `lib/core/widgets/details/review_form_sheet.dart` — a bottom sheet
  with a 5-star picker, a comment field, and an optional photo picker
  (max 3 photos).
- **Logic:** `ReviewSection._writeReview()` in
  `lib/core/widgets/details/review_section.dart` builds a `Review` and calls
  `ReviewRepository.addReview()`, which uploads any photos to Storage first,
  writes the Firestore document, then recalculates the listing's aggregate
  rating.
- **Validation:** the comment is required (`Validators.required`, enforced
  via `Form`/`TextFormField`); the star rating defaults to 5 and can't go
  below 1; a traveler must be signed in (checked before the sheet opens).

### Read
- **UI:** `lib/core/widgets/details/review_list.dart`, embedded near the
  bottom of every Details screen via `ReviewSection`.
- **Logic:** `ReviewRepository.streamForTarget()` streams all
  non-hidden reviews for that listing, ordered newest-first, live.
- Empty state: "No reviews yet — be the first to share your experience."

### Update
- **UI:** the same `review_form_sheet.dart`, pre-filled with the review's
  current rating/comment (`isEditing: true`, title becomes "Edit Your
  Review", button becomes "Update Review"). Only available on a review the
  signed-in traveler owns (`isOwn` check compares `currentUserId` against
  the review's `userId`), via a three-dot menu.
- **Logic:** `ReviewRepository.updateReview()` updates `rating`, `comment`,
  and `photoUrls` on the existing document, then recalculates the aggregate
  rating.

### Delete
- **UI:** the three-dot menu's "Delete" option opens a confirmation dialog
  ("Delete this review? This can't be undone.") before anything happens.
- **Logic:** `ReviewRepository.deleteReview()` deletes the Firestore
  document, deletes any attached photos from Storage, then recalculates the
  aggregate rating.

## 4. User-Friendly Interface

- Star rating uses filled/outline icons, tappable per star.
- Inline error messages via `SnackBar` if a create/update/delete call fails
  (network issues, permission errors, etc.) — the user is never left
  guessing.
- Destructive action (delete) requires an explicit confirm step.
- Edit/Delete are only ever shown on the current user's own review; other
  travelers see a "Report" flag instead.

## 5. Screenshots

| File | Operation |
|---|---|
| `crud_read_empty.png` | Read — empty state before any review exists |
| `crud_create_form.png` | Create — filled-in review form (4★, comment) before submit |
| `crud_read_list.png` | Read — the new review appearing live in the list |
| `crud_update_form.png` | Update — the same review's edit form, rating raised to 5★ |
| `crud_update_result.png` | Update — the list reflecting the saved changes |
| `crud_delete_confirm.png` | Delete — confirmation dialog before removal |
| `crud_delete_result.png` | Delete — list back to the empty state after removal |
