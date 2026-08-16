import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripnest_ph/data/repositories/business_repository.dart';
import 'package:tripnest_ph/domain/models/business.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late BusinessRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = BusinessRepository(firestore: firestore);
  });

  test('create() starts a new listing at viewCount 0', () async {
    final id = await repository.create(
      const Business(
        id: '',
        ownerId: 'owner-1',
        name: 'Test Stay',
        category: BusinessCategory.accommodation,
        description: '',
        provinceId: 'p1',
        provinceName: 'Test Province',
      ),
    );

    final doc = await firestore.collection('businesses').doc(id).get();
    expect(doc.data()!['viewCount'], 0);
  });

  test('incrementViewCount() is atomic — concurrent increments never clobber each other', () async {
    final id = await repository.create(
      const Business(
        id: '',
        ownerId: 'owner-1',
        name: 'Test Stay',
        category: BusinessCategory.accommodation,
        description: '',
        provinceId: 'p1',
        provinceName: 'Test Province',
      ),
    );

    await Future.wait([
      repository.incrementViewCount(id),
      repository.incrementViewCount(id),
      repository.incrementViewCount(id),
    ]);

    final doc = await firestore.collection('businesses').doc(id).get();
    expect(doc.data()!['viewCount'], 3);
  });

  test('incrementViewCount() on a legacy doc with no viewCount field yet starts from 0', () async {
    await firestore.collection('businesses').doc('legacy-1').set({
      'ownerId': 'owner-1',
      'name': 'Legacy Listing',
      'category': BusinessCategory.shop,
      'provinceId': 'p1',
      'provinceName': 'Test Province',
      'status': 'approved',
      // No viewCount field at all — matches a business doc created before
      // this feature existed.
    });

    await repository.incrementViewCount('legacy-1');

    final doc = await firestore.collection('businesses').doc('legacy-1').get();
    expect(doc.data()!['viewCount'], 1);
  });
}
