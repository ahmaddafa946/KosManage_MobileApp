import 'dart:math' as math;

import 'maintenance_text_features.dart';
import 'maintenance_training_data.dart';

/// Multinomial Naive Bayes for maintenance report text.
///
/// Its score is relative to the bundled starter examples and is not a
/// calibrated probability. Keep category selection under owner control.
class MaintenanceNaiveBayes {
  const MaintenanceNaiveBayes();

  MaintenancePrediction predict({
    required String title,
    required String description,
  }) {
    final tokens = tokenizeMaintenanceText('$title $description');
    if (tokens.isEmpty) {
      return const MaintenancePrediction(
        category: 'other',
        confidence: 0,
        needsReview: true,
      );
    }

    final categories = maintenanceCategoryValues;
    final vocabulary = <String>{};
    final documentsByCategory = <String, int>{};
    final tokenCountsByCategory = <String, Map<String, int>>{};
    final totalsByCategory = <String, int>{};

    for (final example in maintenanceTrainingExamples) {
      final category = example.category;
      documentsByCategory.update(
        category,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      final counts = tokenCountsByCategory.putIfAbsent(category, () => {});
      for (final token in tokenizeMaintenanceText(example.text)) {
        vocabulary.add(token);
        counts.update(token, (count) => count + 1, ifAbsent: () => 1);
        totalsByCategory.update(
          category,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }

    final knownTokens = tokens.where(vocabulary.contains).toList(growable: false);
    if (knownTokens.isEmpty) {
      return const MaintenancePrediction(
        category: 'other',
        confidence: 0,
        needsReview: true,
      );
    }

    final logScores = <String, double>{};
    for (final category in categories) {
      final counts = tokenCountsByCategory[category]!;
      final tokenTotal = totalsByCategory[category] ?? 0;
      var score = _log(
        (documentsByCategory[category] ?? 0) /
            maintenanceTrainingExamples.length,
      );

      for (final token in knownTokens) {
        final count = counts[token] ?? 0;
        final probability = (count + 1) / (tokenTotal + vocabulary.length);
        score += _log(probability);
      }
      logScores[category] = score;
    }

    final ranked = logScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final best = ranked.first;
    final maxScore = best.value;
    final exponentialScores = ranked.map(
      (entry) => math.exp(entry.value - maxScore),
    );
    final denominator = exponentialScores.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    final relativeScore =
        denominator == 0 ? 0.0 : 1 / denominator;

    return MaintenancePrediction(
      category: best.key,
      confidence: relativeScore.clamp(0.0, 1.0).toDouble(),
      needsReview: false,
    );
  }

  static double _log(double value) => math.log(value);
}

class MaintenancePrediction {
  const MaintenancePrediction({
    required this.category,
    required this.confidence,
    this.needsReview = false,
  });

  final String category;

  /// Relative model score. This is not calibrated probability.
  final double confidence;

  /// True when the input contains no useful terms from the starter vocabulary.
  final bool needsReview;
}
