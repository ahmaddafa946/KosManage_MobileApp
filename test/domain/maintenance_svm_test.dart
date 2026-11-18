import 'package:flutter_test/flutter_test.dart';
import 'package:kos_manage_mobile/domain/services/maintenance_svm.dart';

void main() {
  const classifier = MaintenanceSvm();

  test('classifies a leaking pipe as plumbing', () {
    final result = classifier.predict(
      title: 'Pipa bocor',
      description: 'Air menetes dari saluran kamar mandi dan keran.',
    );

    expect(result.category, 'plumbing');
    expect(result.needsReview, isFalse);
  });

  test('classifies an electrical short circuit as electrical', () {
    final result = classifier.predict(
      title: 'Stop kontak korslet',
      description: 'Kabel panas, listrik mati, dan tercium bau terbakar.',
    );

    expect(result.category, 'electrical');
    expect(result.needsReview, isFalse);
  });

  test('classifies an air conditioner issue as AC', () {
    final result = classifier.predict(
      title: 'AC tidak dingin',
      description: 'Pendingin menyala tetapi udara tidak dingin dan ada kebocoran freon.',
    );

    expect(result.category, 'AC');
    expect(result.needsReview, isFalse);
  });

  test('does not pretend to classify empty text', () {
    final result = classifier.predict(title: '  ', description: '');

    expect(result.category, 'other');
    expect(result.needsReview, isTrue);
    expect(result.marginGap, 0);
  });
}
