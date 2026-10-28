import 'package:flutter_test/flutter_test.dart';
import 'package:kos_manage_mobile/domain/services/maintenance_naive_bayes.dart';

void main() {
  const classifier = MaintenanceNaiveBayes();

  test('classifies a leaking pipe as plumbing', () {
    final result = classifier.predict(
      title: 'Pipa bocor',
      description: 'Air menetes dari saluran kamar mandi',
    );

    expect(result.category, 'Plumbing');
    expect(result.confidence, inInclusiveRange(0.0, 1.0));
  });

  test('classifies a short circuit as electrical', () {
    final result = classifier.predict(
      title: 'Stop kontak mati',
      description: 'Listrik konslet dan ada bau terbakar',
    );

    expect(result.category, 'Kelistrikan');
  });

  test('returns a valid category for empty text without throwing', () {
    final result = classifier.predict(title: '', description: '');

    expect(
      ['Plumbing', 'Kelistrikan', 'AC/Elektronik', 'Kebersihan', 'Furnitur'],
      contains(result.category),
    );
  });
}
