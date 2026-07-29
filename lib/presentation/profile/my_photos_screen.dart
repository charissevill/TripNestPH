import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/routes/route_paths.dart';
import '../../core/services/places_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/photo_exif.dart';
import '../../core/utils/photo_place_matcher.dart';
import '../../core/widgets/details/place_details_sheet.dart';
import '../../core/widgets/dialogs/confirmation_dialog.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/destination_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/repositories/trip_photo_repository.dart';
import '../../domain/models/destination.dart';
import '../../domain/models/place.dart';
import '../../domain/models/restaurant.dart';
import '../../domain/models/trip_photo.dart';

/// A candidate real place is only trusted from within this radius of the
/// photo's own GPS EXIF fix when fetching curated candidates — kept wider
/// than `photo_place_matcher.dart`'s tighter final-match radius since this
/// is just the initial "what's roughly nearby" fetch (mirrors how "Nearby
/// You" fetches a band before narrowing to a true circle).
const double _candidateFetchRadiusKm = 1;
const double _liveSearchRadiusMeters = 150;

/// Every photo the traveler has added to their "My Photos" journal, newest
/// first — see `trip_photo_repository.dart`/`photo_place_matcher.dart` for
/// how each one gets auto-tagged with a real place from its own GPS EXIF
/// data, never a fabricated guess.
class MyPhotosScreen extends StatefulWidget {
  const MyPhotosScreen({
    super.key,
    this.uidOverride,
    this.photoRepository,
    this.destinationRepository,
    this.restaurantRepository,
    this.placesService,
    this.storageService,
  });

  // Test-only overrides — production call sites never pass these (same
  // pattern as `SearchScreen`'s optional repository overrides), letting a
  // widget test inject fakes without a real Firebase Auth/Storage plugin.
  final String? uidOverride;
  final TripPhotoRepository? photoRepository;
  final DestinationRepository? destinationRepository;
  final RestaurantRepository? restaurantRepository;
  final PlacesService? placesService;
  final StorageService? storageService;

  @override
  State<MyPhotosScreen> createState() => _MyPhotosScreenState();
}

class _MyPhotosScreenState extends State<MyPhotosScreen> {
  late final TripPhotoRepository _photoRepository =
      widget.photoRepository ?? TripPhotoRepository();
  late final DestinationRepository _destinationRepository =
      widget.destinationRepository ?? DestinationRepository();
  late final RestaurantRepository _restaurantRepository =
      widget.restaurantRepository ?? RestaurantRepository();
  late final PlacesService _places = widget.placesService ?? PlacesService();
  late final StorageService _storageService =
      widget.storageService ?? StorageService();
  final ImagePicker _picker = ImagePicker();
  bool _uploading = false;

  String? get _uid =>
      widget.uidOverride ?? context.read<AuthProvider>().firebaseUser?.uid;

