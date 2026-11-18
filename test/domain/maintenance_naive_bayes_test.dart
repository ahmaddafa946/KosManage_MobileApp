import 'package:flutter_test/flutter_test.dart';
import 'package:kos_manage_mobile/domain/services/maintenance_naive_bayes.dart';

void main() {
  const classifier = MaintenanceNaiveBayes();

  test('classifies a leaking pipe as plumbing', () {
    final result = classifier.predict(
      title: 'Pipa bocor',
      description: 'Air menetes dari saluran kamar mandi',
    );

    expect(result.category, 'plumbing');
    expect(result.needsReview, isFalse);
    expect(result.confidence, inInclusiveRange(0.0, 1.0));
  });

  test('classifies a short circuit as electrical', () {
    final result = classifier.predict(
      title: 'Stop kontak mati',
      description: 'Listrik konslet dan ada bau terbakar',
    );

    expect(result.category, 'electrical');
    expect(result.needsReview, isFalse);
  });

  test('does not assign a category when the report has no useful text', () {
    final result = classifier.predict(title: '', description: '');

    expect(result.category, 'other');
    expect(result.confidence, 0);
    expect(result.needsReview, isTrue);
  });
}
