import 'dart:math' as math;

/// Lightweight Multinomial Naive Bayes classifier for maintenance reports.
///
/// Training examples are an initial illustrative seed, not a validated dataset.
/// Replace/extend them with reviewed, labelled KosManage reports before relying
/// on predictions for operational decisions.
class MaintenanceNaiveBayes {
  const MaintenanceNaiveBayes();

  static const _examples = <_TrainingExample>[
    _TrainingExample('Plumbing', 'pipa bocor air menetes saluran kamar mandi wastafel keran mampet saluran air'),
    _TrainingExample('Plumbing', 'toilet wc kloset tersumbat air tidak mengalir pembuangan bocor'),
    _TrainingExample('Plumbing', 'kran rusak shower bocor rembesan dinding kamar mandi'),
    _TrainingExample('Kelistrikan', 'listrik mati stop kontak rusak kabel putus saklar lampu tidak menyala'),
    _TrainingExample('Kelistrikan', 'konslet korsleting bau terbakar meteran listrik token'),
    _TrainingExample('Kelistrikan', 'lampu berkedip kabel panas breaker turun'),
    _TrainingExample('AC/Elektronik', 'ac tidak dingin pendingin bocor freon remote rusak'),
    _TrainingExample('AC/Elektronik', 'kipas angin mati kulkas rusak mesin berisik elektronik'),
    _TrainingExample('AC/Elektronik', 'pompa air tidak menyala motor panas'),
    _TrainingExample('Kebersihan', 'kamar kotor bau sampah saluran berbau jamur lantai berdebu'),
    _TrainingExample('Kebersihan', 'serangga kecoa tikus semut banyak kotoran'),
    _TrainingExample('Kebersihan', 'dinding berjamur lembap noda perlu dibersihkan'),
    _TrainingExample('Furnitur', 'kasur rusak meja patah kursi goyang lemari pintu rusak'),
    _TrainingExample('Furnitur', 'engsel lepas gagang pintu rusak jendela macet'),
    _TrainingExample('Furnitur', 'ranjang patah laci rusak kunci pintu'),
  ];

  MaintenancePrediction predict({
    required String title,
    required String description,
  }) {
    final tokens = _tokenize('$title $description');
    final categories = _examples.map((example) => example.category).toSet();
    final vocabulary = <String>{};
    final documentsByCategory = <String, int>{};
    final tokenCountsByCategory = <String, Map<String, int>>{};
    final totalsByCategory = <String, int>{};

    for (final example in _examples) {
      final category = example.category;
      documentsByCategory.update(category, (count) => count + 1,
          ifAbsent: () => 1);
      final counts = tokenCountsByCategory.putIfAbsent(category, () => {});
      for (final token in _tokenize(example.text)) {
        vocabulary.add(token);
        counts.update(token, (count) => count + 1, ifAbsent: () => 1);
        totalsByCategory.update(category, (count) => count + 1,
            ifAbsent: () => 1);
      }
    }

    final totalDocuments = _examples.length;
    final logScores = <String, double>{};
    for (final category in categories) {
      final counts = tokenCountsByCategory[category]!;
      final tokenTotal = totalsByCategory[category] ?? 0;
      var score = _log(
        (documentsByCategory[category] ?? 0) / totalDocuments,
      );
      for (final token in tokens) {
        final count = counts[token] ?? 0;
        final probability =
            (count + 1) / (tokenTotal + vocabulary.length);
        score += _log(probability);
      }
      logScores[category] = score;
    }

    final sorted = logScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final best = sorted.first;
    final maxScore = best.value;
    final exponentials = sorted.map((entry) => _exp(entry.value - maxScore));
    final denominator = exponentials.fold<double>(0, (sum, value) => sum + value);
    final confidence = denominator == 0 ? 0.0 : 1 / denominator;

    return MaintenancePrediction(
      category: best.key,
      confidence: confidence.clamp(0.0, 1.0).toDouble(),
    );
  }

  static List<String> _tokenize(String text) => text
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((token) => token.length > 1)
      .toList(growable: false);

  static double _log(double value) {
    // All probabilities are positive due to Laplace smoothing.
    return _naturalLog(value);
  }

  static double _naturalLog(double value) {
    // Dart core's log is provided by dart:math.
    return math.log(value);
  }

  static double _exp(double value) => math.exp(value);
}

class MaintenancePrediction {
  const MaintenancePrediction({
    required this.category,
    required this.confidence,
  });

  final String category;
  final double confidence;
}

class _TrainingExample {
  const _TrainingExample(this.category, this.text);

  final String category;
  final String text;
}