  Future<void> _addPhoto() async {
    final uid = _uid;
    if (uid == null) return;
    // Deliberately no `maxWidth`/resize here — image_picker's own re-encode
    // can strip EXIF on some platforms, and the GPS/capture-time tags are
    // the only thing this whole feature is built on.
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final file = File(picked.path);
      final exif = await readPhotoExif(file);
      final match = await _resolvePlace(exif.latitude, exif.longitude);

      final photoUrl = await _storageService.uploadFile(
        folder: FirestorePaths.storageTripPhotos,
        ownerId: uid,
        file: file,
      );
      await _photoRepository.create(
        TripPhoto(
          id: '',
          userId: uid,
          photoUrl: photoUrl,
          createdAt: DateTime.now(),
          takenAt: exif.takenAt,
          latitude: exif.latitude,
          longitude: exif.longitude,
          placeName: match?.name,
          matchTier: match?.tier,
          destinationId: match?.destinationId,
          restaurantId: match?.restaurantId,
          placeId: match?.placeId,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// Never throws — a failed nearby lookup just means the photo uploads
  /// untagged, same best-effort reasoning as every other Places lookup in
  /// this app.
  Future<PhotoPlaceMatch?> _resolvePlace(
    double? latitude,
    double? longitude,
  ) async {
    if (latitude == null || longitude == null) return null;
    try {
      final results = await Future.wait([
        _destinationRepository.getNearbyLatitudeBand(
          latitude: latitude,
          radiusKm: _candidateFetchRadiusKm,
        ),
        _restaurantRepository.getNearbyLatitudeBand(
          latitude: latitude,
          radiusKm: _candidateFetchRadiusKm,
        ),
        _places.searchNearby(
          latitude: latitude,
          longitude: longitude,
          includedTypes: [
            ...PlaceCategory.attractions,
            ...PlaceCategory.dining,
            ...PlaceCategory.lodging,
          ],
          radiusMeters: _liveSearchRadiusMeters,
        ),
      ]);
      return matchPhotoToPlace(
        latitude,
        longitude,
        destinations: results[0] as List<Destination>,
        restaurants: results[1] as List<Restaurant>,
        nearbyPlaces: results[2] as List<Place>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _openPhoto(TripPhoto photo) async {
    if (photo.matchTier == 'curated' && photo.destinationId != null) {
      context.push(RoutePaths.destinationDetails(photo.destinationId!));
      return;
    }
    if (photo.matchTier == 'curated' && photo.restaurantId != null) {
      context.push(RoutePaths.restaurantDetails(photo.restaurantId!));
      return;
    }
    if (photo.matchTier == 'live' && photo.placeName != null) {
      // No full Place details are stored on the photo doc itself (kept
      // lean) — re-resolve them now, biased to the photo's own coordinate,
      // the same live search this codebase already treats as cheap/cached.
      final results = await _places.searchText(
        textQuery: photo.placeName!,
        biasLatitude: photo.latitude,
        biasLongitude: photo.longitude,
        maxResultCount: 1,
      );
      if (results.isNotEmpty && mounted) {
        showPlaceDetailsSheet(
          context,
          place: results.first,
          placesService: _places,
        );
        return;
      }
    }
    if (mounted) _showFullImage(photo);
  }

  Future<void> _deletePhoto(TripPhoto photo) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Delete this photo?',
      message: 'This photo will be permanently removed from your journal.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await _photoRepository.delete(photo.id);
      await _storageService.deleteByUrl(photo.photoUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
      }
    }
  }

  void _showFullImage(TripPhoto photo) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: InteractiveViewer(
          child: CachedNetworkImage(imageUrl: photo.photoUrl),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('My Photos'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploading ? null : _addPhoto,
        child: _uploading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Symbols.add_a_photo_rounded),
      ),
      body: uid == null
          ? const EmptyStateWidget(
              icon: Symbols.person_off_rounded,
              title: 'Sign in required',
              message: 'Sign in to see your photos.',
            )
          : StreamBuilder<List<TripPhoto>>(
              stream: _photoRepository.streamForUser(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return LoadingWidget.grid();
                final photos = snapshot.data ?? const [];
                if (photos.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Symbols.photo_library_rounded,
                    title: 'No photos yet',
                    message:
                        "Upload photos from the places you visit — we'll tag the real place automatically when we can.",
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.huge,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: AppSpacing.sm,
                    mainAxisSpacing: AppSpacing.sm,
                  ),
                  itemCount: photos.length,
                  itemBuilder: (context, i) => _PhotoGridTile(
                    photo: photos[i],
                    onTap: () => _openPhoto(photos[i]),
                    onDelete: () => _deletePhoto(photos[i]),
                  ),
                );
              },
            ),
    );
  }
}

class _PhotoGridTile extends StatelessWidget {
  const _PhotoGridTile({
    required this.photo,
    required this.onTap,
    required this.onDelete,
  });

  final TripPhoto photo;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onDelete,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(imageUrl: photo.photoUrl, fit: BoxFit.cover),
            if (photo.isTagged)
              Positioned(
                left: 4,
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    photo.placeName!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            Positioned(
              top: 2,
              right: 2,
              child: InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Symbols.delete_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
